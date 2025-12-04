# *********************************************************************************************
# SE MANTIENE POR COMPATIBILIDAD CON LA TERCERA EDAD LO VIEJO SIRVE JUAN ehhhhhh ALEJANDRO xD #
# ********************************************************************************************* 
# Con el mayor de los respetos, para alguien por el que siempre senti mucha admiración, a modo homenaje, 
# espero que te guste esta loca vuelta de tuercaal mítico LLEVAR.BAT que tanto me ayudó en mis comienzos con 
#MS-DOS y me guio por este hermoso camino que me  ha dado de comer por tanto tiempo


# *** Versión 1.83 del LLEVAR, por Alex Soft ***
# *** Compatible con Windows 2000 / ARJ32 ***
# *** Hasta 30 diskettes / Nueva instalación ***
# *** Arreglado por fin el problema al instalar ***
# *** Ahora con soporte para volver a llevar ***
# *** Borrado DOBLE de diskettes en Windows 2000 ***

# Este BAT fue creado durante el transcurso de un curso de DOS,
# y con el único propósito de explicar la utilización de diversos comandos.
# Por esa razón fue modificado numerosas veces durante las clases y en
# muchas otras ocasiones.

# Esa es la razón o "excusa" para justificar la desprolijidad del código >;-)

# No obstante, creo que esta pequeña utilidad es LO MEJOR para transportar
# cosas que ocuparían más de 1 diskette. Eso sí, tiene un límite de 30 diskettes,
# pero te avisa ANTES si te pasás.

# Los archivos necesarios son:
#   - LLEVAR.BAT
#   - ASK.EXE
#   - ARJ.EXE
#   - ARJ32.EXE

<#
.SYNOPSIS
    LLEVAR-USB - Sistema de transporte de carpetas en múltiples dispositivos USB
    Versión PowerShell moderna del clásico LLEVAR.BAT de Alex Soft

.DESCRIPTION
    LLEVAR-USB permite transportar carpetas grandes dividiéndolas en múltiples bloques
    que pueden distribuirse en varios dispositivos USB. Es ideal cuando:
    - La carpeta es muy grande para un solo USB
    - No hay conexión a internet/red para transferir archivos
    - Se necesita una solución portable y sin instalación

    FLUJO DE TRABAJO:
    
    === EN LA MÁQUINA ORIGEN ===
    1. El programa comprime la carpeta origen en un archivo .7z (o .zip si usa compresión nativa)
    2. Divide el archivo comprimido en bloques numerados: .alx0001, .alx0002, .alx0003, etc.
    3. Cada bloque tiene el tamaño especificado (por defecto 10 MB, configurable)
    4. Va solicitando dispositivos USB uno por uno
    5. Copia los bloques secuencialmente en cada USB según espacio disponible
    6. Genera un script INSTALAR.ps1 personalizado con:
       - Ruta de destino recomendada
       - Tipo de compresión usado (7-Zip o ZIP nativo)
       - Lógica de reconstrucción automática
    7. Copia INSTALAR.ps1 en la PRIMERA USB
    8. Marca la ÚLTIMA USB con un archivo __EOF__ (End Of Files)
    
    ALTERNATIVA: GENERACIÓN DE IMÁGENES ISO
    - Si se especifica -Iso, genera imágenes ISO en lugar de copiar a USBs
    - Soporta CD (700MB), DVD (4.5GB) o USB (4.5GB)
    - Si el contenido excede la capacidad del medio, divide en múltiples volúmenes:
      * VOL01.iso, VOL02.iso, VOL03.iso, etc.
      * El instalador está en VOL01
      * El marcador __EOF__ está en el último volumen
    - Misma lógica de distribución que con USBs físicos

    === EN LA MÁQUINA DESTINO ===
    1. Insertar la primera USB (la que tiene INSTALAR.ps1)
    2. Ejecutar .\INSTALAR.ps1 con PowerShell
    3. El instalador busca bloques en el USB actual
    4. Va pidiendo los siguientes USB hasta encontrar __EOF__
    5. Reconstruye el archivo comprimido desde los bloques
    6. Descomprime usando 7-Zip o ZIP nativo según corresponda
    7. Deja la carpeta restaurada en el destino especificado

    MÉTODOS DE COMPRESIÓN:
    
    [7-ZIP] (Recomendado)
    - Busca 7-Zip en: PATH → directorio script → rutas estándar → descarga portable
    - Mejor compresión que ZIP
    - Soporta contraseñas/encriptación
    - Puede crear volúmenes divididos nativamente
    
    [ZIP NATIVO] (Fallback automático o forzado)
    - Usa API de Windows (System.IO.Compression)
    - Requiere Windows 10 o superior
    - NO soporta contraseñas
    - Comprime en un solo archivo y luego lo divide en bloques
    - No requiere software adicional en destino

    LOGS:
    - Solo se generan en caso de error
    - Ubicación: %TEMP%\LLEVAR_ERROR.log (origen) y %TEMP%\INSTALAR_ERROR.log (destino)

.NOTES
    Autor: Basado en LLEVAR.BAT de Alex Soft
    Versión PowerShell modernizada con soporte ZIP nativo
#>

param(
    [string]$Origen,
    [string]$Destino,
    [int]$BlockSizeMB = 10,
    [string]$Clave,
    [pscredential]$SourceCredentials,
    [pscredential]$DestinationCredentials,
    [switch]$Iso,
    [ValidateSet("usb", "cd", "dvd")]
    [string]$IsoDestino = "dvd",
    [switch]$UseNativeZip,
    [switch]$Ejemplo,
    [switch]$Instalar,
    [Alias('h')]
    [switch]$Ayuda,
    [switch]$OnedriveOrigen,
    [switch]$OnedriveDestino,
    [switch]$DropboxOrigen,
    [switch]$DropboxDestino,
    [switch]$RobocopyMirror,
    [switch]$Verbose
)

# ========================================================================== #
#                          FUNCIONES DE INSTALACIÓN                          #
# ========================================================================== #

function Test-IsRunningInIDE {
    <#
    .SYNOPSIS
        Detecta si el script se está ejecutando en un IDE o modo debug
    .DESCRIPTION
        Verifica si el host es VSCode, PowerShell ISE, Visual Studio u otro IDE
    #>
    
    $hostName = $host.Name
    
    # Detectar IDEs conocidos
    $ideHosts = @(
        'Visual Studio Code Host',
        'Windows PowerShell ISE Host',
        'PowerShell ISE Host',
        'Visual Studio Host',
        'JetBrains Rider',
        'Default Host'  # Host genérico usado por muchos IDEs
    )
    
    # Verificar por nombre de host
    foreach ($ide in $ideHosts) {
        if ($hostName -like "*$ide*") {
            return $true
        }
    }
    
    # Verificar variables de entorno de VSCode
    if ($env:VSCODE_PID -or $env:TERM_PROGRAM -eq 'vscode') {
        return $true
    }
    
    # Verificar si está en modo debug
    if ($PSDebugContext) {
        return $true
    }
    
    # Verificar proceso padre (VSCode, Code.exe)
    try {
        $parentProcess = (Get-Process -Id $PID).Parent
        if ($parentProcess) {
            $parentName = $parentProcess.ProcessName
            if ($parentName -match 'code|devenv|rider|powershell_ise') {
                return $true
            }
        }
    }
    catch {
        # Ignorar errores al obtener proceso padre
    }
    
    return $false
}

function Install-LlevarToSystem {
    <#
    .SYNOPSIS
        Instala el script Llevar.ps1 en C:\Llevar con 7-Zip y lo agrega al PATH
    #>
    param(
        [switch]$Silent
    )
    
    $installPath = "C:\Llevar"
    $scriptSource = $PSCommandPath
    $scriptName = Split-Path $scriptSource -Leaf
    
    Write-Host ""
    Show-Banner -Message "INSTALACIÓN DE LLEVAR EN EL SISTEMA" -BorderColor Cyan -TextColor Yellow
    Write-Host ""
    Write-Host "Esto instalará:" -ForegroundColor White
    Write-Host "  • Script Llevar.ps1 en C:\Llevar" -ForegroundColor Gray
    Write-Host "  • 7-Zip portable (si está disponible o se descarga)" -ForegroundColor Gray
    Write-Host "  • Agregará C:\Llevar al PATH del sistema" -ForegroundColor Gray
    Write-Host ""
    
    # Crear carpeta C:\Llevar si no existe
    if (-not (Test-Path $installPath)) {
        try {
            New-Item -ItemType Directory -Path $installPath -Force | Out-Null
            Write-Host "✓ Carpeta creada: $installPath" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Error al crear carpeta: $_" -ForegroundColor Red
            return $false
        }
    }
    else {
        Write-Host "✓ Carpeta ya existe: $installPath" -ForegroundColor Green
    }
    
    # Copiar el script
    try {
        $destScript = Join-Path $installPath $scriptName
        Copy-Item -Path $scriptSource -Destination $destScript -Force
        Write-Host "✓ Script copiado: $destScript" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Error al copiar script: $_" -ForegroundColor Red
        return $false
    }
    
    # Buscar archivos de 7-Zip en la carpeta actual
    $currentDir = Split-Path $scriptSource -Parent
    $sevenZipFiles = @(
        "7z.exe", "7z.dll", "7za.exe",
        "7zCon.sfx", "7zS2.sfx", "7zS2con.sfx", "7zSD.sfx"
    )
    
    $foundFiles = @()
    foreach ($file in $sevenZipFiles) {
        $sourcePath = Join-Path $currentDir $file
        if (Test-Path $sourcePath) {
            $foundFiles += $sourcePath
        }
    }
    
    if ($foundFiles.Count -gt 0) {
        Write-Host "`nCopiando archivos de 7-Zip encontrados..." -ForegroundColor Cyan
        foreach ($file in $foundFiles) {
            try {
                $fileName = Split-Path $file -Leaf
                Copy-Item -Path $file -Destination (Join-Path $installPath $fileName) -Force
                Write-Host "  ✓ $fileName" -ForegroundColor Green
            }
            catch {
                Write-Host "  ✗ Error al copiar $fileName" -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host "`n⚠ No se encontraron archivos de 7-Zip en la carpeta actual" -ForegroundColor Yellow
        Write-Host "  Se intentará descargar 7-Zip portable..." -ForegroundColor Gray
        
        # Intentar descargar 7-Zip
        try {
            $7zUrl = "https://www.7-zip.org/a/7zr.exe"
            $7zDest = Join-Path $installPath "7z.exe"
            
            Write-Host "  Descargando desde $7zUrl..." -ForegroundColor Gray
            Invoke-WebRequest -Uri $7zUrl -OutFile $7zDest -UseBasicParsing
            
            if (Test-Path $7zDest) {
                Write-Host "  ✓ 7-Zip descargado exitosamente" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "  ✗ No se pudo descargar 7-Zip: $_" -ForegroundColor Yellow
            Write-Host "  El script funcionará con compresión ZIP nativa" -ForegroundColor Gray
        }
    }
    
    # Agregar al PATH del sistema
    try {
        $currentPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        
        if ($currentPath -notlike "*$installPath*") {
            $newPath = $currentPath + ";" + $installPath
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'Machine')
            
            # También actualizar PATH de la sesión actual
            $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
            
            Write-Host "`n✓ C:\Llevar agregado al PATH del sistema" -ForegroundColor Green
        }
        else {
            Write-Host "`n✓ C:\Llevar ya está en el PATH del sistema" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "`n✗ Error al modificar PATH (requiere permisos de administrador): $_" -ForegroundColor Red
        Write-Host "  Puede agregar manualmente C:\Llevar al PATH" -ForegroundColor Yellow
    }
    
    # Copiar e instalar archivo .inf para menú contextual
    Write-Host "`nInstalando menú contextual 'Llevar A...'..." -ForegroundColor Cyan
    $infSource = Join-Path $currentDir "Llevar.inf"
    $infDest = Join-Path $installPath "Llevar.inf"
    
    if (Test-Path $infSource) {
        try {
            # Copiar archivo .inf a C:\Llevar
            Copy-Item -Path $infSource -Destination $infDest -Force
            Write-Host "✓ Archivo Llevar.inf copiado" -ForegroundColor Green
            
            # Instalar el menú contextual ejecutando el .inf
            try {
                $result = Start-Process -FilePath "rundll32.exe" -ArgumentList "setupapi.dll,InstallHinfSection DefaultInstall 132 $infDest" -Wait -PassThru -NoNewWindow
                
                if ($result.ExitCode -eq 0) {
                    Write-Host "✓ Menú contextual 'Llevar A...' instalado exitosamente" -ForegroundColor Green
                    Write-Host "  Ahora puede hacer clic derecho en archivos o carpetas y seleccionar 'Llevar A...'" -ForegroundColor Gray
                }
                else {
                    Write-Host "⚠ El menú contextual pudo no instalarse correctamente (código: $($result.ExitCode))" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "⚠ Error al instalar menú contextual: $_" -ForegroundColor Yellow
                Write-Host "  Puede instalarlo manualmente haciendo clic derecho en Llevar.inf → Instalar" -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "✗ Error al copiar Llevar.inf: $_" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "⚠ No se encontró Llevar.inf en la carpeta actual" -ForegroundColor Yellow
        Write-Host "  El menú contextual no se instalará" -ForegroundColor Gray
    }
    
    Write-Host ""
    Show-Banner -Message "✓ INSTALACIÓN COMPLETADA" -BorderColor Cyan -TextColor Green
    Write-Host ""
    Write-Host "Ahora puede ejecutar 'Llevar.ps1' desde cualquier ubicación." -ForegroundColor White
    Write-Host "También puede usar el menú contextual 'Llevar A...' en archivos y carpetas." -ForegroundColor White
    Write-Host "Puede ser necesario reiniciar la terminal para que el PATH se actualice." -ForegroundColor Gray
    Write-Host ""
    
    return $true
}

function Test-LlevarInstallation {
    <#
    .SYNOPSIS
        Verifica si el script está ejecutándose desde C:\Llevar
    #>
    $currentPath = $PSCommandPath
    $expectedPath = "C:\Llevar"
    
    # Normalizar rutas para comparación
    $currentDir = Split-Path $currentPath -Parent
    
    return ($currentDir -eq $expectedPath)
}

function Show-InstallationPrompt {
    <#
    .SYNOPSIS
        Muestra un diálogo usando Show-ConsolePopup preguntando si se quiere instalar el script
    #>
    
    $mensaje = @"
Este script no está instalado en C:\Llevar

¿Desea instalarlo en el sistema?

Esto copiará:
  • Script Llevar.ps1 a C:\Llevar
  • 7-Zip portable (si está disponible)
  • Agregará C:\Llevar al PATH del sistema
"@

    $respuesta = Show-ConsolePopup -Title "INSTALACIÓN DE LLEVAR EN EL SISTEMA" -Message $mensaje -Options @("*Sí, instalar", "*No, continuar sin instalar")
    
    # Opción 0 = Sí, Opción 1 = No
    return ($respuesta -eq 0)
}

# ========================================================================== #
#                 VERIFICACIÓN DE PERMISOS DE ADMINISTRADOR                  #
# ========================================================================== #

# Verificar si se está ejecutando como administrador
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# NO pedir permisos de administrador si estamos en un IDE o modo debug
$isInIDE = Test-IsRunningInIDE

if (-not $isAdmin -and -not $isInIDE) {
    Write-Host "⚠ Se requieren permisos de administrador para redimensionar la consola." -ForegroundColor Yellow
    Write-Host "Elevando a administrador..." -ForegroundColor Cyan
    
    # Construir argumentos para relanzar el script
    $scriptPath = $MyInvocation.MyCommand.Path
    $arguments = @("-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"")
    
    # Agregar parámetros pasados originalmente
    if ($Origen) { $arguments += "-Origen", "`"$Origen`"" }
    if ($Destino) { $arguments += "-Destino", "`"$Destino`"" }
    if ($BlockSizeMB -ne 10) { $arguments += "-BlockSizeMB", $BlockSizeMB }
    if ($Clave) { $arguments += "-Clave", "`"$Clave`"" }
    if ($Iso) { $arguments += "-Iso" }
    if ($IsoDestino -ne "dvd") { $arguments += "-IsoDestino", $IsoDestino }
    if ($UseNativeZip) { $arguments += "-UseNativeZip" }
    if ($Ejemplo) { $arguments += "-Ejemplo" }
    if ($Ayuda) { $arguments += "-Ayuda" }
    
    # Relanzar con privilegios de administrador
    Start-Process pwsh.exe -Verb RunAs -ArgumentList $arguments
    exit
}
elseif (-not $isAdmin -and $isInIDE) {
    Write-Host "ℹ Ejecutando en IDE/Debug - saltando solicitud de permisos de administrador" -ForegroundColor Cyan
}

# ========================================================================== #
#                            CONFIGURACIÓN Y LOGS                            #
# ========================================================================== #

# Crear carpeta de logs en el directorio del script
$Global:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Global:LogsDir = Join-Path $Global:ScriptDir "Logs"
if (-not (Test-Path $Global:LogsDir)) {
    New-Item -Path $Global:LogsDir -ItemType Directory -Force | Out-Null
}

# Nombre del log con fecha, hora y minuto (más legible)
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$Global:LogFile = Join-Path $Global:LogsDir "LLEVAR_$timestamp.log"

# Variable global para modo verbose
$Global:VerboseLogging = $Verbose

# Función mejorada de logging
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",  # INFO, WARNING, ERROR, DEBUG
        [System.Management.Automation.ErrorRecord]$ErrorRecord = $null
    )
    
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Obtener información de línea si estamos en modo verbose
    $lineInfo = ""
    if ($Global:VerboseLogging) {
        $callStack = Get-PSCallStack
        if ($callStack.Count -gt 1) {
            $caller = $callStack[1]
            $lineInfo = " [Line: $($caller.ScriptLineNumber), Function: $($caller.FunctionName)]"
        }
    }
    
    $logEntry = "[$time] [$Level]$lineInfo $Message"
    
    # Si hay un ErrorRecord, agregar detalles del error
    if ($ErrorRecord) {
        $logEntry += "`n    Exception: $($ErrorRecord.Exception.Message)"
        $logEntry += "`n    Category: $($ErrorRecord.CategoryInfo.Category)"
        $logEntry += "`n    TargetObject: $($ErrorRecord.TargetObject)"
        if ($ErrorRecord.InvocationInfo) {
            $logEntry += "`n    At: $($ErrorRecord.InvocationInfo.ScriptName):$($ErrorRecord.InvocationInfo.ScriptLineNumber)"
        }
        
        # En modo verbose, agregar stack trace completo
        if ($Global:VerboseLogging -and $ErrorRecord.ScriptStackTrace) {
            $logEntry += "`n    StackTrace:"
            $logEntry += "`n" + $ErrorRecord.ScriptStackTrace
        }
    }
    
    # Escribir al archivo de log
    try {
        Add-Content -Path $Global:LogFile -Value $logEntry -Encoding UTF8
    }
    catch {
        # Si falla el log, intentar escribir en TEMP
        $tempLog = Join-Path $env:TEMP "LLEVAR_ERROR.log"
        Add-Content -Path $tempLog -Value $logEntry -Encoding UTF8
    }
    
    # En modo verbose, también mostrar en consola con color
    if ($Global:VerboseLogging) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "DEBUG" { "Cyan" }
            default { "Gray" }
        }
        Write-Host "[VERBOSE] $logEntry" -ForegroundColor $color
    }
}

# Log inicial
Write-Log "========================================" "INFO"
Write-Log "Iniciando LLEVAR.PS1" "INFO"
Write-Log "Usuario: $env:USERNAME" "INFO"
Write-Log "Computadora: $env:COMPUTERNAME" "INFO"
Write-Log "========================================" "INFO"

# Inicializar consola si es necesario
$hostName = $host.Name -ilike '*consolehost*'
#Write-Host $hostName
#Pause
if ($hostName) {
    $host.UI.RawUI.BackgroundColor = 'Black'
    $host.UI.RawUI.ForegroundColor = 'White'
    Clear-Host
}

function Resize-Console {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Width,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Height
    )

    if ($host.Name -ne 'ConsoleHost') {
        return
    }

    try {
        # Ajustar buffer si es necesario
        if ($Width -gt $host.UI.RawUI.BufferSize.Width) {
            $host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size($Width, $host.UI.RawUI.BufferSize.Height)
        }

        # Limitar al tamaño máximo físico
        if ($Width -gt $host.UI.RawUI.MaxPhysicalWindowSize.Width) {
            $Width = $host.UI.RawUI.MaxPhysicalWindowSize.Width
        }
        if ($Height -gt $host.UI.RawUI.MaxPhysicalWindowSize.Height) {
            $Height = $host.UI.RawUI.MaxPhysicalWindowSize.Height
        }

        # Aplicar nuevo tamaño
        $host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size($Width, $Height)
    }
    catch {
        # Silenciar errores - no es crítico
    }
}

function Write-ErrorLog {
    param($Message, $ErrorRecord)

    # Usar la función Write-Log mejorada
    Write-Log -Message $Message -Level "ERROR" -ErrorRecord $ErrorRecord
}

# ========================================================================== #
#                             LOGO ASCII ANIMADO                             #
# ========================================================================== #

# Función universal para escribir texto con colores
function Write-ColorOutput {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]$InputObject,
        
        [ValidateSet('Black', 'DarkBlue', 'DarkGreen', 'DarkCyan', 'DarkRed', 'DarkMagenta', 'DarkYellow', 'Gray', 'DarkGray', 'Blue', 'Green', 'Cyan', 'Red', 'Magenta', 'Yellow', 'White',
            'BrightBlack', 'BrightBlue', 'BrightGreen', 'BrightCyan', 'BrightRed', 'BrightMagenta', 'BrightYellow', 'BrightWhite')]
        [string]$ForegroundColor = 'White',
        
        [ValidateSet('Black', 'DarkBlue', 'DarkGreen', 'DarkCyan', 'DarkRed', 'DarkMagenta', 'DarkYellow', 'Gray', 'DarkGray', 'Blue', 'Green', 'Cyan', 'Red', 'Magenta', 'Yellow', 'White',
            'BrightBlack', 'BrightBlue', 'BrightGreen', 'BrightCyan', 'BrightRed', 'BrightMagenta', 'BrightYellow', 'BrightWhite')]
        [string]$BackgroundColor = 'Black',
        
        [switch]$NoNewline
    )
    
    begin {
        # Detectar si estamos en PowerShell 7+ con $PSStyle disponible
        $usePSStyle = ($PSVersionTable.PSVersion.Major -ge 7) -and ($null -ne $PSStyle)
    }
    
    process {
        if ($_ -ne $null) {
            $text = $_
        }
        elseif ($null -ne $InputObject) {
            $text = $InputObject
        }
        else {
            $text = ""
        }
        
        if ($usePSStyle) {
            # Usar $PSStyle para colores ANSI en PowerShell 7+
            $fg = $PSStyle.Foreground.$ForegroundColor
            $bg = $PSStyle.Background.$BackgroundColor
            $reset = $PSStyle.Reset
            
            if ($NoNewline) {
                Write-Host "$fg$bg$text$reset" -NoNewline
            }
            else {
                Write-Host "$fg$bg$text$reset"
            }
        }
        else {
            # Fallback para PowerShell 5.1
            if ($NoNewline) {
                Write-Host $text -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor -NoNewline
            }
            else {
                Write-Host $text -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
            }
        }
    }
    
    end {
        # Limpiar si es necesario
    }
}

# Función para calcular el porcentaje al que hay que achicar el codigo ASCII lo más/menos posible
# Para el logo ASCII de alexsoft.txt para que se vea lo más fiel a la imagen real, permite redimenzionar
# Se trata de devolver siempre la proporción 1:1
function Get-AsciiScalingRatios {
    param(
        [int]$OriginalWidth,
        [int]$OriginalHeight,
        [int]$ConsoleWidth,
        [int]$ConsoleHeight
    )
      
    # Intentar que el logo quepa sin reducción
    # Solo reducir si es absolutamente necesario
    
    $widthRatio = 1
    $heightRatio = 1
    $maxWidth = $ConsoleWidth - 2
    
    # Si el logo es más ancho que la consola, reducir horizontalmente
    if ($OriginalWidth -gt $ConsoleWidth) {
        $widthRatio = [Math]::Ceiling($OriginalWidth / ($ConsoleWidth - 2))
    }
    
    # Si el logo es más alto que la consola, reducir verticalmente
    if ($OriginalHeight -gt $ConsoleHeight - 5) {
        $heightRatio = [Math]::Ceiling($OriginalHeight / ($ConsoleHeight - 5))
    }
    
    return @{
        WidthRatio  = $widthRatio
        HeightRatio = $heightRatio
        MaxWidth    = $maxWidth
    }
}

function Set-ConsoleSize {
    param(
        [int]$Width = 120,
        [int]$Height = 40
    )
    
    try {
        # Verificar si estamos en PowerShell ISE (no se puede redimensionar)
        if ($host.Name -match 'ISE') {
            Write-Verbose "PowerShell ISE detectado - no se puede redimensionar la consola"
            return $false
        }
        
        # Verificar si estamos en una sesión de terminal moderna (PowerShell 7+)
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            # PowerShell 7+ puede usar ANSI escapes para redimensionar
            $esc = [char]27
            Write-Host "${esc}[8;${Height};${Width}t" -NoNewline
            Start-Sleep -Milliseconds 50
            return $true
        }
        
        # Para PowerShell 5.1, usar métodos de .NET
        $rawUI = $host.UI.RawUI
        
        # Obtener tamaño actual
        $currentBuffer = $rawUI.BufferSize
        
        # Ajustar buffer primero (debe ser >= ventana)
        $newBufferWidth = [Math]::Max($currentBuffer.Width, $Width)
        $newBufferHeight = [Math]::Max($currentBuffer.Height, $Height + 100) # Buffer más grande para scroll
        
        try {
            $rawUI.BufferSize = New-Object System.Management.Automation.Host.Size($newBufferWidth, $newBufferHeight)
        }
        catch {
            Write-Verbose "No se pudo ajustar buffer: $($_.Message)"
        }
        
        # Ajustar ventana
        try {
            $rawUI.WindowSize = New-Object System.Management.Automation.Host.Size($Width, $Height)
            Start-Sleep -Milliseconds 50
            return $true
        }
        catch {
            # Intentar con métodos de Console directamente
            try {
                [Console]::SetWindowSize($Width, $Height)
                Start-Sleep -Milliseconds 50
                return $true
            }
            catch {
                Write-Verbose "No se pudo redimensionar ventana: $($_.Message)"
            }
        }
        
        return $false
    }
    catch {
        Write-Verbose "Error en Set-ConsoleSize: $($_.Message)"
        return $false
    }
}

# ========================================================================== #
#                            FUNCIÓN SHOW-BANNER                             #
# ========================================================================== #
function Show-Banner {
    <#
    .SYNOPSIS
        Muestra un banner formateado con bordes automáticos y opciones de personalización.
    
    .DESCRIPTION
        Genera un banner con bordes automáticos, calculando el ancho según el texto más largo.
        Soporta múltiples líneas, alineación centrada, colores personalizables y posicionamiento opcional.
    
    .PARAMETER Message
        Mensaje o array de mensajes a mostrar en el banner. Siempre se muestra centrado.
    
    .PARAMETER BorderColor
        Color de los bordes. Default: Cyan
    
    .PARAMETER TextColor
        Color del texto. Default: White
    
    .PARAMETER BackgroundColor
        Color de fondo. Default: Black
    
    .PARAMETER Padding
        Espacios adicionales a cada lado del texto. Default: 2
    
    .PARAMETER X
        Posición horizontal (columna). Si no se especifica, usa el ancho actual.
    
    .PARAMETER Y
        Posición vertical (fila). Si no se especifica, usa la posición actual del cursor.
    
    .EXAMPLE
        Show-Banner "LLEVAR.PS1"
        
    .EXAMPLE
        Show-Banner @("ROBOCOPY MIRROR", "COPIA ESPEJO") -BorderColor Yellow -TextColor Cyan
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Message,
        
        [ConsoleColor]$BorderColor = [ConsoleColor]::Cyan,
        [ConsoleColor]$TextColor = [ConsoleColor]::White,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black,
        
        [int]$Padding = 2,
        
        [int]$X = -1,
        [int]$Y = -1
    )
    
    # Convertir texto a array si es string único
    if ($Message -is [string]) {
        $Message = @($Message)
    }
    
    # Calcular ancho máximo del texto
    $maxLength = 0
    foreach ($line in $Message) {
        if ($line.Length -gt $maxLength) {
            $maxLength = $line.Length
        }
    }
    
    # Ancho total del banner (texto + padding a ambos lados)
    $bannerWidth = $maxLength + ($Padding * 2)
    
    # Crear líneas de borde con caracteres box-drawing
    $topBorder = "╔" + ("═" * $bannerWidth) + "╗"
    $bottomBorder = "╚" + ("═" * $bannerWidth) + "╝"
    
    # Si se especificó posición, mover el cursor
    if ($X -ge 0 -and $Y -ge 0) {
        try {
            [Console]::SetCursorPosition($X, $Y)
        }
        catch {
            # Si falla, continuar con posición actual
        }
    }
    
    # Guardar colores originales
    $originalForeground = [Console]::ForegroundColor
    $originalBackground = [Console]::BackgroundColor
    
    try {
        # Mostrar borde superior
        [Console]::ForegroundColor = $BorderColor
        [Console]::BackgroundColor = $BackgroundColor
        Write-Host $topBorder
        
        # Mostrar cada línea de texto centrada con bordes laterales
        foreach ($line in $Message) {
            $spaces = $bannerWidth - $line.Length
            
            # Siempre centrar
            $leftPad = [Math]::Floor($spaces / 2)
            $rightPad = $spaces - $leftPad
            
            # Mostrar borde lateral izquierdo
            [Console]::ForegroundColor = $BorderColor
            [Console]::BackgroundColor = $BackgroundColor
            Write-Host -NoNewline "║"
            
            # Mostrar contenido de texto centrado
            [Console]::ForegroundColor = $TextColor
            [Console]::BackgroundColor = $BackgroundColor
            Write-Host -NoNewline ((' ' * $leftPad) + $line + (' ' * $rightPad))
            
            # Mostrar borde lateral derecho
            [Console]::ForegroundColor = $BorderColor
            [Console]::BackgroundColor = $BackgroundColor
            Write-Host "║"
        }
        
        # Mostrar borde inferior
        [Console]::ForegroundColor = $BorderColor
        [Console]::BackgroundColor = $BackgroundColor
        Write-Host $bottomBorder
    }
    finally {
        # Restaurar colores originales
        [Console]::ForegroundColor = $originalForeground
        [Console]::BackgroundColor = $originalBackground
    }
}

# ========================================================================== #
#                    FUNCIÓN PARA SONIDOS ESTILO DOS-MIDI                    #
# ========================================================================== #
function Play-DOSBeep {
    param(
        [int]$LineIndex = 0,
        [int]$TotalLines = 100
    )
    
    try {
        # Patrón de frecuencias estilo DOS MIDI (notas musicales típicas de PC Speaker)
        # Usamos un patrón cíclico de 8 notas que se repite
        $frequencies = @(523, 587, 659, 698, 784, 880, 988, 1047)  # Do-Do (octava)
        $freq = $frequencies[$LineIndex % $frequencies.Count]
        
        # Duración muy corta para no ser molesto (50ms)
        $duration = 50
        
        # Cada 3 líneas hacemos un beep más largo y grave para ritmo
        if ($LineIndex % 3 -eq 0) {
            [Console]::Beep(440, 80)  # La grave, más largo
        }
        else {
            [Console]::Beep($freq, $duration)
        }
    }
    catch {
        # Si falla el beep (por ejemplo en entornos sin soporte de sonido), lo ignoramos
    }
}

# ========================================================================== #
#                      FUNCIÓN DE BIENVENIDA PARPADEANTE                     #
# ========================================================================== #
function Show-WelcomeMessage {
    <#
    .SYNOPSIS
        Muestra un mensaje de bienvenida parpadeante centrado en la pantalla
    
    .DESCRIPTION
        Obtiene el nombre de usuario de la variable de entorno USERNAME
        y muestra "BIENVENIDO [USERNAME]" en letras grandes ASCII parpadeando
    #>
    
    param(
        [int]$BlinkCount = 3,
        [int]$VisibleDelayMs = 400,
        [ConsoleColor]$TextColor = [ConsoleColor]::Cyan
    )
    
    # Obtener nombre de usuario
    $username = $env:USERNAME
    if (-not $username) {
        $username = "USUARIO"
    }
    
    # Convertir texto a ASCII art grande (letras simples con bloques)
    function ConvertTo-BigLetters {
        param([string]$Text)
        
        $text = $text.ToUpper()
        $lines = @("", "", "", "", "", "", "")
        
        foreach ($char in $text.ToCharArray()) {
            $letter = switch ($char) {
                'A' { @(" ███  ", "██ ██ ", "█████ ", "██ ██ ", "██ ██ ") }
                'B' { @("████  ", "██ ██ ", "████  ", "██ ██ ", "████  ") }
                'C' { @(" ███  ", "██    ", "██    ", "██    ", " ███  ") }
                'D' { @("████  ", "██ ██ ", "██ ██ ", "██ ██ ", "████  ") }
                'E' { @("█████ ", "██    ", "████  ", "██    ", "█████ ") }
                'F' { @("█████ ", "██    ", "████  ", "██    ", "██    ") }
                'G' { @(" ███  ", "██    ", "██ ██ ", "██ ██ ", " ███  ") }
                'H' { @("██ ██ ", "██ ██ ", "█████ ", "██ ██ ", "██ ██ ") }
                'I' { @("█████ ", "  ██  ", "  ██  ", "  ██  ", "█████ ") }
                'J' { @("  ███ ", "   ██ ", "   ██ ", "██ ██ ", " ███  ") }
                'K' { @("██ ██ ", "██ ██ ", "████  ", "██ ██ ", "██ ██ ") }
                'L' { @("██    ", "██    ", "██    ", "██    ", "█████ ") }
                'M' { @("█   █ ", "██ ██ ", "█ █ █ ", "█   █ ", "█   █ ") }
                'N' { @("██  ██", "███ ██", "██ ███", "██  ██", "██  ██") }
                'O' { @(" ███  ", "██ ██ ", "██ ██ ", "██ ██ ", " ███  ") }
                'P' { @("████  ", "██ ██ ", "████  ", "██    ", "██    ") }
                'Q' { @(" ███  ", "██ ██ ", "██ ██ ", "██ ██ ", " ████ ") }
                'R' { @("████  ", "██ ██ ", "████  ", "██ ██ ", "██ ██ ") }
                'S' { @(" ███  ", "██    ", " ███  ", "   ██ ", " ███  ") }
                'T' { @("█████ ", "  ██  ", "  ██  ", "  ██  ", "  ██  ") }
                'U' { @("██ ██ ", "██ ██ ", "██ ██ ", "██ ██ ", " ███  ") }
                'V' { @("██ ██ ", "██ ██ ", "██ ██ ", " ███  ", "  ██  ") }
                'W' { @("█   █ ", "█   █ ", "█ █ █ ", "██ ██ ", "█   █ ") }
                'X' { @("██ ██ ", "██ ██ ", " ███  ", "██ ██ ", "██ ██ ") }
                'Y' { @("██ ██ ", "██ ██ ", " ███  ", "  ██  ", "  ██  ") }
                'Z' { @("█████ ", "   ██ ", "  ██  ", "██    ", "█████ ") }
                ' ' { @("      ", "      ", "      ", "      ", "      ") }
                default { @("      ", "      ", "      ", "      ", "      ") }
            }
            
            for ($i = 0; $i -lt 5; $i++) {
                $lines[$i + 1] += $letter[$i]
            }
        }
        
        return $lines
    }
    
    # Generar el texto completo en ASCII
    $fullText = "BIENVENIDO $username"
    $asciiLines = ConvertTo-BigLetters -Text $fullText
    
    $winWidth = [Console]::WindowWidth
    $winHeight = [Console]::WindowHeight
    
    # Calcular posición centrada verticalmente
    $startY = [Math]::Max(0, [int][Math]::Floor(($winHeight - $asciiLines.Count) / 2))
    
    # Parpadear el mensaje
    for ($blink = 0; $blink -lt $BlinkCount; $blink++) {
        # Mostrar mensaje
        for ($i = 0; $i -lt $asciiLines.Count; $i++) {
            $line = $asciiLines[$i]
            $lineLength = $line.Length
            $startX = [Math]::Max(0, [int][Math]::Floor(($winWidth - $lineLength) / 2))
            
            try {
                [Console]::SetCursorPosition($startX, $startY + $i)
                Write-Host $line -ForegroundColor $TextColor -NoNewline
            }
            catch {
                # Ignorar errores de posicionamiento
            }
        }
        
        Start-Sleep -Milliseconds $VisibleDelayMs
        
        # Limpiar mensaje (excepto en el último parpadeo)
        if ($blink -lt ($BlinkCount - 1)) {
            for ($i = 0; $i -lt $asciiLines.Count; $i++) {
                $line = $asciiLines[$i]
                $lineLength = $line.Length
                $startX = [Math]::Max(0, [int][Math]::Floor(($winWidth - $lineLength) / 2))
                
                try {
                    [Console]::SetCursorPosition($startX, $startY + $i)
                    Write-Host (" " * $lineLength) -NoNewline
                }
                catch {
                    # Ignorar errores de posicionamiento
                }
            }
            
            Start-Sleep -Milliseconds ([int]($VisibleDelayMs * 0.4))
        }
    }
    
    # Pausa final antes de continuar
    Start-Sleep -Milliseconds 600
}

# ========================================================================== #
#                      FUNCIÓN SHOW-ASCIILOGO MEJORADA                       #
# ========================================================================== #
function Show-AsciiLogo {
    param(
        [string]$Path,
        [int]$DelayMs = 300,
        [bool]$ShowProgress = $true,
        [string]$Label = "",
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::Gray,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black,
        [int]$FinalDelaySeconds = 3,
        [bool]$AutoSizeConsole = $true,
        [ConsoleColor]$BarForegroundColor = [ConsoleColor]::Gray,
        [ConsoleColor]$BarBackgroundColor = [ConsoleColor]::DarkGray,
        [ConsoleColor]$OverlayTextColor = [ConsoleColor]::Blue,
        [ConsoleColor]$OverlayBackgroundColor = [ConsoleColor]::Black,
        [bool]$PlaySound = $true  # Nuevo parámetro para activar/desactivar sonidos
    )

    if (-not (Test-Path $Path)) { 
        Write-Host "Archivo no encontrado: $Path" -ForegroundColor Red
        return 
    }

    # === CONFIGURAR UTF-8 ===
    $originalOutputEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    try {
        $reader = New-Object System.IO.StreamReader($Path, $true)
        $content = $reader.ReadToEnd()
        $reader.Close()
        $lines = $content -split "`r?`n"
    }
    catch {
        [Console]::OutputEncoding = $originalOutputEncoding
        Write-Host "Error leyendo archivo: $_" -ForegroundColor Red
        return
    }

    if (-not $lines -or $lines.Count -eq 0) { 
        [Console]::OutputEncoding = $originalOutputEncoding
        return 
    }
    
    if ($lines -isnot [array]) { $lines = @($lines) }

    # === CALCULAR TAMAÑO DEL LOGO ===
    $maxLineLength = 0
    $effectiveLines = @()
    
    foreach ($line in $lines) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $lineLength = ($line -replace "[\u0000-\u001F]", "").Length
            if ($lineLength -gt $maxLineLength) {
                $maxLineLength = $lineLength
            }
            $effectiveLines += $line
        }
    }
    
    $logoHeight = $effectiveLines.Count
    $logoWidth = $maxLineLength
    
    # === OBTENER TAMAÑO ACTUAL DE LA CONSOLA ===
    $originalConsoleWidth = [Console]::WindowWidth
    $originalConsoleHeight = [Console]::WindowHeight
    
    # === CALCULAR NUEVO TAMAÑO SI SE SOLICITA ===
    if ($AutoSizeConsole) {
        $requiredHeight = $logoHeight + 5
        $requiredWidth = $logoWidth + 4
        
        $ratios = Get-AsciiScalingRatios `
            -OriginalWidth $logoWidth `
            -OriginalHeight $logoHeight `
            -ConsoleWidth $requiredWidth `
            -ConsoleHeight $requiredHeight
        
        if ($ratios.WidthRatio -gt 1 -or $ratios.HeightRatio -gt 1) {
            $requiredWidth = [Math]::Min($requiredWidth, $ratios.MaxWidth)
            $requiredHeight = $logoHeight / $ratios.HeightRatio + 5
        }
        
        $requiredWidth = [Math]::Max($requiredWidth, 80)
        $requiredHeight = [Math]::Max($requiredHeight, 30)
        
        Set-ConsoleSize -Width $requiredWidth -Height $requiredHeight | Out-Null
    }
    
    # === OBTENER NUEVO TAMAÑO ===
    $consoleWidth = [Console]::WindowWidth
    $consoleHeight = [Console]::WindowHeight
    
    $finalRatios = Get-AsciiScalingRatios `
        -OriginalWidth $logoWidth `
        -OriginalHeight $logoHeight `
        -ConsoleWidth $consoleWidth `
        -ConsoleHeight $consoleHeight
    
    # === PREPARAR CONSOLA ===
    $origVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false
    Clear-Host

    # === GUARDAR Y APLICAR COLORES DEL LOGO ===
    $originalFg = [Console]::ForegroundColor
    $originalBg = [Console]::BackgroundColor
    [Console]::ForegroundColor = $ForegroundColor
    [Console]::BackgroundColor = $BackgroundColor

    $startTime = Get-Date
    $barTop = $consoleHeight - 2
    
    # === CENTRAR VERTICALMENTE ===
    $verticalPadding = [Math]::Max(0, [Math]::Floor(($consoleHeight - $logoHeight - 2) / 2))
    
    # === DIBUJAR LOGO ===
    for ($i = 0; $i -lt $effectiveLines.Count; $i++) {
        $verticalPos = $verticalPadding + $i
        
        if ($verticalPos -ge ($consoleHeight - 3)) { break }
        
        $line = $effectiveLines[$i]
        
        # Aplicar escala horizontal si es necesario
        if ($finalRatios.WidthRatio -gt 1) {
            $newLine = ""
            for ($j = 0; $j -lt $line.Length; $j += $finalRatios.WidthRatio) {
                $newLine += $line[$j]
            }
            $line = $newLine
        }
        
        if ($line.Length -gt $consoleWidth) {
            $line = $line.Substring(0, $consoleWidth)
        }
        
        $horizontalPadding = [Math]::Max(0, [Math]::Floor(($consoleWidth - $line.Length) / 2))
        
        try { 
            [Console]::SetCursorPosition($horizontalPadding, $verticalPos) 
        } 
        catch { continue }

        # === ESCRIBIR LÍNEA ===
        Write-Host $line -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor -NoNewline
        
        # === REPRODUCIR SONIDO ESTILO DOS ===
        if ($PlaySound) {
            Play-DOSBeep -LineIndex $i -TotalLines $effectiveLines.Count
        }
        
        # === LLAMAR A LA FUNCIÓN DE BARRA DE PROGRESO ===
        if ($ShowProgress) {
            $percent = [int](($i + 1) / $effectiveLines.Count * 100)

            Write-LlevarProgressBar `
                -Percent $percent `
                -StartTime $startTime `
                -Label $Label `
                -Width ([Math]::Min(50, $consoleWidth - 4)) `
                -Top $barTop `
                -ShowEstimated:$false `
                -ShowRemaining:$false `
                -ShowElapsed:$false `
                -ShowPercent:$true `
                -ForegroundColor $BarForegroundColor `
                -BackgroundColor $BarBackgroundColor `
                -OverlayTextColor $OverlayTextColor `
                -OverlayBackgroundColor $OverlayBackgroundColor
        }

        if ($DelayMs -gt 0 -and $i -lt $effectiveLines.Count - 1) {
            Start-Sleep -Milliseconds $DelayMs
        }
    }

    # === Pausa final ===
    if ($FinalDelaySeconds -gt 0) {
        Start-Sleep -Seconds $FinalDelaySeconds
    }

    # === RESTAURAR TODO ===
    [Console]::ForegroundColor = $originalFg
    [Console]::BackgroundColor = $originalBg
    [Console]::CursorVisible = $origVisible
    [Console]::OutputEncoding = $originalOutputEncoding
    
    # Restaurar tamaño original de consola
    if ($AutoSizeConsole) {
        Start-Sleep -Seconds 1
        Set-ConsoleSize -Width $originalConsoleWidth -Height $originalConsoleHeight | Out-Null
    }
}

function Test-PathWritable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Si es FTP, verificar la conexión
    if ($Path -match '^FTP:(.+)$') {
        $driveName = $Matches[1]
        $ftpInfo = Get-FtpConnection -DriveName $driveName
        if ($ftpInfo) {
            Write-ColorOutput "Conexión FTP válida" -ForegroundColor Green
            return $true
        }
        else {
            Write-ColorOutput "Conexión FTP no encontrada: $driveName" -ForegroundColor Yellow
            return $false
        }
    }

    # Asegurar que el directorio existe (o crearlo)
    if (-not (Test-Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
        catch {
            Write-ColorOutput "No se pudo crear el directorio destino: $Path" -ForegroundColor Yellow
            return $false
        }
    }

    # Probar escritura con un archivo temporal
    $testFile = Join-Path $Path "__LLEVAR_TEST__.tmp"
    try {
        "test" | Out-File -FilePath $testFile -Encoding ASCII -ErrorAction Stop
        Remove-Item $testFile -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-ColorOutput "No se pudo escribir en el destino: $Path" -ForegroundColor Yellow
        return $false
    }
}

function Format-LlevarTime {
    param(
        [int]$Seconds
    )

    if ($Seconds -lt 0) { $Seconds = 0 }
    $ts = [TimeSpan]::FromSeconds($Seconds)
    return ("{0:00}:{1:00}:{2:00}" -f [int]$ts.Hours, [int]$ts.Minutes, [int]$ts.Seconds)
}

# Función Write-LlevarProgressBar mejorada
function Write-LlevarProgressBar {
    param(
        [double]$Percent,
        [datetime]$StartTime,        
        [int]$Width = 40,
        [bool]$ShowElapsed = $true,
        [bool]$ShowEstimated = $true,
        [bool]$ShowRemaining = $true,
        [bool]$ShowPercent = $true,
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::Gray,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::DarkGray,
        [int]$Top = -1,
        [int]$Left = 0,
        [string]$Label = "",
        [ConsoleColor]$OverlayTextColor = [ConsoleColor]::White,    
        [ConsoleColor]$OverlayBackgroundColor = [ConsoleColor]::Black
    )

    if ($Percent -lt 0) { $Percent = 0 }
    if ($Percent -gt 100) { $Percent = 100 }
    if ($Width -lt 10) { $Width = 10 }

    $now = Get-Date
    $elapsed = $now - $StartTime
    $elapsedSec = [int][Math]::Floor($elapsed.TotalSeconds)

    $totalSec = 0
    $remainSec = 0
    if ($Percent -gt 0) {
        $totalSec = [int][Math]::Round($elapsedSec / ($Percent / 100.0))
        if ($totalSec -lt 0) { $totalSec = 0 }
        $remainSec = $totalSec - $elapsedSec
        if ($remainSec -lt 0) { $remainSec = 0 }
    }

    $consoleWidth = [console]::WindowWidth
    $bufferHeight = [console]::BufferHeight

    # Obtener posición actual si Top no está especificado
    if ($Top -lt 0) {
        $Top = [console]::CursorTop
        $Left = 0
    }

    # Validar límites
    if ($Top -ge $bufferHeight - 2) {
        $Top = $bufferHeight - 3
    }
    if ($Top -lt 0) {
        $Top = 0
    }

    # Dibujar barra de una sola vez
    $filled = [int][Math]::Round(($Percent / 100.0) * $Width)
    if ($filled -gt $Width) { $filled = $Width }
    if ($filled -lt 0) { $filled = 0 }

    $filledBar = "█" * $filled
    $emptyBar = "░" * ($Width - $filled)
    $bar = "[$filledBar$emptyBar]"
    
    # Mostrar porcentaje
    if ($ShowPercent) {
        $bar += " {0,3}%" -f [int]$Percent
    }
    
    # Posicionar y escribir barra completa
    try {
        [console]::SetCursorPosition($Left, $Top)
        Write-Host $bar -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor -NoNewline
    }
    catch {
        # Ignorar errores de posicionamiento
    }

    # === TEXTO SUPERPUESTO (LABEL) ===
    if ($Label -and $Label.Trim()) {
        $text = $Label.Trim()
        
        # Ajustar texto si es muy largo
        if ($text.Length -gt $Width) {
            $text = $text.Substring(0, $Width)
        }
        
        # Calcular posición centrada
        $textStart = [Math]::Max(0, [int](($Width - $text.Length) / 2))
        
        # Posicionar al inicio del texto
        try {
            [console]::SetCursorPosition($Left + 1 + $textStart, $Top)
        }
        catch {
            return
        }
        
        # Escribir el texto carácter por carácter
        for ($i = 0; $i -lt $text.Length; $i++) {
            $charPos = $textStart + $i + 1  # +1 para el corchete inicial
            
            # Determinar color de fondo para este carácter
            $bgColor = $OverlayBackgroundColor
            
            # Si la barra ya pasó esta posición, usar el color de la barra llena
            if ($charPos -le $filled) {
                $bgColor = $ForegroundColor  # Usar el color de primer plano de la barra
            }
            
            # Escribir el carácter con colores apropiados
            try {
                Write-Host $text[$i] -ForegroundColor $OverlayTextColor -BackgroundColor $bgColor -NoNewline
            }
            catch {
                Write-Host $text[$i] -NoNewline
            }
        }
    }

    # Mostrar información de tiempo en segunda línea (opcional)
    if ($ShowElapsed -or $ShowEstimated -or $ShowRemaining) {
        $infoParts = @()
        if ($ShowElapsed) {
            $infoParts += ("Transcurrido: {0}" -f (Format-LlevarTime -Seconds $elapsedSec))
        }
        if ($ShowEstimated -and $totalSec -gt 0) {
            $infoParts += ("Estimado: {0}" -f (Format-LlevarTime -Seconds $totalSec))
        }
        if ($ShowRemaining -and $totalSec -gt 0) {
            $infoParts += ("Restante: {0}" -f (Format-LlevarTime -Seconds $remainSec))
        }

        $infoLine = ""
        if ($infoParts.Count -gt 0) {
            $infoLine = ($infoParts -join "  ")
        }

        try {
            $nextLine = $Top + 1
            if ($nextLine -lt $bufferHeight) {
                [console]::SetCursorPosition($Left, $nextLine)
                $infoClear = " " * ([Math]::Min($consoleWidth - 1, 100))
                Write-Host $infoClear -NoNewline -BackgroundColor $BackgroundColor -ForegroundColor $ForegroundColor
                [console]::SetCursorPosition($Left, $nextLine)
                if ($infoLine) {
                    Write-Host $infoLine -NoNewline -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
                }
            }
        }
        catch {}
    }

    # Posicionar para siguiente escritura
    try {
        [console]::SetCursorPosition($Left, $Top + 2)
    }
    catch {}
}

function Invoke-NetworkUpload {
    param(
        [string]$ArchivePath
    )

    if (-not (Test-Path $ArchivePath)) {
        throw "No se encuentra el archivo a subir: $ArchivePath"
    }

    $share = Read-Host "Ingrese la ruta de la unidad de red (por ejemplo \\servidor\share)"
    if (-not $share) {
        Write-ColorOutput "Ruta de red no especificada. Cancelando." -ForegroundColor Yellow
        return
    }

    $useCred = Read-Host "¿Desea especificar credenciales? (S/N)"
    $cred = $null
    if ($useCred -match '^[sS]') {
        $cred = Get-Credential -Message "Credenciales para $share (dejar usuario/clave vacíos si no aplica)"
    }

    $psDriveName = "LLEVAR_NET"
    try {
        # Usar Mount-LlevarNetworkPath para montar la ruta de red
        $mountedPath = Mount-LlevarNetworkPath -Path $share -Credential $cred -DriveName $psDriveName
        
        if (-not (Test-Path $mountedPath)) {
            throw "No se pudo acceder a $share."
        }

        $destPath = Join-Path $mountedPath (Split-Path $ArchivePath -Leaf)

        Write-ColorOutput "Copiando archivo a la unidad de red..." -ForegroundColor Cyan
        Copy-Item $ArchivePath $destPath -Force
        Write-ColorOutput "Archivo copiado correctamente a $share" -ForegroundColor Green
    }
    catch {
        Write-ColorOutput "Error al subir a la unidad de red: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        Remove-PSDrive -Name $psDriveName -ErrorAction SilentlyContinue
    }
}

# ========================================================================== #
#                          MODO EJEMPLO AUTOMÁTICO                           #
# ========================================================================== #

function Test-DestinoType {
    param([string]$Path)
    
    if ($Path -match '^\\\\') {
        return "Red (UNC)"
    }
    elseif ($Path -match '^[A-Za-z]:') {
        $drive = (Get-Item $Path -ErrorAction SilentlyContinue).PSDrive
        if ($drive) {
            return "Unidad Local ($($drive.Root))"
        }
        return "Unidad Local"
    }
    else {
        return "Ruta Relativa"
    }
}

function New-ExampleData {
    param(
        [string]$BaseDir,
        [int]$SizeMB = 20
    )
    
    $exampleDir = Join-Path $BaseDir "EJEMPLO"
    
    if (Test-Path $exampleDir) {
        Write-ColorOutput "Eliminando directorio de ejemplo anterior..." -ForegroundColor Yellow
        Remove-Item $exampleDir -Recurse -Force
    }
    
    Write-Host ""
    Show-Banner -Message "MODO EJEMPLO - Generando datos de prueba" -BorderColor Cyan -TextColor Cyan
    Write-Host ""
    
    Write-Host "Creando carpeta: $exampleDir" -ForegroundColor Gray
    New-Item -ItemType Directory -Path $exampleDir -Force | Out-Null
    
    $tmpFile = Join-Path $exampleDir "EJEMPLO.TMP"
    Write-Host "Generando archivo de ${SizeMB}MB: EJEMPLO.TMP" -ForegroundColor Gray
    
    # Generar archivo con datos aleatorios
    $chunkSize = 1MB
    $totalBytes = $SizeMB * 1MB
    $written = 0
    
    $stream = [System.IO.File]::Create($tmpFile)
    $random = New-Object System.Random
    
    while ($written -lt $totalBytes) {
        $remaining = $totalBytes - $written
        $size = [Math]::Min($chunkSize, $remaining)
        
        $buffer = New-Object byte[] $size
        $random.NextBytes($buffer)
        
        $stream.Write($buffer, 0, $size)
        $written += $size
        
        $percent = [int](($written * 100) / $totalBytes)
        Write-Progress -Activity "Generando archivo de prueba" -Status "$percent% completado" -PercentComplete $percent
    }
    
    $stream.Close()
    Write-Progress -Activity "Generando archivo de prueba" -Completed
    
    Write-Host "✓ Archivo generado: $('{0:N2}' -f ((Get-Item $tmpFile).Length / 1MB)) MB" -ForegroundColor Green
    Write-Host ""
    
    return $exampleDir
}

function Invoke-ExampleMode {
    Write-Host ""
    Show-Banner -Message "MODO EJEMPLO AUTOMÁTICO" -BorderColor Cyan -TextColor Cyan
    Write-Host ""
    Write-Host "Este modo creará automáticamente:" -ForegroundColor Yellow
    Write-Host "  • Una carpeta EJEMPLO con un archivo EJEMPLO.TMP de 50 MB"
    Write-Host "  • Ejecutará el proceso completo de compresión y división"
    Write-Host "  • Copiará los bloques al destino especificado"
    Write-Host "  • Limpiará todos los archivos temporales al finalizar"
    Write-Host ""
    
    # Generar datos de ejemplo
    $baseDir = $PSScriptRoot
    if (-not $baseDir) {
        $baseDir = Get-Location
    }
    
    $origenEjemplo = New-ExampleData -BaseDir $baseDir -SizeMB 50
    
    # Solicitar destino
    Show-Banner -Message "CONFIGURACIÓN DE DESTINO" -BorderColor Gray -TextColor Yellow
    Write-Host ""
    Write-Host "Ingrese la ruta de destino para copiar los bloques."
    Write-Host "Ejemplos:" -ForegroundColor Cyan
    Write-Host "  • Carpeta local:    C:\Temp\Destino"
    Write-Host "  • Red UNC:          \\servidor\compartido\carpeta"
    Write-Host "  • Ruta relativa:    .\Destino"
    Write-Host ""
    
    $destinoEjemplo = Read-Host "Destino"
    
    if (-not $destinoEjemplo) {
        $destinoEjemplo = Join-Path $baseDir "DESTINO_EJEMPLO"
        Write-Host "Usando destino por defecto: $destinoEjemplo" -ForegroundColor Yellow
    }
    
    # Analizar tipo de destino
    $tipoDestino = Test-DestinoType -Path $destinoEjemplo
    Write-Host ""
    Write-Host "Tipo de destino detectado: $tipoDestino" -ForegroundColor Cyan
    
    # Verificar acceso al destino
    $destinoAccesible = $false
    $credenciales = $null
    
    if ($destinoEjemplo -match '^\\\\') {
        Write-Host "Verificando acceso a la ubicación de red..." -ForegroundColor Gray
        
        try {
            if (-not (Test-Path $destinoEjemplo)) {
                New-Item -ItemType Directory -Path $destinoEjemplo -Force -ErrorAction Stop | Out-Null
            }
            "test" | Out-File -FilePath (Join-Path $destinoEjemplo "__test__.tmp") -ErrorAction Stop
            Remove-Item (Join-Path $destinoEjemplo "__test__.tmp") -ErrorAction SilentlyContinue
            $destinoAccesible = $true
            Write-Host "✓ Acceso a red verificado" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ No se pudo acceder a la ruta de red" -ForegroundColor Red
            Write-Host ""
            $pedirCred = Read-Host "¿Desea proporcionar credenciales de red? (S/N)"
            
            if ($pedirCred -match '^[SsYy]') {
                $credenciales = Get-Credential -Message "Credenciales para $destinoEjemplo"
                
                try {
                    # Usar Mount-LlevarNetworkPath para verificar credenciales
                    $tempDrive = "LLEVAR_EJEMPLO"
                    $null = Mount-LlevarNetworkPath -Path $destinoEjemplo -Credential $credenciales -DriveName $tempDrive
                    
                    # Desmontar después de verificar
                    if (Get-PSDrive -Name $tempDrive -ErrorAction SilentlyContinue) {
                        Remove-PSDrive -Name $tempDrive -Force
                    }
                    
                    $destinoAccesible = $true
                    Write-Host "✓ Credenciales aceptadas" -ForegroundColor Green
                }
                catch {
                    Write-Host "✗ Credenciales incorrectas o destino inaccesible" -ForegroundColor Red
                    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                    throw "No se puede continuar sin acceso al destino"
                }
            }
            else {
                throw "Acceso al destino requerido para continuar"
            }
        }
    }
    else {
        # Destino local
        if (-not (Test-Path $destinoEjemplo)) {
            Write-Host "Creando directorio de destino..." -ForegroundColor Gray
            New-Item -ItemType Directory -Path $destinoEjemplo -Force | Out-Null
        }
        $destinoAccesible = $true
        Write-Host "✓ Destino local verificado" -ForegroundColor Green
    }
    
    if (-not $destinoAccesible) {
        throw "No se pudo verificar acceso al destino"
    }
    
    # Mostrar parámetros de ejecución
    Write-Host ""
    Show-Banner "PARÁMETROS DE EJECUCIÓN" -BorderColor Cyan -TextColor Cyan
    Write-Host ""
    Write-Host "  Origen:           $origenEjemplo" -ForegroundColor White
    Write-Host "  Destino:          $destinoEjemplo" -ForegroundColor White
    Write-Host "  Tipo Destino:     $tipoDestino" -ForegroundColor White
    Write-Host "  Tamaño Bloque:    $($script:BlockSizeMB) MB" -ForegroundColor White
    Write-Host "  Usar ZIP Nativo:  $($script:UseNativeZip)" -ForegroundColor White
    Write-Host "  Credenciales Red: $(if ($credenciales) { 'Sí (Usuario: ' + $credenciales.UserName + ')' } else { 'No' })" -ForegroundColor White
    Write-Host ""
    Write-Host "Presione ENTER para continuar o CTRL+C para cancelar..." -ForegroundColor Yellow
    Read-Host
    
    # Ejecutar el proceso
    Write-Host ""
    Show-Banner "INICIANDO PROCESO" -BorderColor Cyan -TextColor Cyan
    Write-Host ""
    
    return @{
        Origen             = $origenEjemplo
        Destino            = $destinoEjemplo
        Credenciales       = $credenciales
        DirectoriosLimpiar = @($origenEjemplo)
    }
}

function Remove-ExampleData {
    param(
        [string[]]$Directories,
        [string]$TempDir
    )
    
    Write-Host ""
    Show-Banner "LIMPIEZA DE ARCHIVOS DE EJEMPLO" -BorderColor Cyan -TextColor Cyan
    Write-Host ""
    
    foreach ($dir in $Directories) {
        if (Test-Path $dir) {
            Write-Host "Eliminando: $dir" -ForegroundColor Gray
            Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path $dir) {
                Write-Host "  ✗ No se pudo eliminar completamente" -ForegroundColor Yellow
            }
            else {
                Write-Host "  ✓ Eliminado" -ForegroundColor Green
            }
        }
    }
    
    if ($TempDir -and (Test-Path $TempDir)) {
        Write-Host "Eliminando archivos temporales: $TempDir" -ForegroundColor Gray
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $TempDir) {
            Write-Host "  ✗ No se pudo eliminar completamente" -ForegroundColor Yellow
        }
        else {
            Write-Host "  ✓ Eliminado" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    Write-Host "✓ Limpieza completada" -ForegroundColor Green
    Write-Host ""
}

function Show-Help {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  LLEVAR-USB - Sistema de transporte de carpetas en múltiples USBs" -ForegroundColor Cyan
    Write-Host "  Versión PowerShell del clásico LLEVAR.BAT de Alex Soft" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "SINOPSIS:" -ForegroundColor Yellow
    Write-Host "  Comprime y divide carpetas grandes en bloques para transportar en múltiples USBs."
    Write-Host "  Genera instalador automático que reconstruye el contenido en la máquina destino."
    Write-Host ""
    Write-Host "USO:" -ForegroundColor Yellow
    Write-Host "  .\Llevar.ps1 [-Origen <ruta>] [-Destino <ruta>] [-BlockSizeMB <n>] [opciones]"
    Write-Host ""
    Write-Host "PARÁMETROS PRINCIPALES:" -ForegroundColor Yellow
    Write-Host "  -Origen <ruta>       Carpeta que se desea transportar (se comprime completa)"
    Write-Host "                       Si no se especifica, se solicitará interactivamente"
    Write-Host ""
    Write-Host "  -Destino <ruta>      Carpeta de destino recomendada en la máquina final"
    Write-Host "                       Se guarda dentro del INSTALAR.ps1 generado"
    Write-Host "                       Si no se especifica, se solicitará interactivamente"
    Write-Host ""
    Write-Host "  -BlockSizeMB <n>     Tamaño de cada bloque .alx en megabytes (por defecto: 10)"
    Write-Host "                       Ajustar según capacidad de los USBs disponibles"
    Write-Host "                       Ejemplo: -BlockSizeMB 50 para bloques de 50 MB"
    Write-Host ""
    Write-Host "  -Clave <password>    Contraseña para encriptar el archivo (solo con 7-Zip)"
    Write-Host "                       NOTA: ZIP nativo NO soporta contraseñas"
    Write-Host ""
    Write-Host "OPCIONES DE COMPRESIÓN:" -ForegroundColor Yellow
    Write-Host "  -UseNativeZip        Fuerza el uso de compresión ZIP nativa de Windows"
    Write-Host "                       Requiere Windows 10 o superior"
    Write-Host "                       No requiere 7-Zip instalado"
    Write-Host "                       Sin soporte para contraseñas"
    Write-Host ""
    Write-Host "                       Si NO se especifica:"
    Write-Host "                       • Busca 7-Zip automáticamente (recomendado)"
    Write-Host "                       • Si no encuentra 7-Zip, ofrece usar ZIP nativo"
    Write-Host ""
    Write-Host "OPCIONES AVANZADAS:" -ForegroundColor Yellow
    Write-Host "  -Iso                 Genera una imagen ISO en lugar de copiar a USBs"
    Write-Host "  -IsoDestino <tipo>   Tipo de medio ISO: 'usb', 'cd', 'dvd' (por defecto: dvd)"
    Write-Host "                       • cd  → 700 MB (divide en múltiples ISOs si excede)"
    Write-Host "                       • dvd → 4.5 GB (divide en múltiples ISOs si excede)"
    Write-Host "                       • usb → 4.5 GB (divide en múltiples ISOs si excede)"
    Write-Host "                       Si el contenido supera la capacidad, genera múltiples"
    Write-Host "                       volúmenes ISO (VOL01, VOL02, etc.) con lógica similar"
    Write-Host "                       a USBs: instalador en VOL01, __EOF__ en último volumen"
    Write-Host ""
    Write-Host "  -Ejemplo             Modo demostración automático"
    Write-Host "                       Genera carpeta EJEMPLO con archivo de 20MB"
    Write-Host "                       Ejecuta proceso completo y limpia al finalizar"
    Write-Host "                       Útil para probar el programa sin datos reales"
    Write-Host ""
    Write-Host "  -Ayuda, -h           Muestra esta ayuda y termina"
    Write-Host ""
    Write-Host "  -RobocopyMirror      Modo copia espejo simple con Robocopy"
    Write-Host "                       Sincroniza origen con destino (MIRROR)"
    Write-Host "                       ⚠ ELIMINA archivos en destino que no existen en origen"
    Write-Host "                       Uso: .\Llevar.ps1 -RobocopyMirror [-Origen <ruta>] [-Destino <ruta>]"
    Write-Host "                       Si no se especifican rutas, las solicitará interactivamente"
    Write-Host ""
    Write-Host "FLUJO DE TRABAJO:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [MÁQUINA ORIGEN]" -ForegroundColor Green
    Write-Host "  1. Ejecutar: .\Llevar.ps1 -Origen C:\MiCarpeta -Destino D:\Restaurar"
    Write-Host "  2. El programa comprime la carpeta (7-Zip o ZIP nativo)"
    Write-Host "  3. Divide en bloques: MiCarpeta.alx0001, .alx0002, .alx0003, etc."
    Write-Host "  4. Solicita USBs uno por uno y copia los bloques"
    Write-Host "  5. Genera INSTALAR.ps1 en la primera USB"
    Write-Host "  6. Marca la última USB con __EOF__"
    Write-Host ""
    Write-Host "  [MÁQUINA DESTINO]" -ForegroundColor Green
    Write-Host "  1. Insertar primera USB (la que tiene INSTALAR.ps1)"
    Write-Host "  2. Ejecutar: .\INSTALAR.ps1"
    Write-Host "  3. El instalador pide los demás USBs automáticamente"
    Write-Host "  4. Reconstruye y descomprime la carpeta original"
    Write-Host "  5. Deja el contenido en la ruta especificada"
    Write-Host ""
    Write-Host "MÉTODOS DE COMPRESIÓN:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [7-ZIP] - Recomendado" -ForegroundColor Green
    Write-Host "  ✓ Mejor compresión que ZIP"
    Write-Host "  ✓ Soporta contraseñas y encriptación"
    Write-Host "  ✓ Búsqueda automática: PATH → script → instalación → descarga"
    Write-Host ""
    Write-Host "  [ZIP NATIVO] - Fallback o forzado con -UseNativeZip" -ForegroundColor Cyan
    Write-Host "  ✓ Requiere Windows 10 o superior"
    Write-Host "  ✓ No requiere software adicional"
    Write-Host "  ✗ NO soporta contraseñas"
    Write-Host "  • Comprime en un solo ZIP y luego lo divide en bloques"
    Write-Host ""
    Write-Host "EJEMPLOS:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  # Uso básico con 7-Zip (automático):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen C:\Proyectos -Destino D:\Proyectos -BlockSizeMB 100"
    Write-Host ""
    Write-Host "  # Forzar ZIP nativo de Windows:" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen C:\Datos -Destino D:\Datos -UseNativeZip"
    Write-Host ""
    Write-Host "  # Con contraseña (requiere 7-Zip):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen C:\Secreto -Destino D:\Secreto -Clave "MiPassword123""
    Write-Host ""
    Write-Host "  # Generar ISO en lugar de copiar a USBs:" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen C:\App -Destino D:\App -Iso -IsoDestino dvd"
    Write-Host ""
    Write-Host "  # Generar múltiples ISOs de CD (700MB cada uno, divide automáticamente):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen C:\GranProyecto -Destino D:\Proyecto -Iso -IsoDestino cd"
    Write-Host ""
    Write-Host "  # Modo interactivo (sin parámetros):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1"
    Write-Host ""
    Write-Host "  # Modo ejemplo automático (demostración):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Ejemplo"
    Write-Host ""
    Write-Host "  # Subir carpeta local a OneDrive (con compresión):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen C:\MiProyecto -Destino onedrive:///Backups/Proyecto -OnedriveDestino"
    Write-Host ""
    Write-Host "  # Descargar desde OneDrive a local (transferencia directa):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen onedrive:///Documentos/Importante -Destino C:\Descargas -OnedriveOrigen"
    Write-Host ""
    Write-Host "  # OneDrive a OneDrive con compresión:" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -OnedriveOrigen -OnedriveDestino -BlockSizeMB 50"
    Write-Host ""
    Write-Host "  # Subir a Dropbox con compresión:" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen C:\Documentos -Destino dropbox:///Backups/Docs -DropboxDestino"
    Write-Host ""
    Write-Host "  # Descargar desde Dropbox a local (directo):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen dropbox:///Proyectos/App -Destino C:\Proyectos -DropboxOrigen"
    Write-Host ""
    Write-Host "  # Copia espejo con Robocopy (sincronización simple):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -RobocopyMirror -Origen C:\Datos -Destino D:\Respaldo"
    Write-Host ""
    Write-Host "  # Robocopy sin especificar rutas (modo interactivo):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -RobocopyMirror"
    Write-Host ""
    Write-Host "SOPORTE ONEDRIVE:" -ForegroundColor Yellow
    Write-Host "  -OnedriveOrigen      Indica que el origen es OneDrive"
    Write-Host "  -OnedriveDestino     Indica que el destino es OneDrive"
    Write-Host ""
    Write-Host "  Requisitos:" -ForegroundColor Cyan
    Write-Host "  • Módulo Microsoft.Graph (se instala automáticamente si falta)"
    Write-Host "  • Permisos: Files.ReadWrite.All"
    Write-Host "  • Autenticación con MFA soportada"
    Write-Host ""
    Write-Host "  Formato de rutas OneDrive:" -ForegroundColor Cyan
    Write-Host "  • onedrive:///carpeta/subcarpeta"
    Write-Host "  • ONEDRIVE:/carpeta/archivo.txt"
    Write-Host "  • Si no se especifica ruta, se solicitará interactivamente"
    Write-Host ""
    Write-Host "  Modos de transferencia:" -ForegroundColor Cyan
    Write-Host "  • Directo: Copia archivos sin comprimir (más rápido)"
    Write-Host "  • Comprimir: Genera bloques + INSTALAR.ps1 (para reinstalar en otro equipo)"
    Write-Host ""
    Write-Host "SOPORTE DROPBOX:" -ForegroundColor Yellow
    Write-Host "  -DropboxOrigen       Indica que el origen es Dropbox"
    Write-Host "  -DropboxDestino      Indica que el destino es Dropbox"
    Write-Host ""
    Write-Host "  Requisitos:" -ForegroundColor Cyan
    Write-Host "  • Autenticación OAuth2 con MFA soportada"
    Write-Host "  • Navegador para autorizar la aplicación"
    Write-Host "  • Token se obtiene automáticamente"
    Write-Host ""
    Write-Host "  Formato de rutas Dropbox:" -ForegroundColor Cyan
    Write-Host "  • dropbox:///carpeta/subcarpeta"
    Write-Host "  • DROPBOX:/archivo.txt"
    Write-Host "  • Si no se especifica ruta, se solicitará interactivamente"
    Write-Host ""
    Write-Host "  Modos de transferencia:" -ForegroundColor Cyan
    Write-Host "  • Directo: Copia archivos sin comprimir (más rápido)"
    Write-Host "  • Comprimir: Genera bloques + INSTALAR.ps1 (para reinstalar en otro equipo)"
    Write-Host ""
    Write-Host "  Características:" -ForegroundColor Cyan
    Write-Host "  • Soporta archivos grandes (>150MB) con upload por sesiones"
    Write-Host "  • Barra de progreso para archivos grandes"
    Write-Host "  • Upload/Download de carpetas completas"
    Write-Host ""
    Write-Host "LOGS:" -ForegroundColor Yellow
    Write-Host "  Solo se generan en caso de error:"
    Write-Host "  • Origen:  %TEMP%\LLEVAR_ERROR.log"
    Write-Host "  • Destino: %TEMP%\INSTALAR_ERROR.log"
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

# ========================================================================== #
#                    PLANTILLA DEL INSTALADOR (EMBUTIDA)                     #
# ========================================================================== #

$InstallerBaseScript = @'
<#
INSTALAR.ps1  
Reconstruye bloques <Nombre>.alx0001 .  
Recrea archivo .7z  
Descomprime carpeta original  
Logs solo en caso de error: %TEMP%\INSTALAR_ERROR.log
#>

param(
    [string]$Destino
)

if (-not $Destino -and $script:DefaultDestino) {
    $Destino = $script:DefaultDestino
}

# ========================================================================== #
#                          LOG Y MANEJO DE ERRORES                           #
# ========================================================================== #

$Global:LogFile = Join-Path $env:TEMP "INSTALAR_ERROR.log"

function Write-ErrorLog {
    param($Message, $ErrorRecord)

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $Global:LogFile ""
    Add-Content $Global:LogFile "[$time] ERROR: $Message"

    if ($ErrorRecord) {
        Add-Content $Global:LogFile "Línea: $($ErrorRecord.InvocationInfo.ScriptLineNumber)"
        Add-Content $Global:LogFile "Columna: $($ErrorRecord.InvocationInfo.OffsetInLine)"
        Add-Content $Global:LogFile "CallStack: $($ErrorRecord.InvocationInfo.PositionMessage)"
    }
}

# ========================================================================== #
#                           EXPLORADOR DOS CLÁSICO                           #
# ========================================================================== #

function Select-FolderDOS {
    param([string]$Prompt)

    Write-Host ""
    Write-Host "=== $Prompt ===" -ForegroundColor Cyan

    $drives = Get-PSDrive -PSProvider FileSystem

    while ($true) {

        Write-Host ""
        Write-Host "Seleccione una unidad:"
        $i = 1
        foreach ($d in $drives) {
            Write-Host " [$i] $($d.Root)"
            $i++
        }
        Write-Host " [0] Cancelar"

        $sel = Read-Host "Opción"
        if ($sel -eq "0") { return $null }

        if ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $drives.Count) {
            $drive = $drives[[int]$sel - 1].Root

            while ($true) {
                Write-Host ""
                Write-Host "Contenido de $drive"
                $items = Get-ChildItem $drive -Directory -ErrorAction SilentlyContinue
                $j = 1
                foreach ($it in $items) {
                    Write-Host " [$j] $($it.Name)"
                    $j++
                }
                Write-Host " [..] Volver"
                Write-Host " [.] Seleccionar esta carpeta"

                $op = Read-Host "Opción"
                if ($op -eq '.') { return $drive }
                if ($op -eq '..') { break }

                if ($op -match '^\d+$' -and [int]$op -ge 1 -and [int]$op -le $items.Count) {
                    $drive = $items[[int]$op - 1].FullName
                }
            }
        }
    }
}

# ========================================================================== #
#                        DETECTAR VERSIÓN DE WINDOWS                         #
# ========================================================================== #

function Test-Windows10OrLater {
    $version = [System.Environment]::OSVersion.Version
    return ($version.Major -ge 10)
}

# ========================================================================== #
#                    COMPRIMIR CON ZIP NATIVO DE WINDOWS                     #
# ========================================================================== #

function Compress-WithNativeZip {
    param(
        [string]$Origen,
        [string]$Temp,
        [string]$Clave
    )

    if (-not (Test-Windows10OrLater)) {
        throw "La compresión nativa requiere Windows 10 o superior."
    }

    $Name = Split-Path $Origen -Leaf
    $zipFile = Join-Path $Temp "$Name.zip"

    Write-Host "Comprimiendo con ZIP nativo de Windows..." -ForegroundColor Cyan
    $startTime = Get-Date
    $barTop = [console]::CursorTop
    Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Compresión ZIP..." -Top $barTop

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        # Si hay clave, mostrar advertencia
        if ($Clave) {
            Write-Host "ADVERTENCIA: ZIP nativo de Windows no soporta encriptación con contraseña." -ForegroundColor Yellow
            Write-Host "El archivo se comprimirá SIN protección de contraseña." -ForegroundColor Yellow
        }

        # Comprimir con progreso simulado
        $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
        [System.IO.Compression.ZipFile]::CreateFromDirectory($Origen, $zipFile, $compressionLevel, $false)
        
        Write-LlevarProgressBar -Percent 100 -StartTime $startTime -Label "Compresión ZIP..." -Top $barTop
        Write-Host "`nCompresión completada: $zipFile" -ForegroundColor Green
        
        return $zipFile
    }
    catch {
        Write-Host "Error al comprimir con ZIP nativo: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# ========================================================================== #
#                        DETECTAR 7-ZIP (INSTALADOR)                         #
# ========================================================================== #

function Get-7z {
    # 1) Intentar ejecutar 7z desde el PATH (puede estar en variables de entorno)
    try {
        $cmd = Get-Command 7z -ErrorAction SilentlyContinue
        if ($cmd) {
            # Verificar que realmente funciona
            $testResult = & $cmd.Source 2>&1
            if ($LASTEXITCODE -ne 255 -and $testResult) {
                return $cmd.Source
            }
        }
    }
    catch {
        # Si falla, continuar con la búsqueda en rutas
    }

    # 2) Buscar 7z/7za junto al INSTALAR.ps1 (en la USB)
    $localCandidates = @(
        (Join-Path $PSScriptRoot "7za.exe"),
        (Join-Path $PSScriptRoot "7z.exe")
    )
    foreach ($p in $localCandidates) {
        if (Test-Path $p) { return $p }
    }

    # 3) Buscar instalación estándar en el sistema
    $paths = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe"
    )

    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }

    Write-Host "No se encontró 7-Zip ni en la USB ni en el sistema." -ForegroundColor Yellow
    throw "No se puede continuar la instalación sin 7-Zip."
}

# ========================================================================== #
#                    DETECTAR BLOQUES EN LA UNIDAD ACTUAL                    #
# ========================================================================== #

function Get-BlocksFromUnit {
    param([string]$Path)

    Get-ChildItem $Path -File |
        Where-Object {
            $_.Name -match '\.7z($|\.)' -or $_.Name -match '\.\d{3}$' -or $_.Name -match '\.alx\d{4}$' -or $_.Name -match '\.zip$'
        } |
        Sort-Object Name |
        Select-Object -ExpandProperty FullName
}

# ========================================================================== #
#                       PEDIR UNIDAD SI FALTAN BLOQUES                       #
# ========================================================================== #

function Request-NextUnit {
    param([string]$ExpectedBlock)

    Write-Host ""
    Write-Host "Falta el bloque: $ExpectedBlock" -ForegroundColor Yellow
    Write-Host "Inserte la unidad que lo contiene."
    Read-Host "ENTER cuando esté lista"

    $usb = $null
    while (-not $usb) {
        $usb = Get-Volume |
        Where-Object { $_.DriveType -eq 'Removable' } |
        Select-Object -First 1
        if (-not $usb) {
            Write-Host "No se detecta USB." -ForegroundColor Yellow
            Start-Sleep 2
        }
    }

    return "$($usb.DriveLetter):\"
}

# ========================================================================== #
#                    RECONSTRUCCIÓN DE TODOS LOS BLOQUES                     #
# ========================================================================== #

function Gather-AllBlocks {
    param($InitialPath)

    $blocks = @{}
    $unit = $InitialPath

    while ($true) {

        $current = Get-BlocksFromUnit $unit
        foreach ($c in $current) {
            $name = Split-Path $c -Leaf
            $blocks[$name] = $c
        }

        # ¿Está __EOF__ aquí?
        if (Test-Path (Join-Path $unit "__EOF__")) {
            break
        }

        # Determinar el siguiente bloque esperado 7z (.7z, .7z.001, .7z.002, o .001, .002, etc.)
        $sorted = $blocks.Keys | Sort-Object
        $last = $sorted[-1]

        $baseName = $null
        $nextName = $null

        if ($last -match '^(?<n>.+\.7z)\.(?<num>\d{3})$') {
            $baseName = $matches['n']
            $num = [int]$matches['num']
            $nextName = ('{0}.{1:D3}' -f $baseName, ($num + 1))
        }
        elseif ($last -match '^(?<n>.+)\.(?<num>\d{3})$') {
            $baseName = $matches['n']
            $num = [int]$matches['num']
            $nextName = ('{0}.{1:D3}' -f $baseName, ($num + 1))
        }
        else {
            break
        }

        $nextUnit = Request-NextUnit $nextName
        $unit = $nextUnit
    }

    return $blocks
}

# ========================================================================== #
#                          RECONSTRUIR ARCHIVO .7Z                           #
# ========================================================================== #

function Rebuild-7z {
    param($Blocks, $Temp)

    # Para volúmenes nativos de 7-Zip no hay que reconstruir nada;
    # simplemente devolver la ruta del primer volumen.
    $firstKey = ($Blocks.Keys | Sort-Object)[0]
    return $Blocks[$firstKey]
}

# ========================================================================== #
#                                DESCOMPRIMIR                                #
# ========================================================================== #

function Extract-7z {
    param($SevenZ, $Destino, $7z)

    Write-Host "Descomprimiendo..." -ForegroundColor Cyan
    & $7z x $SevenZ "-o$Destino" -y | Out-Null
    Write-Host "Completado." -ForegroundColor Green
}

function Extract-NativeZip {
    param($ZipFile, $Destino)

    Write-Host "Descomprimiendo con ZIP nativo de Windows..." -ForegroundColor Cyan
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $Destino, $true)
        Write-Host "Completado." -ForegroundColor Green
    }
    catch {
        Write-Host "Error al descomprimir ZIP: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# ========================================================================== #
#                     RECONSTRUIR ZIP DESDE BLOQUES .alx                     #
# ========================================================================== #

function Rebuild-ZipFromBlocks {
    param($blocks, $Temp)

    Write-Host "Reconstruyendo archivo ZIP desde bloques..." -ForegroundColor Cyan
    
    $sorted = $blocks.Keys | Sort-Object
    $first = $sorted[0]
    
    # Determinar nombre base
    if ($first -match '^(?<name>.+)\.alx\d+$') {
        $baseName = $matches['name']
    }
    else {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($first)
    }
    
    $zipOutput = Join-Path $Temp "$baseName.zip"
    $outStream = [System.IO.File]::Create($zipOutput)
    
    $totalBlocks = $sorted.Count
    $current = 0
    
    foreach ($blockName in $sorted) {
        $current++
        $blockPath = $blocks[$blockName]
        
        Write-Host "Copiando bloque $current de $totalBlocks : $blockName" -ForegroundColor Gray
        
        if (-not (Test-Path $blockPath)) {
            $outStream.Close()
            throw "Falta el bloque: $blockName"
        }
        
        try {
            $inStream = [System.IO.File]::OpenRead($blockPath)
            $inStream.CopyTo($outStream)
            $inStream.Close()
        }
        catch {
            $outStream.Close()
            throw "Error al copiar bloque $blockName : $($_.Exception.Message)"
        }
    }
    
    $outStream.Close()
    Write-Host "Archivo ZIP reconstruido: $zipOutput" -ForegroundColor Green
    return $zipOutput
}

# ========================================================================== #
#                         MANEJAR CARPETA EXISTENTE                          #
# ========================================================================== #

function Handle-ExistingFolder {
    param($Destino, $FolderName)

    $target = Join-Path $Destino $FolderName

    if (-not (Test-Path $target)) { return $target }

    Write-Host "La carpeta $FolderName ya existe." -ForegroundColor Yellow
    Write-Host "[1] Sobrescribir todo"
    Write-Host "[2] Sobrescribir solo más nuevos"
    Write-Host "[3] Elegir otra carpeta"
    Write-Host "[4] Cancelar"

    $opt = Read-Host "Opción"
    switch ($opt) {
        "1" { return $target }
        "2" { return $target } # la lógica se aplica al descomprimir
        "3" {
            $nuevo = Select-FolderDOS "Seleccione nuevo destino"
            return "$nuevo\$FolderName"
        }
        "4" { throw "Instalación cancelada" }
        default { return $target }
    }
}

# ========================================================================== #
#                       FLUJO PRINCIPAL DEL INSTALADOR                       #
# ========================================================================== #

try {

    # Determinar unidad de origen
    $myPath = $PSScriptRoot + "\"
    Write-Host "Buscando bloques en $myPath"

    $blocks = Gather-AllBlocks $myPath

    if ($blocks.Count -eq 0) { throw "No hay bloques de archivo comprimido." }

    # Determinar nombre base (sin extensión de volumen)
    $first = ($blocks.Keys | Sort-Object)[0]
    if ($first -match '^(?<n>.+)\.(?<ext>7z|\d{3})$') {
        $FolderName = $matches['n']
    }
    else {
        $FolderName = [System.IO.Path]::GetFileNameWithoutExtension($first)
    }

    # Determinar destino
    if (-not $Destino) {
        $Destino = $myPath
    }

    if (-not (Test-Path $Destino)) {
        Write-Host "Destino no existe. Creando..."
        New-Item -ItemType Directory -Path $Destino -Force | Out-Null
    }

    # Manejar carpeta existente
    $Destino = Handle-ExistingFolder $Destino $FolderName

    # Crear temporales
    $Temp = Join-Path $env:TEMP "INSTALAR_TEMP"
    if (Test-Path $Temp) { Remove-Item $Temp -Recurse -Force }
    New-Item -ItemType Directory -Path $Temp | Out-Null

    # Verificar tipo de compresión (por defecto 7ZIP si no está definido)
    if (-not $script:CompressionType) {
        $script:CompressionType = "7ZIP"
    }

    Write-Host "Tipo de compresión detectado: $script:CompressionType" -ForegroundColor Cyan

    if ($script:CompressionType -eq "NATIVE_ZIP") {
        # Flujo para ZIP nativo
        Write-Host "Procesando archivo comprimido con ZIP nativo de Windows..." -ForegroundColor Cyan
        
        # Reconstruir ZIP desde bloques .alx
        $zipFull = Rebuild-ZipFromBlocks $blocks $Temp
        
        # Descomprimir con ZIP nativo
        Extract-NativeZip $zipFull $Destino
    }
    else {
        # Flujo para 7-Zip (por defecto)
        # Reconstruir 7z
        $SevenZFull = Rebuild-7z $blocks $Temp

        # Detectar 7z
        $7z = Get-7z

        # Descomprimir
        Extract-7z $SevenZFull $Destino $7z
    }

    # Limpieza
    Remove-Item $Temp -Recurse -Force

    Write-Host "`n✓ Instalación completada."
}
catch {
    Write-ErrorLog "Error en instalación" $_
    Write-Host "Ocurrió un error. Revise el log en $Global:LogFile" -ForegroundColor Red
}
'@

# ========================================================================== #
#                     EXPLORADOR NORTON COMMANDER STYLE                      #
# ========================================================================== #

function Select-PathNavigator {
    <#
    .SYNOPSIS
        Explorador de archivos/carpetas estilo Norton Commander con navegación por teclado
    .PARAMETER Prompt
        Título del explorador
    .PARAMETER AllowFiles
        Si es $true, permite seleccionar archivos. Si es $false, solo carpetas.
    #>
    param(
        [string]$Prompt = "Seleccionar ubicación",
        [bool]$AllowFiles = $false
    )
    
    # Obtener todas las unidades disponibles (solo letras de unidad A-Z)
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -and $_.Name -match '^[A-Z]$' }
    $currentPath = $PWD.Path
    $selectedIndex = 0
    $scrollOffset = 0
    
    # Función auxiliar para buscar recursos compartidos en la red
    function Get-NetworkShares {
        $shares = @()
        
        try {
            Write-Host "`nBuscando recursos compartidos en la red..." -ForegroundColor Cyan
            Write-Host "Esto puede tardar unos segundos..." -ForegroundColor Gray
            
            # Obtener computadoras en la red local
            $computers = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue | 
            Select-Object -ExpandProperty Name
            
            # Buscar en la red local usando net view
            $netView = net view /all 2>$null
            foreach ($line in $netView) {
                if ($line -match '\\\\(.+?)\s') {
                    $computerName = $matches[1]
                    $shares += [PSCustomObject]@{
                        Name            = "\\\\$computerName"
                        FullName        = "\\\\$computerName"
                        IsDirectory     = $true
                        IsParent        = $false
                        IsDriveSelector = $false
                        IsNetworkShare  = $true
                        Size            = "<RED>"
                        Icon            = "🌐"
                    }
                }
            }
        }
        catch {
            # Silenciar errores
        }
        
        if ($shares.Count -eq 0) {
            $shares += [PSCustomObject]@{
                Name            = "(No se encontraron recursos compartidos)"
                FullName        = ""
                IsDirectory     = $false
                IsParent        = $false
                IsDriveSelector = $false
                IsNetworkShare  = $false
                Size            = ""
                Icon            = "⚠"
            }
        }
        
        return $shares
    }
    
    # Función auxiliar para mostrar selector de unidades
    function Show-DriveSelector {
        $driveItems = @()
        foreach ($drive in $drives) {
            $driveItems += [PSCustomObject]@{
                Name            = "$($drive.Root) - $($drive.Description)"
                FullName        = $drive.Root
                IsDirectory     = $true
                IsParent        = $false
                IsDriveSelector = $false
                Size            = ""
                Icon            = "💾"
            }
        }
        return $driveItems
    }
    
    # Función auxiliar para obtener items del directorio actual
    function Get-DirectoryItems {
        param([string]$Path)
        
        $items = @()
        
        try {
            # Detectar si estamos en la raíz de una unidad (C:\, D:\, etc.)
            $isRootDrive = $Path -match '^[A-Za-z]:\\$'
            
            if ($isRootDrive) {
                # En raíz: agregar "..." para ir al selector de unidades
                $items += [PSCustomObject]@{
                    Name            = "..."
                    FullName        = ""
                    IsDirectory     = $true
                    IsParent        = $false
                    IsDriveSelector = $true
                    Size            = ""
                    Icon            = "💾"
                }
            }
            elseif ($Path -ne "") {
                # No estamos en raíz: agregar ".." para subir
                $items += [PSCustomObject]@{
                    Name            = ".."
                    FullName        = Split-Path $Path -Parent
                    IsDirectory     = $true
                    IsParent        = $true
                    IsDriveSelector = $false
                    Size            = ""
                    Icon            = "▲"
                }
            }
            
            # Obtener directorios
            $dirs = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue | Sort-Object Name
            foreach ($dir in $dirs) {
                $items += [PSCustomObject]@{
                    Name            = $dir.Name
                    FullName        = $dir.FullName
                    IsDirectory     = $true
                    IsParent        = $false
                    IsDriveSelector = $false
                    Size            = "<DIR>"
                    Icon            = "📁"
                }
            }
            
            # Obtener archivos si está permitido
            if ($AllowFiles) {
                $files = Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue | Sort-Object Name
                foreach ($file in $files) {
                    $sizeKB = [math]::Round($file.Length / 1KB, 2)
                    $items += [PSCustomObject]@{
                        Name            = $file.Name
                        FullName        = $file.FullName
                        IsDirectory     = $false
                        IsParent        = $false
                        IsDriveSelector = $false
                        Size            = "$sizeKB KB"
                        Icon            = "📄"
                    }
                }
            }
        }
        catch {
            # Si hay error accediendo al directorio, volver atrás
        }
        
        return $items
    }
    
    # Función para dibujar la interfaz
    function Draw-Interface {
        param(
            [string]$Path,
            [array]$Items,
            [int]$SelectedIndex,
            [int]$ScrollOffset
        )
        
        Clear-Host
        $width = [Math]::Min($host.UI.RawUI.WindowSize.Width - 2, 118)
        $height = [Math]::Min($host.UI.RawUI.WindowSize.Height - 12, 25)
        
        # Encabezado
        Write-Host ("╔" + ("═" * ($width)) + "╗") -ForegroundColor Cyan
        $titlePadding = [Math]::Max(0, ($width - $Prompt.Length) / 2)
        Write-Host ("║" + (" " * [Math]::Floor($titlePadding)) + $Prompt + (" " * [Math]::Ceiling($titlePadding)) + "║") -ForegroundColor Cyan
        Write-Host ("╠" + ("═" * ($width)) + "╣") -ForegroundColor Cyan
        
        # Ruta actual
        $pathDisplay = $Path
        if ($pathDisplay.Length -gt ($width - 4)) {
            $pathDisplay = "..." + $pathDisplay.Substring($pathDisplay.Length - ($width - 7))
        }
        Write-Host ("║ " + $pathDisplay.PadRight($width - 2) + " ║") -ForegroundColor Yellow
        Write-Host ("╠" + ("═" * ($width)) + "╣") -ForegroundColor Cyan
        
        # Lista de items
        $visibleItems = $height
        for ($i = 0; $i -lt $visibleItems; $i++) {
            $itemIndex = $i + $ScrollOffset
            
            if ($itemIndex -lt $Items.Count) {
                $item = $Items[$itemIndex]
                $isSelected = ($itemIndex -eq $SelectedIndex)
                
                # Preparar el texto del item
                $icon = $item.Icon
                $name = $item.Name
                $size = $item.Size
                
                # Truncar nombre si es muy largo
                $maxNameLength = $width - 20
                if ($name.Length -gt $maxNameLength) {
                    $name = $name.Substring(0, $maxNameLength - 3) + "..."
                }
                
                $line = " $icon $name".PadRight($width - 12) + $size.PadLeft(10)
                
                if ($isSelected) {
                    Write-Host ("║") -ForegroundColor Cyan -NoNewline
                    Write-Host $line.PadRight($width - 2) -BackgroundColor DarkCyan -ForegroundColor White -NoNewline
                    Write-Host ("║") -ForegroundColor Cyan
                }
                else {
                    $color = if ($item.IsDirectory) { "White" } else { "Gray" }
                    Write-Host ("║") -ForegroundColor Cyan -NoNewline
                    Write-Host $line.PadRight($width - 2) -ForegroundColor $color -NoNewline
                    Write-Host ("║") -ForegroundColor Cyan
                }
            }
            else {
                Write-Host ("║" + (" " * ($width - 2)) + "║") -ForegroundColor Cyan
            }
        }
        
        # Pie con instrucciones
        Write-Host ("╠" + ("═" * ($width)) + "╣") -ForegroundColor Cyan
        
        $instructions = "↑↓:Nav │ Enter:Entrar │ ←:Atrás │ F2:Unidades │ F3:Red │ F10:Seleccionar │ ESC:Salir"
        
        if ($instructions.Length -gt ($width - 4)) {
            $instructions = "↑↓ │ Enter │ ← │ F2:Unit │ F3:Red │ F10:Sel │ ESC"
        }
        
        $instrPadding = [Math]::Max(0, ($width - $instructions.Length) / 2)
        Write-Host ("║ " + (" " * [Math]::Floor($instrPadding)) + $instructions + (" " * [Math]::Ceiling($instrPadding - 1)) + "║") -ForegroundColor Green
        Write-Host ("╚" + ("═" * ($width)) + "╝") -ForegroundColor Cyan
        
        # Información adicional
        Write-Host ""
        $selectedItem = $Items[$SelectedIndex]
        if ($selectedItem) {
            $selectionType = if ($selectedItem.IsDirectory) { "Carpeta" } else { "Archivo" }
            Write-Host " Seleccionado: " -NoNewline -ForegroundColor DarkGray
            Write-Host "$selectionType - $($selectedItem.Name)" -ForegroundColor White
        }
    }
    
    # Si la ruta actual está vacía, mostrar selector de unidades al iniciar
    if ([string]::IsNullOrEmpty($currentPath) -or $currentPath -eq "") {
        $currentPath = " UNIDADES "  # Marcador especial para mostrar selector
    }
    
    # Navegación principal
    while ($true) {
        # Verificar si debemos mostrar selector de unidades
        if ($currentPath -eq " UNIDADES ") {
            $items = Show-DriveSelector
            $pathDisplay = "Seleccione una unidad"
        }
        else {
            $items = Get-DirectoryItems -Path $currentPath
            $pathDisplay = $currentPath
        }
        
        # Ajustar índice si está fuera de rango
        if ($selectedIndex -ge $items.Count) {
            $selectedIndex = [Math]::Max(0, $items.Count - 1)
        }
        
        Draw-Interface -Path $pathDisplay -Items $items -SelectedIndex $selectedIndex -ScrollOffset $scrollOffset
        
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 {
                # Flecha arriba
                if ($selectedIndex -gt 0) {
                    $selectedIndex--
                    if ($selectedIndex -lt $scrollOffset) {
                        $scrollOffset = $selectedIndex
                    }
                }
            }
            40 {
                # Flecha abajo
                if ($selectedIndex -lt ($items.Count - 1)) {
                    $selectedIndex++
                    $visibleHeight = [Math]::Min($host.UI.RawUI.WindowSize.Height - 12, 25)
                    if ($selectedIndex -ge ($scrollOffset + $visibleHeight)) {
                        $scrollOffset = $selectedIndex - $visibleHeight + 1
                    }
                }
            }
            13 {
                # Enter
                $selectedItem = $items[$selectedIndex]
                
                # Si estamos en selector de unidades, cambiar a esa unidad
                if ($currentPath -eq " UNIDADES ") {
                    $currentPath = $selectedItem.FullName
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
                # Si es "..." ir al selector de unidades
                elseif ($selectedItem.IsDriveSelector) {
                    $currentPath = " UNIDADES "
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
                elseif ($selectedItem.IsDirectory) {
                    if ($selectedItem.IsParent) {
                        $parentPath = Split-Path $currentPath -Parent
                        if ($parentPath) {
                            $currentPath = $parentPath
                        }
                        else {
                            # Si no hay parent, ir al selector de unidades
                            $currentPath = " UNIDADES "
                        }
                    }
                    else {
                        $currentPath = $selectedItem.FullName
                    }
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
            }
            39 {
                # Flecha derecha
                $selectedItem = $items[$selectedIndex]
                
                # Si estamos en selector de unidades, entrar a esa unidad
                if ($currentPath -eq " UNIDADES ") {
                    $currentPath = $selectedItem.FullName
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
                # Si es "..." ir al selector de unidades
                elseif ($selectedItem.IsDriveSelector) {
                    $currentPath = " UNIDADES "
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
                elseif ($selectedItem.IsDirectory -and -not $selectedItem.IsParent) {
                    $currentPath = $selectedItem.FullName
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
            }
            37 {
                # Flecha izquierda
                if ($currentPath -eq " UNIDADES ") {
                    # Ya estamos en selector, no hacer nada
                }
                else {
                    $parentPath = Split-Path $currentPath -Parent
                    if ($parentPath) {
                        $currentPath = $parentPath
                    }
                    else {
                        # Si no hay parent, ir al selector de unidades
                        $currentPath = " UNIDADES "
                    }
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
            }
            8 {
                # Backspace
                if ($currentPath -eq " UNIDADES ") {
                    # Ya estamos en selector, no hacer nada
                }
                else {
                    $parentPath = Split-Path $currentPath -Parent
                    if ($parentPath) {
                        $currentPath = $parentPath
                    }
                    else {
                        # Si no hay parent, ir al selector de unidades
                        $currentPath = " UNIDADES "
                    }
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
            }
            113 {
                # F2 - Selector de unidades
                $currentPath = " UNIDADES "
                $selectedIndex = 0
                $scrollOffset = 0
            }
            114 {
                # F3 - Discovery de recursos UNC con credenciales
                Write-Log "Usuario activó F3 para descubrir recursos de red" "INFO"
                
                # Guardar contexto actual
                $savedPath = $currentPath
                
                # Llamar a la función de discovery UNC
                $uncResult = Select-NetworkPath -Purpose "NAVEGADOR"
                
                if ($uncResult -and $uncResult.Path) {
                    # Si se seleccionó un recurso UNC, intentar acceder
                    try {
                        if (Test-Path $uncResult.Path) {
                            $currentPath = $uncResult.Path
                            $selectedIndex = 0
                            $scrollOffset = 0
                            Write-Log "Accedido exitosamente a: $($uncResult.Path)" "INFO"
                        }
                        else {
                            Show-ConsolePopup -Title "Error de Acceso" -Message "No se puede acceder a:`n$($uncResult.Path)`n`nVerifique permisos o credenciales" -Options @("*OK") | Out-Null
                            Write-Log "No se pudo acceder a: $($uncResult.Path)" "WARNING"
                        }
                    }
                    catch {
                        Show-ConsolePopup -Title "Error" -Message "Error al acceder al recurso:`n$($_.Exception.Message)" -Options @("*OK") | Out-Null
                        Write-Log "Error al acceder a recurso UNC: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
                    }
                }
                # Si se canceló, mantener ruta actual
            }
            121 {
                # F10
                $selectedItem = $items[$selectedIndex]
                if ($AllowFiles) {
                    # Permitir seleccionar archivo o carpeta
                    return $selectedItem.FullName
                }
                else {
                    # Solo permitir carpetas
                    if ($selectedItem.IsDirectory -and -not $selectedItem.IsParent -and -not $selectedItem.IsDriveSelector) {
                        return $selectedItem.FullName
                    }
                    elseif ($selectedItem.IsParent) {
                        return $currentPath
                    }
                    else {
                        # Si seleccionó carpeta actual sin tener item específico
                        return $currentPath
                    }
                }
            }
            27 {
                # ESC
                return $null
            }
        }
    }
}

# Función legacy para compatibilidad
function Select-FolderDOS-Llevar {
    param([string]$Prompt)
    return Select-PathNavigator -Prompt $Prompt -AllowFiles $false
}

# ========================================================================== #
#                      OBTENER (O PEDIR) ORIGEN/DESTINO                      #
# ========================================================================== #

function Get-PathOrPrompt {
    param([string]$Path, [string]$Tipo)

    if (-not $Path) {
        $Path = Select-FolderDOS-Llevar "Seleccione carpeta de $Tipo"
    }

    while (-not (Test-Path $Path)) {
        Write-Host "Ruta no válida: $Path" -ForegroundColor Yellow
        $Path = Select-FolderDOS-Llevar "Seleccione carpeta de $Tipo"
    }

    return $Path
}

# ========================================================================== #
#                   ROBOCOPY MIRROR (COPIA ESPEJO SIMPLE)                    #
# ========================================================================== #

function Invoke-RobocopyMirror {
    <#
    .SYNOPSIS
        Realiza una copia espejo simple con Robocopy
    .DESCRIPTION
        Usa Robocopy con /MIR (mirror) para sincronizar origen con destino.
        El destino quedará idéntico al origen (elimina archivos extras en destino).
    .PARAMETER Origen
        Carpeta de origen
    .PARAMETER Destino
        Carpeta de destino
    #>
    param(
        [string]$Origen,
        [string]$Destino
    )
    
    Write-Host ""
    Show-Banner -Message "ROBOCOPY MIRROR - COPIA ESPEJO" -BorderColor Cyan -TextColor Yellow
    Write-Host ""
    Write-Host "  Origen : " -NoNewline -ForegroundColor Gray
    Write-Host $Origen -ForegroundColor White
    Write-Host "  Destino: " -NoNewline -ForegroundColor Gray
    Write-Host $Destino -ForegroundColor White
    Write-Host ""
    Write-Host "⚠ ADVERTENCIA:" -ForegroundColor Yellow
    Write-Host "  El modo MIRROR sincroniza completamente origen y destino." -ForegroundColor Gray
    Write-Host "  Esto significa que:" -ForegroundColor Gray
    Write-Host "  • Copia archivos nuevos y modificados desde origen" -ForegroundColor Gray
    Write-Host "  • ELIMINA archivos en destino que no existen en origen" -ForegroundColor Gray
    Write-Host ""
    Write-Host "¿Desea continuar? (S/N): " -NoNewline -ForegroundColor Yellow
    $respuesta = Read-Host
    
    if ($respuesta -notmatch '^[SsYy]$') {
        Write-Host ""
        Write-Host "Operación cancelada por el usuario." -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "[*] Iniciando copia espejo con Robocopy..." -ForegroundColor Cyan
    Write-Host ""
    
    # Crear destino si no existe
    if (-not (Test-Path $Destino)) {
        Write-Host "    Creando carpeta de destino..." -ForegroundColor Gray
        New-Item -ItemType Directory -Path $Destino -Force | Out-Null
    }
    
    # Ejecutar Robocopy con /MIR
    # /MIR = Mirror (equivale a /E + /PURGE)
    # /R:3 = 3 reintentos en caso de error
    # /W:5 = 5 segundos de espera entre reintentos
    # /NP = No mostrar progreso por archivo (más limpio)
    # /NDL = No mostrar lista de directorios
    # /NFL = No mostrar lista de archivos
    
    $robocopyArgs = @(
        $Origen,
        $Destino,
        '/MIR',
        '/R:3',
        '/W:5',
        '/NP'
    )
    
    Write-Host "    Ejecutando: robocopy $($robocopyArgs -join ' ')" -ForegroundColor DarkGray
    Write-Host ""
    
    $process = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
    $exitCode = $process.ExitCode
    
    Write-Host ""
    
    # Robocopy exit codes:
    # 0 = No se copiaron archivos (ya estaba sincronizado)
    # 1 = Archivos copiados exitosamente
    # 2 = Archivos extras encontrados
    # 3 = Archivos copiados y extras encontrados
    # 4+ = Errores
    
    if ($exitCode -le 3) {
        Write-Host "[✓] Copia espejo completada exitosamente" -ForegroundColor Green
        
        switch ($exitCode) {
            0 { Write-Host "    No hubo cambios, origen y destino ya estaban sincronizados" -ForegroundColor Gray }
            1 { Write-Host "    Se copiaron archivos nuevos o modificados" -ForegroundColor Gray }
            2 { Write-Host "    Se eliminaron archivos extras del destino" -ForegroundColor Gray }
            3 { Write-Host "    Se copiaron archivos y se eliminaron extras" -ForegroundColor Gray }
        }
    }
    else {
        Write-Host "[X] Robocopy finalizó con errores (código: $exitCode)" -ForegroundColor Red
        Write-Host "    Algunos archivos pueden no haberse copiado correctamente" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "    Códigos de error comunes:" -ForegroundColor Gray
        Write-Host "    • 8  = Algunos archivos/carpetas no se pudieron copiar" -ForegroundColor Gray
        Write-Host "    • 16 = Error grave, Robocopy no completó la copia" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
}

# ========================================================================== #
#                          DETECTAR 7-ZIP (LLEVAR)                           #
# ========================================================================== #

function Get-7z-Llevar {
    # 1) Intentar ejecutar 7z desde el PATH (puede estar en variables de entorno)
    try {
        $cmd = Get-Command 7z -ErrorAction SilentlyContinue
        if ($cmd) {
            # Verificar que realmente funciona ejecutándolo
            $testResult = & $cmd.Source 2>&1
            if ($LASTEXITCODE -ne 255 -and $testResult) {
                Write-Host "7-Zip encontrado en PATH: $($cmd.Source)" -ForegroundColor Green
                return $cmd.Source
            }
        }
    }
    catch {
        # Si falla, continuar con la búsqueda en rutas
    }

    # 2) Buscar 7z/7za en el directorio del script (por si ya hay portable)
    $localCandidates = @(
        (Join-Path $PSScriptRoot "7z.exe"),
        (Join-Path $PSScriptRoot "7za.exe")
    )
    foreach ($p in $localCandidates) {
        if (Test-Path $p) { return $p }
    }

    # 3) Buscar instalación estándar
    $paths = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe"
    )

    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }

    # 3) Descargar versión portable a la carpeta del script
    Write-Host "7-Zip no encontrado. Intentando descargar versión portable..." -ForegroundColor Yellow

    try {
        $url = "https://www.7-zip.org/a/7za920.zip"
        $zipPath = Join-Path $PSScriptRoot "7za_portable.zip"
        $destExe = Join-Path $PSScriptRoot "7za.exe"

        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $PSScriptRoot, $true)

        Remove-Item $zipPath -ErrorAction SilentlyContinue

        if (Test-Path $destExe) {
            Write-Host "7-Zip portable descargado en $destExe" -ForegroundColor Green
            return $destExe
        }
        else {
            Write-Host "No se pudo extraer 7za.exe del ZIP descargado." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "No se pudo descargar 7-Zip portable: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 4) Ofrecer usar compresión nativa de Windows si está disponible
    if (Test-Windows10OrLater) {
        Write-Host ""
        Write-Host "7-Zip no está disponible, pero se detectó Windows 10 o superior." -ForegroundColor Yellow
        Write-Host "Puede usar la compresión ZIP nativa de Windows (sin soporte para contraseñas)." -ForegroundColor Yellow
        Write-Host ""
        $response = Read-Host "¿Desea usar compresión ZIP nativa? (S/N)"
        
        if ($response -match '^[SsYy]') {
            return "NATIVE_ZIP"
        }
    }

    throw "7-Zip no encontrado ni descargado. No se puede continuar."
}

# ========================================================================== #
#                       COMPRIMIR EN UN SOLO 7Z O ZIP                        #
# ========================================================================== #

function Compress-Folder {
    param($Origen, $Temp, $SevenZ, $Clave, [int]$BlockSizeMB)

    $Name = Split-Path $Origen -Leaf
    
    # Verificar si se usa ZIP nativo
    if ($SevenZ -eq "NATIVE_ZIP") {
        $zipFile = Compress-WithNativeZip -Origen $Origen -Temp $Temp -Clave $Clave
        
        # Si BlockSizeMB > 0, dividir el ZIP en bloques
        if ($BlockSizeMB -gt 0) {
            Write-Host "`nDividiendo archivo ZIP en bloques de ${BlockSizeMB}MB..." -ForegroundColor Cyan
            $blocks = Split-IntoBlocks -File $zipFile -BlockSizeMB $BlockSizeMB -Temp $Temp
            return @{
                Files           = $blocks
                CompressionType = "NATIVE_ZIP"
                OriginalArchive = $zipFile
            }
        }
        else {
            return @{
                Files           = @($zipFile)
                CompressionType = "NATIVE_ZIP"
                OriginalArchive = $zipFile
            }
        }
    }
    
    # Proceso normal con 7-Zip
    $Out = Join-Path $Temp "$Name.7z"

    $startTime = Get-Date
    $barTop = [console]::CursorTop
    Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Compresión..." -Top $barTop

    $sevenArgs = @("a", "-t7z", "-mx=9", "-bsp1", "-bso0")
    if ($BlockSizeMB -gt 0) {
        $sevenArgs += ("-v{0}m" -f $BlockSizeMB)   # volúmenes en MB
    }
    if ($Clave) {
        $sevenArgs += ("-p$Clave")
    }
    $sevenArgs += @($Out, $Origen)

    & $SevenZ @sevenArgs 2>&1 | ForEach-Object {
        if ($_ -match '(\d+)%') {
            $pct = [double]$matches[1]
            Write-LlevarProgressBar -Percent $pct -StartTime $startTime -Label "Compresión..." -Top $barTop
        }
    }

    Write-LlevarProgressBar -Percent 100 -StartTime $startTime -Label "Compresión..." -Top $barTop

    # Sin división: un solo .7z
    if ($BlockSizeMB -le 0) {
        return @{
            Files           = @($Out)
            CompressionType = "7ZIP"
        }
    }

    # Con división: devolver los volúmenes nativos Nombre.7z.001, .002, ...
    $pattern = "$Name.7z.*"
    $volumes = Get-ChildItem -Path $Temp -Filter $pattern -File | Sort-Object Name

    if (-not $volumes -or $volumes.Count -eq 0) {
        throw "7-Zip no generó volúmenes divididos con -v${BlockSizeMB}m."
    }

    return @{
        Files           = ($volumes | Select-Object -ExpandProperty FullName)
        CompressionType = "7ZIP"
    }
}

# ========================================================================== #
#                      DIVIDIR EL ARCHIVO 7Z EN BLOQUES                      #
# ========================================================================== #

function Split-IntoBlocks {
    param($File, $BlockSizeMB, $Temp)

    $Name = [System.IO.Path]::GetFileNameWithoutExtension($File)
    $fs = [System.IO.File]::OpenRead($File)

    $BlockSize = $BlockSizeMB * 1MB
    $buffer = New-Object byte[] $BlockSize

    $counter = 1
    $totalRead = 0L
    $totalLength = $fs.Length
    $startTime = Get-Date
    $barTop = [console]::CursorTop
    Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Dividiendo en bloques..." -Top $barTop

    $blocks = @()

    while (($read = $fs.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $totalRead += $read
        if ($totalLength -gt 0) {
            $pct = [double](($totalRead * 100.0) / $totalLength)
            Write-LlevarProgressBar -Percent $pct -StartTime $startTime -Label "Dividiendo en bloques..." -Top $barTop
        }

        $num = "{0:D4}" -f $counter
        $OutFile = Join-Path $Temp "$Name.alx$num"
        $blocks += $OutFile

        $out = [System.IO.File]::OpenWrite($OutFile)
        $out.Write($buffer, 0, $read)
        $out.Close()

        $counter++
    }

    $fs.Close()
    Write-LlevarProgressBar -Percent 100 -StartTime $startTime -Label "Dividiendo en bloques..." -Top $barTop
    return $blocks
}

# ========================================================================== #
#                       GENERAR INSTALADOR CONTEXTUAL                        #
# ========================================================================== #

function New-InstallerScript {
    param(
        [string]$Destino,
        [string]$Temp,
        [string]$CompressionType = "7ZIP"
    )

    $lines = $InstallerBaseScript -split "`r?`n"

    $paramStart = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*param\(') {
            $paramStart = $i
            break
        }
    }

    if ($null -eq $paramStart) {
        $installerPath = Join-Path $Temp "Instalar.ps1"
        Set-Content -Path $installerPath -Value $lines -Encoding UTF8
        return $installerPath
    }

    $paramEnd = $paramStart
    while ($paramEnd -lt ($lines.Count - 1) -and $lines[$paramEnd] -notmatch '^\s*\)') {
        $paramEnd++
    }
    $insertIndex = $paramEnd + 1

    $insertLine = "# Destino por defecto no especificado"
    if ($Destino) {
        $escaped = $Destino -replace "'", "''"
        $insertLine = "$script:DefaultDestino = '$escaped'"
    }

    $before = @()
    if ($insertIndex -gt 0) {
        $before = $lines[0..($insertIndex - 1)]
    }

    $after = @()
    if ($insertIndex -lt $lines.Count) {
        $after = $lines[$insertIndex..($lines.Count - 1)]
    }

    $newLines = $before + $insertLine + $after

    # Agregar variable de tipo de compresión
    $compressionLine = "`$script:CompressionType = '$CompressionType'"
    $newLines = $newLines[0..($insertIndex)] + $compressionLine + $newLines[($insertIndex + 1)..($newLines.Count - 1)]

    # Inyectar una versión actualizada de Get-7z al final del instalador
    $get7zPatch = @'
function Get-7z {
    # 1) Intentar ejecutar 7z desde el PATH (puede estar en variables de entorno)
    try {
        $cmd = Get-Command 7z -ErrorAction SilentlyContinue
        if ($cmd) {
            # Verificar que realmente funciona
            $testResult = & $cmd.Source 2>&1
            if ($LASTEXITCODE -ne 255 -and $testResult) {
                return $cmd.Source
            }
        }
    }
    catch {
        # Si falla, continuar con la búsqueda en rutas
    }

    # 2) Buscar 7z/7za junto al INSTALAR.ps1 (en la USB)
    $localCandidates = @(
        (Join-Path $PSScriptRoot "7za.exe"),
        (Join-Path $PSScriptRoot "7z.exe")
    )
    foreach ($p in $localCandidates) {
        if (Test-Path $p) { return $p }
    }

    # 3) Buscar instalación estándar en el sistema
    $paths = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe"
    )

    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }

    # 3) Descargar versión portable a la carpeta TEMP local
    Write-Host "7-Zip no encontrado. Intentando descargar versión portable para la instalación..." -ForegroundColor Yellow

    try {
        $url = "https://www.7-zip.org/a/7za920.zip"
        $tempRoot = Join-Path $env:TEMP "INSTALAR_7ZIP"
        if (-not (Test-Path $tempRoot)) {
            New-Item -ItemType Directory -Path $tempRoot | Out-Null
        }

        $zipPath = Join-Path $tempRoot "7za_portable.zip"
        $destExe = Join-Path $tempRoot "7za.exe"

        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempRoot, $true)

        Remove-Item $zipPath -ErrorAction SilentlyContinue

        if (Test-Path $destExe) {
            Write-Host "7-Zip portable descargado en $destExe" -ForegroundColor Green
            return $destExe
        }
        else {
            Write-Host "No se pudo extraer 7za.exe del ZIP descargado." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "No se pudo descargar 7-Zip portable para la instalación: $($_.Exception.Message)" -ForegroundColor Red
    }

    throw "7-Zip no encontrado ni descargado. No se puede continuar la instalación."
}
'@ -split "`r?`n"

    $newLines = $newLines + $get7zPatch

    $installerPath = Join-Path $Temp "Instalar.ps1"
    Set-Content -Path $installerPath -Value $newLines -Encoding UTF8
    return $installerPath
}

# ========================================================================== #
#                      UTILIDADES DE VOLÚMENES Y COPIA                       #
# ========================================================================== #

function Test-VolumeWritable {
    param(
        [Parameter(Mandatory = $true)] $Volume,
        [long]$RequiredBytes = 0
    )

    if ($Volume.DriveType -ne 'Removable') {
        Write-Host "La unidad $($Volume.DriveLetter): no es removible." -ForegroundColor Yellow
        return $false
    }

    if ($RequiredBytes -gt 0 -and $Volume.SizeRemaining -lt $RequiredBytes) {
        Write-Host "La unidad $($Volume.DriveLetter): no tiene espacio suficiente." -ForegroundColor Yellow
        return $false
    }

    $testPath = "$($Volume.DriveLetter):\__LLEVAR_TEST__.tmp"
    try {
        "test" | Out-File -FilePath $testPath -Encoding ASCII -ErrorAction Stop
        Remove-Item $testPath -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-Host "No se pudo escribir en la unidad $($Volume.DriveLetter):" -ForegroundColor Yellow
        return $false
    }
}

function Get-TargetVolume {
    param(
        [string]$CurrentLetter,
        [long]$RequiredBytes
    )

    while ($true) {
        $volumes = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' }
        if (-not $volumes) {
            Write-Host "No se detecta ninguna unidad removible." -ForegroundColor Yellow
            Start-Sleep 2
            continue
        }

        if ($CurrentLetter) {
            $target = $volumes | Where-Object { $_.DriveLetter -eq $CurrentLetter } | Select-Object -First 1
            if ($target -and (Test-VolumeWritable -Volume $target -RequiredBytes $RequiredBytes)) {
                return $target
            }

            $other = $volumes | Where-Object { $_.DriveLetter -ne $CurrentLetter } | Select-Object -First 1
            if ($other) {
                Write-Host ""
                Write-Host ("La unidad original era {0}:. Ahora se detecta {1}:." -f $CurrentLetter, $other.DriveLetter) -ForegroundColor Yellow
                $ans = Read-Host "¿Usar $($other.DriveLetter): como nuevo destino? (S/N)"
                if ($ans -match '^[sS]') {
                    if (Test-VolumeWritable -Volume $other -RequiredBytes $RequiredBytes) {
                        return $other
                    }
                }
                else {
                    Write-Host ("Reinserte la unidad {0}: y presione ENTER..." -f $CurrentLetter) -ForegroundColor Yellow
                    Read-Host | Out-Null
                    continue
                }
            }

            Write-Host "No se encontró ninguna unidad adecuada." -ForegroundColor Yellow
            Start-Sleep 2
            continue
        }
        else {
            $candidate = $volumes | Select-Object -First 1
            if (Test-VolumeWritable -Volume $candidate -RequiredBytes $RequiredBytes) {
                return $candidate
            }

            Write-Host "La unidad $($candidate.DriveLetter): no es adecuada. Inserte otra y presione ENTER..." -ForegroundColor Yellow
            Read-Host | Out-Null
        }
    }
}

function Copy-BlockWithHashCheck {
    param(
        [string]$BlockPath,
        $Volume,
        [int]$LocalBarTop = -1,
        [int]$GlobalBarTop = -1,
        [ref]$GlobalCopiedBytes = $(New-Object int64 0),
        [long]$GlobalTotalBytes = 0,
        [datetime]$GlobalStartTime = $(Get-Date)
    )

    $destPath = Join-Path ("$($Volume.DriveLetter):\") (Split-Path $BlockPath -Leaf)

    $srcInfo = Get-Item $BlockPath
    $totalSize = $srcInfo.Length

    $localStart = Get-Date
    if ($LocalBarTop -ge 0) {
        Write-LlevarProgressBar -Percent 0 -StartTime $localStart -Label ("Copia bloque {0}" -f (Split-Path $BlockPath -Leaf)) -Top $LocalBarTop
    }
    if ($GlobalBarTop -ge 0 -and $GlobalTotalBytes -gt 0) {
        Write-LlevarProgressBar -Percent ([double](($GlobalCopiedBytes.Value * 100.0) / $GlobalTotalBytes)) -StartTime $GlobalStartTime -Label "Copia total..." -Top $GlobalBarTop
    }

    $bufferSize = 1024 * 1024
    $buffer = New-Object byte[] $bufferSize
    $copiedLocal = 0L

    $inStream = [System.IO.File]::OpenRead($BlockPath)
    $outStream = [System.IO.File]::Open($destPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try {
        while (($read = $inStream.Read($buffer, 0, $bufferSize)) -gt 0) {
            $outStream.Write($buffer, 0, $read)
            $copiedLocal += $read
            $GlobalCopiedBytes.Value += $read

            if ($LocalBarTop -ge 0 -and $totalSize -gt 0) {
                $localPct = [double](($copiedLocal * 100.0) / $totalSize)
                Write-LlevarProgressBar -Percent $localPct -StartTime $localStart -Label ("Copia bloque {0}" -f (Split-Path $BlockPath -Leaf)) -Top $LocalBarTop
            }

            if ($GlobalBarTop -ge 0 -and $GlobalTotalBytes -gt 0) {
                $globalPct = [double](($GlobalCopiedBytes.Value * 100.0) / $GlobalTotalBytes)
                Write-LlevarProgressBar -Percent $globalPct -StartTime $GlobalStartTime -Label "Copia total..." -Top $GlobalBarTop
            }
        }
    }
    finally {
        $inStream.Close()
        $outStream.Close()
    }

    if ($LocalBarTop -ge 0) {
        Write-LlevarProgressBar -Percent 100 -StartTime $localStart -Label ("Copia bloque {0}" -f (Split-Path $BlockPath -Leaf)) -Top $LocalBarTop
    }

    try {
        $srcHash = Get-FileHash -Path $BlockPath -Algorithm SHA256
        $dstHash = Get-FileHash -Path $destPath -Algorithm SHA256

        if ($srcHash.Hash -ne $dstHash.Hash) {
            Write-Host "AVISO: el hash no coincide para $($srcHash.Path)." -ForegroundColor Yellow
            $ans = Read-Host "¿Volver a copiar este bloque? (S/N)"
            if ($ans -match '^[sS]') {
                Copy-Item $BlockPath $destPath -Force
                $srcHash = Get-FileHash -Path $BlockPath -Algorithm SHA256
                $dstHash = Get-FileHash -Path $destPath -Algorithm SHA256
                if ($srcHash.Hash -ne $dstHash.Hash) {
                    throw "Hash no coincide después de reintentar la copia."
                }
            }
            else {
                throw "Hash de copia de bloque no coincide."
            }
        }
    }
    catch {
        Write-Host "Error verificando la copia del bloque: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# ========================================================================== #
#                       COPIAR BLOQUES A UNIDADES USB                        #
# ========================================================================== #

function Copy-BlocksToUSB {
    param(
        $Blocks,
        [string]$InstallerPath,
        [string]$SevenZPath,
        [string]$CompressionType = "7ZIP",
        [string]$DestinationPath = $null,
        [bool]$IsFtp = $false
    )

    # Si el destino es FTP, subir archivos directamente
    if ($IsFtp -and $DestinationPath -match '^FTP:(.+)$') {
        $driveName = $Matches[1]
        Write-Host "`nSubiendo bloques a FTP..." -ForegroundColor Cyan
        
        $totalBytes = 0L
        foreach ($b in $Blocks) {
            $info = Get-Item $b
            $totalBytes += $info.Length
        }
        
        $uploaded = 0
        foreach ($block in $Blocks) {
            $fileName = [System.IO.Path]::GetFileName($block)
            $success = Send-FtpFile -LocalPath $block -DriveName $driveName -RemoteFileName $fileName
            
            if (-not $success) {
                Write-Host "Error al subir $fileName. ¿Desea reintentar?" -ForegroundColor Yellow
                $choice = Read-Host "S/N"
                if ($choice -eq 'S' -or $choice -eq 's') {
                    $success = Send-FtpFile -LocalPath $block -DriveName $driveName -RemoteFileName $fileName
                }
                
                if (-not $success) {
                    throw "Fallo al subir bloques a FTP"
                }
            }
            $uploaded++
        }
        
        # Subir el instalador
        if ($InstallerPath -and (Test-Path $InstallerPath)) {
            $installerName = [System.IO.Path]::GetFileName($InstallerPath)
            Send-FtpFile -LocalPath $InstallerPath -DriveName $driveName -RemoteFileName $installerName
        }
        
        # Subir 7-Zip si es necesario
        if ($SevenZPath -and $CompressionType -ne "NATIVE_ZIP" -and (Test-Path $SevenZPath)) {
            $sevenZName = [System.IO.Path]::GetFileName($SevenZPath)
            Send-FtpFile -LocalPath $SevenZPath -DriveName $driveName -RemoteFileName $sevenZName
        }
        
        Write-Host "`n✓ Todos los archivos subidos a FTP correctamente" -ForegroundColor Green
        return
    }

    # Lógica original para USB
    $firstUSB = $null
    $totalBytes = 0L
    foreach ($b in $Blocks) {
        $info = Get-Item $b
        $totalBytes += $info.Length
    }

    $globalCopied = 0L
    $globalStart = Get-Date

    $globalBarTop = [console]::CursorTop
    Write-Host ""
    $localBarTop = [console]::CursorTop
    Write-Host ""

    foreach ($block in $Blocks) {
        while ($true) {
            Write-Host ""
            Write-Host "Inserte una unidad USB para copiar el bloque:"
            Write-Host "  $([System.IO.Path]::GetFileName($block))"
            Read-Host "Presione ENTER cuando esté lista"

            $usb = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.SizeRemaining -gt 0 } | Select-Object -First 1
            if (-not $usb) {
                Write-Host "No se detecta una USB válida." -ForegroundColor Yellow
                continue
            }

            $free = $usb.SizeRemaining
            $size = (Get-Item $block).Length

            if ($size -gt $free) {
                Write-Host "La USB no tiene espacio suficiente." -ForegroundColor Yellow
                continue
            }

            $refGlobal = [ref]$globalCopied
            Copy-BlockWithHashCheck -BlockPath $block -Volume $usb -LocalBarTop $localBarTop -GlobalBarTop $globalBarTop -GlobalCopiedBytes $refGlobal -GlobalTotalBytes $totalBytes -GlobalStartTime $globalStart
            Write-Host "Copiado a $($usb.DriveLetter):\" -ForegroundColor Green

            if (-not $firstUSB) { $firstUSB = $usb }

            break
        }
    }

    # Último disco → __EOF__
    Write-Host ""
    Write-Host "Inserte la última USB para marcar el final."
    Read-Host "ENTER cuando esté lista"

    $last = $null
    while (-not $last) {
        $last = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.SizeRemaining -gt 0 } | Select-Object -First 1
    }

    New-Item -ItemType File -Path "$($last.DriveLetter):\__EOF__" | Out-Null

    # Copiar instalador y 7-Zip portable en la PRIMERA USB (solo si no es ZIP nativo)
    if ($firstUSB) {
        if ($InstallerPath) {
            Copy-Item $InstallerPath "$($firstUSB.DriveLetter):\" -Force
        }
        if ($SevenZPath -and $CompressionType -ne "NATIVE_ZIP" -and (Test-Path $SevenZPath)) {
            Copy-Item $SevenZPath "$($firstUSB.DriveLetter):\" -Force
        }
    }

    Write-Host "`nProceso completado."
}

# ========================================================================== #
#                   MENU DOS EXTENDIDO (COLORES / HOTKEYS)                   #
# ========================================================================== #

# ========================================================================== #
#                   SISTEMA DE MENÚ INTERACTIVO PRINCIPAL                    #
# ========================================================================== #

function Show-MainMenu {
    <#
    .SYNOPSIS
        Menú principal interactivo de Llevar.ps1
    #>
    
    $config = @{
        # Configuración de Origen
        Origen         = @{
            Tipo           = "Local"  # Local, FTP, OneDrive, Dropbox, UNC, USB
            Path           = $null
            # Solo para FTP
            FtpServer      = $null
            FtpPort        = 21
            FtpDirectory   = "/"
            FtpUser        = $null
            FtpPassword    = $null
            # Solo para UNC/Red
            UncPath        = $null
            UncUser        = $null
            UncPassword    = $null
            UncDomain      = $null
            # Solo para Local/USB
            LocalPath      = $null
            DriveLetter    = $null
            # Solo para OneDrive
            OneDriveEmail  = $null
            OneDriveToken  = $null
            OneDriveApiUrl = "https://graph.microsoft.com/v1.0/me/drive"
            # Solo para Dropbox
            DropboxToken   = $null
            DropboxApiUrl  = "https://api.dropboxapi.com/2"
        }
        
        # Configuración de Destino
        Destino        = @{
            Tipo           = "Local"  # Local, FTP, OneDrive, Dropbox, UNC, USB
            Path           = $null
            # Solo para FTP
            FtpServer      = $null
            FtpPort        = 21
            FtpDirectory   = "/"
            FtpUser        = $null
            FtpPassword    = $null
            # Solo para UNC/Red
            UncPath        = $null
            UncUser        = $null
            UncPassword    = $null
            UncDomain      = $null
            # Solo para Local/USB
            LocalPath      = $null
            DriveLetter    = $null
            # Solo para OneDrive
            OneDriveEmail  = $null
            OneDriveToken  = $null
            OneDriveApiUrl = "https://graph.microsoft.com/v1.0/me/drive"
            # Solo para Dropbox
            DropboxToken   = $null
            DropboxApiUrl  = "https://api.dropboxapi.com/2"
        }
        
        # Configuración general
        BlockSizeMB    = 10
        Clave          = $null
        UseNativeZip   = $false
        Iso            = $false
        IsoDestino     = "dvd"
        RobocopyMirror = $false
    }
    
    while ($true) {
        # Construir display del origen
        $origenDisplay = $config.Origen.Tipo
        if ($config.Origen.Path) {
            $origenDisplay += " → $($config.Origen.Path)"
        }
        elseif ($config.Origen.FtpServer) {
            $origenDisplay += " → $($config.Origen.FtpServer):$($config.Origen.FtpPort)$($config.Origen.FtpDirectory)"
        }
        elseif ($config.Origen.UncPath) {
            $origenDisplay += " → $($config.Origen.UncPath)"
        }
        
        # Construir display del destino
        $destinoDisplay = $config.Destino.Tipo
        if ($config.Destino.Path) {
            $destinoDisplay += " → $($config.Destino.Path)"
        }
        elseif ($config.Destino.FtpServer) {
            $destinoDisplay += " → $($config.Destino.FtpServer):$($config.Destino.FtpPort)$($config.Destino.FtpDirectory)"
        }
        elseif ($config.Destino.UncPath) {
            $destinoDisplay += " → $($config.Destino.UncPath)"
        }
        
        $options = @(
            "*Origen: $origenDisplay",
            "*Destino: $destinoDisplay",
            "*Tamaño de Bloque: $($config.BlockSizeMB) MB",
            "Modo *Robocopy Mirror",
            "Generar *ISO (en lugar de USB)",
            "Usar ZIP *Nativo (sin 7-Zip)",
            "Configurar Con*traseña",
            "Modo *Ejemplo (Demo)",
            "*Ayuda",
            "*Ejecutar Transferencia....LLEVAR =)"
        )
        
        $selection = Show-DosMenu -Title "LLEVAR - MENÚ PRINCIPAL" -Items $options -CancelValue 0
        
        switch ($selection) {
            0 { return $null }  # Salir
            1 { $config = Show-OrigenMenu -Config $config }
            2 { $config = Show-DestinoMenu -Config $config }
            3 { $config = Show-BlockSizeMenu -Config $config }
            4 { $config.RobocopyMirror = -not $config.RobocopyMirror; if ($config.RobocopyMirror) { Show-ConsolePopup -Title "Robocopy Mirror" -Message "Modo Robocopy Mirror activado`n`nSincronizará origen con destino (elimina extras)" -Options @("*OK") | Out-Null } }
            5 { $config = Show-IsoMenu -Config $config }
            6 { $config.UseNativeZip = -not $config.UseNativeZip; Show-ConsolePopup -Title "ZIP Nativo" -Message "ZIP Nativo: $(if($config.UseNativeZip){'ACTIVADO'}else{'DESACTIVADO'})" -Options @("*OK") | Out-Null }
            7 { $config = Show-PasswordMenu -Config $config }
            8 { return @{ Action = "Example" } }
            9 { return @{ Action = "Help" } }
            10 { 
                # Validar configuración completa antes de ejecutar
                $errores = @()
                
                if ($config.RobocopyMirror) {
                    if (-not $config.Origen.Path -and -not $config.Origen.FtpServer -and -not $config.Origen.UncPath) { 
                        $errores += "• Origen no configurado" 
                    }
                    if (-not $config.Destino.Path -and -not $config.Destino.FtpServer -and -not $config.Destino.UncPath) { 
                        $errores += "• Destino no configurado" 
                    }
                }
                else {
                    if (-not $config.Origen.Path -and -not $config.Origen.FtpServer -and -not $config.Origen.UncPath) { 
                        $errores += "• Origen no configurado" 
                    }
                    if (-not $config.Destino.Path -and -not $config.Destino.FtpServer -and -not $config.Destino.UncPath) { 
                        $errores += "• Destino no configurado" 
                    }
                }
                
                if ($errores.Count -gt 0) {
                    $mensaje = "Faltan parámetros requeridos:`n`n" + ($errores -join "`n")
                    Show-ConsolePopup -Title "Configuración Incompleta" -Message $mensaje -Options @("*OK") | Out-Null
                    continue
                }
                
                $config.Action = "Execute"
                return $config
            }
        }
    }
}

function Show-OrigenMenu {
    param($Config)
    
    $options = @(
        "*Local (carpeta del sistema)",
        "*FTP (servidor FTP)",
        "*OneDrive (Microsoft OneDrive)",
        "*Dropbox",
        "*UNC (red compartida)"
    )
    
    $selection = Show-DosMenu -Title "ORIGEN - Seleccione tipo" -Items $options -CancelValue 0
    
    switch ($selection) {
        0 { return $Config }
        1 {
            $Config.Origen.Tipo = "Local"
            $selected = Select-FolderDOS-Llevar "Seleccione carpeta de ORIGEN"
            if ($selected) {
                $Config.Origen.Path = $selected
                $Config.Origen.LocalPath = $selected
                # Limpiar campos FTP/UNC
                $Config.Origen.FtpServer = $null
                $Config.Origen.UncPath = $null
            }
        }
        2 {
            $Config.Origen.Tipo = "FTP"
            $ftpConfig = Get-FtpConfigFromUser -Purpose "ORIGEN"
            if ($ftpConfig) {
                $Config.Origen.Path = $ftpConfig.Path
                $Config.Origen.FtpServer = $ftpConfig.Server
                $Config.Origen.FtpPort = $ftpConfig.Port
                $Config.Origen.FtpDirectory = $ftpConfig.Directory
                $Config.Origen.FtpUser = $ftpConfig.User
                $Config.Origen.FtpPassword = $ftpConfig.Password
                # Limpiar campos Local/UNC
                $Config.Origen.LocalPath = $null
                $Config.Origen.UncPath = $null
            }
        }
        3 {
            $Config.Origen.Tipo = "OneDrive"
            $authResult = Get-OneDriveAuth
            if ($authResult) {
                if ($authResult.UseLocal) {
                    # Uso local
                    $Config.Origen.Path = $authResult.LocalPath
                    $Config.Origen.LocalPath = $authResult.LocalPath
                    $Config.Origen.OneDriveEmail = $authResult.Email
                    $Config.Origen.OneDriveToken = $null
                    $Config.Origen.OneDriveApiUrl = $null
                }
                else {
                    # Uso API
                    Write-Host "`nIngrese la ruta en OneDrive (ej: /Documentos/MiCarpeta):" -ForegroundColor Cyan
                    Write-Host "Presione ENTER para ruta raíz (/)" -ForegroundColor Gray
                    $path = Read-Host "Ruta"
                    if ([string]::IsNullOrWhiteSpace($path)) { $path = "/" }
                    
                    $Config.Origen.Path = "onedrive://$path"
                    $Config.Origen.OneDriveEmail = $authResult.Email
                    $Config.Origen.OneDriveToken = $authResult.Token
                    $Config.Origen.OneDriveApiUrl = $authResult.ApiUrl
                    $Config.Origen.LocalPath = $null
                }
                # Limpiar campos FTP/UNC
                $Config.Origen.FtpServer = $null
                $Config.Origen.UncPath = $null
            }
        }
        4 {
            $Config.Origen.Tipo = "Dropbox"
            $authResult = Get-DropboxAuth
            if ($authResult) {
                if ($authResult.UseLocal) {
                    # Uso local
                    $Config.Origen.Path = $authResult.LocalPath
                    $Config.Origen.LocalPath = $authResult.LocalPath
                    $Config.Origen.DropboxToken = $null
                    $Config.Origen.DropboxApiUrl = $null
                }
                else {
                    # Uso API
                    Write-Host "`nIngrese la ruta en Dropbox (ej: /Documentos/MiCarpeta):" -ForegroundColor Cyan
                    Write-Host "Presione ENTER para ruta raíz (/)" -ForegroundColor Gray
                    $path = Read-Host "Ruta"
                    if ([string]::IsNullOrWhiteSpace($path)) { $path = "/" }
                    
                    $Config.Origen.Path = "dropbox://$path"
                    $Config.Origen.DropboxToken = $authResult.Token
                    $Config.Origen.DropboxApiUrl = $authResult.ApiUrl
                    $Config.Origen.LocalPath = $null
                }
                # Limpiar campos FTP/UNC
                $Config.Origen.FtpServer = $null
                $Config.Origen.UncPath = $null
            }
        }
        5 {
            $Config.Origen.Tipo = "UNC"
            $uncResult = Select-NetworkPath -Purpose "ORIGEN"
            
            if ($uncResult) {
                $Config.Origen.Path = $uncResult.Path
                $Config.Origen.UncPath = $uncResult.Path
                if ($uncResult.Credentials) {
                    $Config.Origen.UncUser = $uncResult.Credentials.UserName
                    $Config.Origen.UncPassword = $uncResult.Credentials.GetNetworkCredential().Password
                    $Config.Origen.UncDomain = $uncResult.Credentials.GetNetworkCredential().Domain
                }
                # Limpiar campos FTP/Local
                $Config.Origen.FtpServer = $null
                $Config.Origen.LocalPath = $null
            }
        }
    }
    
    return $Config
}

function Show-DestinoMenu {
    param($Config)
    
    $options = @(
        "*Local (carpeta del sistema)",
        "*USB (copiar a dispositivos USB)",
        "*FTP (servidor FTP)",
        "*OneDrive (Microsoft OneDrive)",
        "*Dropbox",
        "U*NC (red compartida)"
    )
    
    $selection = Show-DosMenu -Title "DESTINO - Seleccione tipo" -Items $options -CancelValue 0
    
    switch ($selection) {
        0 { return $Config }
        1 {
            $Config.Destino.Tipo = "Local"
            $selected = Select-FolderDOS-Llevar "Seleccione carpeta de DESTINO"
            if ($selected) {
                $Config.Destino.Path = $selected
                $Config.Destino.LocalPath = $selected
                # Limpiar campos FTP/UNC
                $Config.Destino.FtpServer = $null
                $Config.Destino.UncPath = $null
            }
        }
        2 {
            $Config.Destino.Tipo = "USB"
            Show-ConsolePopup -Title "Modo USB" -Message "El programa solicitará USBs durante la transferencia" -Options @("*OK") | Out-Null
            $Config.Destino.Path = "USB"
            # Limpiar campos FTP/UNC/Local
            $Config.Destino.FtpServer = $null
            $Config.Destino.UncPath = $null
            $Config.Destino.LocalPath = $null
        }
        3 {
            $Config.Destino.Tipo = "FTP"
            $ftpConfig = Get-FtpConfigFromUser -Purpose "DESTINO"
            if ($ftpConfig) {
                $Config.Destino.Path = $ftpConfig.Path
                $Config.Destino.FtpServer = $ftpConfig.Server
                $Config.Destino.FtpPort = $ftpConfig.Port
                $Config.Destino.FtpDirectory = $ftpConfig.Directory
                $Config.Destino.FtpUser = $ftpConfig.User
                $Config.Destino.FtpPassword = $ftpConfig.Password
                # Limpiar campos Local/UNC
                $Config.Destino.LocalPath = $null
                $Config.Destino.UncPath = $null
            }
        }
        4 {
            $Config.Destino.Tipo = "OneDrive"
            $authResult = Get-OneDriveAuth
            if ($authResult) {
                if ($authResult.UseLocal) {
                    # Uso local
                    $Config.Destino.Path = $authResult.LocalPath
                    $Config.Destino.LocalPath = $authResult.LocalPath
                    $Config.Destino.OneDriveEmail = $authResult.Email
                    $Config.Destino.OneDriveToken = $null
                    $Config.Destino.OneDriveApiUrl = $null
                }
                else {
                    # Uso API
                    Write-Host "`nIngrese la ruta en OneDrive (ej: /Backups/MiCarpeta):" -ForegroundColor Cyan
                    Write-Host "Presione ENTER para ruta raíz (/)" -ForegroundColor Gray
                    $path = Read-Host "Ruta"
                    if ([string]::IsNullOrWhiteSpace($path)) { $path = "/" }
                    
                    $Config.Destino.Path = "onedrive://$path"
                    $Config.Destino.OneDriveEmail = $authResult.Email
                    $Config.Destino.OneDriveToken = $authResult.Token
                    $Config.Destino.OneDriveApiUrl = $authResult.ApiUrl
                    $Config.Destino.LocalPath = $null
                }
                # Limpiar campos FTP/UNC
                $Config.Destino.FtpServer = $null
                $Config.Destino.UncPath = $null
            }
        }
        5 {
            $Config.Destino.Tipo = "Dropbox"
            $authResult = Get-DropboxAuth
            if ($authResult) {
                if ($authResult.UseLocal) {
                    # Uso local
                    $Config.Destino.Path = $authResult.LocalPath
                    $Config.Destino.LocalPath = $authResult.LocalPath
                    $Config.Destino.DropboxToken = $null
                    $Config.Destino.DropboxApiUrl = $null
                }
                else {
                    # Uso API
                    Write-Host "`nIngrese la ruta en Dropbox (ej: /Backups/MiCarpeta):" -ForegroundColor Cyan
                    Write-Host "Presione ENTER para ruta raíz (/)" -ForegroundColor Gray
                    $path = Read-Host "Ruta"
                    if ([string]::IsNullOrWhiteSpace($path)) { $path = "/" }
                    
                    $Config.Destino.Path = "dropbox://$path"
                    $Config.Destino.DropboxToken = $authResult.Token
                    $Config.Destino.DropboxApiUrl = $authResult.ApiUrl
                    $Config.Destino.LocalPath = $null
                }
                # Limpiar campos FTP/UNC
                $Config.Destino.FtpServer = $null
                $Config.Destino.UncPath = $null
            }
        }
        6 {
            $Config.Destino.Tipo = "UNC"
            $uncResult = Select-NetworkPath -Purpose "DESTINO"
            
            if ($uncResult) {
                $Config.Destino.Path = $uncResult.Path
                $Config.Destino.UncPath = $uncResult.Path
                if ($uncResult.Credentials) {
                    $Config.Destino.UncUser = $uncResult.Credentials.UserName
                    $Config.Destino.UncPassword = $uncResult.Credentials.GetNetworkCredential().Password
                    $Config.Destino.UncDomain = $uncResult.Credentials.GetNetworkCredential().Domain
                }
                # Limpiar campos FTP/Local
                $Config.Destino.FtpServer = $null
                $Config.Destino.LocalPath = $null
            }
        }
    }
    
    return $Config
}

# ========================================================================== #
#                    AUTENTICACIÓN ONEDRIVE / DROPBOX                        #
# ========================================================================== #

function Get-OneDriveAuth {
    <#
    .SYNOPSIS
        Configura autenticación OneDrive con OAuth o ruta local
    .DESCRIPTION
        Detecta si OneDrive está instalado localmente o requiere autenticación API
    .OUTPUTS
        Hashtable con Email, Token, ApiUrl, LocalPath (si aplica)
    #>
    param(
        [switch]$ForceApi  # Forzar uso de API aunque esté instalado
    )
    
    Write-Log "Iniciando configuración OneDrive" "INFO"
    Clear-Host
    Show-Banner -Message "CONFIGURACIÓN ONEDRIVE" -BorderColor "Cyan"
    
    # Buscar instalación local de OneDrive
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
                Write-Log "OneDrive detectado en: $path" "INFO"
                break
            }
        }
    }
    
    if ($oneDriveLocal) {
        Write-Host ""
        Write-Host "OneDrive detectado en:" -ForegroundColor Green
        Write-Host "  $oneDriveLocal" -ForegroundColor White
        Write-Host ""
        
        $opcion = Show-ConsolePopup -Title "OneDrive Local" `
            -Message "¿Desea usar la instalación local o conectar vía API?" `
            -Options @("*Usar Local", "Usar *API", "*Cancelar")
        
        if ($opcion -eq 0) {
            # Usar local
            Write-Log "Usuario eligió usar OneDrive local: $oneDriveLocal" "INFO"
            return @{
                Email     = $env:USERNAME + "@onedrive.com"
                Token     = $null
                ApiUrl    = $null
                LocalPath = $oneDriveLocal
                UseLocal  = $true
            }
        }
        elseif ($opcion -eq 2) {
            # Cancelar
            Write-Log "Usuario canceló configuración OneDrive" "INFO"
            return $null
        }
        # Si opcion = 1 (API), continuar abajo
    }
    
    # Configuración API
    Write-Host ""
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  AUTENTICACIÓN ONEDRIVE API" -ForegroundColor White
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Para usar OneDrive API necesita:" -ForegroundColor Yellow
    Write-Host "  1. Cuenta de Microsoft (Outlook/Hotmail)" -ForegroundColor White
    Write-Host "  2. Token de acceso OAuth 2.0" -ForegroundColor White
    Write-Host ""
    Write-Host "Instrucciones:" -ForegroundColor Cyan
    Write-Host "  • Visite: https://portal.azure.com" -ForegroundColor Gray
    Write-Host "  • Registre aplicación en Azure AD" -ForegroundColor Gray
    Write-Host "  • Obtenga token con permisos Files.ReadWrite" -ForegroundColor Gray
    Write-Host ""
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    $email = Read-Host "Email de Microsoft"
    if ([string]::IsNullOrWhiteSpace($email)) {
        Write-Log "Usuario no proporcionó email OneDrive" "WARNING"
        return $null
    }
    
    Write-Host ""
    Write-Host "Token OAuth 2.0:" -ForegroundColor Yellow
    Write-Host "  (pegue el token - no se mostrará en pantalla)" -ForegroundColor Gray
    $tokenSecure = Read-Host "Token" -AsSecureString
    $token = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenSecure)
    )
    
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-Log "Usuario no proporcionó token OneDrive" "WARNING"
        return $null
    }
    
    Write-Host ""
    Write-Host "Validando credenciales..." -ForegroundColor Yellow
    
    # Validar token con API
    try {
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type"  = "application/json"
        }
        
        $apiUrl = "https://graph.microsoft.com/v1.0/me/drive"
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -TimeoutSec 10
        
        Write-Host "✓ Autenticación exitosa" -ForegroundColor Green
        Write-Host "  Usuario: $($response.owner.user.displayName)" -ForegroundColor White
        Write-Host "  Drive: $($response.name)" -ForegroundColor White
        Write-Log "OneDrive API autenticado: $email - $($response.name)" "INFO"
        
        Start-Sleep -Seconds 2
        
        return @{
            Email     = $email
            Token     = $token
            ApiUrl    = $apiUrl
            LocalPath = $null
            UseLocal  = $false
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host "  ⚠ ERROR DE AUTENTICACIÓN ONEDRIVE" -ForegroundColor Red
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host ""
        Write-Host "Error: $errorMsg" -ForegroundColor Yellow
        Write-Host ""
        Write-Log "Error autenticación OneDrive: $errorMsg" "ERROR" -ErrorRecord $_
        
        Write-Host "Posibles causas:" -ForegroundColor Yellow
        Write-Host "  • Token inválido o expirado" -ForegroundColor DarkGray
        Write-Host "  • Permisos insuficientes" -ForegroundColor DarkGray
        Write-Host "  • Sin conexión a Internet" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host ""
        
        Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        
        $respuesta = Show-ConsolePopup -Title "⚠ ERROR ONEDRIVE" `
            -Message "Error: $errorMsg`n`nPosibles causas:`n• Token inválido/expirado`n• Permisos insuficientes`n• Sin Internet" `
            -Options @("*Reintentar", "*Cancelar") -Beep
        
        if ($respuesta -eq 0) {
            return Get-OneDriveAuth -ForceApi:$ForceApi
        }
        else {
            Write-Log "Usuario canceló tras error OneDrive" "INFO"
            return $null
        }
    }
}

function Get-DropboxAuth {
    <#
    .SYNOPSIS
        Configura autenticación Dropbox con OAuth o ruta local
    .DESCRIPTION
        Detecta si Dropbox está instalado localmente o requiere autenticación API
    .OUTPUTS
        Hashtable con Token, ApiUrl, LocalPath (si aplica)
    #>
    param(
        [switch]$ForceApi
    )
    
    Write-Log "Iniciando configuración Dropbox" "INFO"
    Clear-Host
    Show-Banner -Message "CONFIGURACIÓN DROPBOX" -BorderColor "Blue"
    
    # Buscar instalación local
    $dropboxLocal = $null
    if (-not $ForceApi) {
        $possiblePaths = @(
            "$env:USERPROFILE\Dropbox",
            "$env:LOCALAPPDATA\Dropbox",
            "$env:APPDATA\Dropbox"
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $dropboxLocal = $path
                Write-Log "Dropbox detectado en: $path" "INFO"
                break
            }
        }
    }
    
    if ($dropboxLocal) {
        Write-Host ""
        Write-Host "Dropbox detectado en:" -ForegroundColor Green
        Write-Host "  $dropboxLocal" -ForegroundColor White
        Write-Host ""
        
        $opcion = Show-ConsolePopup -Title "Dropbox Local" `
            -Message "¿Desea usar la instalación local o conectar vía API?" `
            -Options @("*Usar Local", "Usar *API", "*Cancelar")
        
        if ($opcion -eq 0) {
            Write-Log "Usuario eligió usar Dropbox local: $dropboxLocal" "INFO"
            return @{
                Token     = $null
                ApiUrl    = $null
                LocalPath = $dropboxLocal
                UseLocal  = $true
            }
        }
        elseif ($opcion -eq 2) {
            Write-Log "Usuario canceló configuración Dropbox" "INFO"
            return $null
        }
    }
    
    # Configuración API
    Write-Host ""
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host "  AUTENTICACIÓN DROPBOX API" -ForegroundColor White
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Para usar Dropbox API necesita:" -ForegroundColor Yellow
    Write-Host "  1. Cuenta de Dropbox" -ForegroundColor White
    Write-Host "  2. Token de acceso OAuth 2.0" -ForegroundColor White
    Write-Host ""
    Write-Host "Instrucciones:" -ForegroundColor Cyan
    Write-Host "  • Visite: https://www.dropbox.com/developers/apps" -ForegroundColor Gray
    Write-Host "  • Cree una app con permisos files.content.write" -ForegroundColor Gray
    Write-Host "  • Genere un Access Token" -ForegroundColor Gray
    Write-Host ""
    Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host ""
    
    Write-Host "Token OAuth 2.0:" -ForegroundColor Yellow
    Write-Host "  (pegue el token - no se mostrará en pantalla)" -ForegroundColor Gray
    $tokenSecure = Read-Host "Token" -AsSecureString
    $token = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenSecure)
    )
    
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-Log "Usuario no proporcionó token Dropbox" "WARNING"
        return $null
    }
    
    Write-Host ""
    Write-Host "Validando credenciales..." -ForegroundColor Yellow
    
    # Validar token
    try {
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type"  = "application/json"
        }
        
        $apiUrl = "https://api.dropboxapi.com/2/users/get_current_account"
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Post -TimeoutSec 10
        
        Write-Host "✓ Autenticación exitosa" -ForegroundColor Green
        Write-Host "  Usuario: $($response.name.display_name)" -ForegroundColor White
        Write-Host "  Email: $($response.email)" -ForegroundColor White
        Write-Log "Dropbox API autenticado: $($response.email)" "INFO"
        
        Start-Sleep -Seconds 2
        
        return @{
            Token     = $token
            ApiUrl    = "https://api.dropboxapi.com/2"
            LocalPath = $null
            UseLocal  = $false
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host "  ⚠ ERROR DE AUTENTICACIÓN DROPBOX" -ForegroundColor Red
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host ""
        Write-Host "Error: $errorMsg" -ForegroundColor Yellow
        Write-Host ""
        Write-Log "Error autenticación Dropbox: $errorMsg" "ERROR" -ErrorRecord $_
        
        Write-Host "Posibles causas:" -ForegroundColor Yellow
        Write-Host "  • Token inválido o expirado" -ForegroundColor DarkGray
        Write-Host "  • Permisos insuficientes" -ForegroundColor DarkGray
        Write-Host "  • Sin conexión a Internet" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host ""
        
        Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        
        $respuesta = Show-ConsolePopup -Title "⚠ ERROR DROPBOX" `
            -Message "Error: $errorMsg`n`nPosibles causas:`n• Token inválido/expirado`n• Permisos insuficientes`n• Sin Internet" `
            -Options @("*Reintentar", "*Cancelar") -Beep
        
        if ($respuesta -eq 0) {
            return Get-DropboxAuth -ForceApi:$ForceApi
        }
        else {
            Write-Log "Usuario canceló tras error Dropbox" "INFO"
            return $null
        }
    }
}

# ========================================================================== #
#                   FUNCIÓN UNIFICADA DE COPIA CON PROGRESO                  #
# ========================================================================== #

function Copy-LlevarFiles {
    <#
    .SYNOPSIS
        Función unificada para copiar archivos entre cualquier tipo de origen y destino
    .DESCRIPTION
        Soporta todas las combinaciones: Local, FTP, OneDrive, Dropbox, UNC
        Incluye barra de progreso automática con Write-LlevarProgressBar
    .PARAMETER SourceConfig
        Hashtable con configuración de origen (Tipo, Path, credenciales según tipo)
    .PARAMETER DestinationConfig
        Hashtable con configuración de destino (Tipo, Path, credenciales según tipo)
    .PARAMETER SourcePath
        Ruta local del archivo/carpeta a copiar (si origen es Local/UNC)
    .PARAMETER ShowProgress
        Si se debe mostrar barra de progreso (por defecto: $true)
    .PARAMETER ProgressTop
        Posición Y de la barra de progreso (-1 = posición actual)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$SourceConfig,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$DestinationConfig,
        
        [Parameter(Mandatory = $false)]
        [string]$SourcePath,
        
        [bool]$ShowProgress = $true,
        
        [int]$ProgressTop = -1,
        
        [bool]$UseRobocopy = $false,
        
        [bool]$RobocopyMirror = $false
    )
    
    $startTime = Get-Date
    Write-Log "Iniciando copia unificada: $($SourceConfig.Tipo) → $($DestinationConfig.Tipo)" "INFO"
    
    # Validar tipos
    $validTypes = @("Local", "FTP", "OneDrive", "Dropbox", "UNC", "USB")
    if ($SourceConfig.Tipo -notin $validTypes) {
        Write-Log "Tipo de origen inválido: $($SourceConfig.Tipo)" "ERROR"
        throw "Tipo de origen inválido: $($SourceConfig.Tipo)"
    }
    if ($DestinationConfig.Tipo -notin $validTypes) {
        Write-Log "Tipo de destino inválido: $($DestinationConfig.Tipo)" "ERROR"
        throw "Tipo de destino inválido: $($DestinationConfig.Tipo)"
    }
    
    # Determinar ruta de origen
    $sourceLocation = $SourcePath
    if (-not $sourceLocation) {
        if ($SourceConfig.LocalPath) { 
            $sourceLocation = $SourceConfig.LocalPath
        }
        elseif ($SourceConfig.Path) {
            $sourceLocation = $SourceConfig.Path
        }
        else {
            throw "No se pudo determinar la ubicación de origen"
        }
    }
    
    # Verificar que el origen existe (solo para Local/UNC)
    if ($SourceConfig.Tipo -in @("Local", "UNC")) {
        if (-not (Test-Path $sourceLocation)) {
            Write-Log "Origen no existe: $sourceLocation" "ERROR"
            throw "El origen no existe: $sourceLocation"
        }
    }
    
    # Obtener información del archivo/carpeta origen
    $isFolder = $false
    $totalBytes = 0
    $fileCount = 0
    
    if ($SourceConfig.Tipo -in @("Local", "UNC")) {
        $item = Get-Item $sourceLocation
        $isFolder = $item.PSIsContainer
        
        if ($isFolder) {
            $files = Get-ChildItem -Path $sourceLocation -Recurse -File
            $fileCount = $files.Count
            $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
        }
        else {
            $fileCount = 1
            $totalBytes = $item.Length
        }
    }
    
    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Preparando copia..." -Top $ProgressTop -Width 50
    }
    
    Write-Log "Origen: $($SourceConfig.Tipo) - $sourceLocation" "INFO"
    Write-Log "Destino: $($DestinationConfig.Tipo) - $($DestinationConfig.Path)" "INFO"
    Write-Log "Archivos: $fileCount | Tamaño total: $([Math]::Round($totalBytes/1MB, 2)) MB" "INFO"
    
    # ====== MATRIZ DE DECISIÓN: ORIGEN → DESTINO ======
    
    try {
        # LOCAL → LOCAL/UNC
        if ($SourceConfig.Tipo -eq "Local" -and $DestinationConfig.Tipo -in @("Local", "UNC")) {
            # Si UseRobocopy está habilitado, usar Robocopy en lugar de Copy-Item
            if ($UseRobocopy) {
                Copy-LlevarLocalToLocalRobocopy -SourcePath $sourceLocation -DestinationPath $DestinationConfig.Path `
                    -UseMirror $RobocopyMirror -StartTime $startTime -ShowProgress $ShowProgress -ProgressTop $ProgressTop
            }
            else {
                Copy-LlevarLocalToLocal -SourcePath $sourceLocation -DestinationPath $DestinationConfig.Path `
                    -TotalBytes $totalBytes -FileCount $fileCount -StartTime $startTime `
                    -ShowProgress $ShowProgress -ProgressTop $ProgressTop
            }
        }
        
        # LOCAL → FTP
        elseif ($SourceConfig.Tipo -eq "Local" -and $DestinationConfig.Tipo -eq "FTP") {
            Copy-LlevarLocalToFtp -SourcePath $sourceLocation -FtpConfig $DestinationConfig `
                -TotalBytes $totalBytes -FileCount $fileCount -StartTime $startTime `
                -ShowProgress $ShowProgress -ProgressTop $ProgressTop
        }
        
        # LOCAL → ONEDRIVE
        elseif ($SourceConfig.Tipo -eq "Local" -and $DestinationConfig.Tipo -eq "OneDrive") {
            Copy-LlevarLocalToOneDrive -SourcePath $sourceLocation -OneDriveConfig $DestinationConfig `
                -TotalBytes $totalBytes -FileCount $fileCount -StartTime $startTime `
                -ShowProgress $ShowProgress -ProgressTop $ProgressTop
        }
        
        # LOCAL → DROPBOX
        elseif ($SourceConfig.Tipo -eq "Local" -and $DestinationConfig.Tipo -eq "Dropbox") {
            Copy-LlevarLocalToDropbox -SourcePath $sourceLocation -DropboxConfig $DestinationConfig `
                -TotalBytes $totalBytes -FileCount $fileCount -StartTime $startTime `
                -ShowProgress $ShowProgress -ProgressTop $ProgressTop
        }
        
        # FTP → LOCAL
        elseif ($SourceConfig.Tipo -eq "FTP" -and $DestinationConfig.Tipo -in @("Local", "UNC")) {
            Copy-LlevarFtpToLocal -FtpConfig $SourceConfig -DestinationPath $DestinationConfig.Path `
                -StartTime $startTime -ShowProgress $ShowProgress -ProgressTop $ProgressTop
        }
        
        # ONEDRIVE → LOCAL
        elseif ($SourceConfig.Tipo -eq "OneDrive" -and $DestinationConfig.Tipo -in @("Local", "UNC")) {
            Copy-LlevarOneDriveToLocal -OneDriveConfig $SourceConfig -DestinationPath $DestinationConfig.Path `
                -StartTime $startTime -ShowProgress $ShowProgress -ProgressTop $ProgressTop
        }
        
        # DROPBOX → LOCAL
        elseif ($SourceConfig.Tipo -eq "Dropbox" -and $DestinationConfig.Tipo -in @("Local", "UNC")) {
            Copy-LlevarDropboxToLocal -DropboxConfig $SourceConfig -DestinationPath $DestinationConfig.Path `
                -StartTime $startTime -ShowProgress $ShowProgress -ProgressTop $ProgressTop
        }
        
        # ONEDRIVE → DROPBOX (vía local temporal)
        elseif ($SourceConfig.Tipo -eq "OneDrive" -and $DestinationConfig.Tipo -eq "Dropbox") {
            $tempPath = Join-Path $env:TEMP "LlevarTransfer_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
            
            try {
                if ($ShowProgress) {
                    Write-LlevarProgressBar -Percent 25 -StartTime $startTime -Label "Descargando de OneDrive..." -Top $ProgressTop -Width 50
                }
                Copy-LlevarOneDriveToLocal -OneDriveConfig $SourceConfig -DestinationPath $tempPath `
                    -StartTime $startTime -ShowProgress $false -ProgressTop $ProgressTop
                
                if ($ShowProgress) {
                    Write-LlevarProgressBar -Percent 75 -StartTime $startTime -Label "Subiendo a Dropbox..." -Top $ProgressTop -Width 50
                }
                Copy-LlevarLocalToDropbox -SourcePath $tempPath -DropboxConfig $DestinationConfig `
                    -TotalBytes $totalBytes -FileCount $fileCount -StartTime $startTime `
                    -ShowProgress $false -ProgressTop $ProgressTop
            }
            finally {
                Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        # DROPBOX → ONEDRIVE (vía local temporal)
        elseif ($SourceConfig.Tipo -eq "Dropbox" -and $DestinationConfig.Tipo -eq "OneDrive") {
            $tempPath = Join-Path $env:TEMP "LlevarTransfer_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
            
            try {
                if ($ShowProgress) {
                    Write-LlevarProgressBar -Percent 25 -StartTime $startTime -Label "Descargando de Dropbox..." -Top $ProgressTop -Width 50
                }
                Copy-LlevarDropboxToLocal -DropboxConfig $SourceConfig -DestinationPath $tempPath `
                    -StartTime $startTime -ShowProgress $false -ProgressTop $ProgressTop
                
                if ($ShowProgress) {
                    Write-LlevarProgressBar -Percent 75 -StartTime $startTime -Label "Subiendo a OneDrive..." -Top $ProgressTop -Width 50
                }
                Copy-LlevarLocalToOneDrive -SourcePath $tempPath -OneDriveConfig $DestinationConfig `
                    -TotalBytes $totalBytes -FileCount $fileCount -StartTime $startTime `
                    -ShowProgress $false -ProgressTop $ProgressTop
            }
            finally {
                Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Combinaciones no implementadas aún
        else {
            throw "Combinación no soportada: $($SourceConfig.Tipo) → $($DestinationConfig.Tipo)"
        }
        
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 100 -StartTime $startTime -Label "Copia completada" -Top $ProgressTop -Width 50
        }
        
        $elapsed = (Get-Date) - $startTime
        Write-Log "Copia completada en $($elapsed.TotalSeconds) segundos" "INFO"
        
        return @{
            Success        = $true
            BytesCopied    = $totalBytes
            FileCount      = $fileCount
            ElapsedSeconds = $elapsed.TotalSeconds
        }
    }
    catch {
        Write-Log "Error en copia unificada: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Error en copia" -Top $ProgressTop -Width 50 `
                -ForegroundColor Red -BackgroundColor DarkRed
        }
        
        throw
    }
}

# ========================================================================== #
#             FUNCIONES AUXILIARES DE COPIA (DELEGADAS)                     #
# ========================================================================== #

function Copy-LlevarLocalToLocalRobocopy {
    param($SourcePath, $DestinationPath, $UseMirror, $StartTime, $ShowProgress, $ProgressTop)
    
    Write-Log "Copia Local → Local (Robocopy): $SourcePath → $DestinationPath (Mirror: $UseMirror)" "INFO"
    
    # Crear destino si no existe
    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }
    
    # Configurar argumentos de Robocopy
    $robocopyArgs = @(
        $SourcePath,
        $DestinationPath,
        '/E',           # Copiar subdirectorios, incluidos vacíos
        '/R:3',         # 3 reintentos en caso de error
        '/W:5',         # 5 segundos de espera entre reintentos
        '/NP',          # No mostrar progreso por archivo
        '/BYTES',       # Mostrar tamaños en bytes
        '/NFL',         # No mostrar lista de archivos
        '/NDL'          # No mostrar lista de directorios
    )
    
    # Si es modo Mirror, agregar /PURGE
    if ($UseMirror) {
        $robocopyArgs += '/MIR'  # Mirror mode (incluye /PURGE)
        Write-Log "Modo Mirror activado - eliminará archivos extras en destino" "WARNING"
    }
    
    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 0 -StartTime $StartTime -Label "Copiando con Robocopy..." -Top $ProgressTop -Width 50
    }
    
    Write-Log "Ejecutando: robocopy $($robocopyArgs -join ' ')" "INFO"
    
    # Ejecutar Robocopy
    $process = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
    $exitCode = $process.ExitCode
    
    # Robocopy exit codes:
    # 0 = No changes (already synchronized)
    # 1 = Files copied successfully
    # 2 = Extra files found
    # 3 = Files copied and extras found
    # 4+ = Errors
    
    if ($exitCode -le 3) {
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 100 -StartTime $StartTime -Label "Copia Robocopy completada" -Top $ProgressTop -Width 50
        }
        
        $exitMessage = switch ($exitCode) {
            0 { "Sin cambios - origen y destino sincronizados" }
            1 { "Archivos copiados exitosamente" }
            2 { "Archivos extras encontrados en destino" }
            3 { "Archivos copiados y extras procesados" }
        }
        
        Write-Log "Robocopy completado: $exitMessage (código: $exitCode)" "INFO"
    }
    else {
        Write-Log "Robocopy finalizó con errores (código: $exitCode)" "ERROR"
        throw "Robocopy falló con código de salida: $exitCode"
    }
}

function Copy-LlevarLocalToLocal {
    param($SourcePath, $DestinationPath, $TotalBytes, $FileCount, $StartTime, $ShowProgress, $ProgressTop)
    
    Write-Log "Copia Local → Local: $SourcePath → $DestinationPath" "INFO"
    
    if (Test-Path $SourcePath -PathType Container) {
        # Es carpeta
        $files = Get-ChildItem -Path $SourcePath -Recurse -File
        $copiedBytes = 0
        $fileIndex = 0
        
        foreach ($file in $files) {
            $fileIndex++
            $relativePath = $file.FullName.Substring($SourcePath.Length).TrimStart('\')
            $destFile = Join-Path $DestinationPath $relativePath
            $destDir = Split-Path $destFile -Parent
            
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            
            Copy-Item -Path $file.FullName -Destination $destFile -Force
            $copiedBytes += $file.Length
            
            if ($ShowProgress -and $TotalBytes -gt 0) {
                $percent = [Math]::Min(100, ($copiedBytes * 100.0 / $TotalBytes))
                $label = "Copiando $fileIndex/$FileCount - $($file.Name)"
                Write-LlevarProgressBar -Percent $percent -StartTime $StartTime -Label $label -Top $ProgressTop -Width 50
            }
        }
    }
    else {
        # Es archivo
        $destFile = Join-Path $DestinationPath (Split-Path $SourcePath -Leaf)
        Copy-Item -Path $SourcePath -Destination $destFile -Force
        
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 50 -StartTime $StartTime -Label "Copiando archivo..." -Top $ProgressTop -Width 50
        }
    }
}

function Copy-LlevarLocalToFtp {
    param($SourcePath, $FtpConfig, $TotalBytes, $FileCount, $StartTime, $ShowProgress, $ProgressTop)
    
    Write-Log "Copia Local → FTP: $SourcePath → $($FtpConfig.FtpServer)" "INFO"
    
    # Usar función existente Invoke-NetworkUpload si está disponible
    # O implementar subida FTP con progreso aquí
    
    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 50 -StartTime $StartTime -Label "Subiendo a FTP..." -Top $ProgressTop -Width 50
    }
    
    # TODO: Implementar subida FTP con progreso byte por byte
    throw "Copia Local → FTP no implementada aún con progreso"
}

function Copy-LlevarLocalToOneDrive {
    param($SourcePath, $OneDriveConfig, $TotalBytes, $FileCount, $StartTime, $ShowProgress, $ProgressTop)
    
    Write-Log "Copia Local → OneDrive: $SourcePath → $($OneDriveConfig.Path)" "INFO"
    
    if ($OneDriveConfig.UseLocal -and $OneDriveConfig.LocalPath) {
        # Usar copia local
        Copy-LlevarLocalToLocal -SourcePath $SourcePath -DestinationPath $OneDriveConfig.LocalPath `
            -TotalBytes $TotalBytes -FileCount $FileCount -StartTime $StartTime `
            -ShowProgress $ShowProgress -ProgressTop $ProgressTop
    }
    else {
        # Usar API
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 50 -StartTime $StartTime -Label "Subiendo a OneDrive API..." -Top $ProgressTop -Width 50
        }
        
        # TODO: Usar Upload-OneDriveFile o Upload-OneDriveFolder con progreso
        throw "Copia Local → OneDrive API no implementada aún con progreso"
    }
}

function Copy-LlevarLocalToDropbox {
    param($SourcePath, $DropboxConfig, $TotalBytes, $FileCount, $StartTime, $ShowProgress, $ProgressTop)
    
    Write-Log "Copia Local → Dropbox: $SourcePath → $($DropboxConfig.Path)" "INFO"
    
    if ($DropboxConfig.UseLocal -and $DropboxConfig.LocalPath) {
        # Usar copia local
        Copy-LlevarLocalToLocal -SourcePath $SourcePath -DestinationPath $DropboxConfig.LocalPath `
            -TotalBytes $TotalBytes -FileCount $FileCount -StartTime $StartTime `
            -ShowProgress $ShowProgress -ProgressTop $ProgressTop
    }
    else {
        # Usar API
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 50 -StartTime $StartTime -Label "Subiendo a Dropbox API..." -Top $ProgressTop -Width 50
        }
        
        # TODO: Usar Upload-DropboxFile o Upload-DropboxFolder con progreso
        throw "Copia Local → Dropbox API no implementada aún con progreso"
    }
}

function Copy-LlevarFtpToLocal {
    param($FtpConfig, $DestinationPath, $StartTime, $ShowProgress, $ProgressTop)
    
    Write-Log "Copia FTP → Local: $($FtpConfig.FtpServer) → $DestinationPath" "INFO"
    
    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 50 -StartTime $StartTime -Label "Descargando de FTP..." -Top $ProgressTop -Width 50
    }
    
    # TODO: Implementar descarga FTP con progreso
    throw "Copia FTP → Local no implementada aún con progreso"
}

function Copy-LlevarOneDriveToLocal {
    param($OneDriveConfig, $DestinationPath, $StartTime, $ShowProgress, $ProgressTop)
    
    Write-Log "Copia OneDrive → Local: $($OneDriveConfig.Path) → $DestinationPath" "INFO"
    
    if ($OneDriveConfig.UseLocal -and $OneDriveConfig.LocalPath) {
        # Copiar desde local
        $totalBytes = 0
        $fileCount = 0
        
        if (Test-Path $OneDriveConfig.LocalPath -PathType Container) {
            $files = Get-ChildItem -Path $OneDriveConfig.LocalPath -Recurse -File
            $fileCount = $files.Count
            $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
        }
        
        Copy-LlevarLocalToLocal -SourcePath $OneDriveConfig.LocalPath -DestinationPath $DestinationPath `
            -TotalBytes $totalBytes -FileCount $fileCount -StartTime $StartTime `
            -ShowProgress $ShowProgress -ProgressTop $ProgressTop
    }
    else {
        # Usar API
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 50 -StartTime $StartTime -Label "Descargando de OneDrive API..." -Top $ProgressTop -Width 50
        }
        
        # TODO: Usar Download-OneDriveFile o Download-OneDriveFolder con progreso
        throw "Copia OneDrive API → Local no implementada aún con progreso"
    }
}

function Copy-LlevarDropboxToLocal {
    param($DropboxConfig, $DestinationPath, $StartTime, $ShowProgress, $ProgressTop)
    
    Write-Log "Copia Dropbox → Local: $($DropboxConfig.Path) → $DestinationPath" "INFO"
    
    if ($DropboxConfig.UseLocal -and $DropboxConfig.LocalPath) {
        # Copiar desde local
        $totalBytes = 0
        $fileCount = 0
        
        if (Test-Path $DropboxConfig.LocalPath -PathType Container) {
            $files = Get-ChildItem -Path $DropboxConfig.LocalPath -Recurse -File
            $fileCount = $files.Count
            $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
        }
        
        Copy-LlevarLocalToLocal -SourcePath $DropboxConfig.LocalPath -DestinationPath $DestinationPath `
            -TotalBytes $totalBytes -FileCount $fileCount -StartTime $StartTime `
            -ShowProgress $ShowProgress -ProgressTop $ProgressTop
    }
    else {
        # Usar API
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 50 -StartTime $StartTime -Label "Descargando de Dropbox API..." -Top $ProgressTop -Width 50
        }
        
        # TODO: Usar Download-DropboxFile o Download-DropboxFolder con progreso
        throw "Copia Dropbox API → Local no implementada aún con progreso"
    }
}

function Get-FtpConfigFromUser {
    param([string]$Purpose)
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  CONFIGURACIÓN FTP - $Purpose" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Servidor FTP (ej: 192.168.1.100 o ftp.ejemplo.com): " -NoNewline -ForegroundColor Cyan
    $server = Read-Host
    
    # Si no tiene protocolo, agregarlo
    if ($server -notlike "ftp://*" -and $server -notlike "ftps://*") {
        $server = "ftp://$server"
    }
    
    Write-Host "Puerto (presione ENTER para usar 21 predeterminado): " -NoNewline -ForegroundColor Cyan
    $portInput = Read-Host
    $port = 21
    if (-not [string]::IsNullOrWhiteSpace($portInput)) {
        if ([int]::TryParse($portInput, [ref]$port)) {
            Write-Log "Puerto FTP configurado: $port" "INFO"
        }
        else {
            Write-Host "Puerto inválido, usando 21" -ForegroundColor Yellow
            Write-Log "Puerto FTP inválido ($portInput), usando 21" "WARNING"
        }
    }
    
    # Agregar puerto a la URL si no es el predeterminado
    if ($port -ne 21) {
        $serverUri = [uri]$server
        $server = "$($serverUri.Scheme)://$($serverUri.Host):$port"
    }
    
    Write-Host "Ruta en servidor (ej: /carpeta/subcarpeta o presione ENTER para raíz): " -NoNewline -ForegroundColor Cyan
    $path = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($path)) {
        $fullPath = $server
    }
    else {
        $fullPath = "$server$path"
    }
    
    Write-Host ""
    Write-Host "Credenciales FTP:" -ForegroundColor Yellow
    $credentials = Get-Credential -Message "Ingrese usuario y contraseña para $server"
    
    if (-not $credentials) {
        Write-Log "Configuración FTP cancelada por el usuario" "WARNING"
        return $null
    }
    
    # Validar conexión
    Write-Host ""
    Write-Host "Validando conexión FTP..." -ForegroundColor Cyan
    Write-Log "Intentando conectar a: $server (Usuario: $($credentials.UserName))" "INFO"
    
    try {
        $testUri = [uri]$server
        $request = [System.Net.FtpWebRequest]::Create($testUri)
        $request.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
        $request.Credentials = $credentials.GetNetworkCredential()
        $request.Timeout = 15000
        $request.UsePassive = $true
        
        $response = $request.GetResponse()
        $statusDescription = $response.StatusDescription
        $response.Close()
        
        Write-Host "✓ Conexión FTP exitosa" -ForegroundColor Green
        Write-Host "  Estado: $statusDescription" -ForegroundColor Gray
        Write-Log "Conexión FTP exitosa: $server - $statusDescription" "INFO"
        
        Start-Sleep -Seconds 3
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host "  ⚠ ERROR DE CONEXIÓN FTP" -ForegroundColor Red
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host ""
        Write-Host "Servidor: $server" -ForegroundColor White
        Write-Host "Puerto: $port" -ForegroundColor White
        Write-Host "Error: $errorMsg" -ForegroundColor Yellow
        Write-Host ""
        Write-Log "Error de conexión FTP a ${server}:${port} - $errorMsg" "ERROR" -ErrorRecord $_
        
        Write-Host "Posibles causas:" -ForegroundColor Yellow
        Write-Host "  • Servidor o puerto incorrectos" -ForegroundColor DarkGray
        Write-Host "  • Credenciales inválidas" -ForegroundColor DarkGray
        Write-Host "  • Firewall bloqueando la conexión" -ForegroundColor DarkGray
        Write-Host "  • Servidor FTP no disponible" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Log detallado en: $Global:LogFile" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host ""
        
        # Pausa para que el usuario pueda leer el error
        Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        
        $mensajePopup = @"
Error: $errorMsg

Posibles causas:
  • Servidor/puerto incorrectos
  • Credenciales inválidas
  • Firewall bloqueando conexión
  • Servidor no disponible

Log: $Global:LogFile
"@
        
        $respuesta = Show-ConsolePopup -Title "⚠ ERROR DE CONEXIÓN FTP" -Message $mensajePopup -Options @("*Reintentar", "*Cancelar") -Beep
        
        if ($respuesta -eq 1) {
            # Opción 1 = Cancelar
            Write-Log "Usuario canceló configuración FTP tras error de conexión" "INFO"
            return $null
        }
        
        # Opción 0 = Reintentar - volver a llamar recursivamente
        Write-Log "Usuario eligió reintentar conexión FTP" "INFO"
        return Get-FtpConfigFromUser
    }
    
    return @{
        Path      = $fullPath
        Server    = $server
        Port      = $port
        Directory = $directory
        User      = $credentials.UserName
        Password  = $credentials.GetNetworkCredential().Password
    }
}

function Show-BlockSizeMenu {
    param($Config)
    
    Write-Host ""
    Write-Host "Tamaño actual de bloque: $($Config.BlockSizeMB) MB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Tamaños comunes:" -ForegroundColor Gray
    Write-Host "  • 10 MB  - USBs pequeños" -ForegroundColor DarkGray
    Write-Host "  • 50 MB  - USBs medianos" -ForegroundColor DarkGray
    Write-Host "  • 100 MB - USBs grandes" -ForegroundColor DarkGray
    Write-Host "  • 500 MB - Discos externos" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Ingrese nuevo tamaño en MB (ENTER para mantener actual): " -NoNewline -ForegroundColor Cyan
    $userInput = Read-Host
    
    if (-not [string]::IsNullOrWhiteSpace($userInput)) {
        $newSize = 0
        if ([int]::TryParse($userInput, [ref]$newSize) -and $newSize -gt 0) {
            $Config.BlockSizeMB = $newSize
            Show-ConsolePopup -Title "Tamaño de Bloque" -Message "Tamaño configurado: $newSize MB" -Options @("*OK") | Out-Null
        }
        else {
            Show-ConsolePopup -Title "Error" -Message "Tamaño inválido. Debe ser un número mayor a 0" -Options @("*OK") | Out-Null
        }
    }
    
    return $Config
}

function Show-IsoMenu {
    param($Config)
    
    $options = @(
        "Modo *USB (normal)",
        "Generar *CD (700 MB)",
        "Generar *DVD (4.5 GB)",
        "Generar ISO tipo *USB (4.5 GB)"
    )
    
    $selection = Show-DosMenu -Title "MODO ISO" -Items $options -CancelValue 0 -DefaultValue $(if ($Config.Iso) { 2 }else { 1 })
    
    switch ($selection) {
        0 { return $Config }
        1 {
            $Config.Iso = $false
            Show-ConsolePopup -Title "Modo USB" -Message "Modo USB activado (normal)" -Options @("*OK") | Out-Null
        }
        2 {
            $Config.Iso = $true
            $Config.IsoDestino = "cd"
            Show-ConsolePopup -Title "Modo ISO" -Message "Generará imágenes ISO de CD (700 MB)" -Options @("*OK") | Out-Null
        }
        3 {
            $Config.Iso = $true
            $Config.IsoDestino = "dvd"
            Show-ConsolePopup -Title "Modo ISO" -Message "Generará imágenes ISO de DVD (4.5 GB)" -Options @("*OK") | Out-Null
        }
        4 {
            $Config.Iso = $true
            $Config.IsoDestino = "usb"
            Show-ConsolePopup -Title "Modo ISO" -Message "Generará imágenes ISO tipo USB (4.5 GB)" -Options @("*OK") | Out-Null
        }
    }
    
    return $Config
}

function Show-PasswordMenu {
    param($Config)
    
    if ($Config.Clave) {
        $options = @(
            "*Cambiar contraseña",
            "*Eliminar contraseña"
        )
        $selection = Show-DosMenu -Title "CONTRASEÑA (Actual: ******)" -Items $options -CancelValue 0
        
        if ($selection -eq 0) { return $Config }
        if ($selection -eq 2) {
            $Config.Clave = $null
            Show-ConsolePopup -Title "Contraseña" -Message "Contraseña eliminada" -Options @("*OK") | Out-Null
            return $Config
        }
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  CONFIGURAR CONTRASEÑA" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "⚠ NOTA: Solo funciona con 7-Zip (no con ZIP nativo)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Ingrese contraseña (ENTER para cancelar): " -NoNewline -ForegroundColor Cyan
    $pass1 = Read-Host -AsSecureString
    
    if ($pass1.Length -eq 0) {
        return $Config
    }
    
    Write-Host "Confirme contraseña: " -NoNewline -ForegroundColor Cyan
    $pass2 = Read-Host -AsSecureString
    
    $ptr1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass1)
    $ptr2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass2)
    $plainPass1 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr1)
    $plainPass2 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr2)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr1)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr2)
    
    if ($plainPass1 -eq $plainPass2) {
        $Config.Clave = $plainPass1
        Show-ConsolePopup -Title "Contraseña" -Message "Contraseña configurada correctamente" -Options @("*OK") | Out-Null
    }
    else {
        Show-ConsolePopup -Title "Error" -Message "Las contraseñas no coinciden" -Options @("*OK") | Out-Null
    }
    
    return $Config
}

# ========================================================================== #
#                        FUNCIÓN DE MENÚ DOS MEJORADA                        #
# ========================================================================== #

function Show-DosMenu {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [string[]]$Items,
        [int]$CancelValue = 0,

        [ConsoleColor]$BorderColor = [ConsoleColor]::White,
        [ConsoleColor]$TextColor = [ConsoleColor]::Gray,
        [ConsoleColor]$TextBackgroundColor = [ConsoleColor]::Black,
        [ConsoleColor]$HighlightForegroundColor = [ConsoleColor]::Black,
        [ConsoleColor]$HighlightBackgroundColor = [ConsoleColor]::Yellow,
        [ConsoleColor]$HotkeyColor = [ConsoleColor]::Cyan,
        [ConsoleColor]$AutoHotkeyColor = [ConsoleColor]::DarkCyan,
        [ConsoleColor]$HotkeyBackgroundColor = [ConsoleColor]::Black,
        [int]$DefaultValue = $CancelValue,
        
        [int]$X = -1,
        [int]$Y = -1
    )

    if (-not $Items -or $Items.Count -eq 0) {
        throw "Show-DosMenu: no hay elementos para mostrar."
    }

    $hasCancel = $true
    $cancelLabel = "Cancelar / Volver"

    # 1) Parsear items con posible *hotkey
    $meta = @()
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $num = $i + 1
        $raw = $Items[$i]
        $display = $raw
        $hotChar = $null
        $hotIndex = -1
        $isAuto = $false

        $starIndex = $raw.IndexOf('*')
        if ($starIndex -ge 0 -and $starIndex -lt ($raw.Length - 1)) {
            $hotChar = $raw[$starIndex + 1]
            $display = $raw.Remove($starIndex, 1)
            $hotIndex = $starIndex
        }

        $meta += [pscustomobject]@{
            Value        = $num
            DisplayText  = $display
            HotkeyChar   = $hotChar
            HotkeyIndex  = $hotIndex
            IsAutoHotkey = $isAuto
        }
    }

    # 2) Evitar teclas repetidas
    $usedHotkeys = @()
    foreach ($m in $meta) {
        if ($m.HotkeyChar) {
            $key = ([string]$m.HotkeyChar).ToUpper()
            if ($usedHotkeys -contains $key) {
                $m.HotkeyChar = $null
                $m.HotkeyIndex = -1
            }
            else {
                $usedHotkeys += $key
            }
        }
    }

    # 3) Asignar teclas automaticas donde falten
    foreach ($m in $meta) {
        if (-not $m.HotkeyChar) {
            $text = $m.DisplayText
            for ($idx = 0; $idx -lt $text.Length; $idx++) {
                $ch = $text[$idx]
                if ([char]::IsLetterOrDigit($ch)) {
                    $upper = [string]::ToUpper([string]$ch)
                    if (-not ($usedHotkeys -contains $upper)) {
                        $m.HotkeyChar = $ch
                        $m.HotkeyIndex = $idx
                        $m.IsAutoHotkey = $true
                        $usedHotkeys += $upper
                        break
                    }
                }
            }
        }
    }

    # 4) Construir lista de opciones (incluye cancelar)
    $optionLines = @()
    $optionMeta = @()

    if ($hasCancel) {
        $cancelMeta = [pscustomobject]@{
            Value        = $CancelValue
            DisplayText  = $cancelLabel
            HotkeyChar   = $null
            HotkeyIndex  = -1
            IsAutoHotkey = $false
        }
        $optionMeta += $cancelMeta
        $optionLines += ("{0}: {1}" -f $CancelValue, $cancelLabel)
    }

    foreach ($m in $meta) {
        $optionMeta += $m
        $optionLines += ("{0}: {1}" -f $m.Value, $m.DisplayText)
    }

    $contentWidth = ($optionLines | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $titleWidth = $Title.Length
    if ($titleWidth -gt $contentWidth) { $contentWidth = $titleWidth }

    $padding = 2
    $innerWidth = $contentWidth + ($padding * 2)

    $top = "╔" + ("═" * $innerWidth) + "╗"
    $bottom = "╚" + ("═" * $innerWidth) + "╝"

    # Línea divisoria
    $divider = "╠" + ("═" * $innerWidth) + "╣"

    # Título centrado
    $leftPad = [int][Math]::Floor(($innerWidth - $Title.Length) / 2)
    $rightPad = $innerWidth - $Title.Length - $leftPad
    $titleLine = "║" + (" " * $leftPad) + $Title + (" " * $rightPad) + "║"

    # Seleccion inicial
    $selectedIndex = 0
    if ($optionMeta.Count -gt 0) {
        for ($i = 0; $i -lt $optionMeta.Count; $i++) {
            if ($optionMeta[$i].Value -eq $DefaultValue) {
                $selectedIndex = $i
                break
            }
        }
    }

    # Calcular posición si se especificó
    $menuX = -1
    $menuY = -1
    if ($X -ge 0 -and $Y -ge 0) {
        $winWidth = [Console]::WindowWidth
        $winHeight = [Console]::WindowHeight
        $menuX = [Math]::Max(0, [Math]::Min($X, $winWidth - $innerWidth - 2))
        $menuY = [Math]::Max(0, [Math]::Min($Y, $winHeight - ($optionLines.Count + 5)))
    }

    while ($true) {
        # Siempre limpiar pantalla
        Clear-Host
        
        # Si se especificó posición, mover cursor a esa posición
        if ($menuX -ge 0 -and $menuY -ge 0) {
            try {
                [Console]::SetCursorPosition($menuX, $menuY)
            }
            catch {
                # Si falla, continuar con posición por defecto
            }
        }
        
        Write-Host $top       -ForegroundColor $BorderColor
        
        if ($menuX -ge 0 -and $menuY -ge 0) {
            [Console]::SetCursorPosition($menuX, $menuY + 1)
        }
        Write-Host $titleLine -ForegroundColor $BorderColor
        
        if ($menuX -ge 0 -and $menuY -ge 0) {
            [Console]::SetCursorPosition($menuX, $menuY + 2)
        }
        Write-Host $divider -ForegroundColor $BorderColor
        
        if ($menuX -ge 0 -and $menuY -ge 0) {
            [Console]::SetCursorPosition($menuX, $menuY + 3)
        }
        Write-Host ("║" + (" " * $innerWidth) + "║") -ForegroundColor $BorderColor

        for ($i = 0; $i -lt $optionLines.Count; $i++) {
            $line = $optionLines[$i]
            $metaItem = $optionMeta[$i]
            $padRight = $innerWidth - $line.Length
            if ($padRight -lt 0) { $padRight = 0 }

            $isSelected = ($i -eq $selectedIndex)

            $lineBg = $TextBackgroundColor
            $lineFg = $TextColor
            if ($isSelected) {
                $lineBg = $HighlightBackgroundColor
                $lineFg = $HighlightForegroundColor
            }

            $prefix = ("{0}: " -f $metaItem.Value)
            $display = $metaItem.DisplayText

            if ($menuX -ge 0 -and $menuY -ge 0) {
                [Console]::SetCursorPosition($menuX, $menuY + 4 + $i)
            }
            Write-Host -NoNewline "║ " -ForegroundColor $BorderColor -BackgroundColor $lineBg
            Write-Host -NoNewline $prefix -ForegroundColor $lineFg -BackgroundColor $lineBg

            if ($metaItem.HotkeyIndex -ge 0 -and $metaItem.HotkeyIndex -lt $display.Length) {
                $left = $display.Substring(0, $metaItem.HotkeyIndex)
                $keyChar = $display.Substring($metaItem.HotkeyIndex, 1)
                $right = ""
                if ($metaItem.HotkeyIndex -lt ($display.Length - 1)) {
                    $right = $display.Substring($metaItem.HotkeyIndex + 1)
                }

                if ($left.Length -gt 0) {
                    Write-Host -NoNewline $left -ForegroundColor $lineFg -BackgroundColor $lineBg
                }

                $keyFg = if ($metaItem.IsAutoHotkey) { $AutoHotkeyColor } else { $HotkeyColor }
                $keyBg = $HotkeyBackgroundColor
                if ($isSelected) {
                    $keyBg = $HighlightBackgroundColor
                }

                Write-Host -NoNewline $keyChar -ForegroundColor $keyFg -BackgroundColor $keyBg

                if ($right.Length -gt 0) {
                    Write-Host -NoNewline $right -ForegroundColor $lineFg -BackgroundColor $lineBg
                }
            }
            else {
                Write-Host -NoNewline $display -ForegroundColor $lineFg -BackgroundColor $lineBg
            }

            Write-Host -NoNewline (" " * ($padRight - 1)) -ForegroundColor $lineBg -BackgroundColor $lineBg
            Write-Host "║" -ForegroundColor $BorderColor -BackgroundColor $lineBg
        }

        if ($menuX -ge 0 -and $menuY -ge 0) {
            [Console]::SetCursorPosition($menuX, $menuY + 4 + $optionLines.Count)
        }
        Write-Host $bottom -ForegroundColor $BorderColor
        Write-Host ""
        Write-Host "Use flechas, ENTER, numero, o tecla resaltada."

        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            'UpArrow' { $selectedIndex = ($selectedIndex - 1); if ($selectedIndex -lt 0) { $selectedIndex = $optionLines.Count - 1 } }
            'DownArrow' { $selectedIndex = ($selectedIndex + 1); if ($selectedIndex -ge $optionLines.Count) { $selectedIndex = 0 } }
            'Enter' {
                $lineSel = $optionLines[$selectedIndex]
                if ($lineSel -match '^\s*(\d+)\s*:') {
                    return [int]$matches[1]
                }
            }
            default {
                $ch = $key.KeyChar
                if ($ch -match '^\d$') {
                    $num = [int]::Parse($ch)
                    foreach ($m in $optionMeta) {
                        if ($m.Value -eq $num) {
                            return $num
                        }
                    }
                }
                elseif ($ch -match '^[A-Za-z0-9]$') {
                    $upperCh = [string]::ToUpper([string]$ch)
                    foreach ($m in $optionMeta) {
                        if ($m.HotkeyChar) {
                            $mKey = [string]::ToUpper([string]$m.HotkeyChar)
                            if ($mKey -eq $upperCh) {
                                return [int]$m.Value
                            }
                        }
                    }
                }
            }
        }
    }
}

# ========================================================================== #
#                         POPUP DE MENSAJE (CONSOLE)                         #
# ========================================================================== #

function Show-ConsolePopup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string[]]$Options = @("*Aceptar"),
        [int]$DefaultIndex = 0,

        [ConsoleColor]$BorderColor = [ConsoleColor]::White,
        [ConsoleColor]$BorderBackgroundColor = [ConsoleColor]::Black,
        [ConsoleColor]$TitleColor = [ConsoleColor]::Yellow,
        [ConsoleColor]$TitleBackgroundColor = [ConsoleColor]::DarkBlue,
        [ConsoleColor]$TextColor = [ConsoleColor]::Gray,
        [ConsoleColor]$TextBackgroundColor = [ConsoleColor]::Black,
        [ConsoleColor]$OptionColor = [ConsoleColor]::Gray,
        [ConsoleColor]$OptionBackgroundColor = [ConsoleColor]::Black,
        [ConsoleColor]$OptionHighlightColor = [ConsoleColor]::Black,
        [ConsoleColor]$OptionHighlightBackground = [ConsoleColor]::Yellow,
        [ConsoleColor]$HotkeyColor = [ConsoleColor]::Cyan,
        [ConsoleColor]$AutoHotkeyColor = [ConsoleColor]::DarkCyan,
        [ConsoleColor]$HotkeyBackgroundColor = [ConsoleColor]::Black,

        [switch]$AllowEsc,
        [switch]$Beep,
        
        [int]$X = -1,
        [int]$Y = -1
    )

    if (-not $Options -or $Options.Count -eq 0) {
        $Options = @("*Aceptar")
    }

    if ($Beep) {
        [console]::Beep()
    }

    $msgLines = $Message -split "`r?`n"

    # procesar opciones con * hotkeys
    $meta = @()
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $raw = $Options[$i]
        $display = $raw
        $hotChar = $null
        $hotIndex = -1
        $isAuto = $false

        $starIndex = $raw.IndexOf('*')
        if ($starIndex -ge 0 -and $starIndex -lt ($raw.Length - 1)) {
            $hotChar = $raw[$starIndex + 1]
            $display = $raw.Remove($starIndex, 1)
            $hotIndex = $starIndex
        }

        $meta += [pscustomobject]@{
            Index       = $i
            DisplayText = $display
            HotkeyChar  = $hotChar
            HotkeyIndex = $hotIndex
            IsAuto      = $isAuto
        }
    }

    $usedHotkeys = @()
    foreach ($m in $meta) {
        if ($m.HotkeyChar) {
            $key = ([string]$m.HotkeyChar).ToUpper()
            if ($usedHotkeys -contains $key) {
                $m.HotkeyChar = $null
                $m.HotkeyIndex = -1
            }
            else {
                $usedHotkeys += $key
            }
        }
    }

    foreach ($m in $meta) {
        if (-not $m.HotkeyChar) {
            $text = $m.DisplayText
            for ($idx = 0; $idx -lt $text.Length; $idx++) {
                $ch = $text[$idx]
                if ([char]::IsLetterOrDigit($ch)) {
                    $upper = ([string]$ch).ToUpper()
                    if (-not ($usedHotkeys -contains $upper)) {
                        $m.HotkeyChar = $ch
                        $m.HotkeyIndex = $idx
                        $m.IsAuto = $true
                        $usedHotkeys += $upper
                        break
                    }
                }
            }
        }
    }

    $optionsText = ($meta | ForEach-Object { $_.DisplayText }) -join "   "
    $maxMsgWidth = ($msgLines | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    if ($null -eq $maxMsgWidth) { $maxMsgWidth = 0 }
    $contentWidth = [Math]::Max($maxMsgWidth, [Math]::Max($Title.Length, $optionsText.Length))
    $padding = 4
    $innerWidth = $contentWidth + $padding
    $boxWidth = $innerWidth + 2

    $topLine = "╔" + ("═" * $innerWidth) + "╗"
    $bottomLine = "╚" + ("═" * $innerWidth) + "╝"
    $dividerLine = "╠" + ("═" * $innerWidth) + "╣"

    $winWidth = [console]::WindowWidth
    $winHeight = [console]::WindowHeight

    # Usar posición especificada o calcular centrado
    if ($X -ge 0) {
        $boxLeft = [Math]::Max(0, [Math]::Min($X, $winWidth - $boxWidth))
    }
    else {
        $boxLeft = [Math]::Max(0, [int][Math]::Floor(($winWidth - $boxWidth) / 2))
    }
    
    if ($Y -ge 0) {
        $boxTop = [Math]::Max(0, [Math]::Min($Y, $winHeight - ($msgLines.Count + 6)))
    }
    else {
        $boxTop = [Math]::Max(0, [int][Math]::Floor(($winHeight - ($msgLines.Count + 6)) / 2))
    }

    $selected = if ($DefaultIndex -ge 0 -and $DefaultIndex -lt $meta.Count) { $DefaultIndex } else { 0 }

    while ($true) {
        # dibujar fondo
        for ($row = 0; $row -lt ($msgLines.Count + 6); $row++) {
            [console]::SetCursorPosition($boxLeft, $boxTop + $row)
            Write-Host (" " * $boxWidth) -NoNewline -BackgroundColor $BorderBackgroundColor
        }

        # borde superior
        [console]::SetCursorPosition($boxLeft, $boxTop)
        Write-Host $topLine -ForegroundColor $BorderColor -BackgroundColor $BorderBackgroundColor

        # titulo
        $titlePad = $innerWidth - $Title.Length
        $leftPad = [int][Math]::Floor($titlePad / 2)
        $rightPad = $innerWidth - $Title.Length - $leftPad
        $titleLine = "║" + (" " * $leftPad) + $Title + (" " * $rightPad) + "║"
        [console]::SetCursorPosition($boxLeft, $boxTop + 1)
        Write-Host $titleLine -ForegroundColor $TitleColor -BackgroundColor $TitleBackgroundColor

        # linea divisoria
        [console]::SetCursorPosition($boxLeft, $boxTop + 2)
        Write-Host $dividerLine -ForegroundColor $BorderColor -BackgroundColor $BorderBackgroundColor

        # mensaje (centrado)
        for ($i = 0; $i -lt $msgLines.Count; $i++) {
            $line = $msgLines[$i]
            $linePad = $innerWidth - $line.Length
            if ($linePad -lt 0) { $linePad = 0 }
            
            # Centrar el mensaje
            $lineLeftPad = [int][Math]::Floor($linePad / 2)
            $lineRightPad = $linePad - $lineLeftPad
            
            [console]::SetCursorPosition($boxLeft, $boxTop + 3 + $i)
            Write-Host -NoNewline "║" -ForegroundColor $BorderColor -BackgroundColor $TextBackgroundColor
            Write-Host -NoNewline (" " * $lineLeftPad) -ForegroundColor $TextColor -BackgroundColor $TextBackgroundColor
            Write-Host -NoNewline $line -ForegroundColor $TextColor -BackgroundColor $TextBackgroundColor
            Write-Host -NoNewline (" " * $lineRightPad) -ForegroundColor $TextColor -BackgroundColor $TextBackgroundColor
            Write-Host "║" -ForegroundColor $BorderColor -BackgroundColor $TextBackgroundColor
        }

        # linea separadora antes de opciones
        [console]::SetCursorPosition($boxLeft, $boxTop + 3 + $msgLines.Count)
        Write-Host $dividerLine -ForegroundColor $BorderColor -BackgroundColor $BorderBackgroundColor

        # opciones (centradas)
        # Calcular ancho total de opciones con espacios entre ellas
        $optionsWidth = 0
        for ($i = 0; $i -lt $meta.Count; $i++) {
            $optionsWidth += $meta[$i].DisplayText.Length
            if ($i -gt 0) { $optionsWidth += 3 }  # espacios entre opciones
        }
        
        # Calcular padding para centrar
        $optionsPad = $innerWidth - $optionsWidth
        if ($optionsPad -lt 0) { $optionsPad = 0 }
        $optionsLeftPad = [int][Math]::Floor($optionsPad / 2)
        $optionsRightPad = $optionsPad - $optionsLeftPad
        
        [console]::SetCursorPosition($boxLeft, $boxTop + 4 + $msgLines.Count)
        Write-Host -NoNewline "║" -ForegroundColor $BorderColor -BackgroundColor $TextBackgroundColor
        Write-Host -NoNewline (" " * $optionsLeftPad) -BackgroundColor $TextBackgroundColor

        for ($i = 0; $i -lt $meta.Count; $i++) {
            $m = $meta[$i]
            $isSel = ($i -eq $selected)

            $fg = $OptionColor
            $bg = $OptionBackgroundColor
            if ($isSel) {
                $fg = $OptionHighlightColor
                $bg = $OptionHighlightBackground
            }

            $display = $m.DisplayText

            if ($i -gt 0) {
                Write-Host "   " -NoNewline -ForegroundColor $fg -BackgroundColor $bg
            }

            if ($m.HotkeyIndex -ge 0 -and $m.HotkeyIndex -lt $display.Length) {
                $left = $display.Substring(0, $m.HotkeyIndex)
                $keyCh = $display.Substring($m.HotkeyIndex, 1)
                $right = ""
                if ($m.HotkeyIndex -lt ($display.Length - 1)) {
                    $right = $display.Substring($m.HotkeyIndex + 1)
                }

                if ($left.Length -gt 0) {
                    Write-Host $left -NoNewline -ForegroundColor $fg -BackgroundColor $bg
                }

                $kfg = if ($m.IsAuto) { $AutoHotkeyColor } else { $HotkeyColor }
                $kbg = $HotkeyBackgroundColor
                if ($isSel) { 
                    $kbg = $OptionHighlightBackground
                    $kfg = [ConsoleColor]::DarkBlue  # Color que se lee bien sobre amarillo
                }

                Write-Host $keyCh -NoNewline -ForegroundColor $kfg -BackgroundColor $kbg

                if ($right.Length -gt 0) {
                    Write-Host $right -NoNewline -ForegroundColor $fg -BackgroundColor $bg
                }
            }
            else {
                Write-Host $display -NoNewline -ForegroundColor $fg -BackgroundColor $bg
            }
        }
        
        # Completar con espacios y cerrar borde derecho
        Write-Host -NoNewline (" " * $optionsRightPad) -BackgroundColor $TextBackgroundColor
        Write-Host "║" -ForegroundColor $BorderColor -BackgroundColor $TextBackgroundColor

        [console]::SetCursorPosition($boxLeft, $boxTop + 5 + $msgLines.Count)
        Write-Host $bottomLine -ForegroundColor $BorderColor -BackgroundColor $BorderBackgroundColor

        # leer tecla
        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            'LeftArrow' { $selected = ($selected - 1); if ($selected -lt 0) { $selected = $meta.Count - 1 } }
            'RightArrow' { $selected = ($selected + 1); if ($selected -ge $meta.Count) { $selected = 0 } }
            'UpArrow' { $selected = ($selected - 1); if ($selected -lt 0) { $selected = $meta.Count - 1 } }
            'DownArrow' { $selected = ($selected + 1); if ($selected -ge $meta.Count) { $selected = 0 } }
            'Enter' { return $selected }
            'Escape' {
                if ($AllowEsc) {
                    return -1
                }
            }
            default {
                $ch = $key.KeyChar
                if ($ch -match '^[A-Za-z0-9]$') {
                    $upperCh = [string]::ToUpper([string]$ch)
                    for ($i = 0; $i -lt $meta.Count; $i++) {
                        $m = $meta[$i]
                        if ($m.HotkeyChar) {
                            $k = [string]::ToUpper([string]$m.HotkeyChar)
                            if ($k -eq $upperCh) {
                                return $i
                            }
                        }
                    }
                }
            }
        }
    }
}

# ========================================================================== #
#                         FUNCIONES DE RED Y UNC                             #
# ========================================================================== #

function Get-NetworkComputers {
    <#
    .SYNOPSIS
        Descubre equipos en la red local LAN
    
    .DESCRIPTION
        Escanea la red local buscando equipos disponibles usando NetBIOS y WMI
    #>
    
    Write-Host "`nBuscando equipos en la red local..." -ForegroundColor Cyan
    Write-Host "Esto puede tardar unos segundos..." -ForegroundColor Gray
    Write-Host ""
    
    $computers = @()
    
    try {
        # Método 1: Usar net view (rápido pero puede no funcionar en todas las redes)
        $netViewOutput = net view 2>$null
        if ($LASTEXITCODE -eq 0) {
            $netViewOutput | ForEach-Object {
                if ($_ -match '^\\\\\w+') {
                    $computerName = $_.Trim().Split()[0].TrimStart('\')
                    if ($computerName -and $computerName -ne '') {
                        $computers += [PSCustomObject]@{
                            Name = $computerName
                            Path = "\\$computerName"
                        }
                    }
                }
            }
        }
    }
    catch {
        # Ignorar errores de net view
    }
    
    # Método 2: Intentar con Get-ADComputer (si está en dominio)
    try {
        if (Get-Command Get-ADComputer -ErrorAction SilentlyContinue) {
            $adComputers = Get-ADComputer -Filter * -Properties Name 2>$null | Select-Object -First 50
            foreach ($comp in $adComputers) {
                if ($comp.Name -and ($computers.Name -notcontains $comp.Name)) {
                    $computers += [PSCustomObject]@{
                        Name = $comp.Name
                        Path = "\\$($comp.Name)"
                    }
                }
            }
        }
    }
    catch {
        # AD no disponible o no está en dominio
    }
    
    return $computers
}

function Test-UncPathAccess {
    <#
    .SYNOPSIS
        Verifica si se puede acceder a una ruta UNC
    
    .DESCRIPTION
        Intenta acceder a una ruta UNC con o sin credenciales
    #>
    
    param(
        [string]$UncPath,
        [PSCredential]$Credential = $null
    )
    
    try {
        # Si hay credenciales, intentar montar con net use
        if ($Credential) {
            $username = $Credential.UserName
            $password = $Credential.GetNetworkCredential().Password
            
            # Intentar montar la ruta con credenciales
            $netUseCmd = "net use `"$UncPath`" /user:$username $password 2>&1"
            $result = Invoke-Expression $netUseCmd
            
            if ($LASTEXITCODE -eq 0) {
                # Verificar acceso
                if (Test-Path $UncPath) {
                    return @{
                        Success = $true
                        Message = "Acceso exitoso con credenciales"
                    }
                }
                else {
                    return @{
                        Success = $false
                        Message = "Credenciales aceptadas pero ruta no accesible"
                    }
                }
            }
            else {
                return @{
                    Success = $false
                    Message = "Credenciales incorrectas o acceso denegado"
                }
            }
        }
        else {
            # Sin credenciales, intentar acceso directo
            if (Test-Path $UncPath) {
                return @{
                    Success = $true
                    Message = "Acceso exitoso sin credenciales"
                }
            }
            else {
                return @{
                    Success = $false
                    Message = "No se puede acceder (puede requerir credenciales)"
                }
            }
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Error: $($_.Exception.Message)"
        }
    }
}

function Get-ComputerShares {
    <#
    .SYNOPSIS
        Lista los recursos compartidos de un equipo
    
    .DESCRIPTION
        Obtiene la lista de carpetas compartidas en un equipo de red
    #>
    
    param(
        [string]$ComputerName,
        [PSCredential]$Credential = $null
    )
    
    $shares = @()
    
    try {
        # Usar net view para listar shares
        $netViewOutput = net view "\\$ComputerName" 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            $inShareList = $false
            
            foreach ($line in $netViewOutput) {
                # Detectar el inicio de la lista de shares
                if ($line -match '^\-{3,}') {
                    $inShareList = $true
                    continue
                }
                
                # Si estamos en la lista y la línea no está vacía
                if ($inShareList -and $line.Trim() -ne '') {
                    # Extraer el nombre del share (primera columna)
                    $parts = $line -split '\s{2,}'
                    if ($parts.Count -gt 0) {
                        $shareName = $parts[0].Trim()
                        if ($shareName -and $shareName -ne '') {
                            $shares += [PSCustomObject]@{
                                Name = $shareName
                                Path = "\\$ComputerName\$shareName"
                            }
                        }
                    }
                }
            }
        }
    }
    catch {
        # Ignorar errores
    }
    
    return $shares
}

function Select-NetworkPath {
    <#
    .SYNOPSIS
        Menú interactivo para seleccionar ruta UNC con discovery o manual
    
    .DESCRIPTION
        Permite al usuario elegir entre descubrir equipos en red o ingresar ruta manual
    #>
    
    param(
        [string]$Purpose = "DESTINO"
    )
    
    $options = @(
        "*Descubrir equipos en la red (automático)",
        "Ingresar ruta *Manual (\\servidor\carpeta)"
    )
    
    $selection = Show-DosMenu -Title "RED UNC - $Purpose" -Items $options -CancelValue 0
    
    switch ($selection) {
        0 { 
            return $null 
        }
        1 {
            # Modo Discovery
            $computers = Get-NetworkComputers
            
            if ($computers.Count -eq 0) {
                Show-ConsolePopup -Title "Sin Equipos" -Message "No se encontraron equipos en la red`n`nIntente el modo manual" -Options @("*OK") | Out-Null
                return $null
            }
            
            # Mostrar lista de equipos encontrados
            $computerNames = $computers | ForEach-Object { $_.Name }
            $selectedIdx = Show-DosMenu -Title "Equipos Encontrados - Seleccione uno" -Items $computerNames -CancelValue 0
            
            if ($selectedIdx -eq 0) {
                return $null
            }
            
            $selectedComputer = $computers[$selectedIdx - 1].Name
            
            # Obtener shares del equipo
            Write-Host "`nObteniendo recursos compartidos de $selectedComputer..." -ForegroundColor Cyan
            $shares = Get-ComputerShares -ComputerName $selectedComputer
            
            if ($shares.Count -eq 0) {
                Show-ConsolePopup -Title "Sin Recursos" -Message "No se encontraron recursos compartidos en $selectedComputer`n`nIntente con otro equipo o modo manual" -Options @("*OK") | Out-Null
                return $null
            }
            
            # Mostrar lista de shares
            $shareNames = $shares | ForEach-Object { "$($_.Name) → $($_.Path)" }
            $shareIdx = Show-DosMenu -Title "Recursos Compartidos - $selectedComputer" -Items $shareNames -CancelValue 0
            
            if ($shareIdx -eq 0) {
                return $null
            }
            
            $selectedShare = $shares[$shareIdx - 1].Path
            
            # Intentar acceso sin credenciales primero
            Write-Host "`nVerificando acceso a $selectedShare..." -ForegroundColor Cyan
            $accessTest = Test-UncPathAccess -UncPath $selectedShare
            
            if ($accessTest.Success) {
                Write-Host "✓ $($accessTest.Message)" -ForegroundColor Green
                return @{
                    Path        = $selectedShare
                    Credentials = $null
                }
            }
            else {
                Write-Host "⚠ $($accessTest.Message)" -ForegroundColor Yellow
                
                # Preguntar si quiere ingresar credenciales
                $needCreds = Show-ConsolePopup -Title "Acceso Denegado" -Message "$($accessTest.Message)`n`n¿Desea ingresar credenciales?" -Options @("*Sí", "*No")
                
                if ($needCreds -eq 1) {
                    $creds = Get-Credential -Message "Credenciales para $selectedShare"
                    
                    if ($creds) {
                        Write-Host "`nVerificando credenciales..." -ForegroundColor Cyan
                        $accessTestWithCreds = Test-UncPathAccess -UncPath $selectedShare -Credential $creds
                        
                        if ($accessTestWithCreds.Success) {
                            Write-Host "✓ $($accessTestWithCreds.Message)" -ForegroundColor Green
                            return @{
                                Path        = $selectedShare
                                Credentials = $creds
                            }
                        }
                        else {
                            Show-ConsolePopup -Title "Error de Acceso" -Message $accessTestWithCreds.Message -Options @("*OK") | Out-Null
                            return $null
                        }
                    }
                }
                
                return $null
            }
        }
        2 {
            # Modo Manual
            Write-Host "`nIngrese la ruta UNC (ej: \\\\servidor\\compartido\\carpeta):" -ForegroundColor Cyan
            $path = Read-Host "Ruta UNC"
            
            if ([string]::IsNullOrWhiteSpace($path)) {
                return $null
            }
            
            # Validar formato UNC
            if ($path -notlike "\\*") {
                Show-ConsolePopup -Title "Formato Inválido" -Message "La ruta debe comenzar con \\\\ (ej: \\\\servidor\\carpeta)" -Options @("*OK") | Out-Null
                return $null
            }
            
            # Intentar acceso
            Write-Host "`nVerificando acceso a $path..." -ForegroundColor Cyan
            $accessTest = Test-UncPathAccess -UncPath $path
            
            if ($accessTest.Success) {
                Write-Host "✓ $($accessTest.Message)" -ForegroundColor Green
                return @{
                    Path        = $path
                    Credentials = $null
                }
            }
            else {
                Write-Host "⚠ $($accessTest.Message)" -ForegroundColor Yellow
                
                # Preguntar credenciales
                $needCreds = Show-ConsolePopup -Title "Acceso Denegado" -Message "$($accessTest.Message)`n`n¿Desea ingresar credenciales?" -Options @("*Sí", "*No")
                
                if ($needCreds -eq 1) {
                    $creds = Get-Credential -Message "Credenciales para $path"
                    
                    if ($creds) {
                        Write-Host "`nVerificando credenciales..." -ForegroundColor Cyan
                        $accessTestWithCreds = Test-UncPathAccess -UncPath $path -Credential $creds
                        
                        if ($accessTestWithCreds.Success) {
                            Write-Host "✓ $($accessTestWithCreds.Message)" -ForegroundColor Green
                            return @{
                                Path        = $path
                                Credentials = $creds
                            }
                        }
                        else {
                            Show-ConsolePopup -Title "Error de Acceso" -Message $accessTestWithCreds.Message -Options @("*OK") | Out-Null
                            return $null
                        }
                    }
                }
                else {
                    # Permitir continuar aunque no se haya verificado acceso
                    $continue = Show-ConsolePopup -Title "Continuar Sin Verificar" -Message "¿Desea continuar sin verificar acceso?`n(puede fallar durante la transferencia)" -Options @("*Sí", "*No")
                    
                    if ($continue -eq 1) {
                        return @{
                            Path        = $path
                            Credentials = $null
                        }
                    }
                }
                
                return $null
            }
        }
    }
    
    return $null
}

function Split-UncRootAndPath {
    param(
        [string]$Path
    )

    if (-not $Path -or $Path -notlike "\\\\*") {
        return @($null, $null)
    }

    $trim = $Path.TrimStart('\')
    $parts = $trim.Split('\')
    if ($parts.Length -lt 2) {
        return @($null, $null)
    }

    $root = "\\\\" + $parts[0] + "\" + $parts[1]
    $rest = ""
    if ($parts.Length -gt 2) {
        $rest = "\" + ([string]::Join('\', $parts[2..($parts.Length - 1)]))
    }

    return @($root, $rest)
}

# ========================================================================== #
#                                SOPORTE FTP                                 #
# ========================================================================== #

function Test-IsFtpPath {
    param([string]$Path)
    return $Path -match '^ftp://|^ftps://'
}

# ========================================================================== #
#                              SOPORTE ONEDRIVE                              #
# ========================================================================== #

function Test-MicrosoftGraphModule {
    <#
    .SYNOPSIS
        Verifica si el módulo Microsoft.Graph está instalado y lo instala si es necesario
    .DESCRIPTION
        Detecta si los módulos Microsoft.Graph.Authentication y Microsoft.Graph.Files están disponibles.
        Si no están instalados, intenta instalarlos automáticamente.
        Si la instalación falla, muestra error y retorna false.
    .RETURNS
        $true si los módulos están disponibles, $false si faltan y no se pueden instalar
    #>
    
    Write-Host "`n══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  VERIFICACIÓN DE MÓDULOS MICROSOFT.GRAPH" -ForegroundColor Yellow
    Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Módulos requeridos
    $requiredModules = @(
        'Microsoft.Graph.Authentication',
        'Microsoft.Graph.Files'
    )
    
    $missingModules = @()
    
    # Verificar cada módulo
    foreach ($moduleName in $requiredModules) {
        Write-Host "Verificando módulo: $moduleName..." -NoNewline -ForegroundColor Gray
        
        $module = Get-Module -ListAvailable -Name $moduleName | Select-Object -First 1
        
        if ($module) {
            Write-Host " ✓ Instalado (v$($module.Version))" -ForegroundColor Green
        }
        else {
            Write-Host " ✗ No encontrado" -ForegroundColor Yellow
            $missingModules += $moduleName
        }
    }
    
    # Si no faltan módulos, importar y continuar
    if ($missingModules.Count -eq 0) {
        Write-Host ""
        Write-Host "✓ Todos los módulos requeridos están instalados" -ForegroundColor Green
        
        # Importar módulos si no están cargados
        foreach ($moduleName in $requiredModules) {
            if (-not (Get-Module -Name $moduleName)) {
                Write-Host "Importando módulo: $moduleName..." -NoNewline -ForegroundColor Gray
                try {
                    Import-Module $moduleName -ErrorAction Stop
                    Write-Host " ✓" -ForegroundColor Green
                }
                catch {
                    Write-Host " ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
                    return $false
                }
            }
        }
        
        Write-Host ""
        return $true
    }
    
    # Intentar instalar módulos faltantes
    Write-Host ""
    Write-Host "══════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  INSTALACIÓN DE MÓDULOS FALTANTES" -ForegroundColor Yellow
    Write-Host "══════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Se requiere instalar los siguientes módulos:" -ForegroundColor Cyan
    foreach ($mod in $missingModules) {
        Write-Host "  • $mod" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "NOTA: La instalación puede tardar varios minutos." -ForegroundColor Yellow
    Write-Host "      Se instalará para el usuario actual (no requiere administrador)." -ForegroundColor Yellow
    Write-Host ""
    
    $response = Read-Host "¿Desea instalar los módulos ahora? (S/N)"
    
    if ($response -notmatch '^[SsYy]') {
        Write-Host ""
        Write-Host "✗ Instalación cancelada por el usuario." -ForegroundColor Red
        Write-Host ""
        Write-Host "Para usar OneDrive, instale manualmente los módulos con:" -ForegroundColor Yellow
        Write-Host "  Install-Module Microsoft.Graph -Scope CurrentUser" -ForegroundColor White
        Write-Host ""
        return $false
    }
    
    Write-Host ""
    Write-Host "Instalando módulos Microsoft.Graph..." -ForegroundColor Cyan
    Write-Host "Esto puede tardar varios minutos, por favor espere..." -ForegroundColor Gray
    Write-Host ""
    
    try {
        # Instalar Microsoft.Graph (incluye todos los submódulos)
        Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        
        Write-Host ""
        Write-Host "✓ Módulos instalados exitosamente" -ForegroundColor Green
        Write-Host ""
        
        # Verificar instalación
        $allInstalled = $true
        foreach ($moduleName in $requiredModules) {
            $module = Get-Module -ListAvailable -Name $moduleName | Select-Object -First 1
            if (-not $module) {
                Write-Host "✗ Error: No se pudo verificar la instalación de $moduleName" -ForegroundColor Red
                $allInstalled = $false
            }
        }
        
        if (-not $allInstalled) {
            Write-Host ""
            Write-Host "✗ La instalación no se completó correctamente." -ForegroundColor Red
            Write-Host "Por favor, intente instalar manualmente:" -ForegroundColor Yellow
            Write-Host "  Install-Module Microsoft.Graph -Scope CurrentUser" -ForegroundColor White
            Write-Host ""
            return $false
        }
        
        # Importar módulos recién instalados
        Write-Host "Importando módulos..." -ForegroundColor Cyan
        foreach ($moduleName in $requiredModules) {
            Write-Host "  • $moduleName..." -NoNewline -ForegroundColor Gray
            try {
                Import-Module $moduleName -ErrorAction Stop
                Write-Host " ✓" -ForegroundColor Green
            }
            catch {
                Write-Host " ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
                return $false
            }
        }
        
        Write-Host ""
        Write-Host "✓ Módulos listos para usar" -ForegroundColor Green
        Write-Host ""
        return $true
    }
    catch {
        Write-Host ""
        Write-Host "✗ Error durante la instalación:" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Posibles causas:" -ForegroundColor Yellow
        Write-Host "  • Falta de conexión a Internet" -ForegroundColor Gray
        Write-Host "  • Problemas con PowerShell Gallery" -ForegroundColor Gray
        Write-Host "  • Permisos insuficientes" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Intente instalar manualmente:" -ForegroundColor Yellow
        Write-Host "  Install-Module Microsoft.Graph -Scope CurrentUser" -ForegroundColor White
        Write-Host ""
        return $false
    }
}

function Test-IsOneDrivePath {
    param([string]$Path)
    return $Path -match '^onedrive://|^ONEDRIVE:'
}

function Ensure-GraphConnected {
    <#
    .SYNOPSIS
        Asegura conexión autenticada con Microsoft Graph
    .DESCRIPTION
        Verifica si hay sesión activa de Microsoft Graph, si no la hay, inicia login con MFA
    #>
    try {
        $ctx = Get-MgContext -ErrorAction Stop
        if ($ctx.Account) {
            Write-Host "[+] Ya estás autenticado como $($ctx.Account)" -ForegroundColor Green
            return $true
        }
    }
    catch {}

    Write-Host "[*] No hay sesión activa. Iniciando login con MFA..." -ForegroundColor Yellow
    
    try {
        Connect-MgGraph -Scopes "Files.ReadWrite.All" | Out-Null
        Write-Host "[+] Autenticación correcta." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[X] Error al autenticar: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Upload-OneDriveFile {
    <#
    .SYNOPSIS
        Sube archivo a OneDrive
    .PARAMETER LocalPath
        Ruta local del archivo a subir
    .PARAMETER RemotePath
        Ruta relativa en OneDrive donde se subirá el archivo
    #>
    param(
        [string]$LocalPath,
        [string]$RemotePath
    )

    if (-not (Test-Path $LocalPath)) {
        throw "El archivo local no existe: $LocalPath"
    }

    $bytes = [System.IO.File]::ReadAllBytes($LocalPath)
    $fileName = Split-Path $LocalPath -Leaf
    $remote = "root:/$RemotePath/${fileName}:"

    Write-Host "[*] Subiendo archivo a OneDrive → $remote" -ForegroundColor Cyan

    try {
        # Para archivos grandes, usar sesión de upload
        $fileSize = (Get-Item $LocalPath).Length
        
        if ($fileSize -gt 4MB) {
            # Upload de archivo grande con sesión
            $uploadUrl = "https://graph.microsoft.com/v1.0/me/drive/$remote/createUploadSession"
            $uploadSession = Invoke-MgGraphRequest -Method POST -Uri $uploadUrl
            
            $chunkSize = 320KB * 10  # 3.2MB chunks
            $stream = [System.IO.File]::OpenRead($LocalPath)
            $buffer = New-Object byte[] $chunkSize
            $bytesUploaded = 0
            
            while ($bytesUploaded -lt $fileSize) {
                $bytesRead = $stream.Read($buffer, 0, $chunkSize)
                $rangeStart = $bytesUploaded
                $rangeEnd = $bytesUploaded + $bytesRead - 1
                
                $headers = @{
                    "Content-Length" = $bytesRead
                    "Content-Range"  = "bytes $rangeStart-$rangeEnd/$fileSize"
                }
                
                $dataToSend = $buffer[0..($bytesRead - 1)]
                Invoke-RestMethod -Method PUT -Uri $uploadSession.uploadUrl -Body $dataToSend -Headers $headers | Out-Null
                
                $bytesUploaded += $bytesRead
                $percent = [int](($bytesUploaded * 100) / $fileSize)
                Write-Host "`r  Progreso: $percent%" -NoNewline -ForegroundColor Gray
            }
            
            $stream.Close()
            Write-Host ""
        }
        else {
            # Upload simple para archivos pequeños
            New-MgDriveItemContent -DriveId "me" -DriveItemId $remote -BodyParameter $bytes | Out-Null
        }
        
        Write-Host "[✓] Subida completada." -ForegroundColor Green
    }
    catch {
        Write-Host "[X] Error al subir: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Download-OneDriveFile {
    <#
    .SYNOPSIS
        Descarga archivo desde OneDrive
    .PARAMETER OneDrivePath
        Ruta del archivo en OneDrive (formato: root:/folder/file.txt:)
    .PARAMETER LocalPath
        Ruta local donde se guardará el archivo
    #>
    param(
        [string]$OneDrivePath,
        [string]$LocalPath
    )

    Write-Host "[*] Descargando archivo desde OneDrive..." -ForegroundColor Cyan
    
    try {
        $content = Get-MgDriveItemContent -DriveId "me" -DriveItemId $OneDrivePath
        
        $folder = Split-Path $LocalPath
        if (-not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder | Out-Null
        }

        [System.IO.File]::WriteAllBytes($LocalPath, $content)
        Write-Host "[✓] Descarga completada → $LocalPath" -ForegroundColor Green
    }
    catch {
        Write-Host "[X] Error al descargar: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Upload-OneDriveFolder {
    <#
    .SYNOPSIS
        Sube todos los archivos de una carpeta a OneDrive
    .PARAMETER LocalFolder
        Ruta local de la carpeta
    .PARAMETER RemotePath
        Ruta relativa en OneDrive
    #>
    param(
        [string]$LocalFolder,
        [string]$RemotePath
    )
    
    if (-not (Test-Path $LocalFolder)) {
        throw "La carpeta local no existe: $LocalFolder"
    }
    
    Write-Host "[*] Subiendo carpeta a OneDrive: $LocalFolder → $RemotePath" -ForegroundColor Cyan
    
    $files = Get-ChildItem -Path $LocalFolder -File -Recurse
    $total = $files.Count
    $current = 0
    
    foreach ($file in $files) {
        $current++
        $relativePath = $file.FullName.Substring($LocalFolder.Length).TrimStart('\\', '/')
        $targetPath = "$RemotePath/$relativePath".Replace('\\', '/')
        $targetFolder = Split-Path $targetPath -Parent
        
        Write-Host "[$current/$total] Subiendo: $relativePath" -ForegroundColor Gray
        
        try {
            Upload-OneDriveFile -LocalPath $file.FullName -RemotePath $targetFolder
        }
        catch {
            Write-Host "  [X] Error al subir $relativePath" -ForegroundColor Red
        }
    }
    
    Write-Host "[✓] Carpeta subida completamente" -ForegroundColor Green
}

function Download-OneDriveFolder {
    <#
    .SYNOPSIS
        Descarga todos los archivos de una carpeta de OneDrive
    .PARAMETER OneDrivePath
        Ruta en OneDrive (formato: root:/folder:)
    .PARAMETER LocalFolder
        Ruta local donde se guardará
    #>
    param(
        [string]$OneDrivePath,
        [string]$LocalFolder
    )
    
    Write-Host "[*] Descargando carpeta desde OneDrive: $OneDrivePath → $LocalFolder" -ForegroundColor Cyan
    
    try {
        # Listar archivos en OneDrive
        $items = Get-MgDriveItem -DriveId "me" -DriveItemId $OneDrivePath -ExpandProperty "children"
        
        if (-not (Test-Path $LocalFolder)) {
            New-Item -ItemType Directory -Path $LocalFolder | Out-Null
        }
        
        foreach ($item in $items.Children) {
            $localPath = Join-Path $LocalFolder $item.Name
            
            if ($item.Folder) {
                # Es una carpeta, recursión
                $subPath = "$OneDrivePath/$($item.Name)"
                Download-OneDriveFolder -OneDrivePath $subPath -LocalFolder $localPath
            }
            else {
                # Es un archivo
                Write-Host "  Descargando: $($item.Name)" -ForegroundColor Gray
                $itemPath = "root:/$($item.ParentReference.Path)/$($item.Name):"
                Download-OneDriveFile -OneDrivePath $itemPath -LocalPath $localPath
            }
        }
        
        Write-Host "[✓] Carpeta descargada completamente" -ForegroundColor Green
    }
    catch {
        Write-Host "[X] Error al descargar carpeta: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# ========================================================================== #
#                              SOPORTE DROPBOX                               #
# ========================================================================== #

function Test-IsDropboxPath {
    param([string]$Path)
    return $Path -match '^dropbox://|^DROPBOX:'
}

function Get-DropboxToken {
    <#
    .SYNOPSIS
        Obtiene token de acceso de Dropbox mediante OAuth2
    .DESCRIPTION
        Abre navegador para autenticación con MFA, inicia listener local
        y captura el token de acceso
    #>
    
    $appKey = "qf3ohh840jfse3j"  # App Key pública
    $redirectUri = "http://localhost:53682/"
    $state = [Guid]::NewGuid().ToString()

    $authUrl = "https://www.dropbox.com/oauth2/authorize?response_type=token&client_id=$appKey&redirect_uri=$redirectUri&state=$state"

    Write-Host "[*] Abriendo ventana para iniciar sesión en Dropbox..." -ForegroundColor Cyan
    Write-Host "    Por favor, autoriza la aplicación en el navegador" -ForegroundColor Gray
    Write-Host ""

    Start-Process $authUrl

    try {
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add($redirectUri)
        $listener.Start()

        Write-Host "[*] Esperando que completes el inicio de sesión y MFA..." -ForegroundColor Yellow

        $context = $listener.GetContext()
        $response = $context.Response

        $html = "<html><body><h1 style='color:green;font-family:Arial'>¡Listo! Ya podés cerrar esta ventana.</h1><p>Volvé a la consola para continuar.</p></body></html>"
        $buffer = [Text.Encoding]::UTF8.GetBytes($html)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.OutputStream.Close()
        $listener.Stop()

        $raw = $context.Request.RawUrl

        if ($raw -match "access_token=([^&]+)") {
            Write-Host "[+] Token obtenido correctamente" -ForegroundColor Green
            return $matches[1]
        }

        throw "No se pudo obtener token Dropbox"
    }
    catch {
        Write-Host "[X] Error al obtener token: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Ensure-DropboxConnected {
    <#
    .SYNOPSIS
        Asegura que hay un token válido de Dropbox
    .DESCRIPTION
        Verifica si hay token guardado en variable global, si no, solicita autenticación
    #>
    
    if ($Global:DropboxToken) {
        Write-Host "[+] Ya hay un token de Dropbox activo" -ForegroundColor Green
        return $true
    }

    Write-Host "[*] No hay sesión activa. Iniciando login con Dropbox..." -ForegroundColor Yellow
    Write-Host ""
    
    try {
        $Global:DropboxToken = Get-DropboxToken
        return $true
    }
    catch {
        Write-Host "[X] Error al autenticar: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Upload-DropboxFile {
    <#
    .SYNOPSIS
        Sube archivo a Dropbox
    .PARAMETER LocalPath
        Ruta local del archivo a subir
    .PARAMETER RemotePath
        Ruta en Dropbox donde se subirá el archivo (debe empezar con /)
    .PARAMETER Token
        Token de acceso de Dropbox
    #>
    param(
        [string]$LocalPath,
        [string]$RemotePath,
        [string]$Token
    )

    if (-not (Test-Path $LocalPath)) {
        throw "El archivo local no existe: $LocalPath"
    }

    # Asegurar que la ruta remota empiece con /
    if (-not $RemotePath.StartsWith('/')) {
        $RemotePath = "/$RemotePath"
    }

    Write-Host "[*] Subiendo archivo a Dropbox → $RemotePath" -ForegroundColor Cyan

    try {
        $fileSize = (Get-Item $LocalPath).Length
        
        # Para archivos grandes (>150MB), usar sesión de upload
        if ($fileSize -gt 150MB) {
            Write-Host "    Archivo grande detectado, usando upload por sesiones..." -ForegroundColor Gray
            Upload-DropboxFileLarge -LocalPath $LocalPath -RemotePath $RemotePath -Token $Token
        }
        else {
            # Upload simple para archivos pequeños
            $bytes = [System.IO.File]::ReadAllBytes($LocalPath)

            $headers = @{
                "Authorization"   = "Bearer $Token"
                "Dropbox-API-Arg" = '{"path":"' + $RemotePath + '","mode":"overwrite"}'
                "Content-Type"    = "application/octet-stream"
            }

            Invoke-RestMethod `
                -Uri "https://content.dropboxapi.com/2/files/upload" `
                -Method Post `
                -Headers $headers `
                -Body $bytes | Out-Null
        }
        
        Write-Host "[✓] Subida completada." -ForegroundColor Green
    }
    catch {
        Write-Host "[X] Error al subir: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Upload-DropboxFileLarge {
    <#
    .SYNOPSIS
        Sube archivo grande a Dropbox usando sesiones
    #>
    param(
        [string]$LocalPath,
        [string]$RemotePath,
        [string]$Token
    )

    $chunkSize = 8MB
    $stream = [System.IO.File]::OpenRead($LocalPath)
    $fileSize = $stream.Length
    $uploaded = 0
    $sessionId = $null

    try {
        # Iniciar sesión
        $buffer = New-Object byte[] $chunkSize
        $bytesRead = $stream.Read($buffer, 0, $chunkSize)
        $uploaded += $bytesRead

        $headers = @{
            "Authorization" = "Bearer $Token"
            "Content-Type"  = "application/octet-stream"
        }

        $response = Invoke-RestMethod `
            -Uri "https://content.dropboxapi.com/2/files/upload_session/start" `
            -Method Post `
            -Headers $headers `
            -Body $buffer[0..($bytesRead - 1)]

        $sessionId = $response.session_id
        Write-Host "    Sesión iniciada: $($uploaded / 1MB)MB / $($fileSize / 1MB)MB" -ForegroundColor Gray

        # Subir chunks
        while ($uploaded -lt $fileSize) {
            $bytesRead = $stream.Read($buffer, 0, $chunkSize)
            if ($bytesRead -eq 0) { break }

            $cursor = @{
                session_id = $sessionId
                offset     = $uploaded
            } | ConvertTo-Json -Compress

            $headers["Dropbox-API-Arg"] = $cursor

            Invoke-RestMethod `
                -Uri "https://content.dropboxapi.com/2/files/upload_session/append_v2" `
                -Method Post `
                -Headers $headers `
                -Body $buffer[0..($bytesRead - 1)] | Out-Null

            $uploaded += $bytesRead
            $percent = [int](($uploaded * 100) / $fileSize)
            Write-Host "`r    Progreso: $percent% ($($uploaded / 1MB)MB / $($fileSize / 1MB)MB)" -NoNewline -ForegroundColor Gray
        }

        Write-Host ""

        # Finalizar sesión
        $finishArg = @{
            cursor = @{
                session_id = $sessionId
                offset     = $uploaded
            }
            commit = @{
                path = $RemotePath
                mode = "overwrite"
            }
        } | ConvertTo-Json -Compress

        $headers["Dropbox-API-Arg"] = $finishArg
        $headers.Remove("Content-Type")
        $headers["Content-Type"] = "application/octet-stream"

        Invoke-RestMethod `
            -Uri "https://content.dropboxapi.com/2/files/upload_session/finish" `
            -Method Post `
            -Headers $headers `
            -Body @() | Out-Null
    }
    finally {
        $stream.Close()
    }
}

function Download-DropboxFile {
    <#
    .SYNOPSIS
        Descarga archivo desde Dropbox
    .PARAMETER RemotePath
        Ruta del archivo en Dropbox
    .PARAMETER LocalPath
        Ruta local donde se guardará el archivo
    .PARAMETER Token
        Token de acceso de Dropbox
    #>
    param(
        [string]$RemotePath,
        [string]$LocalPath,
        [string]$Token
    )

    # Asegurar que la ruta remota empiece con /
    if (-not $RemotePath.StartsWith('/')) {
        $RemotePath = "/$RemotePath"
    }

    Write-Host "[*] Descargando archivo desde Dropbox..." -ForegroundColor Cyan
    
    try {
        $headers = @{
            "Authorization"   = "Bearer $Token"
            "Dropbox-API-Arg" = '{"path":"' + $RemotePath + '"}'
        }

        $response = Invoke-WebRequest `
            -Uri "https://content.dropboxapi.com/2/files/download" `
            -Method Post `
            -Headers $headers
        
        $folder = Split-Path $LocalPath
        if (-not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder | Out-Null
        }

        [System.IO.File]::WriteAllBytes($LocalPath, $response.Content)
        Write-Host "[✓] Descarga completada → $LocalPath" -ForegroundColor Green
    }
    catch {
        Write-Host "[X] Error al descargar: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Upload-DropboxFolder {
    <#
    .SYNOPSIS
        Sube todos los archivos de una carpeta a Dropbox
    .PARAMETER LocalFolder
        Ruta local de la carpeta
    .PARAMETER RemotePath
        Ruta en Dropbox
    .PARAMETER Token
        Token de acceso de Dropbox
    #>
    param(
        [string]$LocalFolder,
        [string]$RemotePath,
        [string]$Token
    )
    
    if (-not (Test-Path $LocalFolder)) {
        throw "La carpeta local no existe: $LocalFolder"
    }
    
    # Asegurar que la ruta remota empiece con /
    if (-not $RemotePath.StartsWith('/')) {
        $RemotePath = "/$RemotePath"
    }
    
    Write-Host "[*] Subiendo carpeta a Dropbox: $LocalFolder → $RemotePath" -ForegroundColor Cyan
    
    $files = Get-ChildItem -Path $LocalFolder -File -Recurse
    $total = $files.Count
    $current = 0
    
    foreach ($file in $files) {
        $current++
        $relativePath = $file.FullName.Substring($LocalFolder.Length).TrimStart('\\', '/').Replace('\\', '/')
        $targetPath = "$RemotePath/$relativePath".Replace('//', '/')
        
        Write-Host "[$current/$total] Subiendo: $relativePath" -ForegroundColor Gray
        
        try {
            Upload-DropboxFile -LocalPath $file.FullName -RemotePath $targetPath -Token $Token
        }
        catch {
            Write-Host "  [X] Error al subir $relativePath" -ForegroundColor Red
        }
    }
    
    Write-Host "[✓] Carpeta subida completamente" -ForegroundColor Green
}

function Download-DropboxFolder {
    <#
    .SYNOPSIS
        Descarga todos los archivos de una carpeta de Dropbox
    .PARAMETER RemotePath
        Ruta en Dropbox
    .PARAMETER LocalFolder
        Ruta local donde se guardará
    .PARAMETER Token
        Token de acceso de Dropbox
    #>
    param(
        [string]$RemotePath,
        [string]$LocalFolder,
        [string]$Token
    )
    
    # Asegurar que la ruta remota empiece con /
    if (-not $RemotePath.StartsWith('/')) {
        $RemotePath = "/$RemotePath"
    }
    
    Write-Host "[*] Descargando carpeta desde Dropbox: $RemotePath → $LocalFolder" -ForegroundColor Cyan
    
    try {
        # Listar archivos en Dropbox
        $headers = @{
            "Authorization" = "Bearer $Token"
            "Content-Type"  = "application/json"
        }

        $body = @{
            path      = $RemotePath
            recursive = $true
        } | ConvertTo-Json

        $response = Invoke-RestMethod `
            -Uri "https://api.dropboxapi.com/2/files/list_folder" `
            -Method Post `
            -Headers $headers `
            -Body $body
        
        if (-not (Test-Path $LocalFolder)) {
            New-Item -ItemType Directory -Path $LocalFolder | Out-Null
        }
        
        foreach ($entry in $response.entries) {
            if ($entry.".tag" -eq "file") {
                $relativePath = $entry.path_display.Substring($RemotePath.Length).TrimStart('/')
                $localPath = Join-Path $LocalFolder $relativePath.Replace('/', '\\')
                
                Write-Host "  Descargando: $($entry.name)" -ForegroundColor Gray
                Download-DropboxFile -RemotePath $entry.path_display -LocalPath $localPath -Token $Token
            }
        }
        
        Write-Host "[✓] Carpeta descargada completamente" -ForegroundColor Green
    }
    catch {
        Write-Host "[X] Error al descargar carpeta: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Connect-FtpServer {
    <#
    .SYNOPSIS
        Configura y valida conexión a servidor FTP
    
    .DESCRIPTION
        Solicita configuración de FTP (puerto, autenticación, credenciales) y valida la conexión.
        Retorna objeto con la configuración para uso posterior.
    
    .PARAMETER FtpUrl
        URL del servidor FTP (puede incluir puerto)
    
    .PARAMETER Tipo
        Tipo de conexión: "Origen" o "Destino"
    
    .EXAMPLE
        $ftpConfig = Connect-FtpServer -FtpUrl "ftp://servidor.com" -Tipo "Origen"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FtpUrl,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Tipo
    )
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  CONFIGURACIÓN FTP - $Tipo" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Extraer servidor de la URL
    if ($FtpUrl -match '^(ftps?://)([^/:]+)(:(\d+))?(/.*)?$') {
        $protocol = $Matches[1]
        $server = $Matches[2]
        $portFromUrl = $Matches[4]
        $path = if ($Matches[5]) { $Matches[5] } else { "/" }
    }
    else {
        throw "URL FTP inválida: $FtpUrl"
    }
    
    Write-Host "Servidor: " -NoNewline
    Write-Host $server -ForegroundColor White
    Write-Host "Protocolo: " -NoNewline
    Write-Host $protocol.TrimEnd('://').ToUpper() -ForegroundColor White
    Write-Host ""
    
    # Solicitar puerto
    if ($portFromUrl) {
        $puerto = [int]$portFromUrl
        Write-Host "Puerto detectado en URL: $puerto" -ForegroundColor Green
    }
    else {
        Write-Host "Ingrese puerto FTP [21]: " -NoNewline -ForegroundColor Cyan
        $puertoInput = Read-Host
        $puerto = if ([string]::IsNullOrWhiteSpace($puertoInput)) { 21 } else { [int]$puertoInput }
    }
    
    Write-Host "Puerto configurado: " -NoNewline
    Write-Host $puerto -ForegroundColor White
    Write-Host ""
    
    # Solicitar tipo de autenticación
    Write-Host "Tipo de autenticación:" -ForegroundColor Cyan
    Write-Host "  1. Anónima (sin credenciales)" -ForegroundColor Gray
    Write-Host "  2. Usuario y Contraseña (Básica)" -ForegroundColor Gray
    Write-Host "  3. Usuario y Contraseña con SSL/TLS (FTPS)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Seleccione opción [2]: " -NoNewline -ForegroundColor Cyan
    $authOption = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($authOption)) {
        $authOption = "2"
    }
    
    $useSsl = $false
    $credential = $null
    $authType = ""
    
    switch ($authOption) {
        "1" {
            $authType = "Anónima"
            Write-Host "Usando autenticación anónima" -ForegroundColor Yellow
            # Crear credencial anónima
            $securePass = ConvertTo-SecureString "anonymous@" -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential("anonymous", $securePass)
        }
        "2" {
            $authType = "Básica"
            Write-Host "Autenticación con usuario y contraseña (sin SSL)" -ForegroundColor Yellow
            $credential = Get-Credential -Message "Credenciales para FTP: $server"
            if (-not $credential) {
                throw "Se requieren credenciales para conectar al servidor FTP"
            }
        }
        "3" {
            $authType = "SSL/TLS"
            $useSsl = $true
            Write-Host "Autenticación con usuario y contraseña (SSL/TLS habilitado)" -ForegroundColor Yellow
            $credential = Get-Credential -Message "Credenciales FTPS para: $server"
            if (-not $credential) {
                throw "Se requieren credenciales para conectar al servidor FTPS"
            }
            # Cambiar protocolo a FTPS si no lo es
            if ($protocol -notmatch '^ftps://') {
                $protocol = "ftps://"
            }
        }
        default {
            $authType = "Básica"
            Write-Host "Opción inválida, usando autenticación básica por defecto" -ForegroundColor Yellow
            $credential = Get-Credential -Message "Credenciales para FTP: $server"
            if (-not $credential) {
                throw "Se requieren credenciales para conectar al servidor FTP"
            }
        }
    }
    
    Write-Host ""
    Write-Host "Validando conexión a $server`:$puerto..." -ForegroundColor Cyan
    
    # Construir URL completa
    $fullUrl = "${protocol}${server}:${puerto}${path}"
    
    # Intentar conexión de prueba
    try {
        $testRequest = [System.Net.FtpWebRequest]::Create($fullUrl)
        $testRequest.Credentials = New-Object System.Net.NetworkCredential(
            $credential.UserName,
            $credential.GetNetworkCredential().Password
        )
        $testRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
        $testRequest.UseBinary = $true
        $testRequest.KeepAlive = $false
        $testRequest.EnableSsl = $useSsl
        $testRequest.Timeout = 10000  # 10 segundos
        
        # Ignorar errores de certificado SSL si es necesario
        if ($useSsl) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        }
        
        $response = $testRequest.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $listing = $reader.ReadToEnd()
        $reader.Close()
        $stream.Close()
        $response.Close()
        
        Write-Host "✓ Conexión exitosa a $server`:$puerto" -ForegroundColor Green
        Write-Host "✓ Autenticación verificada ($authType)" -ForegroundColor Green
        
        # Mostrar algunos archivos si los hay
        if ($listing) {
            $files = $listing.Split("`n") | Where-Object { $_.Trim() -ne "" } | Select-Object -First 5
            if ($files.Count -gt 0) {
                Write-Host "✓ Directorio accesible (archivos encontrados: $($files.Count))" -ForegroundColor Green
            }
        }
        
        Write-Host ""
        
        # Retornar configuración
        return [PSCustomObject]@{
            Url        = $fullUrl
            Server     = $server
            Port       = $puerto
            Protocol   = $protocol.TrimEnd('://')
            Path       = $path
            Credential = $credential
            UseSsl     = $useSsl
            AuthType   = $authType
            Validated  = $true
        }
    }
    catch {
        Write-Host "✗ Error al conectar a $server`:$puerto" -ForegroundColor Red
        Write-Host "  Mensaje: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        
        Write-Host "Posibles causas:" -ForegroundColor Yellow
        Write-Host "  • Puerto incorrecto (verifique que sea $puerto)" -ForegroundColor Gray
        Write-Host "  • Credenciales inválidas" -ForegroundColor Gray
        Write-Host "  • Servidor no accesible o firewall bloqueando" -ForegroundColor Gray
        Write-Host "  • SSL/TLS requerido pero no configurado" -ForegroundColor Gray
        Write-Host ""
        
        throw "No se pudo validar la conexión FTP al $Tipo"
    }
}

function Mount-FtpPath {
    param(
        [string]$Path,
        [pscredential]$Credential,
        [string]$DriveName
    )
    
    # Extraer componentes de la URL FTP
    if ($Path -match '^(ftps?://)(.*?)(/.*)?$') {
        $protocol = $Matches[1]
        $server = $Matches[2]
        $remotePath = if ($Matches[3]) { $Matches[3] } else { '/' }
    }
    else {
        throw "Formato de URL FTP inválido: $Path"
    }
    
    # Solicitar credenciales si no se proporcionaron
    if (-not $Credential) {
        Write-Host "Se requieren credenciales para: $protocol$server" -ForegroundColor Yellow
        $Credential = Get-Credential -Message "Credenciales FTP para $server"
        if (-not $Credential) {
            throw "Se requieren credenciales para acceder a $Path"
        }
    }
    
    # Crear unidad de red con WebClient
    try {
        if (Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue) {
            Remove-PSDrive -Name $DriveName -ErrorAction SilentlyContinue
        }
        
        # Usar New-PSDrive con proveedor FileSystem para FTP
        # Nota: PowerShell no soporta FTP nativamente con PSDrive, usaremos WebClient
        $ftpInfo = @{
            Url      = "$protocol$server$remotePath"
            Username = $Credential.UserName
            Password = $Credential.GetNetworkCredential().Password
            Protocol = $protocol
        }
        
        # Guardar la información FTP globalmente para uso posterior
        $Global:FtpConnections = @{} -as [hashtable]
        if (-not $Global:FtpConnections) {
            $Global:FtpConnections = @{}
        }
        $Global:FtpConnections[$DriveName] = $ftpInfo
        
        Write-Host "✓ Conexión FTP establecida: $protocol$server" -ForegroundColor Green
        return "FTP:$DriveName"
    }
    catch {
        throw "Error al conectar con FTP: $($_.Exception.Message)"
    }
}

function Get-FtpConnection {
    param([string]$DriveName)
    
    if ($Global:FtpConnections -and $Global:FtpConnections.ContainsKey($DriveName)) {
        return $Global:FtpConnections[$DriveName]
    }
    return $null
}

function Send-FtpFile {
    param(
        [string]$LocalPath,
        [string]$DriveName,
        [string]$RemoteFileName
    )
    
    $ftpInfo = Get-FtpConnection -DriveName $DriveName
    if (-not $ftpInfo) {
        throw "Conexión FTP no encontrada: $DriveName"
    }
    
    $remoteUrl = "$($ftpInfo.Url.TrimEnd('/'))/$RemoteFileName"
    
    try {
        $webclient = New-Object System.Net.WebClient
        $webclient.Credentials = New-Object System.Net.NetworkCredential($ftpInfo.Username, $ftpInfo.Password)
        
        Write-Host "Subiendo $RemoteFileName a FTP..." -ForegroundColor Cyan
        $webclient.UploadFile($remoteUrl, $LocalPath)
        $webclient.Dispose()
        
        Write-Host "✓ Archivo subido: $RemoteFileName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error al subir archivo FTP: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Receive-FtpFile {
    param(
        [string]$RemoteFileName,
        [string]$DriveName,
        [string]$LocalPath
    )
    
    $ftpInfo = Get-FtpConnection -DriveName $DriveName
    if (-not $ftpInfo) {
        throw "Conexión FTP no encontrada: $DriveName"
    }
    
    $remoteUrl = "$($ftpInfo.Url.TrimEnd('/'))/$RemoteFileName"
    
    try {
        $webclient = New-Object System.Net.WebClient
        $webclient.Credentials = New-Object System.Net.NetworkCredential($ftpInfo.Username, $ftpInfo.Password)
        
        Write-Host "Descargando $RemoteFileName desde FTP..." -ForegroundColor Cyan
        $webclient.DownloadFile($remoteUrl, $LocalPath)
        $webclient.Dispose()
        
        Write-Host "✓ Archivo descargado: $RemoteFileName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error al descargar archivo FTP: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Mount-LlevarNetworkPath {
    param(
        [string]$Path,
        [pscredential]$Credential,
        [string]$DriveName
    )

    # Verificar si es FTP
    if (Test-IsFtpPath -Path $Path) {
        return Mount-FtpPath -Path $Path -Credential $Credential -DriveName $DriveName
    }

    # Continuar con lógica UNC existente
    if (-not $Path -or $Path -notlike "\\\\*") {
        return $Path
    }

    $parts = Split-UncRootAndPath -Path $Path
    $root = $parts[0]
    $rest = $parts[1]

    if (-not $root) { return $Path }

    while ($true) {
        if (Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue) {
            Remove-PSDrive -Name $DriveName -ErrorAction SilentlyContinue
        }

        try {
            if ($Credential) {
                New-PSDrive -Name $DriveName -PSProvider FileSystem -Root $root -Credential $cred -ErrorAction Stop | Out-Null
            }
            else {
                # Intento sin credenciales explÌcitas
                New-PSDrive -Name $DriveName -PSProvider FileSystem -Root $root -ErrorAction Stop | Out-Null
            }
        }
        catch {
            # Solo si no se pasaron credenciales como parametro interactuamos
            if (-not $Credential) {
                $choice = Show-DosMenu -Title "Error de red" -Items @("*Reintentar", "*Cancelar") -CancelValue 1 -DefaultValue 1
                if ($choice -eq 1) {
                    # Reintentar: pedir credenciales
                    $cred = Get-Credential -Message "Credenciales para $root"
                    continue
                }
                else {
                    throw "No se pudo acceder a $root."
                }
            }
            else {
                throw
            }
        }

        break
    }

    $driveRoot = ($DriveName + ":\")
    if ($rest) {
        $sub = $rest.TrimStart('\')
        return (Join-Path $driveRoot $sub)
    }
    else {
        return $driveRoot
    }
}

# Version extendida que reemplaza a la original
# ========================================================================== #
#                         CREAR IMAGEN ISO (IMAPI2)                          #
# ========================================================================== #

function New-LlevarIsoImage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFolder,
        [Parameter(Mandatory = $true)]
        [string]$IsoPath,
        [string]$VolumeLabel = "LLEVAR"
    )

    if (-not (Test-Path $SourceFolder)) {
        throw "Carpeta de origen para ISO no encontrada: $SourceFolder"
    }

    try {
        $image = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
    }
    catch {
        Write-Host "No se pudo crear el objeto COM IMAPI2FS. No es posible generar la ISO automaticamente." -ForegroundColor Red
        return $null
    }

    if ($VolumeLabel.Length -gt 32) {
        $VolumeLabel = $VolumeLabel.Substring(0, 32)
    }

    $image.VolumeName = $VolumeLabel

    $root = $image.Root
    $root.AddTree($SourceFolder, $false) | Out-Null

    $result = $image.CreateResultImage()
    $stream = $result.ImageStream

    $out = [System.IO.File]::Open($IsoPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try {
        $startTime = Get-Date
        $barTop = [console]::CursorTop
        $totalBytes = 0L
        try {
            if ($result.Blocks -and $result.BlockSize) {
                $totalBytes = [int64]$result.Blocks * [int64]$result.BlockSize
            }
        }
        catch {
            $totalBytes = 0L
        }
        Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Creando ISO..." -Top $barTop

        $bufferSize = 2048 * 32
        $buffer = New-Object byte[] $bufferSize
        $written = 0L

        while ($true) {
            $read = $stream.Read($buffer, 0, $bufferSize)
            if ($read -le 0) { break }
            $out.Write($buffer, 0, $read)
            $written += $read

            if ($totalBytes -gt 0) {
                $pct = [double](($written * 100.0) / $totalBytes)
                Write-LlevarProgressBar -Percent $pct -StartTime $startTime -Label "Creando ISO..." -Top $barTop
            }
            else {
                Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Creando ISO..." -Top $barTop
            }
        }

        Write-LlevarProgressBar -Percent 100 -StartTime $startTime -Label "Creando ISO..." -Top $barTop
    }
    finally {
        $out.Close()
    }

    return $IsoPath
}

function New-LlevarIsoMain {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Origen,
        [Parameter(Mandatory = $true)]
        [string]$Destino,
        [Parameter(Mandatory = $true)]
        [string]$Temp,
        [Parameter(Mandatory = $true)]
        [string]$SevenZ,
        [int]$BlockSizeMB,
        [string]$Clave
    )

    # Determinar capacidad del medio
    $mediaCapacity = switch ($IsoDestino) {
        'cd' { 700MB }
        'dvd' { 4500MB }  # 4.5 GB para DVD
        'usb' { 4500MB }  # Por defecto similar a DVD
        default { 4500MB }
    }

    # Comprimir archivos
    $compressionResult = Compress-Folder $Origen $Temp $SevenZ $Clave $BlockSizeMB
    $blocks = $compressionResult.Files
    $compressionType = $compressionResult.CompressionType

    $installerScript = New-InstallerScript -Destino $Destino -Temp $Temp -CompressionType $compressionType

    # Calcular tamaño total de bloques más archivos auxiliares
    $totalBlocksSize = 0L
    foreach ($block in $blocks) {
        $totalBlocksSize += (Get-Item $block).Length
    }

    # Tamaño estimado de archivos auxiliares
    $auxSize = 0L
    if ($installerScript -and (Test-Path $installerScript)) {
        $auxSize += (Get-Item $installerScript).Length
    }
    if ($SevenZ -and $SevenZ -ne "NATIVE_ZIP" -and (Test-Path $SevenZ)) {
        $auxSize += (Get-Item $SevenZ).Length
    }
    $auxSize += 1KB  # __EOF__ marker

    $totalSize = $totalBlocksSize + $auxSize

    $baseName = Split-Path $Origen -Leaf
    if (-not $baseName) { $baseName = "LLEVAR" }

    $label = $baseName
    if ($label.Length -gt 32) { $label = $label.Substring(0, 32) }

    $mediaTag = switch ($IsoDestino) {
        'cd' { 'CD' }
        'dvd' { 'DVD' }
        'usb' { 'USB' }
        default { 'ISO' }
    }

    # Si todo cabe en un solo ISO, usar lógica original
    if ($totalSize -le $mediaCapacity) {
        Write-Host "`nGenerando imagen ISO única..." -ForegroundColor Cyan
        
        $isoRoot = Join-Path $Temp "LLEVAR_ISO_ROOT"
        if (Test-Path $isoRoot) {
            Remove-Item $isoRoot -Recurse -Force
        }
        New-Item -ItemType Directory -Path $isoRoot | Out-Null

        foreach ($block in $blocks) {
            Copy-Item $block $isoRoot -Force
        }

        if ($installerScript) {
            Copy-Item $installerScript $isoRoot -Force
        }
        if ($SevenZ -and $SevenZ -ne "NATIVE_ZIP" -and (Test-Path $SevenZ)) {
            Copy-Item $SevenZ $isoRoot -Force
        }

        New-Item -ItemType File -Path (Join-Path $isoRoot "__EOF__") | Out-Null

        $isoName = "{0}_{1}.iso" -f $label, $mediaTag
        $isoPath = Join-Path $PSScriptRoot $isoName

        $isoResult = New-LlevarIsoImage -SourceFolder $isoRoot -IsoPath $isoPath -VolumeLabel $label

        if ($isoResult) {
            Write-Host "Imagen ISO creada en: $isoResult" -ForegroundColor Green
        }
        else {
            Write-Host "No se pudo crear la imagen ISO. Los archivos estan en: $isoRoot" -ForegroundColor Red
        }
    }
    else {
        # Dividir en múltiples volúmenes ISO
        Write-Host "`nEl contenido supera la capacidad de un $mediaTag (~$([math]::Round($mediaCapacity/1MB, 0)) MB)." -ForegroundColor Yellow
        Write-Host "Se generarán múltiples volúmenes ISO..." -ForegroundColor Cyan

        $volumes = @()
        $currentVolume = @()
        $currentSize = 0L
        $volumeNumber = 1

        # Reservar espacio para archivos auxiliares en el primer volumen
        $firstVolumeReserve = $auxSize

        foreach ($block in $blocks) {
            $blockSize = (Get-Item $block).Length
            
            # Verificar si el bloque cabe en el volumen actual
            $requiredSpace = $blockSize
            if ($volumeNumber -eq 1) {
                $requiredSpace += $firstVolumeReserve
            }

            if ($currentSize + $requiredSpace -gt $mediaCapacity -and $currentVolume.Count -gt 0) {
                # Crear nuevo volumen
                $volumes += , @{
                    Number = $volumeNumber
                    Blocks = $currentVolume
                    Size   = $currentSize
                }
                $volumeNumber++
                $currentVolume = @()
                $currentSize = 0L
            }

            # Agregar bloque al volumen actual
            $currentVolume += $block
            $currentSize += $blockSize
        }

        # Agregar último volumen
        if ($currentVolume.Count -gt 0) {
            $volumes += , @{
                Number = $volumeNumber
                Blocks = $currentVolume
                Size   = $currentSize
            }
        }

        Write-Host "`nSe generarán $($volumes.Count) volúmenes ISO" -ForegroundColor Cyan
        Write-Host ""

        $isoFiles = @()

        # Crear cada volumen ISO
        for ($i = 0; $i -lt $volumes.Count; $i++) {
            $vol = $volumes[$i]
            $isFirst = ($i -eq 0)
            $isLast = ($i -eq ($volumes.Count - 1))

            $volumeLabel = "{0}_V{1:D2}" -f $label, $vol.Number
            if ($volumeLabel.Length -gt 32) { $volumeLabel = $volumeLabel.Substring(0, 32) }

            Write-Host "Creando volumen $($vol.Number) de $($volumes.Count)..." -ForegroundColor Cyan

            $isoRoot = Join-Path $Temp "LLEVAR_ISO_VOL_$($vol.Number)"
            if (Test-Path $isoRoot) {
                Remove-Item $isoRoot -Recurse -Force
            }
            New-Item -ItemType Directory -Path $isoRoot | Out-Null

            # Copiar bloques del volumen
            foreach ($block in $vol.Blocks) {
                Copy-Item $block $isoRoot -Force
            }

            # Primer volumen: incluir instalador y 7-Zip
            if ($isFirst) {
                if ($installerScript) {
                    Copy-Item $installerScript $isoRoot -Force
                }
                if ($SevenZ -and $SevenZ -ne "NATIVE_ZIP" -and (Test-Path $SevenZ)) {
                    Copy-Item $SevenZ $isoRoot -Force
                }
            }

            # Último volumen: incluir marcador __EOF__
            if ($isLast) {
                New-Item -ItemType File -Path (Join-Path $isoRoot "__EOF__") | Out-Null
            }

            # Generar nombre del ISO
            $isoName = "{0}_{1}_VOL{2:D2}.iso" -f $label, $mediaTag, $vol.Number
            $isoPath = Join-Path $PSScriptRoot $isoName

            # Crear imagen ISO
            $isoResult = New-LlevarIsoImage -SourceFolder $isoRoot -IsoPath $isoPath -VolumeLabel $volumeLabel

            if ($isoResult) {
                $isoFiles += $isoResult
                $sizeGB = [math]::Round((Get-Item $isoResult).Length / 1GB, 2)
                Write-Host "  ✓ $isoName ($sizeGB GB)" -ForegroundColor Green
            }
            else {
                Write-Host "  ✗ Error creando $isoName" -ForegroundColor Red
                Write-Host "    Los archivos están en: $isoRoot" -ForegroundColor Yellow
            }

            Write-Host ""
        }

        # Resumen final
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host "  ✓ VOLÚMENES ISO GENERADOS" -ForegroundColor Green
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host ""
        Write-Host "Total de volúmenes: $($isoFiles.Count)" -ForegroundColor White
        Write-Host "Ubicación: $PSScriptRoot" -ForegroundColor White
        Write-Host ""
        Write-Host "Archivos generados:" -ForegroundColor Cyan
        foreach ($iso in $isoFiles) {
            Write-Host "  - $(Split-Path $iso -Leaf)" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "NOTA: Grabe cada volumen ISO en un $mediaTag separado en orden." -ForegroundColor Yellow
        Write-Host "      El instalador está en el VOL01." -ForegroundColor Yellow
        Write-Host "      El marcador __EOF__ está en el último volumen." -ForegroundColor Yellow
    }
}
# ========================================================================== #
#                          FLUJO PRINCIPAL (LLEVAR)                          #
# ========================================================================== #

# Mostrar logo ASCII si existe (siempre)
$logoPath = Join-Path $PSScriptRoot "alexsoft.txt"
if (Test-Path $logoPath) {
    # Usar Show-AsciiLogo como renderer unificado para el logo con sonidos estilo DOS
    Show-AsciiLogo -Path $logoPath -DelayMs 30 -ShowProgress $true -Label "Cargando..." -ForegroundColor Gray -PlaySound $true
    # Limpiar pantalla después de cargar el logo
    Clear-Host
    
    # Mostrar mensaje de bienvenida personalizado parpadeante
    Show-WelcomeMessage -BlinkCount 3 -VisibleDelayMs 450 -TextColor Cyan
    
    # Limpiar para mostrar el menú
    Clear-Host
}

# ========================================================================== #
#                        VERIFICACIÓN DE INSTALACIÓN                         #
# ========================================================================== #

# Verificar si NO está ejecutándose desde C:\Llevar (excepto si es -Ejemplo o -Ayuda)
if (-not $Ejemplo -and -not $Ayuda) {
    $isInstalled = Test-LlevarInstallation
    
    if (-not $isInstalled) {
        $wantsInstall = Show-InstallationPrompt
        
        if ($wantsInstall) {
            # Usuario dijo SÍ - proceder con instalación
            # Detectar si está en IDE/Debug
            $isInIDE = Test-IsRunningInIDE
            
            if ($isInIDE) {
                Write-Host "`n[DEBUG/IDE] Omitiendo verificación de permisos de administrador" -ForegroundColor Cyan
                
                # Instalar directamente sin verificar permisos
                $installed = Install-LlevarToSystem
                
                if ($installed) {
                    Write-Host "`nPresione cualquier tecla para continuar con la ejecución normal..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                    Clear-Host
                }
                else {
                    Write-Host "`nNo se pudo completar la instalación." -ForegroundColor Red
                    Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                    exit
                }
            }
            else {
                # Verificar permisos de administrador
                $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                
                if (-not $isAdmin) {
                    Write-Host "`n⚠ Se requieren permisos de administrador para instalar." -ForegroundColor Yellow
                    Write-Host "Relanzando como administrador..." -ForegroundColor Cyan
                
                    $scriptPath = $MyInvocation.MyCommand.Path
                    Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"" -Verb RunAs
                    exit
                }
                else {
                    # Ya es admin, instalar directamente
                    $installed = Install-LlevarToSystem
                
                    if ($installed) {
                        Write-Host "`nPresione cualquier tecla para continuar con la ejecución normal..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                        Clear-Host
                    }
                    else {
                        Write-Host "`nNo se pudo completar la instalación." -ForegroundColor Red
                        Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                        exit
                    }
                }
            }
        }
        # Si wantsInstall es FALSE, simplemente continuar sin hacer nada
        # El script seguirá ejecutándose normalmente desde su ubicación actual
    }
    # Si isInstalled es TRUE, simplemente continuar sin mostrar nada
}

# ========================================================================== #
#                     MENU INTERACTIVO (sin parámetros)                      #
# ========================================================================== #

# Detectar si se ejecutó sin parámetros principales
$noParams = (
    -not $Ayuda -and
    -not $Instalar -and
    -not $RobocopyMirror -and
    -not $Ejemplo -and
    -not $Origen -and
    -not $Destino -and
    -not $Iso
)

if ($noParams) {
    Write-Host ""
    Show-Banner "MODO INTERACTIVO" -BorderColor Cyan -TextColor Cyan
    Write-Host ""
    Write-Host "No se especificaron parámetros. Iniciando menú interactivo..." -ForegroundColor Gray
    Write-Host ""
    
    # Mostrar menú principal
    $config = Show-MainMenu
    
    # Si el usuario canceló (salió del menú), terminar
    if ($null -eq $config -or $config.Action -eq "Exit") {
        Write-Host ""
        Write-Host "Operación cancelada por el usuario." -ForegroundColor Yellow
        Write-Host ""
        exit
    }
    
    # Procesar configuración del menú según la acción seleccionada
    switch ($config.Action) {
        "Execute" {
            # Mapear configuración del menú a variables del script
            
            # Mapear origen según su tipo
            if ($config.Origen.FtpServer) {
                # Es FTP - construir URL y credenciales
                $Origen = $config.Origen.Path
                $script:FtpSourceServer = $config.Origen.FtpServer
                $script:FtpSourcePort = $config.Origen.FtpPort
                $script:FtpSourceUser = $config.Origen.FtpUser
                $script:FtpSourcePassword = $config.Origen.FtpPassword
            }
            elseif ($config.Origen.UncPath) {
                # Es UNC - ruta y credenciales de red
                $Origen = $config.Origen.Path
                if ($config.Origen.UncUser) {
                    $secPassword = ConvertTo-SecureString $config.Origen.UncPassword -AsPlainText -Force
                    $script:UncSourceCredentials = New-Object System.Management.Automation.PSCredential($config.Origen.UncUser, $secPassword)
                }
            }
            else {
                # Es Local, OneDrive, Dropbox o USB
                $Origen = $config.Origen.Path
            }
            
            # Mapear destino según su tipo
            if ($config.Destino.FtpServer) {
                # Es FTP - construir URL y credenciales
                $Destino = $config.Destino.Path
                $script:FtpDestinationServer = $config.Destino.FtpServer
                $script:FtpDestinationPort = $config.Destino.FtpPort
                $script:FtpDestinationUser = $config.Destino.FtpUser
                $script:FtpDestinationPassword = $config.Destino.FtpPassword
            }
            elseif ($config.Destino.UncPath) {
                # Es UNC - ruta y credenciales de red
                $Destino = $config.Destino.Path
                if ($config.Destino.UncUser) {
                    $secPassword = ConvertTo-SecureString $config.Destino.UncPassword -AsPlainText -Force
                    $script:UncDestinationCredentials = New-Object System.Management.Automation.PSCredential($config.Destino.UncUser, $secPassword)
                }
            }
            else {
                # Es Local, OneDrive, Dropbox o USB
                $Destino = $config.Destino.Path
            }
            
            # Mapear configuración general
            $BlockSizeMB = $config.BlockSizeMB
            $Clave = $config.Clave
            $UseNativeZip = $config.UseNativeZip
            $Iso = $config.Iso
            $IsoDestino = $config.IsoDestino
            $RobocopyMirror = $config.RobocopyMirror
            
            Write-Host ""
            Show-Banner "CONFIGURACIÓN COMPLETA - INICIANDO EJECUCIÓN" -BorderColor Green -TextColor Green
            Write-Host ""
            
            # Log verbose de la configuración
            if ($Global:VerboseLogging) {
                Write-Log "=== CONFIGURACIÓN MAPEADA ===" "DEBUG"
                Write-Log "Origen: $Origen (Tipo: $($config.Origen.Tipo))" "DEBUG"
                Write-Log "Destino: $Destino (Tipo: $($config.Destino.Tipo))" "DEBUG"
                if ($config.Origen.FtpServer) {
                    Write-Log "FTP Origen: $($config.Origen.FtpServer):$($config.Origen.FtpPort) Usuario: $($config.Origen.FtpUser)" "DEBUG"
                }
                if ($config.Destino.FtpServer) {
                    Write-Log "FTP Destino: $($config.Destino.FtpServer):$($config.Destino.FtpPort) Usuario: $($config.Destino.FtpUser)" "DEBUG"
                }
            }
        }
        "Example" {
            # Activar modo ejemplo
            $Ejemplo = $true
        }
        "Help" {
            # Mostrar ayuda
            Clear-Host
            Show-Help
            exit
        }
    }
}

# Si es ayuda, mostrarla
if ($Ayuda) {
    Clear-Host
    Show-Help
    exit
}

# Modo Robocopy Mirror
if ($RobocopyMirror) {
    # Solicitar origen y destino usando la función centralizada
    $Origen = Get-PathOrPrompt $Origen "ORIGEN"
    $Destino = Get-PathOrPrompt $Destino "DESTINO"
    
    # Ejecutar copia espejo
    Invoke-RobocopyMirror -Origen $Origen -Destino $Destino
    
    Write-Host ""
    Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Modo Ejemplo
if ($Ejemplo) {
    try {
        $ejemploConfig = Invoke-ExampleMode
        
        $Origen = $ejemploConfig.Origen
        $Destino = $ejemploConfig.Destino
        $directoriosLimpiar = $ejemploConfig.DirectoriosLimpiar
        
        # Validar si se forzó ZIP nativo
        if ($UseNativeZip) {
            if (-not (Test-Windows10OrLater)) {
                Write-Host ""
                Write-Host "ERROR: La compresión ZIP nativa requiere Windows 10 o superior." -ForegroundColor Red
                Write-Host ""
                return
            }
            $SevenZ = "NATIVE_ZIP"
        }
        else {
            $SevenZ = Get-7z-Llevar
        }
        
        $Temp = Join-Path $env:TEMP "LLEVAR_TEMP_EJEMPLO"
        if (-not (Test-Path $Temp)) { New-Item -Type Directory $Temp | Out-Null }
        
        # Validar destino escribible
        if (-not (Test-PathWritable -Path $Destino)) {
            Write-Host "Destino no es escribible. Cancelando." -ForegroundColor Red
            Remove-ExampleData -Directories $directoriosLimpiar -TempDir $Temp
            return
        }
        
        # Ejecutar compresión
        $compressionResult = Compress-Folder $Origen $Temp $SevenZ $Clave $BlockSizeMB
        $blocks = $compressionResult.Files
        $compressionType = $compressionResult.CompressionType
        
        Write-Host ""
        Show-Banner -Message "BLOQUES GENERADOS" -BorderColor Cyan -TextColor Cyan
        Write-Host ""
        Write-Host "Total de bloques: $($blocks.Count)" -ForegroundColor White
        Write-Host "Tipo de compresión: $compressionType" -ForegroundColor White
        Write-Host ""
        
        $totalSize = 0
        foreach ($block in $blocks) {
            $size = (Get-Item $block).Length
            $totalSize += $size
            Write-Host "  • $([System.IO.Path]::GetFileName($block)) - $('{0:N2}' -f ($size / 1MB)) MB" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "Tamaño total: $('{0:N2}' -f ($totalSize / 1MB)) MB" -ForegroundColor White
        Write-Host ""
        
        # Copiar bloques al destino
        Show-Banner "COPIANDO BLOQUES AL DESTINO" -BorderColor Cyan -TextColor Cyan
        Write-Host ""
        
        $installerScript = New-InstallerScript -Destino $Destino -Temp $Temp -CompressionType $compressionType
        
        # Copiar cada bloque al destino
        $counter = 0
        foreach ($block in $blocks) {
            $counter++
            $fileName = [System.IO.Path]::GetFileName($block)
            $destPath = Join-Path $Destino $fileName
            
            Write-Host "[$counter/$($blocks.Count)] Copiando: $fileName" -ForegroundColor Gray
            Copy-Item $block $destPath -Force
            Write-Host "  ✓ Copiado" -ForegroundColor Green
        }
        
        # Copiar instalador
        if ($installerScript) {
            Write-Host ""
            Write-Host "Copiando INSTALAR.ps1 al destino..." -ForegroundColor Gray
            Copy-Item $installerScript $Destino -Force
            Write-Host "  ✓ Copiado" -ForegroundColor Green
        }
        
        # Copiar 7z si es necesario
        if ($SevenZ -ne "NATIVE_ZIP" -and (Test-Path $SevenZ)) {
            Write-Host "Copiando 7z.exe al destino..." -ForegroundColor Gray
            Copy-Item $SevenZ $Destino -Force
            Write-Host "  ✓ Copiado" -ForegroundColor Green
        }
        
        # Crear marcador EOF
        Write-Host "Creando marcador __EOF__..." -ForegroundColor Gray
        New-Item -ItemType File -Path (Join-Path $Destino "__EOF__") -Force | Out-Null
        Write-Host "  ✓ Creado" -ForegroundColor Green
        
        Write-Host ""
        Show-Banner "PROCESO COMPLETADO" -BorderColor Cyan -TextColor Cyan
        Write-Host ""
        Write-Host "✓ Bloques copiados al destino: $Destino" -ForegroundColor Green
        Write-Host "✓ Total de archivos en destino: $($blocks.Count + 3)" -ForegroundColor Green
        Write-Host ""
        
        # Limpieza
        Remove-ExampleData -Directories $directoriosLimpiar -TempDir $Temp
        
        Show-Banner "EJEMPLO FINALIZADO" -BorderColor Cyan -TextColor Cyan
        Write-Host ""
        Write-Host "Para instalar en otra máquina, copie el contenido de:" -ForegroundColor Yellow
        Write-Host "  $Destino" -ForegroundColor White
        Write-Host ""
        Write-Host "Y ejecute: .\INSTALAR.ps1" -ForegroundColor Yellow
        Write-Host ""
        
        return
    }
    catch {
        Write-ErrorLog "Error en modo ejemplo." $_
        Write-Host ""
        Write-Host "✗ Error en modo ejemplo: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Revise el log en: $Global:LogFile" -ForegroundColor Yellow
        Write-Host ""
        
        if ($directoriosLimpiar) {
            Remove-ExampleData -Directories $directoriosLimpiar -TempDir $Temp
        }
        return
    }
}

# ========================================================================== #
#                VERIFICAR INSTALACIÓN Y PARÁMETRO -Instalar                 #
# ========================================================================== #

# Si se pasó -Instalar, realizar instalación directamente
if ($Instalar) {
    # Detectar si está en IDE/Debug
    $isInIDE = Test-IsRunningInIDE
    
    if ($isInIDE) {
        Write-Host "`n[DEBUG/IDE] Omitiendo verificación de permisos de administrador" -ForegroundColor Cyan
    }
    else {
        # Verificar permisos de administrador
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            Write-Host "`n⚠ Se requieren permisos de administrador para instalar." -ForegroundColor Yellow
            Write-Host "Elevando a administrador..." -ForegroundColor Cyan
            
            $scriptPath = $MyInvocation.MyCommand.Path
            Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"", "-Instalar" -Verb RunAs
            exit
        }
    }
    
    # Realizar instalación
    $installed = Install-LlevarToSystem
    
    if ($installed) {
        Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    
    exit
}

# ========================================================================== #
#                     MODO NORMAL - EJECUCIÓN PRINCIPAL                      #
# ========================================================================== #

# Modo Normal
try {
    # Validar si se forzó ZIP nativo
    if ($UseNativeZip) {
        if (-not (Test-Windows10OrLater)) {
            Write-Host ""
            Write-Host "ERROR: La compresión ZIP nativa requiere Windows 10 o superior." -ForegroundColor Red
            Write-Host ""
            Write-Host "Su versión de Windows: $([System.Environment]::OSVersion.Version)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Opciones:" -ForegroundColor Cyan
            Write-Host "  1. Actualice a Windows 10 o superior" -ForegroundColor Gray
            Write-Host "  2. Quite el parámetro -UseNativeZip para usar 7-Zip automáticamente" -ForegroundColor Gray
            Write-Host "  3. Instale 7-Zip manualmente desde: https://www.7-zip.org/" -ForegroundColor Gray
            Write-Host ""
            return
        }
        Write-Host ""
        Write-Host "Usando compresión ZIP nativa de Windows (forzado por parámetro)" -ForegroundColor Cyan
        Write-Host "NOTA: ZIP nativo NO soporta contraseñas. El parámetro -Clave será ignorado." -ForegroundColor Yellow
        Write-Host ""
    }

    # Validar origen si viene del menú contextual
    if ($Origen) {
        # Si el origen viene del menú contextual, validarlo
        if (Test-Path $Origen) {
            Write-Host ""
            Show-Banner "ORIGEN PRESELECCIONADO DESDE MENÚ CONTEXTUAL" -BorderColor Cyan -TextColor Cyan
            Write-Host ""
            
            $item = Get-Item $Origen
            if ($item.PSIsContainer) {
                Write-Host "Carpeta seleccionada: $Origen" -ForegroundColor Green
            }
            else {
                Write-Host "Archivo seleccionado: $Origen" -ForegroundColor Green
                Write-Host ""
                Write-Host "NOTA: Se comprimirá el archivo individual." -ForegroundColor Yellow
            }
            Write-Host ""
        }
        else {
            Write-Host ""
            Write-Host "⚠ El origen especificado no existe: $Origen" -ForegroundColor Yellow
            Write-Host ""
            $Origen = $null
        }
    }
    
    # Si no hay origen o era inválido, pedirlo
    if (-not $Origen) {
        $Origen = Get-PathOrPrompt $Origen "ORIGEN"
    }
    
    # Pedir destino solo si no está configurado o es una ruta local que no existe
    if (-not $Destino) {
        $Destino = Get-PathOrPrompt $Destino "DESTINO"
    }
    elseif (-not ($Destino -match '^ftp://|^onedrive://|^dropbox://|^\\\\')) {
        # Si es ruta local, verificar que exista
        if (-not (Test-Path $Destino)) {
            Write-Host ""
            Write-Host "⚠ El destino especificado no existe: $Destino" -ForegroundColor Yellow
            Write-Host ""
            $Destino = Get-PathOrPrompt $Destino "DESTINO"
        }
    }

    # Determinar si origen o destino son FTP, OneDrive o Dropbox
    $origenEsFtp = Test-IsFtpPath -Path $Origen
    $destinoEsFtp = Test-IsFtpPath -Path $Destino
    $origenEsOneDrive = $OnedriveOrigen -or (Test-IsOneDrivePath -Path $Origen)
    $destinoEsOneDrive = $OnedriveDestino -or (Test-IsOneDrivePath -Path $Destino)
    $origenEsDropbox = $DropboxOrigen -or (Test-IsDropboxPath -Path $Origen)
    $destinoEsDropbox = $DropboxDestino -or (Test-IsDropboxPath -Path $Destino)
    
    # Si alguno es FTP, OneDrive o Dropbox, preguntar modo de transferencia
    $TransferMode = "Compress" # Por defecto comprimir
    if ($origenEsFtp -or $destinoEsFtp -or $origenEsOneDrive -or $destinoEsOneDrive -or $origenEsDropbox -or $destinoEsDropbox) {
        Add-Type -AssemblyName System.Windows.Forms
        
        $tipoTransfer = "FTP"
        if ($origenEsOneDrive -or $destinoEsOneDrive) { $tipoTransfer = "OneDrive/FTP" }
        if ($origenEsDropbox -or $destinoEsDropbox) { $tipoTransfer = "Dropbox/OneDrive/FTP" }
        
        $result = [System.Windows.Forms.MessageBox]::Show(
            "¿Cómo desea realizar la transferencia?`n`n• Transferir Directamente: Copia archivos sin comprimir`n• Comprimir Primero: Comprime, divide en bloques y transfiere (genera INSTALAR.ps1)`n`nNota: Si elige comprimir, los archivos temporales se eliminarán automáticamente.",
            "Modo de Transferencia $tipoTransfer",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button2
        )
        $TransferMode = if ($result -eq [System.Windows.Forms.DialogResult]::Yes) { "Direct" } else { "Compress" }
        Write-Host "Modo seleccionado: $TransferMode" -ForegroundColor Cyan
    }
    
    # Autenticar con OneDrive si es necesario
    if ($origenEsOneDrive -or $destinoEsOneDrive) {
        # Primero verificar que los módulos de Microsoft.Graph estén instalados
        if (-not (Test-MicrosoftGraphModule)) {
            Write-Host ""
            Write-Host "✗ No se pueden usar funciones de OneDrive sin los módulos Microsoft.Graph" -ForegroundColor Red
            Write-Host ""
            return
        }
        
        Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  AUTENTICACIÓN ONEDRIVE" -ForegroundColor Yellow
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        if (-not (Ensure-GraphConnected)) {
            Write-Host "No se pudo autenticar con OneDrive. Cancelando." -ForegroundColor Red
            return
        }
    }
    
    # Autenticar con Dropbox si es necesario
    if ($origenEsDropbox -or $destinoEsDropbox) {
        Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  AUTENTICACIÓN DROPBOX" -ForegroundColor Yellow
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        if (-not (Ensure-DropboxConnected)) {
            Write-Host "No se pudo autenticar con Dropbox. Cancelando." -ForegroundColor Red
            return
        }
    }

    # Si Origen o Destino son rutas UNC, FTP, OneDrive o Dropbox, procesarlas
    $origenMontado = $Origen
    $destinoMontado = $Destino
    $origenDrive = $null
    $destinoDrive = $null
    
    # Manejar origen OneDrive
    if ($origenEsOneDrive) {
        Write-Host "Configurando origen OneDrive..." -ForegroundColor Cyan
        if ($Origen -match '^onedrive://(.+)$' -or $Origen -match '^ONEDRIVE:(.+)$') {
            $origenMontado = $Matches[1]
        }
        else {
            # Solicitar ruta en OneDrive
            Write-Host "Ingrese la ruta en OneDrive (ejemplo: /Documentos/MiCarpeta): " -NoNewline
            $origenMontado = Read-Host
        }
        Write-Host "✓ Origen OneDrive configurado: $origenMontado" -ForegroundColor Green
    }
    # Manejar origen Dropbox
    elseif ($origenEsDropbox) {
        Write-Host "Configurando origen Dropbox..." -ForegroundColor Cyan
        if ($Origen -match '^dropbox://(.+)$' -or $Origen -match '^DROPBOX:(.+)$') {
            $origenMontado = $Matches[1]
        }
        else {
            # Solicitar ruta en Dropbox
            Write-Host "Ingrese la ruta en Dropbox (ejemplo: /Documentos/MiCarpeta): " -NoNewline
            $origenMontado = Read-Host
        }
        Write-Host "✓ Origen Dropbox configurado: $origenMontado" -ForegroundColor Green
    }
    elseif ($Origen -match '^\\\\' -or (Test-IsFtpPath -Path $Origen)) {
        $origenEsFtp = Test-IsFtpPath -Path $Origen
        $tipoOrigen = if ($origenEsFtp) { "FTP" } else { "UNC" }
        Write-Host "Montando ruta $tipoOrigen de origen..." -ForegroundColor Cyan
        $origenDrive = "LLEVAR_ORIGEN"
        try {
            $credOrigen = if ($origenEsFtp) { $SourceCredentials } else { $null }
            $origenMontado = Mount-LlevarNetworkPath -Path $Origen -Credential $credOrigen -DriveName $origenDrive
            Write-Host "✓ Origen montado: $origenMontado" -ForegroundColor Green
        }
        catch {
            Write-Host "Error al montar origen: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
    }
    
    # Manejar destino OneDrive
    if ($destinoEsOneDrive) {
        Write-Host "Configurando destino OneDrive..." -ForegroundColor Cyan
        if ($Destino -match '^onedrive://(.+)$' -or $Destino -match '^ONEDRIVE:(.+)$') {
            $destinoMontado = $Matches[1]
        }
        else {
            # Solicitar ruta en OneDrive
            Write-Host "Ingrese la ruta en OneDrive (ejemplo: /Documentos/Destino): " -NoNewline
            $destinoMontado = Read-Host
        }
        Write-Host "✓ Destino OneDrive configurado: $destinoMontado" -ForegroundColor Green
    }
    # Manejar destino Dropbox
    elseif ($destinoEsDropbox) {
        Write-Host "Configurando destino Dropbox..." -ForegroundColor Cyan
        if ($Destino -match '^dropbox://(.+)$' -or $Destino -match '^DROPBOX:(.+)$') {
            $destinoMontado = $Matches[1]
        }
        else {
            # Solicitar ruta en Dropbox
            Write-Host "Ingrese la ruta en Dropbox (ejemplo: /Documentos/Destino): " -NoNewline
            $destinoMontado = Read-Host
        }
        Write-Host "✓ Destino Dropbox configurado: $destinoMontado" -ForegroundColor Green
    }
    elseif ($Destino -match '^\\\\' -or (Test-IsFtpPath -Path $Destino)) {
        $destinoEsFtp = Test-IsFtpPath -Path $Destino
        $tipoDestino = if ($destinoEsFtp) { "FTP" } else { "UNC" }
        Write-Host "Montando ruta $tipoDestino de destino..." -ForegroundColor Cyan
        $destinoDrive = "LLEVAR_DESTINO"
        try {
            $credDestino = if ($destinoEsFtp) { $DestinationCredentials } else { $null }
            $destinoMontado = Mount-LlevarNetworkPath -Path $Destino -Credential $credDestino -DriveName $destinoDrive
            Write-Host "✓ Destino montado: $destinoMontado" -ForegroundColor Green
        }
        catch {
            Write-Host "Error al montar destino: $($_.Exception.Message)" -ForegroundColor Red
            # Limpiar origen si fue montado
            if ($origenDrive -and (Get-PSDrive -Name $origenDrive -ErrorAction SilentlyContinue)) {
                Remove-PSDrive -Name $origenDrive -Force -ErrorAction SilentlyContinue
            }
            return
        }
    }

    # Determinar método de compresión
    if ($UseNativeZip) {
        $SevenZ = "NATIVE_ZIP"
    }
    else {
        $SevenZ = Get-7z-Llevar
    }

    $Temp = Join-Path $env:TEMP "LLEVAR_TEMP"
    if (-not (Test-Path $Temp)) { New-Item -Type Directory $Temp | Out-Null }

    # Validar que el destino (local o UNC) sea escribible
    if (-not (Test-PathWritable -Path $destinoMontado)) {
        Write-Host "Destino no es escribible. Cancelando." -ForegroundColor Red
        # Limpiar unidades montadas
        if ($origenDrive -and (Get-PSDrive -Name $origenDrive -ErrorAction SilentlyContinue)) {
            Remove-PSDrive -Name $origenDrive -Force -ErrorAction SilentlyContinue
        }
        if ($destinoDrive -and (Get-PSDrive -Name $destinoDrive -ErrorAction SilentlyContinue)) {
            Remove-PSDrive -Name $destinoDrive -Force -ErrorAction SilentlyContinue
        }
        return
    }

    if ($Iso) {
        New-LlevarIsoMain -Origen $origenMontado -Destino $destinoMontado -Temp $Temp -SevenZ $SevenZ -BlockSizeMB $BlockSizeMB -Clave $Clave
        
        # Limpiar unidades montadas
        if ($origenDrive -and (Get-PSDrive -Name $origenDrive -ErrorAction SilentlyContinue)) {
            Remove-PSDrive -Name $origenDrive -Force -ErrorAction SilentlyContinue
        }
        if ($destinoDrive -and (Get-PSDrive -Name $destinoDrive -ErrorAction SilentlyContinue)) {
            Remove-PSDrive -Name $destinoDrive -Force -ErrorAction SilentlyContinue
        }
        return
    }

    # Manejo según modo de transferencia
    if ($TransferMode -eq "Direct") {
        # ============================================
        # MODO TRANSFERENCIA DIRECTA (SIN COMPRESIÓN)
        # ============================================
        Write-Host "`nIniciando transferencia directa..." -ForegroundColor Cyan
        
        # Usar función unificada de copia
        try {
            # Si venimos del menú, usar la configuración del menú
            if ($config -and $config.Origen -and $config.Destino) {
                Write-Log "Usando configuración del menú para Copy-LlevarFiles" "INFO"
                
                # Detectar si se debe usar Robocopy (solo para Local→Local o Local→UNC)
                $useRobocopy = $false
                if ($config.Origen.Tipo -eq "Local" -and $config.Destino.Tipo -in @("Local", "UNC")) {
                    $useRobocopy = $config.RobocopyMirror -or $false
                }
                
                $copyResult = Copy-LlevarFiles -SourceConfig $config.Origen -DestinationConfig $config.Destino `
                    -SourcePath $origenMontado -ShowProgress $true -ProgressTop -1 `
                    -UseRobocopy $useRobocopy -RobocopyMirror $config.RobocopyMirror
                
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
                Write-Host "  ✓ TRANSFERENCIA COMPLETADA" -ForegroundColor Green
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
                Write-Host ""
                Write-Host "Archivos copiados: $($copyResult.FileCount)" -ForegroundColor White
                Write-Host "Bytes transferidos: $([Math]::Round($copyResult.BytesCopied/1MB, 2)) MB" -ForegroundColor White
                Write-Host "Tiempo transcurrido: $([Math]::Round($copyResult.ElapsedSeconds, 2)) segundos" -ForegroundColor White
                Write-Host ""
            }
            else {
                # Si venimos de línea de comandos, construir configuraciones
                Write-Log "Construyendo configuración desde parámetros de línea de comandos" "INFO"
                
                $sourceConfig = @{
                    Tipo      = "Local"
                    Path      = $origenMontado
                    LocalPath = $origenMontado
                }
                
                $destConfig = @{
                    Tipo      = "Local"
                    Path      = $destinoMontado
                    LocalPath = $destinoMontado
                }
                
                # Detectar tipos especiales
                if ($origenEsFtp) { 
                    $sourceConfig.Tipo = "FTP"
                    $sourceConfig.FtpServer = $script:FtpSourceServer
                    $sourceConfig.FtpPort = $script:FtpSourcePort
                    $sourceConfig.FtpUser = $script:FtpSourceUser
                    $sourceConfig.FtpPassword = $script:FtpSourcePassword
                }
                if ($origenEsOneDrive) { 
                    $sourceConfig.Tipo = "OneDrive" 
                    # TODO: Obtener credenciales OneDrive si es necesario
                }
                if ($origenEsDropbox) { 
                    $sourceConfig.Tipo = "Dropbox"
                    # TODO: Obtener credenciales Dropbox si es necesario
                }
                
                if ($destinoEsFtp) { 
                    $destConfig.Tipo = "FTP"
                    $destConfig.FtpServer = $script:FtpDestinationServer
                    $destConfig.FtpPort = $script:FtpDestinationPort
                    $destConfig.FtpUser = $script:FtpDestinationUser
                    $destConfig.FtpPassword = $script:FtpDestinationPassword
                }
                if ($destinoEsOneDrive) { 
                    $destConfig.Tipo = "OneDrive"
                    # TODO: Obtener credenciales OneDrive si es necesario
                }
                if ($destinoEsDropbox) { 
                    $destConfig.Tipo = "Dropbox"
                    # TODO: Obtener credenciales Dropbox si es necesario
                }
                
                # Detectar si se debe usar Robocopy
                $useRobocopy = $false
                if ($sourceConfig.Tipo -eq "Local" -and $destConfig.Tipo -in @("Local", "UNC") -and $RobocopyMirror) {
                    $useRobocopy = $true
                }
                
                $copyResult = Copy-LlevarFiles -SourceConfig $sourceConfig -DestinationConfig $destConfig `
                    -SourcePath $origenMontado -ShowProgress $true -ProgressTop -1 `
                    -UseRobocopy $useRobocopy -RobocopyMirror $RobocopyMirror
                
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
                Write-Host "  ✓ TRANSFERENCIA COMPLETADA" -ForegroundColor Green
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
                Write-Host ""
                Write-Host "Archivos copiados: $($copyResult.FileCount)" -ForegroundColor White
                Write-Host "Bytes transferidos: $([Math]::Round($copyResult.BytesCopied/1MB, 2)) MB" -ForegroundColor White
                Write-Host "Tiempo transcurrido: $([Math]::Round($copyResult.ElapsedSeconds, 2)) segundos" -ForegroundColor White
                Write-Host ""
            }
            
            Write-Host "✓ Transferencia directa completada." -ForegroundColor Green
        }
        catch {
            Write-Host "Error durante transferencia directa: $($_.Exception.Message)" -ForegroundColor Red
            Write-ErrorLog "Error en transferencia directa" $_
        }
        
        # Limpiar unidades montadas
        if ($origenDrive -and (Get-PSDrive -Name $origenDrive -ErrorAction SilentlyContinue)) {
            Remove-PSDrive -Name $origenDrive -Force -ErrorAction SilentlyContinue
        }
        if ($destinoDrive -and (Get-PSDrive -Name $destinoDrive -ErrorAction SilentlyContinue)) {
            Remove-PSDrive -Name $destinoDrive -Force -ErrorAction SilentlyContinue
        }
        
        Write-Host "`n✓ Finalizado (Modo Directo)."
        return
    }

    # ============================================
    # MODO COMPRESIÓN Y TRANSFERENCIA
    # ============================================
    Write-Host "`nIniciando compresión y transferencia..." -ForegroundColor Cyan
    
    # Si origen es OneDrive o Dropbox, descargar primero a temporal
    $origenParaComprimir = $origenMontado
    $tempOrigenCloud = $null
    
    if ($origenEsOneDrive) {
        Write-Host "Descargando desde OneDrive a carpeta temporal..." -ForegroundColor Cyan
        $tempOrigenCloud = Join-Path $env:TEMP "LLEVAR_ONEDRIVE_ORIGEN"
        if (Test-Path $tempOrigenCloud) {
            Remove-Item $tempOrigenCloud -Recurse -Force
        }
        New-Item -Type Directory $tempOrigenCloud | Out-Null
        
        Download-OneDriveFolder -OneDrivePath "root:${origenMontado}:" -LocalFolder $tempOrigenCloud
        $origenParaComprimir = $tempOrigenCloud
    }
    elseif ($origenEsDropbox) {
        Write-Host "Descargando desde Dropbox a carpeta temporal..." -ForegroundColor Cyan
        $tempOrigenCloud = Join-Path $env:TEMP "LLEVAR_DROPBOX_ORIGEN"
        if (Test-Path $tempOrigenCloud) {
            Remove-Item $tempOrigenCloud -Recurse -Force
        }
        New-Item -Type Directory $tempOrigenCloud | Out-Null
        
        Download-DropboxFolder -RemotePath $origenMontado -LocalFolder $tempOrigenCloud -Token $Global:DropboxToken
        $origenParaComprimir = $tempOrigenCloud
    }
    
    $compressionResult = Compress-Folder $origenParaComprimir $Temp $SevenZ $Clave $BlockSizeMB
    $blocks = $compressionResult.Files
    $compressionType = $compressionResult.CompressionType

    $installerScript = New-InstallerScript -Destino $destinoMontado -Temp $Temp -CompressionType $compressionType

    # Si destino es OneDrive o Dropbox, subir bloques
    if ($destinoEsOneDrive) {
        Write-Host "`nSubiendo bloques a OneDrive..." -ForegroundColor Cyan
        
        $totalBlocks = $blocks.Count
        $currentBlock = 0
        
        foreach ($block in $blocks) {
            $currentBlock++
            $fileName = [System.IO.Path]::GetFileName($block)
            Write-Host "[$currentBlock/$totalBlocks] Subiendo: $fileName" -ForegroundColor Gray
            Upload-OneDriveFile -LocalPath $block -RemotePath $destinoMontado
        }
        
        # Subir instalador
        if ($installerScript -and (Test-Path $installerScript)) {
            Write-Host "Subiendo INSTALAR.ps1..." -ForegroundColor Gray
            Upload-OneDriveFile -LocalPath $installerScript -RemotePath $destinoMontado
        }
        
        # Subir 7-Zip si es necesario
        if ($SevenZ -and $compressionType -ne "NATIVE_ZIP" -and (Test-Path $SevenZ)) {
            Write-Host "Subiendo 7z.exe..." -ForegroundColor Gray
            Upload-OneDriveFile -LocalPath $SevenZ -RemotePath $destinoMontado
        }
        
        Write-Host "`n✓ Todos los archivos subidos a OneDrive" -ForegroundColor Green
    }
    elseif ($destinoEsDropbox) {
        Write-Host "`nSubiendo bloques a Dropbox..." -ForegroundColor Cyan
        
        $totalBlocks = $blocks.Count
        $currentBlock = 0
        
        foreach ($block in $blocks) {
            $currentBlock++
            $fileName = [System.IO.Path]::GetFileName($block)
            $remotePath = "$destinoMontado/$fileName".Replace('//', '/')
            Write-Host "[$currentBlock/$totalBlocks] Subiendo: $fileName" -ForegroundColor Gray
            Upload-DropboxFile -LocalPath $block -RemotePath $remotePath -Token $Global:DropboxToken
        }
        
        # Subir instalador
        if ($installerScript -and (Test-Path $installerScript)) {
            Write-Host "Subiendo INSTALAR.ps1..." -ForegroundColor Gray
            $installerName = [System.IO.Path]::GetFileName($installerScript)
            $remotePath = "$destinoMontado/$installerName".Replace('//', '/')
            Upload-DropboxFile -LocalPath $installerScript -RemotePath $remotePath -Token $Global:DropboxToken
        }
        
        # Subir 7-Zip si es necesario
        if ($SevenZ -and $compressionType -ne "NATIVE_ZIP" -and (Test-Path $SevenZ)) {
            Write-Host "Subiendo 7z.exe..." -ForegroundColor Gray
            $remotePath = "$destinoMontado/7z.exe".Replace('//', '/')
            Upload-DropboxFile -LocalPath $SevenZ -RemotePath $remotePath -Token $Global:DropboxToken
        }
        
        Write-Host "`n✓ Todos los archivos subidos a Dropbox" -ForegroundColor Green
    }
    else {
        Copy-BlocksToUSB -Blocks $blocks -InstallerPath $installerScript -SevenZPath $SevenZ -CompressionType $compressionType -DestinationPath $destinoMontado -IsFtp $destinoEsFtp
    }
    
    # Limpiar temporal de cloud origen si existe
    if ($tempOrigenCloud -and (Test-Path $tempOrigenCloud)) {
        Write-Host "`nLimpiando descarga temporal de cloud..." -ForegroundColor Cyan
        Remove-Item $tempOrigenCloud -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Limpiar archivos temporales después de transferir
    Write-Host "`nLimpiando archivos temporales..." -ForegroundColor Cyan
    try {
        if (Test-Path $Temp) {
            Remove-Item -Path $Temp -Recurse -Force -ErrorAction Stop
            Write-Host "✓ Archivos temporales eliminados de: $Temp" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Advertencia: No se pudieron eliminar algunos archivos temporales: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-ErrorLog "Error al limpiar archivos temporales" $_
    }

    # Limpiar unidades montadas
    if ($origenDrive -and (Get-PSDrive -Name $origenDrive -ErrorAction SilentlyContinue)) {
        Remove-PSDrive -Name $origenDrive -Force -ErrorAction SilentlyContinue
    }
    if ($destinoDrive -and (Get-PSDrive -Name $destinoDrive -ErrorAction SilentlyContinue)) {
        Remove-PSDrive -Name $destinoDrive -Force -ErrorAction SilentlyContinue
    }

    Write-Host "`n✓ Finalizado (Modo Comprimido)."
}
catch {
    Write-ErrorLog "Error en ejecución." $_
    Write-Host "Ocurrió un error. Revise el log en: $Global:LogFile" -ForegroundColor Red
        
    # Limpiar unidades montadas en caso de error
    if ($origenDrive -and (Get-PSDrive -Name $origenDrive -ErrorAction SilentlyContinue)) {
        Remove-PSDrive -Name $origenDrive -Force -ErrorAction SilentlyContinue
    }
    if ($destinoDrive -and (Get-PSDrive -Name $destinoDrive -ErrorAction SilentlyContinue)) {
        Remove-PSDrive -Name $destinoDrive -Force -ErrorAction SilentlyContinue
    }
}
