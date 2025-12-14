# *********************************************************************************************
# SE MANTIENE POR COMPATIBILIDAD CON LA TERCERA EDAD LO VIEJO SIRVE JUAN ehhhhhh ALEJANDRO xD #
# ********************************************************************************************* 
# Con el mayor de los respetos, para alguien por el que siempre senti mucha admiración, a modo homenaje, 
# espero que te guste esta loca vuelta de tuercaal mítico LLEVAR.BAT que tanto me ayudó en mis començos con 
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
    Autor: Basado en LLEVAR.BAT de Alex Soft propiedad de Alejandro Nacir
    Versión PowerShell modernizada con soporte ZIP nativo
#>

# ========================================================================== #
#                          DEFINICIÓN DE PARÁMETROS                          #
# ==========================================================================
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
    [ValidateSet("local", "iso-cd", "iso-dvd", "ftp", "onedrive", "dropbox")]
    [string]$TipoEjemplo = "local",
    [switch]$Instalar,
    [switch]$Desinstalar,
    [Alias('h')]
    [switch]$Ayuda,
    [ValidateSet("Navigator", "FTP", "OneDrive", "Dropbox", "Compression", "Robocopy", "UNC", "USB", "ISO")]
    [string]$Test,
    [switch]$OnedriveOrigen,
    [switch]$OnedriveDestino,
    [string]$OneDrivePath,
    [switch]$DropboxOrigen,
    [switch]$DropboxDestino,
    [string]$DropboxPath,
    [switch]$RobocopyMirror,
    [switch]$Verbose,
    [switch]$ForceLogo
)

# ========================================================================== #
#              CONFIGURAR PREFERENCIAS DE ERROR/WARNING TEMPRANO             #
# ========================================================================== #

# ========================================================================== #
#              VERIFICACIÓN DE POWERSHELL 7 CON MÓDULO DEDICADO              #
# ========================================================================== #

# Rutas críticas tempranas
$Global:ScriptDir = $PSScriptRoot
$Global:ModulesPath = Join-Path $Global:ScriptDir "Modules"

# Importar módulo de verificación de PowerShell
try {
    $psVersionPath = Join-Path $Global:ModulesPath "System\PowerShellVersion.psm1"
    if (Test-Path $psVersionPath) {
        Import-Module $psVersionPath -Force -Global -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        
        # Verificar PowerShell 7 - si falla, el script terminará
        if (-not (Assert-PowerShell7)) {
            exit 1
        }
    }
    else {
        # Si no existe el módulo, hacer verificación básica
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-Host ""
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
            Write-Host " ⚠ POWERSHELL 7 REQUERIDO" -ForegroundColor Yellow
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
            Write-Host ""
            Write-Host "Este programa requiere PowerShell 7 o superior." -ForegroundColor White
            Write-Host "Versión actual: PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Gray
            Write-Host "Descargue desde: https://aka.ms/powershell" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            exit 1
        }
    }
}
catch {
    Write-Host "Error al verificar versión de PowerShell: $_" -ForegroundColor Red
    exit 1
}

# ========================================================================== #
#              VERIFICACIÓN Y AUTO-ELEVACIÓN DE PERMISOS ADMIN               #
# ========================================================================== #

# Verificar si se está ejecutando como administrador
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "🔒 Elevando permisos de administrador..." -ForegroundColor Cyan
    
    try {
        # Construir argumentos para mantener todos los parámetros
        $argList = @(
            '-NoProfile'
            '-ExecutionPolicy', 'Bypass'
            '-File', "`"$PSCommandPath`""
        )
        
        # Agregar parámetros bound
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            if ($param.Value -is [switch]) {
                if ($param.Value) {
                    $argList += "-$($param.Key)"
                }
            }
            else {
                $argList += "-$($param.Key)"
                $argList += "`"$($param.Value)`""
            }
        }
        
        # Iniciar proceso elevado (intenta automáticamente sin preguntar)
        $process = Start-Process -FilePath "pwsh.exe" `
            -ArgumentList $argList `
            -Verb RunAs `
            -PassThru `
            -WindowStyle Normal `
            -ErrorAction Stop
        
        # Esperar a que termine el proceso elevado
        $process.WaitForExit()
        
        # Salir del proceso no elevado
        exit $process.ExitCode
    }
    catch {
        # Si falla la elevación automática (usuario cancela UAC o error de seguridad)
        $errorType = $_.Exception.GetType().Name
        
        # Si es una cancelación del usuario (OperationCanceledException o similar)
        if ($errorType -eq "Win32Exception" -or $_.Exception.Message -match "cancel|1223") {
            # Mostrar popup de advertencia
            try {
                Add-Type -AssemblyName PresentationFramework
                [System.Windows.MessageBox]::Show(
                    "LLEVAR requiere permisos de administrador para funcionar correctamente.`n`n" +
                    "La operación fue cancelada por el usuario.`n`n" +
                    "No se puede continuar sin permisos de administrador.",
                    "Permisos de Administrador Requeridos",
                    "OK",
                    "Warning"
                ) | Out-Null
            }
            catch {
                # Fallback si no se puede mostrar MessageBox
                Write-Host ""
                Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
                Write-Host "║                                                               ║" -ForegroundColor Yellow
                Write-Host "║  ⚠ PERMISOS DE ADMINISTRADOR REQUERIDOS                      ║" -ForegroundColor Yellow
                Write-Host "║                                                               ║" -ForegroundColor Yellow
                Write-Host "║  La operación fue cancelada.                                  ║" -ForegroundColor Yellow
                Write-Host "║  No se puede continuar sin permisos de administrador.         ║" -ForegroundColor Yellow
                Write-Host "║                                                               ║" -ForegroundColor Yellow
                Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        else {
            # Otro tipo de error al elevar permisos
            try {
                Add-Type -AssemblyName PresentationFramework
                [System.Windows.MessageBox]::Show(
                    "No se pudo elevar permisos de administrador.`n`n" +
                    "Error: $($_.Exception.Message)`n`n" +
                    "Por favor ejecute PowerShell como administrador manualmente.",
                    "Error de Elevación de Permisos",
                    "OK",
                    "Error"
                ) | Out-Null
            }
            catch {
                # Fallback
                Write-Host ""
                Write-Host "❌ No se pudo elevar permisos de administrador" -ForegroundColor Red
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Por favor ejecute PowerShell como administrador manualmente." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        exit 1
    }
}

# ========================================================================== #
#              CONFIGURAR PREFERENCIAS DE ERROR/WARNING TEMPRANO             #
# ========================================================================== #

# Configurar preferencias ANTES de cualquier importación para silenciar errores/warnings
$script:OriginalErrorPreference = $ErrorActionPreference
$script:OriginalWarningPreference = $WarningPreference
$ErrorActionPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

# ========================================================================== #
#                    INICIALIZACIÓN TEMPRANA DE LOGGING                      #
# ========================================================================== #

# Crear carpeta de logs si no existe (ScriptDir ya definido en verificación PS7)
$Global:LogsDir = Join-Path $Global:ScriptDir "Logs"
if (-not (Test-Path $Global:LogsDir)) {
    New-Item -Path $Global:LogsDir -ItemType Directory -Force | Out-Null
}

# Nombre base del log con fecha, hora y minuto
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$Global:LogBaseName = "LLEVAR_$timestamp"
$Global:LogFile = Join-Path $Global:LogsDir "$($Global:LogBaseName).log"

function Write-InitLogSafe {
    param([string]$Value)
    try {
        if (-not $Global:LogFile) {
            $Global:LogFile = Join-Path $Global:LogsDir "$($Global:LogBaseName)_fallback.log"
        }
        # Crear carpeta del log si aún no existe
        $logDir = Split-Path -Parent $Global:LogFile
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        Add-Content -Path $Global:LogFile -Value $Value -Encoding UTF8
    }
    catch {
        # Último recurso: dejar constancia en consola
        Write-Host "No se pudo escribir el log en $Global:LogFile : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Iniciar transcript para capturar TODA la salida (incluyendo warnings de importación)
$TranscriptFile = Join-Path $Global:LogsDir "$($Global:LogBaseName)_TRANSCRIPT.log"
try {
    Start-Transcript -Path $TranscriptFile -Force | Out-Null
}
catch {
    # Transcript no disponible en algunos contextos (ISE)
    $TranscriptFile = $null
}

# Log inicial básico
$initLog = @"
========================================
Iniciando LLEVAR.PS1
Fecha/Hora: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Usuario: $env:USERNAME
Computadora: $env:COMPUTERNAME
PowerShell: $($PSVersionTable.PSVersion)
Modo Verbose: $Verbose
Transcript: $(if ($TranscriptFile) { 'Activo' } else { 'No disponible' })
========================================
"@
Write-InitLogSafe $initLog

# ========================================================================== #
#                   WRAPPER DE MANEJO DE ERRORES GLOBAL                      #
# ========================================================================== #

try {
    # Configurar preferencias de error para capturar todo
    $ErrorActionPreference = 'Continue'
    
    # Alias local para simplicidad
    $ModulesPath = $Global:ModulesPath
    
    # ========================================================================== #
    #                        IMPORTAR TODOS LOS MÓDULOS                          #
    # ========================================================================== #

    # Las preferencias de error/warning ya están configuradas al inicio del script
    # Variables para capturar errores y warnings durante importación
    $importWarnings = @()
    $importErrors = @()

    # Módulos Core
    Import-Module (Join-Path $ModulesPath "Core\TransferConfig.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Core\Validation.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    

    # Módulos UI (básicos - ConfigMenus se importa después de Transfer)
    Import-Module (Join-Path $ModulesPath "UI\Console.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "UI\ProgressBar.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "UI\Banners.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "UI\Navigator.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "UI\Menus.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    # Módulos de Compresión
    Import-Module (Join-Path $ModulesPath "Compression\SevenZip.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Compression\NativeZip.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Compression\BlockSplitter.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    # Módulos de Transferencia
    Import-Module (Join-Path $ModulesPath "Transfer\Local.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Transfer\FTP.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Transfer\UNC.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Transfer\OneDrive.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Transfer\Dropbox.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Transfer\Floppy.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Transfer\Unified.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    # ConfigMenus se importa DESPUÉS de Transfer porque usa funciones de esos módulos
    Import-Module (Join-Path $ModulesPath "UI\ConfigMenus.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    # Módulos de Instalación
    Import-Module (Join-Path $ModulesPath "Installation\SystemInstall.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Installation\Uninstall.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Installation\Installer.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Installation\Installation.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Installation\Install.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Installation\InstallationCheck.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    # Módulos de Utilidades

    Import-Module (Join-Path $ModulesPath "Utilities\Examples.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Utilities\Help.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Utilities\PathSelectors.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Utilities\VolumeManagement.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    # Módulos del Sistema
    Import-Module (Join-Path $ModulesPath "System\Audio.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "System\FileSystem.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "System\Robocopy.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "System\ISO.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    # Módulos de Parámetros
    Import-Module (Join-Path $ModulesPath "Parameters\Help.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Parameters\Example.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Parameters\Test.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Parameters\Robocopy.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Parameters\InteractiveMenu.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Import-Module (Join-Path $ModulesPath "Parameters\NormalMode.psm1") -Force -Global -WarningVariable +importWarnings -ErrorVariable +importErrors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    
    # --------------------------------------------------------------------------
    # Manejo genérico de errores / advertencias durante importación de módulos
    # --------------------------------------------------------------------------

    # Si hubo errores de importación, abortar con log crítico
    if ($importErrors -and $importErrors.Count -gt 0) {

        $importErrorLog = @"
[ERROR CRÍTICO]
Se produjeron errores durante la importación de uno o más módulos.
La inicialización del sistema no puede continuar.
"@

        $importErrorLog += "`nErrores ($($importErrors.Count)):`n"
        foreach ($err in $importErrors) {
            $importErrorLog += "  - $($err.Exception.Message)`n"
        }

        if ($importWarnings -and $importWarnings.Count -gt 0) {
            $importErrorLog += "`nAdvertencias adicionales ($($importWarnings.Count)):`n"
            foreach ($warning in $importWarnings) {
                $importErrorLog += "  - $warning`n"
            }
        }

        Write-InitLogSafe $importErrorLog
        throw "ERROR CRÍTICO: Falló la importación de módulos. Revisa el log en: $Global:LogFile"
    }

    # Si NO hubo errores críticos, pero sí advertencias, registrarlas
    if ($importWarnings -and $importWarnings.Count -gt 0) {

        $importWarningLog = @"
[ADVERTENCIAS DURANTE IMPORTACIÓN DE MÓDULOS]
La inicialización continuó, pero se detectaron advertencias.
"@

        $importWarningLog += "`nAdvertencias ($($importWarnings.Count)):`n"
        foreach ($warning in $importWarnings) {
            $importWarningLog += "  - $warning`n"
        }

        Write-InitLogSafe $importWarningLog
    }
    
    # Variable para indicar que hay advertencias a mostrar después del logo
    $script:HasImportWarnings = ($importWarnings -and $importWarnings.Count -gt 0)

    
    # Restaurar preferencias de error y warning después de la importación
    # para que el resto del script funcione normalmente
    $ErrorActionPreference = $script:OriginalErrorPreference
    $WarningPreference = $script:OriginalWarningPreference

    # ========================================================================== #
    #                 VERIFICACIÓN DE PERMISOS DE ADMINISTRADOR                  #
    # ========================================================================== #

    # Verificar si se está ejecutando como administrador
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    # Detectar si estamos en VS Code, ISE, u otro IDE usando la función del módulo
    $isInIDE = Test-IsRunningInIDE

    # Si estamos en IDE, activar verbose automáticamente (sin pasarlo como parámetro)
    if ($isInIDE -and -not $Verbose) {
        $Verbose = $true
        Write-Host "[DEBUG/IDE] Verbose activado automáticamente" -ForegroundColor DarkGray
    }

    # ========================================================================== #
    #                   ELEVACIÓN AUTOMÁTICA A ADMINISTRADOR                     #
    # ========================================================================== #
    
    # Si NO está en IDE, NO es admin, y NO es parámetro de instalación -> elevar
    # (Instalación maneja su propia elevación en Install.psm1)
    if (-not $isInIDE -and -not $isAdmin -and -not $Instalar) {
        Write-Host "`nLlevar requiere permisos de administrador." -ForegroundColor Yellow
        Write-Host "Elevando automáticamente..." -ForegroundColor Cyan
        
        # Construir argumentos preservando todos los parámetros
        $arguments = @("-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$($MyInvocation.MyCommand.Path)`"")
        
        # Agregar parámetros originales
        if ($Origen) { $arguments += "-Origen", "`"$Origen`"" }
        if ($Destino) { $arguments += "-Destino", "`"$Destino`"" }
        if ($RobocopyMirror) { $arguments += "-RobocopyMirror" }
        if ($Ejemplo) { $arguments += "-Ejemplo" }
        if ($Ayuda) { $arguments += "-Ayuda" }
        if ($Test) { $arguments += "-Test" }
        if ($ForceLogo) { $arguments += "-ForceLogo" }
        if ($Verbose) { $arguments += "-Verbose" }
        
        Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
        exit
    }

    # ========================================================================== #
    #                            INICIALIZACIÓN                                  #
    # ========================================================================== #

    # Inicializar sistema de logs
    Initialize-LogFile -Verbose:$Verbose

    # Inicializar consola si es necesario (solo si hay consola válida)
    # NO hacer Clear-Host aquí para no borrar errores/warnings antes del logo
    $hostName = $host.Name
    if ($hostName -and ($hostName -ilike '*consolehost*' -or $hostName -ilike '*visual studio code host*')) {
        try {
            $rawUI = $host.UI.RawUI
            if ($rawUI) {
                $rawUI.BackgroundColor = 'Black'
                $rawUI.ForegroundColor = 'White'
                # Clear-Host eliminado - Show-AsciiLogo lo hará cuando sea necesario
            }
        }
        catch {
            # Si no hay consola válida (por ejemplo, en algunos hosts embebidos), continuar sin fallar
        }
    }

    # ========================================================================== #
    # ========================================================================== #
    #                     ⬇⬇⬇ EJECUCIÓN PRINCIPAL ⬇⬇⬇                           #
    #                          FLUJO PRINCIPAL (LLEVAR)                          #
    # ========================================================================== #
    # ========================================================================== #
    
    # Verificar si hay parámetros de ejecución directa
    $hasExecutionParams = ($Origen -or $Destino -or $RobocopyMirror -or $Ejemplo -or $Ayuda -or $Instalar -or $Desinstalar -or $Test)

    # ========================================================================== #
    #                        LOGO Y MENSAJE DE BIENVENIDA                        #
    # ========================================================================== #
    
    # Variable para rastrear si se mostró el logo
    $script:LogoWasShown = $false

    $forceLogoEnv = $false
    if ($env:LLEVAR_FORCE_LOGO -eq '1' -or $env:LLEVAR_FORCE_LOGO -eq 'true') { $forceLogoEnv = $true }
    
    # Mostrar logo si:
    # - Se especifica -ForceLogo o variable de entorno -> SIEMPRE mostrar
    # - O si NO hay parámetros de ejecución Y NO está en IDE
    if ($ForceLogo -or $forceLogoEnv) {
        $shouldShowLogo = $true
    }
    else {
        $shouldShowLogo = (-not $hasExecutionParams) -and (-not $isInIDE)
    }
    
    # Log de depuración solo si Write-Log está disponible
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        Write-Log "Logo check -> isInIDE=$isInIDE hasParams=$hasExecutionParams ForceLogo=$ForceLogo EnvForceLogo=$forceLogoEnv" "DEBUG"
    }
    
    # Mostrar logo ASCII si corresponde
    if ($shouldShowLogo) {
        $logoPath = Join-Path $PSScriptRoot "Data\alexsoft.txt"
        if (Test-Path $logoPath) {
            try {
                # Usar Show-AsciiLogo como renderer unificado para el logo con sonidos estilo DOS
                # Show-AsciiLogo hace su propio Clear-Host internamente
                Show-AsciiLogo -Path $logoPath -DelayMs 30 -ShowProgress $true -Label "Cargando..." -ForegroundColor Gray -PlaySound $true -FinalDelaySeconds 2
                $script:LogoWasShown = $true
                
                # Mostrar mensaje de bienvenida personalizado parpadeante
                Show-WelcomeMessage -BlinkCount 3 -VisibleDelayMs 450 -TextColor Cyan
                
                # Mostrar advertencias si las hay (los errores críticos ya abortaron antes)
                if ($script:HasImportWarnings) {
                    Write-Host ""
                    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
                    Write-Host "  ADVERTENCIAS DURANTE LA CARGA DE MÓDULOS" -ForegroundColor Yellow
                    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Advertencias ($($importWarnings.Count)):" -ForegroundColor Yellow
                    foreach ($warning in $importWarnings) {
                        Write-Host "  ⚠ $warning" -ForegroundColor Yellow
                    }
                    Write-Host ""
                    Write-Host "Los detalles completos están en el log: $Global:LogFile" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Cyan
                    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
                
                # Limpiar para mostrar el menú
                Clear-Host
            }
            catch {
                # Si hay error en el logo (ej: cuando se usa -NoProfile), simplemente continuar
                # No es un error crítico, solo significa que las funciones de consola no están disponibles
                try {
                    Write-Log "Error mostrando logo ASCII: $($_.Exception.Message)" "WARNING"
                }
                catch {
                    # Ignorar errores al escribir el log
                }
                try {
                    Clear-Host
                }
                catch {
                    # Ignorar si Clear-Host falla
                }
            }
        }
    }

    # Si no se mostró el logo pero hubo advertencias y no hay parámetros, mostrarlas igual
    if (-not $script:LogoWasShown -and -not $hasExecutionParams -and $script:HasImportWarnings) {
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host "  ADVERTENCIAS DURANTE LA CARGA DE MÓDULOS" -ForegroundColor Yellow
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Advertencias ($($importWarnings.Count)):" -ForegroundColor Yellow
        foreach ($warning in $importWarnings) { Write-Host "  ⚠ $warning" -ForegroundColor Yellow }
        Write-Host ""
        Write-Host "Los detalles completos están en el log: $Global:LogFile" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Cyan
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-Host
    }

    # ========================================================================== #
    #                        VERIFICACIÓN DE INSTALACIÓN                         #
    # ========================================================================== #

    # Verificar instalación solo si NO hay parámetros de ejecución directa
    if (-not $hasExecutionParams) {
        Invoke-InstallationCheck -Ejemplo:$Ejemplo -Ayuda:$Ayuda -IsAdmin $isAdmin -IsInIDE $isInIDE -ScriptPath $MyInvocation.MyCommand.Path -LogoWasShown $script:LogoWasShown
    }

    # ========================================================================== #
    #                   PROCESAMIENTO DE PARÁMETROS DE EJECUCIÓN                 #
    # ========================================================================== #

    # 1. Verificar parámetro -Ayuda
    Invoke-HelpParameter -Ayuda:$Ayuda

    # 2. Verificar parámetro -Instalar
    Invoke-InstallParameter -Instalar:$Instalar -IsAdmin $isAdmin -IsInIDE $isInIDE -ScriptPath $MyInvocation.MyCommand.Path

    # 3. Verificar parámetro -Desinstalar
    Invoke-UninstallParameter -Desinstalar:$Desinstalar -IsAdmin $isAdmin -IsInIDE $isInIDE -ScriptPath $MyInvocation.MyCommand.Path

    # 4. Verificar parámetro -RobocopyMirror
    Invoke-RobocopyParameter -RobocopyMirror:$RobocopyMirror -Origen $Origen -Destino $Destino

    # 4. Verificar parámetro -Ejemplo (modo completamente automático)
    $ejemploExecuted = Invoke-ExampleParameter -Ejemplo:$Ejemplo -TipoEjemplo $TipoEjemplo
    if ($ejemploExecuted) {
        exit
    }

    # 5. Verificar parámetro -Test (modo pruebas individuales)
    if ($Test) {
        $testExecuted = Invoke-TestParameter -Test $Test
        if ($testExecuted) {
            exit
        }
    }

    # 6. Configurar TransferConfig según parámetros o menú interactivo
    
    # ✅ CREAR INSTANCIA ÚNICA DE TRANSFERCONFIG AL INICIO
    $transferConfig = New-TransferConfig

    # Detectar si hay parámetros de ejecución que configuran origen/destino
    $hasOriginDestinationParams = ($Origen -or $Destino -or $OnedriveOrigen -or $OnedriveDestino -or $DropboxOrigen -or $DropboxDestino)
    
    # Variable para indicar si el origen fue predefinido (desde CMD o menú contextual)
    $origenPredefinido = $false

    # Si hay parámetros de línea de comandos, configurar TransferConfig directamente
    if ($hasOriginDestinationParams) {
        # ===== DETECTAR Y CONFIGURAR ORIGEN =====
        if ($Origen) {
            $origenPredefinido = $true
            # Detectar tipo de origen según formato del path
            if ($Origen -match '^ftp(s)?://') {
                # Es FTP - parsear URL
                if ($Origen -match '^(ftp(s)?)://([^:/]+):?(\d+)?(/.*)?$') {
                    $ftpScheme = $matches[1]
                    $ftpServer = $matches[3]
                    $ftpPort = if ($matches[4]) { [int]$matches[4] } else { 21 }
                    $ftpDirectory = if ($matches[5]) { $matches[5] } else { "/" }
                    
                    # ✅ ASIGNAR DIRECTAMENTE A $transferConfig
                    $transferConfig.Origen.Tipo = "FTP"
                    $transferConfig.Origen.FTP.Server = "$ftpScheme`://$ftpServer"
                    $transferConfig.Origen.FTP.Port = $ftpPort
                    $transferConfig.Origen.FTP.Directory = $ftpDirectory
                    $transferConfig.Origen.FTP.UseSsl = ($ftpScheme -eq "ftps")
                    $transferConfig.OrigenIsSet = $true
                    
                    if ($SourceCredentials) {
                        $transferConfig.Origen.FTP.Credentials = $SourceCredentials
                        $transferConfig.Origen.FTP.User = $SourceCredentials.UserName
                        $transferConfig.Origen.FTP.Password = $SourceCredentials.GetNetworkCredential().Password
                    }
                }
            }
            elseif ($Origen -match '^\\\\') {
                # Es UNC - ruta de red
                $transferConfig.Origen.Tipo = "UNC"
                $transferConfig.Origen.UNC.Path = $Origen
                $transferConfig.OrigenIsSet = $true
            }
            elseif ($OnedriveOrigen) {
                # OneDrive especificado por parámetro
                $transferConfig.Origen.Tipo = "OneDrive"
                $transferConfig.Origen.OneDrive.Path = $Origen
                $transferConfig.OrigenIsSet = $true
            }
            elseif ($DropboxOrigen) {
                # Dropbox especificado por parámetro
                $transferConfig.Origen.Tipo = "Dropbox"
                $transferConfig.Origen.Dropbox.Path = $Origen
                $transferConfig.OrigenIsSet = $true
            }
            else {
                # Es Local por defecto
                $transferConfig.Origen.Tipo = "Local"
                $transferConfig.Origen.Local.Path = $Origen
                $transferConfig.OrigenIsSet = $true
            }
        }
        
        # ===== DETECTAR Y CONFIGURAR DESTINO =====
        if ($OnedriveDestino) {
            # OneDrive especificado por parámetro - autenticar
            $authResult = Get-OneDriveAuth
            if ($authResult) {
                $transferConfig.Destino.Tipo = "OneDrive"
                $transferConfig.Destino.OneDrive.Path = if ($OneDrivePath) { $OneDrivePath } else { "/" }
                $transferConfig.Destino.OneDrive.Token = $authResult.Token
                $transferConfig.Destino.OneDrive.RefreshToken = $authResult.RefreshToken
                $transferConfig.Destino.OneDrive.Email = $authResult.Email
                $transferConfig.Destino.OneDrive.ApiUrl = $authResult.ApiUrl
                $transferConfig.Destino.OneDrive.UseLocal = $authResult.UseLocal
                $transferConfig.Destino.OneDrive.LocalPath = $authResult.LocalPath
                $transferConfig.Destino.OneDrive.DriveId = $authResult.DriveId
                $transferConfig.DestinoIsSet = $true
            }
            else {
                Write-Host "No se pudo autenticar con OneDrive" -ForegroundColor Red
                exit 1
            }
        }
        elseif ($DropboxDestino) {
            # Dropbox especificado por parámetro
            $transferConfig.Destino.Tipo = "Dropbox"
            $transferConfig.Destino.Dropbox.Path = if ($DropboxPath) { $DropboxPath } else { "/" }
            $transferConfig.DestinoIsSet = $true
        }
        elseif ($Destino) {
            # Detectar tipo de destino según formato y parámetros
            if ($Iso) {
                # ISO especificado explícitamente
                $transferConfig.Destino.Tipo = "ISO"
                $transferConfig.Destino.ISO.OutputPath = $Destino
                $transferConfig.Destino.ISO.Size = $IsoDestino
                $transferConfig.DestinoIsSet = $true
            }
            elseif ($Destino -match '^ftp(s)?://') {
                # Es FTP - parsear URL
                if ($Destino -match '^(ftp(s)?)://([^:/]+):?(\d+)?(/.*)?$') {
                    $ftpScheme = $matches[1]
                    $ftpServer = $matches[3]
                    $ftpPort = if ($matches[4]) { [int]$matches[4] } else { 21 }
                    $ftpDirectory = if ($matches[5]) { $matches[5] } else { "/" }
                    
                    # ✅ ASIGNAR DIRECTAMENTE A $transferConfig
                    $transferConfig.Destino.Tipo = "FTP"
                    $transferConfig.Destino.FTP.Server = "$ftpScheme`://$ftpServer"
                    $transferConfig.Destino.FTP.Port = $ftpPort
                    $transferConfig.Destino.FTP.Directory = $ftpDirectory
                    $transferConfig.Destino.FTP.UseSsl = ($ftpScheme -eq "ftps")
                    $transferConfig.DestinoIsSet = $true                    
                    
                    if ($DestinationCredentials) {
                        $transferConfig.Destino.FTP.Credentials = $DestinationCredentials
                        $transferConfig.Destino.FTP.User = $DestinationCredentials.UserName
                        $transferConfig.Destino.FTP.Password = $DestinationCredentials.GetNetworkCredential().Password
                    }
                }
            }
            elseif ($Destino -match '^\\\\') {
                # Es UNC - ruta de red
                $transferConfig.Destino.Tipo = "UNC"
                $transferConfig.Destino.UNC.Path = $Destino
                $transferConfig.DestinoIsSet = $true
            }
            elseif ($Destino -ieq "FLOPPY") {
                # Diskette especificado
                $transferConfig.Destino.Tipo = "Diskette"
                $transferConfig.Destino.Diskette.OutputPath = $env:TEMP
                $transferConfig.Destino.Diskette.MaxDisks = 30
                $transferConfig.DestinoIsSet = $true
            }
            else {
                # Es Local por defecto
                $transferConfig.Destino.Tipo = "Local"
                $transferConfig.Destino.Local.Path = $Destino
                $transferConfig.DestinoIsSet = $true
            }
        }
        
        # ✅ CONFIGURAR OPCIONES GENERALES
        $transferConfig.Opciones.BlockSizeMB = $BlockSizeMB
        $transferConfig.Opciones.Clave = $Clave
        $transferConfig.Opciones.UseNativeZip = $UseNativeZip
        $transferConfig.Opciones.RobocopyMirror = $RobocopyMirror
    }
    
    # Si SOLO se configuró el origen (desde arrastrar o menú contextual), mostrar popup y menú interactivo
    if ($origenPredefinido -and -not $transferConfig.DestinoIsSet) {
        # Mostrar popup informativo
        Show-ConsolePopup -Title "Origen Configurado" `
            -Message "✓ Origen: $($transferConfig.Origen.Tipo) → $(Get-TransferPath -Config $transferConfig -Section 'Origen')`n`n⚠ Falta configurar el destino`n`nSe mostrará el menú para completar la configuración." `
            -Options @("*Continuar")
        
        # Marcar que el origen está bloqueado para el menú
        $transferConfig.OrigenBloqueado = $true
        
        # Mostrar menú interactivo con origen bloqueado
        $menuAction = Invoke-InteractiveMenu -TransferConfig $transferConfig -Ayuda:$Ayuda -Instalar:$Instalar -RobocopyMirror:$RobocopyMirror -Ejemplo:$Ejemplo -Origen $Origen -Destino $Destino -Iso:$Iso -OrigenBloqueado
        
        # Procesar acción retornada del menú
        if ($menuAction -eq "Example") {
            $exampleStartTime = Get-Date
            Invoke-NormalMode -TransferConfig $transferConfig
            $exampleElapsed = (Get-Date) - $exampleStartTime
            Show-ExampleSummary -ExampleInfo $script:ExampleInfo -TransferConfig $transferConfig -ElapsedTime $exampleElapsed
            exit
        }
    }
    # Si NO hay parámetros de origen/destino, mostrar menú normal
    elseif (-not $hasOriginDestinationParams) {        
        $menuAction = Invoke-InteractiveMenu -TransferConfig $transferConfig -Ayuda:$Ayuda -Instalar:$Instalar -RobocopyMirror:$RobocopyMirror -Ejemplo:$Ejemplo -Origen $Origen -Destino $Destino -Iso:$Iso
        
        # Procesar acción retornada del menú
        if ($menuAction -eq "Example") {
            $exampleStartTime = Get-Date
            Invoke-NormalMode -TransferConfig $transferConfig
            $exampleElapsed = (Get-Date) - $exampleStartTime
            Show-ExampleSummary -ExampleInfo $script:ExampleInfo -TransferConfig $transferConfig -ElapsedTime $exampleElapsed
            exit
        }
    }

    # ========================================================================== #
    #                     MODO NORMAL - EJECUCIÓN PRINCIPAL                      #
    # ========================================================================== #

    # Ejecutar solo si origen Y destino están configurados
    if ($transferConfig.OrigenIsSet -and $transferConfig.DestinoIsSet) {
        Invoke-NormalMode -TransferConfig $transferConfig
    }
    elseif (-not $transferConfig.OrigenIsSet -and -not $transferConfig.DestinoIsSet) {
        # Sin configuración, no hacer nada (modo ayuda, ejemplo, etc. ya se ejecutaron)
    }
    else {
        Write-Host ""
        Write-Host "ERROR: Configuración incompleta" -ForegroundColor Red
        if (-not $transferConfig.OrigenIsSet) {
            Write-Host "  - Origen no configurado" -ForegroundColor Yellow
        }
        if (-not $transferConfig.DestinoIsSet) {
            Write-Host "  - Destino no configurado" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    # ========================================================================== #
    #                         FINALIZACIÓN Y LIMPIEZA                            #
    # ========================================================================== #

    # Registrar finalización en el log (solo si está inicializado)
    if ($Global:LogFile) {
        try {
            $endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Add-Content -Path $Global:LogFile -Value "========================================" -Encoding UTF8
            Add-Content -Path $Global:LogFile -Value "Finalización: $endTime" -Encoding UTF8
            Add-Content -Path $Global:LogFile -Value "========================================" -Encoding UTF8
        }
        catch {
            # Si falla escribir al log, continuar sin fallar
        }
    }

}
catch {
    $errorTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $ex = $_.Exception

    $errorLog = @"
========================================
ERROR CRÍTICO NO MANEJADO
Fecha/Hora: $errorTime
========================================
Mensaje: $($ex.Message)
Tipo: $($ex.GetType().FullName)
Línea: $($_.InvocationInfo.ScriptLineNumber)
Comando: $($_.InvocationInfo.Line)

Stack Trace:
$($_.ScriptStackTrace)

Detalle completo:
$($_ | Out-String)
========================================
"@

    # Intentar escribir al log solo si está inicializado
    if ($Global:LogFile) {
        try {
            Add-Content -Path $Global:LogFile -Value $errorLog -Encoding UTF8
        }
        catch {
            # Si falla escribir al log, continuar sin fallar
        }
    }

    # Mostrar error en consola con formato visible
    try {
        Show-Banner "❌ ERROR CRÍTICO NO MANEJADO" -BorderColor Red -TextColor White -Padding 2
    }
    catch {
        Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║    ❌ ERROR CRÍTICO NO MANEJADO      ║" -ForegroundColor Red
        Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Mensaje: " -NoNewline -ForegroundColor Yellow
    Write-Host $ex.Message -ForegroundColor White
    Write-Host ""
    Write-Host "Línea: " -NoNewline -ForegroundColor Yellow
    Write-Host $_.InvocationInfo.ScriptLineNumber -ForegroundColor White
    Write-Host ""
    Write-Host "Comando: " -NoNewline -ForegroundColor Yellow
    Write-Host $_.InvocationInfo.Line -ForegroundColor Gray
    Write-Host ""
    Write-Host "Detalles completos guardados en:" -ForegroundColor Cyan
    Write-Host "  $Global:LogFile" -ForegroundColor Gray
    Write-Host ""

    # Detener transcript si está activo
    try { Stop-Transcript | Out-Null } catch { }

    # Pausar para que el usuario vea el error
    Read-Host "Presione ENTER para salir"
}
finally {
    # Siempre ejecutar limpieza

    # Detener transcript (si no se ha detenido previamente)
    try {
        if ($TranscriptFile) {
            Stop-Transcript | Out-Null
        }
    }
    catch {
        # Ignorar errores al detener transcript
    }

    # Mostrar ubicación de logs si el modo verbose está activo
    if ($Verbose) {
        Write-Host "`nLogs guardados en:" -ForegroundColor Cyan
        Write-Host "  - Log principal: $Global:LogFile" -ForegroundColor Gray
        if ($TranscriptFile) {
            Write-Host "  - Transcript: $TranscriptFile" -ForegroundColor Gray
        }
    }
}
