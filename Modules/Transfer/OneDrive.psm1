# ========================================================================== #
#                      MÃ“DULO: OPERACIONES ONEDRIVE                          #
# ========================================================================== #
# PropÃ³sito: AutenticaciÃ³n y operaciones con OneDrive (API REST)             #
# Funciones:                                                                 #  
#   - Get-OneDriveAuth: AutenticaciÃ³n OAuth con captura automÃ¡tica           #
#   - Get-OneDriveFiles: Lista archivos del root de OneDrive                 #
#   - Send-OneDriveFile: Sube archivo a OneDrive                             #
#   - Receive-OneDriveFile: Descarga archivo desde OneDrive                  #
#   - Test-OneDriveConnection: Prueba completa de conexiÃ³n y operaciones     #
# ========================================================================== #

function Test-IsOneDrivePath {
    <#
    .SYNOPSIS
        Detecta si una ruta es OneDrive
    #>
    param([string]$Path)
    return $Path -match '^onedrive://|^ONEDRIVE:'
}

function Get-OneDriveAuth {
    <#
    .SYNOPSIS
        Configura autenticaciÃ³n OneDrive con OAuth o ruta local
    .OUTPUTS
        Hashtable con Email, Token, ApiUrl, LocalPath, UseLocal
    #>
    param([switch]$ForceApi)
    
    Write-Log "Iniciando configuraciÃ³n OneDrive" "INFO"
    Clear-Host
    Show-Banner -Message "CONFIGURACIÃ“N ONEDRIVE" -BorderColor "Cyan"
    
    # Buscar instalaciÃ³n local
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
        Write-Host "`nOneDrive detectado en:" -ForegroundColor Green
        Write-Host "  $oneDriveLocal" -ForegroundColor White
        Write-Host ""
        
        $opcion = Show-ConsolePopup -Title "OneDrive Local" `
            -Message "Â¿Usar instalaciÃ³n local o API?" `
            -Options @("*Usar Local", "Usar *API", "*Cancelar")
        
        if ($opcion -eq 0) {
            Write-Log "Usuario eligiÃ³ OneDrive local" "INFO"
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
    
    # ConfiguraciÃ³n API con Device Code Flow
    Show-Banner "AUTENTICACIÃ“N ONEDRIVE API" -BorderColor Cyan -TextColor White
    Write-Host "`nAutenticaciÃ³n con Microsoft Device Code Flow" -ForegroundColor Yellow
    Write-Host "Solo necesitas tu cuenta Microsoft" -ForegroundColor White
    Write-Host ""
    
    try {
        $tokenData = Get-OneDriveDeviceToken
        
        if (-not $tokenData) {
            Write-Host "`nâœ— AutenticaciÃ³n cancelada o fallida" -ForegroundColor Red
            return $null
        }
        
        # Obtener informaciÃ³n del usuario
        $headers = @{
            "Authorization" = "Bearer $($tokenData.access_token)"
            "Content-Type"  = "application/json"
        }
        
        $apiUrl = "https://graph.microsoft.com/v1.0/me/drive"
        $userInfo = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me" -Headers $headers -Method Get
        
        Write-Host "`nâœ“ AutenticaciÃ³n exitosa" -ForegroundColor Green
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
        Write-Host "`nâœ— Error de autenticaciÃ³n: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Error OneDrive: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        return $null
    }
}

function Close-BrowserWindow {
    param([int]$BrowserPID)
    
    try {
        $proc = Get-Process -Id $BrowserPID -ErrorAction SilentlyContinue
        
        if ($proc) {
            # Intentar cerrar la ventana principal
            $proc.CloseMainWindow() | Out-Null
            
            # Esperar a que cierre
            $proc | Wait-Process -Timeout 3 -ErrorAction SilentlyContinue
            
            # Si sigue abierto, forzar cierre
            if (-not $proc.HasExited) {
                Stop-Process -Id $BrowserPID -Force -ErrorAction SilentlyContinue
            }
            
            Write-Host "âœ“ Navegador cerrado" -ForegroundColor Green
            return $true
        }
    }
    catch {}
    
    return $false
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

    # Crear perfil temporal Ãºnico para forzar nueva instancia
    $tempProfile = Join-Path $env:TEMP "LlevarOAuth_$(Get-Random)"
    
    # Helper para Chromium (Chrome/Edge) con perfil temporal
    function New-ChromiumArgs {
        param(
            [string]$Url,
            [string]$TempProfile,
            [switch]$Incognito
        )

        $browserArgs = @(
            "--user-data-dir=`"$TempProfile`""
            "--no-first-run"
            "--no-default-browser-check"
            "--new-window"
        )

        if ($Incognito) {
            $browserArgs += "--incognito"
        }

        $browserArgs += "`"$Url`""

        return $browserArgs
    }

    # Chrome 64-bit
    if (Test-Path $chrome) {
        $browserArgs = New-ChromiumArgs -Url $Url -TempProfile $tempProfile -Incognito:$Incognito
        return Start-Process $chrome -ArgumentList $browserArgs -PassThru
    }
    # Chrome 32-bit
    elseif (Test-Path $chromeX86) {
        $browserArgs = New-ChromiumArgs -Url $Url -TempProfile $tempProfile -Incognito:$Incognito
        return Start-Process $chromeX86 -ArgumentList $browserArgs -PassThru
    }
    # Edge (Chromium)
    elseif (Test-Path $edge) {
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
        return Start-Process $edge -ArgumentList $browserArgs -PassThru
    }
    # Firefox
    elseif (Test-Path $firefox) {
        $browserArgs = @()
        if ($Incognito) {
            $browserArgs += "-private-window"
        }
        else {
            $browserArgs += "-new-window"
        }
        $browserArgs += "`"$Url`""
        return Start-Process $firefox -ArgumentList $browserArgs -PassThru
    }

    # Ãšltimo recurso â†’ navegador predeterminado
    return Start-Process $Url -PassThru
}

function Get-BrowserOAuthCode {
    param(
        [string]$ExpectedPrefix = "https://login.microsoftonline.com/common/oauth2/nativeclient",
        [int]$BrowserPID
    )

    Add-Type -AssemblyName UIAutomationClient
    Write-Host "Esperando redirecciÃ³n del navegador..." -ForegroundColor Cyan
    Write-Host "  PID buscado: $BrowserPID" -ForegroundColor Gray

    $timeout = (Get-Date).AddMinutes(2)    
    $checkCount = 0

    while ((Get-Date) -lt $timeout) {
        Start-Sleep -Milliseconds 500
        $checkCount++

        # Buscar todas las ventanas de Chrome/Edge (pueden ser mÃºltiples procesos)
        $browsers = Get-Process | Where-Object { 
            $_.ProcessName -match 'chrome|msedge' -and $_.MainWindowHandle -ne 0 
        }

        foreach ($browser in $browsers) {
            try {
                $ae = [System.Windows.Automation.AutomationElement]::FromHandle($browser.MainWindowHandle)
                if (-not $ae) { continue }

                $windowTitle = $ae.Current.Name
                
                # Debug cada 10 iteraciones
                if ($checkCount % 10 -eq 0) {
                    Write-Host "  Escaneando ventana PID=$($browser.Id): $windowTitle" -ForegroundColor DarkGray
                }

                # Buscar controles Edit (barra de direcciones)
                $cond = New-Object System.Windows.Automation.PropertyCondition(
                    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                    [System.Windows.Automation.ControlType]::Edit
                )

                $editList = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)

                foreach ($edit in $editList) {
                    try {
                        $vp = $edit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
                        $url = $vp.Current.Value

                        # Buscar "code=" en cualquier parte del texto
                        if ($url -and $url -match "code=([^&\s`"']+)") {
                            $code = $matches[1]
                            Write-Host "`nâœ“ CÃ³digo encontrado en PID $($browser.Id)" -ForegroundColor Green
                            Write-Host "  Ventana: $windowTitle" -ForegroundColor Gray
                            Write-Host "  CÃ³digo: $code" -ForegroundColor Green
                            
                            # Cerrar esta ventana especÃ­fica
                            try {
                                $browser.CloseMainWindow() | Out-Null
                                Start-Sleep -Milliseconds 500
                                if (-not $browser.HasExited) {
                                    Stop-Process -Id $browser.Id -Force -ErrorAction SilentlyContinue
                                }
                                Write-Host "âœ“ Navegador cerrado" -ForegroundColor Green
                            }
                            catch {}
                            
                            return $code
                        }
                    }
                    catch {}
                }
            }
            catch {}
        }
    }

    Write-Host "`nâœ— No se pudo capturar el cÃ³digo (timeout despuÃ©s de $checkCount intentos)" -ForegroundColor Red
    return $null
}

function Get-OneDriveDeviceToken {
    <#
    .SYNOPSIS
        AutenticaciÃ³n OAuth con captura automÃ¡tica del cÃ³digo desde el navegador
    .DESCRIPTION
        Abre el navegador para autenticar y captura automÃ¡ticamente el cÃ³digo de la URL
    .OUTPUTS
        Hashtable con access_token, refresh_token, expires_in
    #>
    
    $clientId = "a9279514-9d58-4233-989a-cf21e5ea6bf1"
    $redirectUri = "https://login.microsoftonline.com/common/oauth2/nativeclient"
    $scope = "offline_access Files.ReadWrite.All User.Read"
    
    try {
        Write-Host ""
        Write-Host "â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—" -ForegroundColor Cyan
        Write-Host "â•‘        AUTENTICACIÃ“N INTERACTIVA MICROSOFT ONEDRIVE            â•‘" -ForegroundColor Cyan
        Write-Host "â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£" -ForegroundColor Cyan
        Write-Host "â•‘  1. Se abrirÃ¡ el navegador para iniciar sesiÃ³n                 â•‘" -ForegroundColor White
        Write-Host "â•‘  2. Autoriza el acceso a OneDrive                              â•‘" -ForegroundColor White
        Write-Host "â•‘  3. El cÃ³digo se capturarÃ¡ automÃ¡ticamente                     â•‘" -ForegroundColor White
        Write-Host "â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•" -ForegroundColor Cyan
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
        
        Write-Host "Abriendo navegador para autenticaciÃ³n..." -ForegroundColor Yellow
        Write-Host "  (Usando perfil temporal para nueva instancia)" -ForegroundColor Gray
        
        $browserProc = Start-Browser -Url $authUri
        
        if ($browserProc -and $browserProc.Id) {
            $browserPID = $browserProc.Id
            Write-Host "âœ“ Navegador iniciado (PID: $browserPID)" -ForegroundColor Green
            Start-Sleep -Seconds 3  # Dar tiempo a que cargue la ventana
            
            # Capturar cÃ³digo (ahora busca en TODAS las ventanas de Chrome/Edge)
            $code = Get-BrowserOAuthCode -BrowserPID $browserPID
        }
        else {
            Write-Host "âš  No se pudo obtener el PID del navegador" -ForegroundColor Yellow
            $code = $null
        }
        
        # Si no se capturÃ³ automÃ¡ticamente, pedir manualmente
        if (-not $code) {
            Write-Host "`nâš  No se capturÃ³ automÃ¡ticamente. Por favor copia el cÃ³digo:" -ForegroundColor Yellow
            Write-Host "Busca en la barra de direcciones del navegador: code=..." -ForegroundColor Gray
            $code = Read-Host "Pega el cÃ³digo aquÃ­"
            
            if (-not $code) {
                Write-Host "`nâœ— No se ingresÃ³ cÃ³digo" -ForegroundColor Red
                return $null
            }
            
            $code = $code -replace '^code=', '' -replace '\s', ''
        }

        if ($code.Length -lt 10) {
            Write-Host "`nâœ— CÃ³digo invÃ¡lido (muy corto)" -ForegroundColor Red
            return $null
        }
        
        Write-Host "`nâœ“ Obteniendo token de acceso..." -ForegroundColor Green
        
        $tokenUrl = "https://login.microsoftonline.com/consumers/oauth2/v2.0/token"
        $tokenParams = @{
            client_id    = $clientId
            redirect_uri = $redirectUri
            code         = $code
            grant_type   = "authorization_code"
        }
        
        $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenParams -ErrorAction Stop
        
        if ($response.access_token) {
            Write-Host "âœ“ Â¡AutenticaciÃ³n exitosa!" -ForegroundColor Green
            return @{
                access_token  = $response.access_token
                refresh_token = $response.refresh_token
                expires_in    = $response.expires_in
            }
        }
        else {
            Write-Host "âœ— No se pudo obtener el token" -ForegroundColor Red
            return $null
        }
    }
    catch {
        Write-Host "`nâœ— Error en autenticaciÃ³n: $($_.Exception.Message)" -ForegroundColor Red
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
        Write-Host "âœ— Error listando archivos: $($_.Exception.Message)" -ForegroundColor Red
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
        Write-Host "âœ— Error subiendo archivo: $($_.Exception.Message)" -ForegroundColor Red
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
        Write-Host "âœ— Error descargando archivo: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-OneDriveConnection {
    <#
    .SYNOPSIS
        Prueba completa de conexiÃ³n y operaciones con OneDrive
    .PARAMETER OneDriveConfig
        ConfiguraciÃ³n de OneDrive con Token
    #>
    param([hashtable]$OneDriveConfig)
    
    try {
        Write-Host "`nâ•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—" -ForegroundColor Cyan
        Write-Host "â•‘  PRUEBA DE CONEXIÃ“N Y OPERACIONES   â•‘" -ForegroundColor Cyan
        Write-Host "â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•" -ForegroundColor Cyan
        Write-Host ""
        
        $token = $OneDriveConfig.Token
        
        # 1. Listar archivos del root
        Write-Host "[1/3] Listando archivos en OneDrive raÃ­z..." -ForegroundColor Yellow
        $files = Get-OneDriveFiles -Token $token
        
        if ($files) {
            Write-Host "âœ“ Archivos encontrados: $($files.Count)" -ForegroundColor Green
            foreach ($file in $files | Select-Object -First 10) {
                $icon = if ($file.folder) { "ðŸ“" } else { "ðŸ“„" }
                $size = if ($file.size) { " ($([Math]::Round($file.size/1KB, 2)) KB)" } else { "" }
                Write-Host "  $icon $($file.name)$size" -ForegroundColor Gray
            }
            if ($files.Count -gt 10) {
                Write-Host "  ... y $($files.Count - 10) mÃ¡s" -ForegroundColor DarkGray
            }
        }
        else {
            Write-Host "âœ— No se pudieron listar archivos" -ForegroundColor Red
            return $false
        }
        
        # 2. Crear archivo de prueba y subirlo
        Write-Host "`n[2/3] Creando y subiendo archivo de prueba..." -ForegroundColor Yellow
        
        $testFileName = "LLEVAR_Test_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $tempFile = Join-Path $env:TEMP $testFileName
        $testContent = @"
â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
â•‘     ARCHIVO DE PRUEBA - LLEVAR         â•‘
â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Usuario: $($OneDriveConfig.Email)
Sistema: $env:COMPUTERNAME

Este archivo fue creado automÃ¡ticamente
para probar la conexiÃ³n con OneDrive.

âœ“ Subida exitosa
"@
        
        [System.IO.File]::WriteAllText($tempFile, $testContent, [System.Text.Encoding]::UTF8)
        Write-Host "  Archivo temporal creado: $testFileName" -ForegroundColor Gray
        
        $uploadResult = Send-OneDriveFile -Token $token -LocalPath $tempFile -RemoteFileName $testFileName
        
        if ($uploadResult) {
            Write-Host "âœ“ Archivo subido a OneDrive: $testFileName" -ForegroundColor Green
            Write-Host "  (El archivo permanecerÃ¡ en OneDrive para verificaciÃ³n)" -ForegroundColor Gray
        }
        else {
            Write-Host "âœ— Error subiendo archivo" -ForegroundColor Red
            return $false
        }
        
        # 3. Descargar el archivo
        Write-Host "`n[3/3] Descargando archivo desde OneDrive..." -ForegroundColor Yellow
        
        $downloadPath = "C:\Temp"
        if (-not (Test-Path $downloadPath)) {
            New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
        }
        
        $downloadFile = Join-Path $downloadPath $testFileName
        
        $downloadResult = Receive-OneDriveFile -Token $token -RemoteFileName $testFileName -LocalPath $downloadFile
        
        if ($downloadResult -and (Test-Path $downloadFile)) {
            Write-Host "âœ“ Archivo descargado correctamente" -ForegroundColor Green
            Write-Host "  UbicaciÃ³n: $downloadFile" -ForegroundColor Gray
            
            # Mostrar contenido
            Write-Host "  Contenido del archivo descargado:" -ForegroundColor Cyan
            Get-Content $downloadFile | ForEach-Object {
                Write-Host "  $_" -ForegroundColor White
            }
        }
        else {
            Write-Host "âœ— Error descargando archivo" -ForegroundColor Red
            return $false
        }
        
        # Limpiar solo el archivo temporal local (el de OneDrive queda)
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
        
        Write-Host ""
        Write-Host "ðŸ“Œ Archivo de prueba en OneDrive: $testFileName" -ForegroundColor Cyan
        Write-Host "ðŸ“‚ Archivo descargado localmente: $downloadFile" -ForegroundColor Cyan
        
        Write-Host "`nâœ“ Â¡Todas las operaciones completadas exitosamente!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "`nâœ— Error en prueba: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Test-IsOneDrivePath',
    'Get-OneDriveAuth',
    'Start-Browser',
    'Close-BrowserWindow',
    'Get-BrowserOAuthCode',
    'Get-OneDriveFiles',
    'Send-OneDriveFile',
    'Receive-OneDriveFile',
    'Test-OneDriveConnection'
)