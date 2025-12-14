# ========================================================================== #
#                       MÓDULO: GESTIÓN DE NAVEGADOR                         #
# ========================================================================== #
# Propósito: Funciones reutilizables para interactuar con navegadores       #
# Casos de uso: OAuth, autenticación interactiva, captura de URLs           #
# Compatible con: Chrome, Edge, Firefox                                      #
# ========================================================================== #

# Imports necesarios
$ModulesPath = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force -Global

# Almacén simple de ventanas abiertas por tag (solo handle y t¡tulo inicial)
if (-not $script:BrowserWindows) {
    $script:BrowserWindows = @{}
}

# ========================================================================== #
# FUNCIONES DE DETECCIÓN Y CONTROL DE VENTANAS
# ========================================================================== #

function Get-BrowserWindowHandle {
    <#
    .SYNOPSIS
        Obtiene el handle de una ventana de navegador específica
    .DESCRIPTION
        Busca ventanas de navegador por tag único o devuelve la más reciente.
        Optimizado para identificación rápida sin archivos temporales.
    .PARAMETER Tag
        Tag único para identificar la ventana (opcional)
    .OUTPUTS
        PSCustomObject con Handle, ProcessId, ProcessName, Title o $null
    #>
    param(
        [string]$Tag
    )

    $browserNames = "chrome", "msedge", "firefox"

    if ($Tag -and $script:BrowserWindows.ContainsKey($Tag)) {
        $entry = $script:BrowserWindows[$Tag]
        $handle = [intptr]$entry.Handle
        $proc = Get-Process | Where-Object {
            $_.Name -in $browserNames -and $_.MainWindowHandle -eq $handle
        } | Select-Object -First 1

        if ($proc) {
            return [pscustomobject]@{
                Handle      = $proc.MainWindowHandle
                ProcessId   = $proc.Id
                ProcessName = $proc.ProcessName
                Title       = $proc.MainWindowTitle
            }
        }
    }

    # Si hay tag, buscar ventana que lo contenga en el título
    if ($Tag) {
        $window = Get-Process | Where-Object {
            $_.Name -in $browserNames -and
            $_.MainWindowHandle -ne 0 -and
            $_.MainWindowTitle -like "*$Tag*"
        } | Select-Object -First 1

        if ($window) {
            return [pscustomobject]@{
                Handle      = $window.MainWindowHandle
                ProcessId   = $window.Id
                ProcessName = $window.ProcessName
                Title       = $window.MainWindowTitle
            }
        }
    }

    # Si no hay coincidencia explícita y se buscaba por Tag, no devolver otra ventana
    if ($Tag) { return $null }

    # Si no se encuentra por tag, devolver la ventana de navegador más reciente
    # Ordenar por StartTime descendente para obtener la más nueva
    $windows = Get-Process | Where-Object {
        $_.Name -in $browserNames -and
        $_.MainWindowHandle -ne 0
    } | Sort-Object -Property { $_.StartTime } -Descending

    if ($windows) {
        $window = $windows | Select-Object -First 1
        return [pscustomobject]@{
            Handle      = $window.MainWindowHandle
            ProcessId   = $window.Id
            ProcessName = $window.ProcessName
            Title       = $window.MainWindowTitle
        }
    }

    return $null
}

function Close-BrowserWindow {
    <#
    .SYNOPSIS
        Cierra una ventana específica de navegador usando WM_CLOSE
    .DESCRIPTION
        Envía mensaje WM_CLOSE a la ventana identificada por tag único
    .PARAMETER Tag
        Tag único de la ventana a cerrar
    .OUTPUTS
        $true si se cerró exitosamente, $false si no
    #>
    param(
        [string]$Tag
    )

    if (-not ("Win32" -as [type])) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam);
}
"@
    }

    $windowInfo = Get-BrowserWindowHandle -Tag $Tag
    if (-not $windowInfo) {
        Write-Log "No se pudo encontrar ventana con tag: $Tag" "DEBUG"
        return $false
    }

    Write-Log "Cerrando ventana: $($windowInfo.Title) (PID: $($windowInfo.ProcessId))" "DEBUG"

    # Enviar WM_CLOSE a la ventana específica
    $WM_CLOSE = 0x0010
    [Win32]::PostMessage($windowInfo.Handle, $WM_CLOSE, [intptr]::Zero, [intptr]::Zero) | Out-Null

    Start-Sleep -Milliseconds 400

    # Verificar si se cerró
    $stillOpen = Get-BrowserWindowHandle -Tag $Tag

    $entry = $null
    if ($script:BrowserWindows.ContainsKey($Tag)) {
        $entry = $script:BrowserWindows[$Tag]
        $script:BrowserWindows.Remove($Tag) | Out-Null
    }

    # Limpiar HTML temporal si lo tenemos registrado
    if ($entry -and $entry.TempFile -and (Test-Path $entry.TempFile)) {
        Remove-Item $entry.TempFile -ErrorAction SilentlyContinue
    }

    return (-not $stillOpen)
}

function Get-DefaultBrowser {
    <#
    .SYNOPSIS
        Obtiene el navegador predeterminado de Windows
    .DESCRIPTION
        Lee el registro de Windows para determinar el navegador predeterminado
    .OUTPUTS
        Hashtable con Nombre, Ruta, Ejecutable o $null si no se encuentra
    #>
    
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.html\UserChoice"
        $progId = (Get-ItemProperty -Path $regPath -Name "Progid" -ErrorAction SilentlyContinue).Progid
        
        if (-not $progId) {
            $regPath = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice"
            $progId = (Get-ItemProperty -Path $regPath -Name "Progid" -ErrorAction SilentlyContinue).Progid
        }
        
        if (-not $progId) { return $null }
        
        $browserPaths = @{
            "ChromeHTML" = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe")
            "MSEdgeHTM"  = "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe"
            "FirefoxURL" = "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
            "IE.HTTP"    = "$env:ProgramFiles\Internet Explorer\iexplore.exe"
        }
        
        if ($browserPaths.ContainsKey($progId)) {
            $paths = $browserPaths[$progId]
            if ($paths -is [array]) {
                foreach ($path in $paths) {
                    if (Test-Path $path) {
                        return @{
                            Name       = $progId
                            Ruta       = $path
                            Ejecutable = Split-Path -Leaf $path
                        }
                    }
                }
            }
            elseif (Test-Path $paths) {
                return @{
                    Name       = $progId
                    Ruta       = $paths
                    Ejecutable = Split-Path -Leaf $paths
                }
            }
        }
    }
    catch {}
    
    return $null
}

# ========================================================================== #
# FUNCIONES DE LANZAMIENTO DE NAVEGADOR
# ========================================================================== #

function Start-Browser {
    <#
    .SYNOPSIS
        Lanza el navegador predeterminado con una URL específica
    .DESCRIPTION
        Abre el navegador con un tag único en la URL para identificar la ventana.
        Enfoque optimizado para OAuth sin archivos temporales.
    .PARAMETER Url
        URL a abrir en el navegador
    .PARAMETER Incognito
        Si se debe abrir en modo incógnito/privado
    .PARAMETER UseTempProfile
        Si se debe usar un perfil temporal (útil para OAuth)
    .PARAMETER Tag
        Tag único para identificar la ventana (se genera automáticamente si no se provee)
    .OUTPUTS
        PSCustomObject con BrowserPath, BrowserName, Tag, TaggedUrl
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [switch]$Incognito,
        [switch]$UseTempProfile,

        [string]$Tag = ("LLEVAR_" + (Get-Random -Minimum 100000 -Maximum 999999))
    )

    # Agregar tag único a la URL para identificación
    $separator = if ($Url -match '\?') { '&' } else { '?' }
    $taggedUrl = "$Url${separator}llevar_id=$Tag"

    # Detectar navegador predeterminado
    $default = Get-DefaultBrowser
    $browserPath = $null
    $browserName = $null

    if ($default -and (Test-Path $default.Ruta)) {
        $browserPath = $default.Ruta
        $browserName = $default.Ejecutable
    }
    else {
        # Fallback: buscar navegadores conocidos
        $candidates = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
            "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe",
            "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
        )

        foreach ($c in $candidates) {
            if (Test-Path $c) {
                $browserPath = $c
                $browserName = Split-Path -Leaf $c
                break
            }
        }
    }

    if (-not $browserPath) {
        throw "No se encontró un navegador compatible."
    }

    # Crear perfil temporal si se solicita
    $profilePath = $null
    if ($UseTempProfile) {
        $profilePath = Join-Path $env:TEMP ("LlevarBrowserProfile_" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $profilePath -Force | Out-Null
    }

    # Construir argumentos según el navegador
    $argList = @()

    $windowArg = $null

    # Crear HTML temporal con título único y redirección diferida
    $tempHtml = Join-Path $env:TEMP ("Llevar_" + $Tag + "_" + (Get-Random) + ".html")
    $htmlContent = @"
<html>
<head>
  <meta charset="utf-8">
  <title>$Tag</title>
  <script>
    setTimeout(function(){ window.location.href = '$taggedUrl'; }, 1500);
  </script>
</head>
<body>Autenticacion $Tag</body>
</html>
"@
    Set-Content -LiteralPath $tempHtml -Value $htmlContent -Encoding UTF8
    
    # CRÍTICO: Para forzar ventana nueva, se debe usar cmd /c start que crea una instancia separada
    # Esto previene que se abra como pestaña en una ventana existente
    
    if ($browserName -like "*chrome*") {
        if ($UseTempProfile) {
            $argList += "--user-data-dir=`"$profilePath`""
            $argList += "--no-first-run"
            $argList += "--no-default-browser-check"
        }
        # Agregar --new-window ANTES de incognito para forzar ventana
        $argList += "--new-window"
        $windowArg = "--new-window"
        if ($Incognito) {
            $argList += "--incognito"
        }
        # URL al final
        $argList += "`"$tempHtml`""
    }
    elseif ($browserName -like "*msedge*" -or $browserName -like "*edge*") {
        if ($UseTempProfile) {
            $argList += "--user-data-dir=`"$profilePath`""
            $argList += "--no-first-run"
            $argList += "--no-default-browser-check"
        }
        # Agregar --new-window ANTES de inprivate para forzar ventana
        $argList += "--new-window"
        $windowArg = "--new-window"
        if ($Incognito) {
            $argList += "-inprivate"
        }
        # URL al final
        $argList += "`"$tempHtml`""
    }
    elseif ($browserName -like "*firefox*") {
        if ($Incognito) {
            $argList += "-private-window"
            $windowArg = "-private-window"
        }
        else {
            $argList += "-new-window"
            $windowArg = "-new-window"
        }
        $argList += "`"$tempHtml`""
    }

    if (-not $windowArg) {
        $windowArg = "--new-window"
        $argList += $windowArg
    }

    # Construir comando completo para cmd
    $cmdArgs = "/c start `"`" `"$browserPath`" " + ($argList -join " ")
    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArgs -PassThru -WindowStyle Hidden

    # Esperar a que la ventana se cree (antes de la redirección)
    # Como usamos cmd /c start, necesitamos esperar más tiempo para que el navegador inicie
    Start-Sleep -Milliseconds 1200

    # Capturar handle por título único del HTML temporal
    # Buscar el proceso del navegador (no cmd.exe)
    $window = $null
    $browserProcessName = if ($browserName -like "*chrome*") { "chrome" } 
    elseif ($browserName -like "*msedge*" -or $browserName -like "*edge*") { "msedge" }
    elseif ($browserName -like "*firefox*") { "firefox" }
    else { "chrome" }
    
    foreach ($delay in @(0, 300, 300, 400, 500)) {
        $window = Get-Process | Where-Object {
            $_.Name -eq $browserProcessName -and 
            $_.MainWindowHandle -ne 0 -and 
            $_.MainWindowTitle -like "*$Tag*"
        } | Sort-Object StartTime -Descending | Select-Object -First 1
        if ($window) { break }
        if ($delay -gt 0) { Start-Sleep -Milliseconds $delay }
    }

    if ($window) {
        $script:BrowserWindows[$Tag] = @{
            Handle    = $window.MainWindowHandle
            Title     = $window.MainWindowTitle
            TempFile  = $tempHtml
            ProcessId = $window.Id
        }
    }
    else {
        Write-Log "No se pudo capturar ventana para tag $Tag" "WARNING"
        $script:BrowserWindows[$Tag] = @{
            Handle    = [intptr]::Zero
            Title     = $null
            TempFile  = $tempHtml
            ProcessId = $proc.Id
        }
    }

    return [pscustomobject]@{
        BrowserPath = $browserPath
        BrowserName = $browserName
        Tag         = $Tag
        TaggedUrl   = $taggedUrl
        LaunchTime  = $launchTime
    }
}

# ========================================================================== #
# FUNCIONES DE CAPTURA DE DATOS (OAUTH/URLs)
# ========================================================================== #

function Get-BrowserUrlCode {
    <#
    .SYNOPSIS
        Captura automáticamente un código desde la barra de direcciones del navegador
    .DESCRIPTION
        Usa UI Automation para inspeccionar la barra de direcciones de navegadores
        y extraer códigos OAuth. Detecta errores como /wrongplace.
        Optimizado para velocidad con intervalos de 400ms.
    .PARAMETER ExpectedPrefix
        Prefijo esperado de la URL (ej: redirect_uri)
    .PARAMETER CodeParameter
        Nombre del parámetro a extraer (por defecto: "code")
    .PARAMETER TimeoutSeconds
        Tiempo máximo de espera en segundos (por defecto 30s)
    .PARAMETER CheckIntervalMs
        Intervalo entre chequeos en milisegundos (por defecto 200ms)
    .PARAMETER Tag
        Tag único para cerrar la ventana después (no se usa para buscar)
    .OUTPUTS
        Hashtable con Code, WindowTitle, FullUrl o $null si falla/timeout
    .EXAMPLE
        $result = Get-BrowserUrlCode -ExpectedPrefix "https://localhost/callback" -CodeParameter "code"
        if ($result) { Write-Host "Código: $($result.Code)" }
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExpectedPrefix,
        
        [string]$CodeParameter = "code",
        [int]$TimeoutSeconds = 30,
        [int]$CheckIntervalMs = 200,
        [string]$Tag,
        [switch]$ShowProgress
    )

    Add-Type -AssemblyName UIAutomationClient

    $targetProcessIds = $null
    if ($Tag -and $script:BrowserWindows.ContainsKey($Tag)) {
        $targetPid = $script:BrowserWindows[$Tag].ProcessId
        if ($targetPid) { $targetProcessIds = , $targetPid }
    }

    if ($ShowProgress) {
        Write-Host "" 
        Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║  Esperando autorización en el navegador...                ║" -ForegroundColor Yellow
        Write-Host "║  Por favor, completa la autenticación                     ║" -ForegroundColor Yellow
        Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
    }
    
    Write-Log "Iniciando captura de código desde navegador (timeout: ${TimeoutSeconds}s, intervalo: ${CheckIntervalMs}ms)" "INFO"
    
    $timeout = (Get-Date).AddSeconds($TimeoutSeconds)
    $attemptCount = 0
    $maxAttempts = [math]::Ceiling($TimeoutSeconds * 1000 / $CheckIntervalMs)
    $lastProgress = 0

    while ((Get-Date) -lt $timeout -and $attemptCount -lt $maxAttempts) {
        $attemptCount++
        Start-Sleep -Milliseconds $CheckIntervalMs

        # Mostrar progreso cada 5 segundos
        if ($ShowProgress) {
            $elapsed = (Get-Date) - ($timeout.AddSeconds(-$TimeoutSeconds))
            $elapsedSeconds = [int]$elapsed.TotalSeconds
            if ($elapsedSeconds -gt $lastProgress -and $elapsedSeconds % 5 -eq 0) {
                $lastProgress = $elapsedSeconds
                $remaining = $TimeoutSeconds - $elapsedSeconds
                Write-Host "  ⏱ Esperando... ($remaining segundos restantes)" -ForegroundColor Gray
            }
        }

        try {
            # Buscar TODAS las ventanas de navegador (el tag está en la URL, no en el título)
            $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { 
                $_.Name -in @("msedge", "chrome", "firefox") -and $_.MainWindowHandle -ne 0
            }

            foreach ($p in $procs) {
                if ($targetProcessIds -and ($p.Id -notin $targetProcessIds)) { continue }
                try {
                    $ae = [System.Windows.Automation.AutomationElement]::FromHandle($p.MainWindowHandle)
                    if (-not $ae) { continue }

                    $cond = New-Object System.Windows.Automation.PropertyCondition(
                        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                        [System.Windows.Automation.ControlType]::Edit
                    )

                    $editList = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)

                    foreach ($edit in $editList) {
                        try {
                            $valuePattern = $edit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
                            if (-not $valuePattern) { continue }

                            $currentUrl = $valuePattern.Current.Value
                            
                            # Log para debugging (solo cada 20 intentos)
                            if ($attemptCount % 20 -eq 0) {
                                Write-Log "Inspeccionando URL: $($currentUrl.Substring(0, [Math]::Min(80, $currentUrl.Length)))..." "DEBUG"
                            }

                            # Detectar error wrongplace (Microsoft cambia a esta URL cuando hay problemas)
                            if ($currentUrl -and $currentUrl -match "login\.microsoftonline\.com/common/wrongplace") {
                                Write-Log "Detectado error 'wrongplace' en OAuth - autenticación fallida" "ERROR"
                                if ($ShowProgress) {
                                    Write-Host ""
                                    Write-Host "✗ Error de autenticación detectado (wrongplace)" -ForegroundColor Red
                                    Write-Host "  La sesión fue redirigida a página de error" -ForegroundColor Yellow
                                }
                                return $null
                            }

                            # Buscar el código en URLs que contengan el prefijo esperado
                            if ($currentUrl -and $currentUrl -match [regex]::Escape($ExpectedPrefix)) {
                                if ($ShowProgress) {
                                    Write-Host "" 
                                    Write-Host "✓ URL de redirección detectada" -ForegroundColor Green
                                }
                                Write-Log "URL capturada: $currentUrl" "INFO"

                                # Extraer código usando el parámetro especificado
                                $pattern = "[?&]$CodeParameter=([^&\s]+)"
                                if ($currentUrl -match $pattern) {
                                    $code = $matches[1]
                                    if ($ShowProgress) {
                                        Write-Host "✓ Código capturado automáticamente" -ForegroundColor Green
                                        Write-Host ""
                                    }
                                    return @{
                                        Code        = $code
                                        WindowTitle = $p.MainWindowTitle
                                        FullUrl     = $currentUrl
                                    }
                                }
                                else {
                                    Write-Log "URL coincide pero no se encontró parámetro '$CodeParameter'" "WARNING"
                                }
                            }
                        }
                        catch {
                            continue
                        }
                    }
                }
                catch {
                    # Ignorar errores de procesos individuales
                }
            }
        }
        catch {
            Write-Log "Error en Get-BrowserUrlCode iteración $attemptCount : $($_.Exception.Message)" "DEBUG"
        }
    }

    if ($ShowProgress) {
        Write-Host ""
        Write-Host "⚠ No se pudo capturar automáticamente el código" -ForegroundColor Yellow
        Write-Host "  (timeout: ${TimeoutSeconds}s, intentos: $attemptCount)" -ForegroundColor Gray
    }
    Write-Log "Timeout capturando código después de ${TimeoutSeconds}s y $attemptCount intentos" "WARNING"
    return $null
}

# Alias para compatibilidad con código existente
function Get-BrowserOAuthCode {
    Add-Type -AssemblyName UIAutomationClient

    # Cargar PostMessage para cerrar por HANDLE
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;

    public class WinAPI {
        [DllImport("user32.dll")]
        public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    }
"@

    Write-Host "Esperando redirección del navegador..." -ForegroundColor Cyan

    $timeout = (Get-Date).AddMinutes(2)

    while ((Get-Date) -lt $timeout) {

        # Detectar navegadores abiertos
        $browsers = Get-Process | Where-Object { $_.Name -in "chrome", "msedge", "firefox" }

        foreach ($p in $browsers) {
            try {
                if ($p.MainWindowHandle -eq 0) { continue }

                # Leer automatización UI
                $ae = [System.Windows.Automation.AutomationElement]::FromHandle($p.MainWindowHandle)
                if (-not $ae) { continue }

                # Buscar campos tipo EDIT (barra de direcciones)
                $cond = New-Object System.Windows.Automation.PropertyCondition(
                    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                    [System.Windows.Automation.ControlType]::Edit
                )

                $edits = $ae.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)

                foreach ($edit in $edits) {
                    try {
                        # Obtener ValuePattern (texto actual)
                        $vp = $edit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
                        $url = $vp.Current.Value

                        if ($url -and $url -match "code=([^&]+)") {
                            $code = $matches[1]

                            Write-Host "`n✓ Código OAuth capturado automáticamente!" -ForegroundColor Green
                            Write-Host "Código: $code" -ForegroundColor White

                            # Cerrar EXACTAMENTE como prueba.ps1 (WM_CLOSE)
                            [WinAPI]::PostMessage($p.MainWindowHandle, 0x0010, 0, 0) | Out-Null
                            Write-Host "Ventana cerrada por WM_CLOSE (handle: $($p.MainWindowHandle))" -ForegroundColor DarkGray

                            return $code
                        }
                    }
                    catch { }
                }

            }
            catch { }
        }

        Start-Sleep -Milliseconds 300
    }

    Write-Host "✗ No se pudo capturar el código automáticamente." -ForegroundColor Red
    return $null
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Get-BrowserWindowHandle',
    'Close-BrowserWindow',
    'Get-DefaultBrowser',
    'Start-Browser',
    'Get-BrowserUrlCode',
    'Get-BrowserOAuthCode'
)
