# ========================================================================== #
#                      MÓDULO: OPERACIONES ONEDRIVE                          #
# ========================================================================== #
# Propósito: Autenticación y operaciones con OneDrive (API REST)             #
# Funciones:                                                                 #  
#   - Get-OneDriveAuth: Autenticación OAuth con captura automática           #
#   - Get-OneDriveFiles: Lista archivos del root de OneDrive                 #
#   - Send-OneDriveFile: Sube archivo a OneDrive                             #
#   - Receive-OneDriveFile: Descarga archivo desde OneDrive                  #
#   - Test-OneDriveConnection: Prueba completa de conexión y operaciones     #
# ========================================================================== #

# Imports necesarios
$ModulesPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ModulesPath "Modules\UI\Menus.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\UI\Banners.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\UI\ProgressBar.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Core\TransferConfig.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Core\Logger.psm1") -Force -Global

function Test-IsOneDrivePath {
    <#
    .SYNOPSIS
        Detecta si una ruta es OneDrive
    #>
    param([string]$Path)
    return $Path -match '^onedrive://|^ONEDRIVE:'
}

function Close-BrowserWindow {
    param(
        [int]$BrowserPID,
        [string]$ProfilePath
    )

    $closed = $false
    try {
        if ($BrowserPID) {
            $proc = Get-Process -Id $BrowserPID -ErrorAction SilentlyContinue
            if ($proc) {
                $proc.CloseMainWindow() | Out-Null
                Start-Sleep -Milliseconds 500
                if (-not $proc.HasExited) {
                    Stop-Process -Id $BrowserPID -Force -ErrorAction SilentlyContinue
                }
                $closed = $true
            }
        }
    }
    catch {}

    if ($ProfilePath -and (Test-Path $ProfilePath)) {
        try {
            Remove-Item -Path $ProfilePath -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {}
    }

    return $closed
}

function Start-Browser {
    param(
        [string]$Url,
        [switch]$Incognito
    )

    $chrome = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    $chromeX86 = "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe"
    $edge = "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe"
    $firefox = "$env:ProgramFiles\Mozilla Firefox\firefox.exe"

    $tempProfile = Join-Path $env:TEMP ("LlevarOAuth_{0}" -f ([guid]::NewGuid().ToString("N")))

    function New-ChromiumArgs {
        param(
            [string]$Url,
            [string]$TempProfile,
            [switch]$Incognito
        )

        $arguments = @(
            "--user-data-dir=`"$TempProfile`""
            "--no-first-run"
            "--no-default-browser-check"
            "--new-window"
        )

        if ($Incognito) {
            $arguments += "--incognito"
        }

        $arguments += "`"$Url`""
        return $arguments
    }

    if (Test-Path $chrome) {
        New-Item -ItemType Directory -Path $tempProfile -Force -ErrorAction SilentlyContinue | Out-Null
        $browserArgs = New-ChromiumArgs -Url $Url -TempProfile $tempProfile -Incognito:$Incognito
        $proc = Start-Process $chrome -ArgumentList $browserArgs -PassThru
        return [pscustomobject]@{ Process = $proc; ProfilePath = $tempProfile }
    }
    elseif (Test-Path $chromeX86) {
        New-Item -ItemType Directory -Path $tempProfile -Force -ErrorAction SilentlyContinue | Out-Null
        $browserArgs = New-ChromiumArgs -Url $Url -TempProfile $tempProfile -Incognito:$Incognito
        $proc = Start-Process $chromeX86 -ArgumentList $browserArgs -PassThru
        return [pscustomobject]@{ Process = $proc; ProfilePath = $tempProfile }
    }
    elseif (Test-Path $edge) {
        New-Item -ItemType Directory -Path $tempProfile -Force -ErrorAction SilentlyContinue | Out-Null
        $browserArgs = @(
            "--user-data-dir=`"$tempProfile`""
            "--no-first-run"
            "--no-default-browser-check"
            "--new-window"
        )
        if ($Incognito) {
            $browserArgs += "-inprivate"
        }
        $browserArgs += "`"$Url`""
        $proc = Start-Process $edge -ArgumentList $browserArgs -PassThru
        return [pscustomobject]@{ Process = $proc; ProfilePath = $tempProfile }
    }
    elseif (Test-Path $firefox) {
        $browserArgs = @()
        if ($Incognito) {
            $browserArgs += "-private-window"
        }
        else {
            $browserArgs += "-new-window"
        }
        $browserArgs += "`"$Url`""
        $proc = Start-Process $firefox -ArgumentList $browserArgs -PassThru
        return [pscustomobject]@{ Process = $proc; ProfilePath = $null }
    }

    $fallback = Start-Process $Url -PassThru
    return [pscustomobject]@{ Process = $fallback; ProfilePath = $null }
}

function Get-BrowserOAuthCode {
    param(
        [string]$ExpectedPrefix = "https://login.microsoftonline.com/common/oauth2/nativeclient"
    )

    Add-Type -AssemblyName UIAutomationClient

    Write-Host "Esperando redirección del navegador..." -ForegroundColor Cyan
    
    $timeout = (Get-Date).AddMinutes(2)

    while ((Get-Date) -lt $timeout) {
        Start-Sleep -Milliseconds 300

        $procs = Get-Process | Where-Object { $_.Name -in "msedge", "chrome", "firefox" }

        foreach ($p in $procs) {
            try {
                $ae = [System.Windows.Automation.AutomationElement]::FromHandle($p.MainWindowHandle)
                if (-not $ae) { continue }

                # Buscar barra de direcciones (Edit controls)
                $cond = New-Object System.Windows.Automation.PropertyCondition(
                    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                    [System.Windows.Automation.ControlType]::Edit
                )

                $editList = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)

                foreach ($edit in $editList) {
                    try {
                        $vp = $edit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
                        $url = $vp.Current.Value

                        # Buscar "code=" en la URL sin importar el prefijo exacto
                        if ($url -and $url -match "code=([^&\s]+)") {
                            $code = $matches[1]
                            Write-Host "✓ Código capturado automáticamente!" -ForegroundColor Green
                            
                            # Cerrar la pestaña/ventana del navegador
                            try {
                                $window.Quit()
                            }
                            catch {
                                # Si no se puede cerrar, intentar navegar a blank
                                try {
                                    $window.Navigate("about:blank")
                                }
                                catch {}
                            }
                            
                            return $code
                        }
                    }
                    catch {}
                }
            }
            catch {}
        }
    }

    Write-Host "✗ No se pudo capturar automáticamente el código." -ForegroundColor Red
    return $null
}

function Get-OneDriveDeviceToken {
    <#
    .SYNOPSIS
        Autenticación OAuth con captura automática del código desde el navegador
    .DESCRIPTION
        Abre el navegador para autenticar y captura automáticamente el código de la URL
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
        Start-Browser -Url $authUri
        
        $code = Get-BrowserOAuthCode -ExpectedPrefix $redirectUri
        
        if (-not $code) {
            Write-Host "Pega manualmente el código de la URL:" -ForegroundColor Yellow
            Write-Host "Busca en la barra de direcciones: code=MC543_Bl2.2U..." -ForegroundColor Gray
            $code = Read-Host "Código"
            
            if (-not $code) {
                Write-Host "✗ No se ingresó código" -ForegroundColor Red
                return $null
            }
            
            $code = $code -replace '^code=', '' -replace '\s', ''
        }
        
        if ($code.Length -lt 10) {
            Write-Host "✗ Código inválido (muy corto)" -ForegroundColor Red
            return $null
        }
        
        Write-Host "✓ Obteniendo token de acceso..." -ForegroundColor Green
        
        $tokenUrl = "https://login.microsoftonline.com/consumers/oauth2/v2.0/token"
        $tokenParams = @{
            client_id    = $clientId
            redirect_uri = $redirectUri
            code         = $code
            grant_type   = "authorization_code"
        }
        
        $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenParams -ErrorAction Stop
        
        if ($response.access_token) {
            Write-Host "✓ ¡Autenticación exitosa!" -ForegroundColor Green
            return @{
                access_token  = $response.access_token
                refresh_token = $response.refresh_token
                expires_in    = $response.expires_in
            }
        }
        else {
            Write-Host "✗ No se pudo obtener el token" -ForegroundColor Red
            return $null
        }
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
    
    # Buscar instalación local
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
    
    # Configuración API con Device Code Flow
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
        
        # Obtener información del usuario
        $headers = @{
            "Authorization" = "Bearer $($tokenData.access_token)"
            "Content-Type"  = "application/json"
        }
        
        $apiUrl = "https://graph.microsoft.com/v1.0/me/drive"
        $userInfo = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me" -Headers $headers -Method Get
        
        Write-Host "✓ Autenticación exitosa" -ForegroundColor Green
        Write-Host "  Usuario: $($userInfo.displayName)" -ForegroundColor White
        Write-Host "  Email: $($userInfo.userPrincipalName)" -ForegroundColor White
        Write-Log "OneDrive API autenticado: $($userInfo.userPrincipalName)" "INFO"
        
        return @{
            Email        = $userInfo.userPrincipalName
            Token        = $tokenData.access_token
            RefreshToken = $tokenData.refresh_token
            ApiUrl       = $apiUrl
            LocalPath    = $null
            UseLocal     = $false
        }
    }
    catch {
        Write-Host "✗ Error de autenticación: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Error OneDrive: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        return $null
    }
}

function Get-OneDriveFiles {
    <#
    .SYNOPSIS
        Lista archivos y carpetas del root de OneDrive
    .PARAMETER Token
        Token de acceso de OneDrive
    #>
    param([string]$Token)
    
    try {
        $headers = @{
            "Authorization" = "Bearer $Token"
            "Content-Type"  = "application/json"
        }
        
        $url = "https://graph.microsoft.com/v1.0/me/drive/root/children"
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        
        return $response.value
    }
    catch {
        Write-Host "✗ Error listando archivos: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Send-OneDriveFile {
    <#
    .SYNOPSIS
        Sube un archivo a OneDrive
    .PARAMETER Token
        Token de acceso
    .PARAMETER LocalPath
        Ruta local del archivo
    .PARAMETER RemoteFileName
        Nombre del archivo en OneDrive
    #>
    param(
        [string]$Token,
        [string]$LocalPath,
        [string]$RemoteFileName
    )
    
    try {
        if (-not (Test-Path $LocalPath)) {
            throw "Archivo no existe: $LocalPath"
        }
        
        $fileContent = [System.IO.File]::ReadAllBytes($LocalPath)
        
        $headers = @{
            "Authorization" = "Bearer $Token"
            "Content-Type"  = "application/octet-stream"
        }
        
        $url = "https://graph.microsoft.com/v1.0/me/drive/root:/${RemoteFileName}:/content"
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Put -Body $fileContent
        
        return $response
    }
    catch {
        Write-Host "✗ Error subiendo archivo: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Receive-OneDriveFile {
    <#
    .SYNOPSIS
        Descarga un archivo desde OneDrive
    .PARAMETER Token
        Token de acceso
    .PARAMETER RemoteFileName
        Nombre del archivo en OneDrive
    .PARAMETER LocalPath
        Ruta local donde guardar
    #>
    param(
        [string]$Token,
        [string]$RemoteFileName,
        [string]$LocalPath
    )
    
    try {
        $headers = @{
            "Authorization" = "Bearer $Token"
        }
        
        # Obtener URL de descarga
        $url = "https://graph.microsoft.com/v1.0/me/drive/root:/${RemoteFileName}"
        $fileInfo = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        
        if (-not $fileInfo.'@microsoft.graph.downloadUrl') {
            throw "No se pudo obtener URL de descarga"
        }
        
        # Descargar archivo
        $downloadUrl = $fileInfo.'@microsoft.graph.downloadUrl'
        Invoke-WebRequest -Uri $downloadUrl -OutFile $LocalPath
        
        return $true
    }
    catch {
        Write-Host "✗ Error descargando archivo: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-OneDriveConnection {
    <#
    .SYNOPSIS
        Prueba completa de conexión y operaciones con OneDrive
    .PARAMETER OneDriveConfig
        Configuración de OneDrive con Token
    #>
    param([hashtable]$OneDriveConfig)
    
    try {
        Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║  PRUEBA DE CONEXIÓN Y OPERACIONES    ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        
        $token = $OneDriveConfig.Token
        
        # 1. Listar archivos del root
        Write-Host "[1/3] Listando archivos en OneDrive raíz..." -ForegroundColor Yellow
        $files = Get-OneDriveFiles -Token $token
        
        if ($files) {
            Write-Host "✓ Archivos encontrados: $($files.Count)" -ForegroundColor Green
            foreach ($file in $files | Select-Object -First 10) {
                $icon = if ($file.folder) { "📁" } else { "📄" }
                $size = if ($file.size) { " ($([Math]::Round($file.size/1KB, 2)) KB)" } else { "" }
                Write-Host "  $icon $($file.name)$size" -ForegroundColor Gray
            }
            if ($files.Count -gt 10) {
                Write-Host "  ... y $($files.Count - 10) más" -ForegroundColor DarkGray
            }
        }
        else {
            Write-Host "✗ No se pudieron listar archivos" -ForegroundColor Red
            return $false
        }
        
        # 2. Crear archivo de prueba y subirlo
        Write-Host "[2/3] Creando y subiendo archivo de prueba..." -ForegroundColor Yellow
        
        $testFileName = "LLEVAR_Test_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $tempFile = Join-Path $env:TEMP $testFileName
        $testContent = @"
╔════════════════════════════════════════╗
║     ARCHIVO DE PRUEBA - LLEVAR         ║
╚════════════════════════════════════════╝

Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Usuario: $($OneDriveConfig.Email)
Sistema: $env:COMPUTERNAME

Este archivo fue creado automáticamente
para probar la conexión con OneDrive.

✓ Subida exitosa
"@
        
        [System.IO.File]::WriteAllText($tempFile, $testContent, [System.Text.Encoding]::UTF8)
        Write-Host "  Archivo temporal creado: $testFileName" -ForegroundColor Gray
        
        $uploadResult = Send-OneDriveFile -Token $token -LocalPath $tempFile -RemoteFileName $testFileName
        
        if ($uploadResult) {
            Write-Host "✓ Archivo subido a OneDrive: $testFileName" -ForegroundColor Green
            Write-Host "  (El archivo permanecerá en OneDrive para verificación)" -ForegroundColor Gray
        }
        else {
            Write-Host "✗ Error subiendo archivo" -ForegroundColor Red
            return $false
        }
        
        # 3. Descargar el archivo
        Write-Host "[3/3] Descargando archivo desde OneDrive..." -ForegroundColor Yellow
        
        $downloadPath = "C:\Temp"
        if (-not (Test-Path $downloadPath)) {
            New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
        }
        
        $downloadFile = Join-Path $downloadPath $testFileName
        
        $downloadResult = Receive-OneDriveFile -Token $token -RemoteFileName $testFileName -LocalPath $downloadFile
        
        if ($downloadResult -and (Test-Path $downloadFile)) {
            Write-Host "✓ Archivo descargado correctamente" -ForegroundColor Green
            Write-Host "Ubicación: $downloadFile" -ForegroundColor Gray
            
            # Mostrar contenido
            Write-Host "Contenido del archivo descargado:" -ForegroundColor Cyan
            Get-Content $downloadFile | ForEach-Object {
                Write-Host "  $_" -ForegroundColor White
            }
        }
        else {
            Write-Host "✗ Error descargando archivo" -ForegroundColor Red
            return $false
        }
        
        # Limpiar solo el archivo temporal local (el de OneDrive queda)
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
        
        Write-Host ""
        Write-Host "📌 Archivo de prueba en OneDrive: $testFileName" -ForegroundColor Cyan
        Write-Host "📂 Archivo descargado localmente: $downloadFile" -ForegroundColor Cyan
        
        Write-Host "✓ ¡Todas las operaciones completadas exitosamente!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ Error en prueba: $($_.Exception.Message)" -ForegroundColor Red
        return $false
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
    .DESCRIPTION
        Autentica con Microsoft Graph y configura la sección correspondiente.
        Asigna SOLO los valores OneDrive a:
        - $Llevar.Origen.Tipo = "OneDrive" + $Llevar.Origen.OneDrive.* si $Cual = "Origen"
        - $Llevar.Destino.Tipo = "OneDrive" + $Llevar.Destino.OneDrive.* si $Cual = "Destino"
        
        ⚠ NO PISA otros valores del objeto $Llevar
    .PARAMETER Llevar
        Objeto TransferConfig donde se guardarán SOLO los valores OneDrive
    .PARAMETER Cual
        "Origen" o "Destino" - indica qué sección configurar
    .OUTPUTS
        $true si la configuración fue exitosa, $false si se canceló
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Llevar,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Cual
    )
    
    Show-Banner "CONFIGURACIÓN ONEDRIVE - $Cual" -BorderColor Cyan -TextColor Yellow
    
    # Verificar módulo Microsoft.Graph
    if (-not (Test-MicrosoftGraphModule)) {
        Write-Host "⚠ Módulo Microsoft.Graph no instalado" -ForegroundColor Yellow
        Write-Host ""
        
        $respuesta = Show-ConsolePopup -Title "Microsoft.Graph Requerido" `
            -Message "Se requiere el módulo Microsoft.Graph para OneDrive.`n`n¿Desea instalarlo ahora?" `
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
    
    # Autenticar con OneDrive
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
        
        # Solicitar ruta OneDrive
        $onedrivePath = "/"
        if ($authResult.UseLocal -and $authResult.LocalPath) {
            $onedrivePath = $authResult.LocalPath
            Write-Host "Usando instalación local de OneDrive: $onedrivePath" -ForegroundColor Cyan
        }
        else {
            Write-Host "Ruta en OneDrive (ej: /Documentos/MiCarpeta): " -NoNewline -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Presione ENTER para usar raíz (/): " -NoNewline -ForegroundColor Gray
            $onedrivePath = Read-Host
            
            if ([string]::IsNullOrWhiteSpace($onedrivePath)) {
                $onedrivePath = "/"
            }
            elseif (-not $onedrivePath.StartsWith('/')) {
                $onedrivePath = "/$onedrivePath"
            }
        }
        
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
            -Message "Error: $errorMsg`n`n¿Desea reintentar?" `
            -Options @("*Reintentar", "*Cancelar") -Beep
        
        if ($respuesta -eq 0) {
            return Get-OneDriveConfigFromUser -Llevar $Llevar -Cual $Cual
        }
        else {
            return $false
        }
    }
    
    # Asignar solo la sección OneDrive correspondiente
    if ($Cual -eq "Origen") {
        $Llevar.Origen.Tipo = "OneDrive"
        $Llevar.Origen.OneDrive.Path = $onedrivePath
        $Llevar.Origen.OneDrive.Token = $authResult.Token
        $Llevar.Origen.OneDrive.RefreshToken = $authResult.RefreshToken
        $Llevar.Origen.OneDrive.Email = $authResult.Email
        $Llevar.Origen.OneDrive.ApiUrl = $authResult.ApiUrl
        $Llevar.Origen.OneDrive.UseLocal = $authResult.UseLocal
        $Llevar.Origen.OneDrive.LocalPath = $authResult.LocalPath
        
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
        
        Write-Log "OneDrive Destino configurado: $onedrivePath (Usuario: $($authResult.Email))" "INFO"
    }
    
    Write-Host ""
    Write-Host "✓ Configuración OneDrive guardada en \$Llevar.$Cual.OneDrive" -ForegroundColor Green
    Write-Host ""
    
    return $true
}

function Send-LlevarOneDriveFile {
    <#
    .SYNOPSIS
        Sube un archivo local a OneDrive usando la configuración de TransferConfig
    .PARAMETER Llevar
        Objeto TransferConfig con Destino.Tipo = "OneDrive" y tokens configurados
    .PARAMETER LocalPath
        Ruta local del archivo a subir
    .PARAMETER RemotePath
        Ruta remota base en OneDrive (ej: /Carpeta)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Llevar,

        [Parameter(Mandatory = $true)]
        [string]$LocalPath,

        [Parameter(Mandatory = $true)]
        [string]$RemotePath
    )

    if (-not (Test-Path $LocalPath)) {
        throw "Send-LlevarOneDriveFile: archivo local no encontrado: $LocalPath"
    }

    $oneDriveConfig = $Llevar.Destino.OneDrive
    $token = $oneDriveConfig.Token
    $useLocal = $oneDriveConfig.UseLocal
    $localRoot = $oneDriveConfig.LocalPath

    # Soporte para instalación local de OneDrive (sin API)
    if ($useLocal -and $localRoot) {
        $remoteFolder = if ([string]::IsNullOrWhiteSpace($RemotePath)) { "/" } else { $RemotePath }
        if (-not $remoteFolder.StartsWith('/')) {
            $remoteFolder = "/$remoteFolder"
        }
        $remoteFolder = $remoteFolder.Replace('//', '/')

        $targetFolder = if ($remoteFolder -eq "/") { $localRoot } else { Join-Path $localRoot $remoteFolder.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar) }
        if (-not (Test-Path $targetFolder)) {
            New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
        }

        $fileName = [System.IO.Path]::GetFileName($LocalPath)
        $targetPath = Join-Path $targetFolder $fileName
        Copy-Item -Path $LocalPath -Destination $targetPath -Force
        Write-Log "Archivo copiado a OneDrive local: $targetPath" "INFO"
        return $true
    }

    if (-not $token) {
        throw "Send-LlevarOneDriveFile: falta Token en Destino.OneDrive"
    }

    # Normalizar ruta remota (evitar //)
    $remoteFolder = $RemotePath
    if (-not $remoteFolder.StartsWith('/')) {
        $remoteFolder = "/$remoteFolder"
    }
    $remoteFolder = $remoteFolder.Replace('//', '/')

    $fileName = [System.IO.Path]::GetFileName($LocalPath)
    $uploadUrl = "https://graph.microsoft.com/v1.0/me/drive/root:${remoteFolder}/${fileName}:/content"
    $uploadHeaders = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/octet-stream"
    }

    $fileContent = [System.IO.File]::ReadAllBytes($LocalPath)

    Invoke-RestMethod -Uri $uploadUrl -Headers $uploadHeaders -Method Put -Body $fileContent | Out-Null
    return $true
}

function Copy-LlevarLocalToOneDrive {
    <#
    .SYNOPSIS
        Copia archivos locales a OneDrive con progreso
    .DESCRIPTION
        DELEGADO AL DISPATCHER UNIFICADO
    .PARAMETER Llevar
        Objeto TransferConfig completo
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Llevar,
        
        [datetime]$StartTime = (Get-Date),
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )
    
    # DELEGAR AL DISPATCHER
    Write-Log "Copy-LlevarLocalToOneDrive: Delegando al dispatcher unificado" "INFO"
    
    $ModulesPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $dispatcherPath = Join-Path $ModulesPath "Modules\Transfer\Unified.psm1"
    if (-not (Get-Command Invoke-TransferDispatcher -ErrorAction SilentlyContinue)) {
        Import-Module $dispatcherPath -Force -Global
    }
    
    return Invoke-TransferDispatcher -Llevar $Llevar `
        -ShowProgress $ShowProgress -ProgressTop $ProgressTop
}

function Copy-LlevarOneDriveToLocal {
    <#
    .SYNOPSIS
        Descarga archivos desde OneDrive a local con progreso
    .DESCRIPTION
        DELEGADO AL DISPATCHER UNIFICADO
    .PARAMETER Llevar
        Objeto TransferConfig completo
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Llevar,
        
        [datetime]$StartTime = (Get-Date),
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )
    
    # DELEGAR AL DISPATCHER
    Write-Log "Copy-LlevarOneDriveToLocal: Delegando al dispatcher unificado" "INFO"
    
    $ModulesPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $dispatcherPath = Join-Path $ModulesPath "Modules\Transfer\Unified.psm1"
    if (-not (Get-Command Invoke-TransferDispatcher -ErrorAction SilentlyContinue)) {
        Import-Module $dispatcherPath -Force -Global
    }
    
    return Invoke-TransferDispatcher -Llevar $Llevar `
        -ShowProgress $ShowProgress -ProgressTop $ProgressTop
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Test-IsOneDrivePath',
    'Get-OneDriveAuth',
    'Close-BrowserWindow',
    'Start-Browser',
    'Get-BrowserOAuthCode',
    'Get-OneDriveDeviceToken',
    'Get-OneDriveFiles',
    'Send-OneDriveFile',
    'Receive-OneDriveFile',
    'Test-OneDriveConnection',
    'Test-MicrosoftGraphModule',
    'Get-OneDriveConfigFromUser',
    'Send-LlevarOneDriveFile',
    'Copy-LlevarLocalToOneDrive',
    'Copy-LlevarOneDriveToLocal'
)
