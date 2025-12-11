# ========================================================================== #
#                    MÓDULO: AUTENTICACIÓN ONEDRIVE                          #
# ========================================================================== #
# Propósito: Autenticación OAuth con OneDrive usando Device Code Flow       #
# Funciones principales:                                                     #
#   - Get-OneDriveAuth: Autenticación completa con navegador                 #
#   - Get-OneDriveDeviceToken: Device Code Flow OAuth                        #
#   - Update-OneDriveToken: Refrescar token expirado                         #
#   - Test-OneDriveToken: Validar token                                      #
# ========================================================================== #

# Imports necesarios
$ModulesPath = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
Import-Module (Join-Path $ModulesPath "Modules\UI\Menus.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\UI\Banners.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Core\Logger.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\System\Browser.psm1") -Force -Global

# ========================================================================== #
# FUNCIONES DE AUTENTICACIÓN OAUTH
# ========================================================================== #

function Update-OneDriveToken {
    <#
    .SYNOPSIS
        Actualiza el token OAuth de OneDrive cuando ha expirado
    .PARAMETER RefreshToken
        Refresh token obtenido en autenticación
    .OUTPUTS
        Hashtable con nuevo access_token, refresh_token, expires_in o $null si falla
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RefreshToken
    )

    if ([string]::IsNullOrWhiteSpace($RefreshToken)) {
        Write-Log "Update-OneDriveToken: RefreshToken vacío" "WARNING"
        return $null
    }

    try {
        $clientId = "a9279514-9d58-4233-989a-cf21e5ea6bf1"
        $tokenUrl = "https://login.microsoftonline.com/consumers/oauth2/v2.0/token"

        $tokenParams = @{
            client_id     = $clientId
            grant_type    = "refresh_token"
            refresh_token = $RefreshToken
        }

        Write-Log "Actualizando token OAuth..." "INFO"

        $response = Invoke-RestMethod -Uri $tokenUrl `
            -Method Post `
            -Body $tokenParams `
            -ContentType "application/x-www-form-urlencoded" `
            -ErrorAction Stop

        if ($response.access_token) {
            Write-Log "Token actualizado exitosamente (válido por $($response.expires_in)s)" "INFO"
            return @{
                access_token  = $response.access_token
                refresh_token = $response.refresh_token
                expires_in    = $response.expires_in
            }
        }
        else {
            Write-Log "No se obtuvo access_token en respuesta de actualización" "ERROR"
            return $null
        }
    }
    catch {
        Write-Log "Error actualizando token: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        return $null
    }
}

function Test-OneDriveToken {
    <#
    .SYNOPSIS
        Verifica si un token OAuth de OneDrive es válido
    .PARAMETER Token
        Token de acceso a verificar
    .OUTPUTS
        $true si es válido, $false si no lo es
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token
    )

    if ([string]::IsNullOrWhiteSpace($Token)) {
        Write-Log "Test-OneDriveToken: Token vacío" "WARNING"
        return $false
    }

    try {
        $headers = @{
            "Authorization" = "Bearer $Token"
            "Content-Type"  = "application/json"
        }

        $response = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me" `
            -Headers $headers `
            -Method Get `
            -ErrorAction Stop

        if ($response.id) {
            Write-Log "Token válido para usuario: $($response.userPrincipalName)" "DEBUG"
            return $true
        }
    }
    catch {
        Write-Log "Token inválido o expirado: $($_.Exception.Message)" "DEBUG"
    }

    return $false
}

function Get-OneDriveDeviceToken {
    <#
    .SYNOPSIS
        Autenticación OAuth con captura automática del código desde el navegador
    .DESCRIPTION
        Abre el navegador predeterminado para autenticar y captura automáticamente el código OAuth
    .OUTPUTS
        Hashtable con access_token, refresh_token, expires_in
    #>

    $clientId = "a9279514-9d58-4233-989a-cf21e5ea6bf1"
    $redirectUri = "https://login.microsoftonline.com/common/oauth2/nativeclient"
    $scope = "offline_access Files.ReadWrite.All User.Read"

    try {
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║        AUTENTICACIÓN INTERACTIVA MICROSOFT ONEDRIVE            ║" -ForegroundColor Cyan
        Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
        Write-Host "║  1. Se abrirá el navegador para iniciar sesión                 ║" -ForegroundColor White
        Write-Host "║  2. Autoriza el acceso a OneDrive                              ║" -ForegroundColor White
        Write-Host "║  3. El código se capturará automáticamente                     ║" -ForegroundColor White
        Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""

        # Construir URL de autenticación
        $authUrl = "https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize"
        $params = @{
            client_id     = $clientId
            redirect_uri  = $redirectUri
            response_type = "code"
            scope         = $scope
        }

        $queryString = ($params.GetEnumerator() | ForEach-Object {
                "$($_.Key)=$([System.Net.WebUtility]::UrlEncode($_.Value))"
            }) -join "&"

        $authUri = "$authUrl`?$queryString"

        Write-Host "Abriendo navegador para autenticación..." -ForegroundColor Yellow

        # Abrimos el navegador
        Start-Process $authUri | Out-Null

        # Capturar código automáticamente con la función nueva
        $code = Get-BrowserOAuthCode

        if (-not $code) {
            Write-Host ""
            Write-Host "✗ No se pudo capturar automáticamente." -ForegroundColor Red
            Write-Host "Ingrese manualmente la URL completa o el código:" -ForegroundColor Yellow

            $manual = Read-Host "Pegue aquí"

            if (-not $manual) {
                Write-Host "✗ No se ingresó nada." -ForegroundColor Red
                return $null
            }

            if ($manual -match "code=([^&\s]+)") {
                $code = $matches[1]
            }
            else {
                $code = $manual
            }

            Write-Host "✓ Código capturado manualmente." -ForegroundColor Green
        }

        # Validación mínima
        if ($code.Length -lt 10) {
            Write-Host "✗ Código inválido (muy corto)" -ForegroundColor Red
            return $null
        }

        Write-Host ""
        Write-Host "✓ Código recibido. Solicitando token..." -ForegroundColor Green

        # Solicitar token
        $tokenUrl = "https://login.microsoftonline.com/consumers/oauth2/v2.0/token"
        $tokenParams = @{
            client_id    = $clientId
            redirect_uri = $redirectUri
            code         = $code
            grant_type   = "authorization_code"
        }

        $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenParams -ErrorAction Stop

        if ($response.access_token) {
            Write-Host ""
            Write-Host "✓ ¡Autenticación exitosa!" -ForegroundColor Green
            return @{
                access_token  = $response.access_token
                refresh_token = $response.refresh_token
                expires_in    = $response.expires_in
            }
        }

        Write-Host "✗ No se pudo obtener el token" -ForegroundColor Red
        return $null
    }
    catch {
        Write-Host "✗ Error en autenticación: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}


function Get-OneDriveAuth {
    <#
    .SYNOPSIS
        Configura autenticación OneDrive con OAuth o ruta local
    .OUTPUTS
        Hashtable con Email, Token, ApiUrl, LocalPath, UseLocal
    #>
    param([switch]$ForceApi)
    
    Write-Log "Iniciando configuración OneDrive" "INFO"
    Clear-Host
    Show-Banner -Message "CONFIGURACIÓN ONEDRIVE" -BorderColor "Cyan"
    
    $oneDriveLocal = $null
    if (-not $ForceApi) {
        $possiblePaths = @(
            "$env:USERPROFILE\OneDrive",
            "$env:LOCALAPPDATA\Microsoft\OneDrive",
            "$env:OneDrive"
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $oneDriveLocal = $path
                Write-Log "OneDrive detectado: $path" "INFO"
                break
            }
        }
    }
    
    if ($oneDriveLocal) {
        Write-Host "OneDrive detectado en:" -ForegroundColor Green
        Write-Host "  $oneDriveLocal" -ForegroundColor White
        Write-Host ""
        
        $opcion = Show-ConsolePopup -Title "OneDrive Local" `
            -Message "¿Usar instalación local o API?" `
            -Options @("*Usar Local", "Usar *API", "*Cancelar")
        
        if ($opcion -eq 0) {
            Write-Log "Usuario eligió OneDrive local" "INFO"
            return @{
                Email     = $env:USERNAME + "@onedrive.com"
                Token     = $null
                ApiUrl    = $null
                LocalPath = $oneDriveLocal
                UseLocal  = $true
            }
        }
        elseif ($opcion -eq 2) {
            return $null
        }
    }
    
    Show-Banner "AUTENTICACIÓN ONEDRIVE API" -BorderColor Cyan -TextColor White
    Write-Host "Autenticación con Microsoft Device Code Flow" -ForegroundColor Yellow
    Write-Host "Solo necesitas tu cuenta Microsoft" -ForegroundColor White
    Write-Host ""
    
    try {
        $tokenData = Get-OneDriveDeviceToken
        
        if (-not $tokenData) {
            Write-Host "✗ Autenticación cancelada o fallida" -ForegroundColor Red
            return $null
        }
        
        $headers = @{
            "Authorization" = "Bearer $($tokenData.access_token)"
            "Content-Type"  = "application/json"
        }
        
        $apiUrl = "https://graph.microsoft.com/v1.0/me/drive"
        $userInfo = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me" -Headers $headers -Method Get
        $driveInfo = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/drive" -Headers $headers -Method Get
        
        Write-Host "✓ Autenticación exitosa" -ForegroundColor Green
        Write-Host "Usuario: $($userInfo.displayName)" -ForegroundColor White
        Write-Host "Email: $($userInfo.userPrincipalName)" -ForegroundColor White
        Write-Log "OneDrive API autenticado: $($userInfo.userPrincipalName)" "INFO"
        
        return @{
            Email        = $userInfo.userPrincipalName
            Token        = $tokenData.access_token
            RefreshToken = $tokenData.refresh_token
            ApiUrl       = $apiUrl
            LocalPath    = $null
            UseLocal     = $false
            DriveId      = $driveInfo.id
            RootId       = $driveInfo.root.id
        }
    }
    catch {
        Write-Host "✗ Error de autenticación: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Error OneDrive: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        return $null
    }
}

function Test-MicrosoftGraphModule {
    <#
    .SYNOPSIS
        Verifica si el módulo Microsoft.Graph está instalado
    #>
    return $null -ne (Get-Module -ListAvailable -Name Microsoft.Graph)
}

function Get-OneDriveConfigFromUser {
    <#
    .SYNOPSIS
        Solicita configuración OneDrive al usuario y la asigna directamente a $Llevar
    .PARAMETER Llevar
        Objeto TransferConfig donde se guardarán SOLO los valores OneDrive
    .PARAMETER Cual
        "Origen" o "Destino" - indica qué sección configurar
    .OUTPUTS
        $true si la configuración fue exitosa, $false si se canceló
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Llevar,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Cual
    )
    
    Show-Banner "CONFIGURACIÓN ONEDRIVE - $Cual" -BorderColor Cyan -TextColor Yellow
    
    if (-not (Test-MicrosoftGraphModule)) {
        Write-Host "⚠ Módulo Microsoft.Graph no instalado" -ForegroundColor Yellow
        Write-Host ""
        
        $respuesta = Show-ConsolePopup -Title "Microsoft.Graph Requerido" `
            -Message "Se requiere el módulo Microsoft.Graph para OneDrive. ¿Desea instalarlo ahora?" `
            -Options @("*Instalar", "*Cancelar")
        
        if ($respuesta -eq 0) {
            try {
                Write-Host "Instalando Microsoft.Graph..." -ForegroundColor Cyan
                Install-Module Microsoft.Graph -Scope CurrentUser -Force
                Write-Host "✓ Módulo instalado correctamente" -ForegroundColor Green
            }
            catch {
                Write-Host "⚠ Error instalando módulo: $($_.Exception.Message)" -ForegroundColor Red
                Write-Log "Error instalando Microsoft.Graph: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
                return $false
            }
        }
        else {
            Write-Host "Configuración OneDrive cancelada" -ForegroundColor Yellow
            return $false
        }
    }
    
    Write-Host ""
    Write-Host "Autenticando con OneDrive..." -ForegroundColor Cyan
    Write-Host "(Se abrirá el navegador para autenticación)" -ForegroundColor Gray
    Write-Host ""
    Write-Log "Intentando autenticar OneDrive para $Cual" "INFO"
    
    try {
        $authResult = Get-OneDriveAuth
        
        if (-not $authResult) {
            Write-Host "✗ Autenticación cancelada" -ForegroundColor Red
            return $false
        }
        
        Write-Host "✓ Autenticación exitosa" -ForegroundColor Green
        Write-Host ""
        
        # Importar módulo de transferencia para navegación
        $transferModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "OneDrive\OneDriveTransfer.psm1"
        Import-Module $transferModulePath -Force -Global
        
        $navigatorConfig = [pscustomobject]@{
            Token     = $authResult.Token
            UseLocal  = $authResult.UseLocal
            LocalPath = $authResult.LocalPath
            DriveId   = $authResult.DriveId
            RootId    = $authResult.RootId
        }

        try {
            if ($authResult.UseLocal -and $authResult.LocalPath) {
                Write-Host "Usando instalación local de OneDrive: $($authResult.LocalPath)" -ForegroundColor Cyan
                $onedrivePath = Select-OneDriveFolder -OneDriveConfig $navigatorConfig `
                    -Prompt "Seleccionar carpeta local de OneDrive" -InitialPath "/"
            }
            else {
                $onedrivePath = Select-OneDriveFolder -OneDriveConfig $navigatorConfig `
                    -Prompt "Seleccionar carpeta OneDrive" -InitialPath "/"
            }
        }
        catch {
            Write-Log "Navigator OneDrive error: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
            Write-Host "No se pudo navegar OneDrive: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }

        if (-not $onedrivePath) {
            Write-Host "No se seleccionó ninguna carpeta OneDrive" -ForegroundColor Yellow
            return $false
        }

        Write-Host "Ruta seleccionada: $onedrivePath" -ForegroundColor Green
        Write-Host ""
        Write-Host "✓ Ruta configurada: $onedrivePath" -ForegroundColor Green
        
    }
    catch {
        $errorMsg = $_.Exception.Message
        Show-Banner "⚠ ERROR DE AUTENTICACIÓN ONEDRIVE" -BorderColor Red -TextColor Red
        Write-Host "Error: $errorMsg" -ForegroundColor Yellow
        Write-Host ""
        Write-Log "Error autenticación OneDrive - $errorMsg" "ERROR" -ErrorRecord $_
        
        $respuesta = Show-ConsolePopup -Title "⚠ ERROR ONEDRIVE" `
            -Message "Error: $errorMsg ¿Desea reintentar?" `
            -Options @("*Reintentar", "*Cancelar") -Beep
        
        if ($respuesta -eq 0) {
            return Get-OneDriveConfigFromUser -Llevar $Llevar -Cual $Cual
        }
        else {
            return $false
        }
    }
    
    if ($Cual -eq "Origen") {
        $Llevar.Origen.Tipo = "OneDrive"
        $Llevar.Origen.OneDrive.Path = $onedrivePath
        $Llevar.Origen.OneDrive.Token = $authResult.Token
        $Llevar.Origen.OneDrive.RefreshToken = $authResult.RefreshToken
        $Llevar.Origen.OneDrive.Email = $authResult.Email
        $Llevar.Origen.OneDrive.ApiUrl = $authResult.ApiUrl
        $Llevar.Origen.OneDrive.UseLocal = $authResult.UseLocal
        $Llevar.Origen.OneDrive.LocalPath = $authResult.LocalPath
        $Llevar.Origen.OneDrive.DriveId = $authResult.DriveId
        $Llevar.Origen.OneDrive.RootId = $authResult.RootId

        Write-Log "OneDrive Origen configurado: $onedrivePath (Usuario: $($authResult.Email))" "INFO"
    }
    else {
        $Llevar.Destino.Tipo = "OneDrive"
        $Llevar.Destino.OneDrive.Path = $onedrivePath
        $Llevar.Destino.OneDrive.Token = $authResult.Token
        $Llevar.Destino.OneDrive.RefreshToken = $authResult.RefreshToken
        $Llevar.Destino.OneDrive.Email = $authResult.Email
        $Llevar.Destino.OneDrive.ApiUrl = $authResult.ApiUrl
        $Llevar.Destino.OneDrive.UseLocal = $authResult.UseLocal
        $Llevar.Destino.OneDrive.LocalPath = $authResult.LocalPath
        $Llevar.Destino.OneDrive.DriveId = $authResult.DriveId
        $Llevar.Destino.OneDrive.RootId = $authResult.RootId

        Write-Log "OneDrive Destino configurado: $onedrivePath (Usuario: $($authResult.Email))" "INFO"
    }
    
    Write-Host ""
    Write-Host "✓ Configuración OneDrive guardada en \$Llevar.$Cual.OneDrive" -ForegroundColor Green
    Write-Host ""
    
    return $true
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Update-OneDriveToken',
    'Test-OneDriveToken',
    'Get-OneDriveDeviceToken',
    'Get-OneDriveAuth',
    'Test-MicrosoftGraphModule',
    'Get-OneDriveConfigFromUser'
)
