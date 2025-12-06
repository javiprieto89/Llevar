# Importar clases de TransferConfig (using module DEBE estar al INICIO del archivo)
using module "Q:\Utilidad\LLevar\Modules\Core\TransferConfig.psm1"

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
    [ValidateSet("local", "iso-cd", "iso-dvd", "ftp", "onedrive", "dropbox")]
    [string]$TipoEjemplo = "local",
    [switch]$Instalar,
    [Alias('h')]
    [switch]$Ayuda,
    [ValidateSet("Navigator", "FTP", "OneDrive", "Dropbox", "Compression", "Robocopy", "UNC", "USB", "ISO")]
    [string]$Test,
    [switch]$OnedriveOrigen,
    [switch]$OnedriveDestino,
    [switch]$DropboxOrigen,
    [switch]$DropboxDestino,
    [switch]$RobocopyMirror,
    [switch]$Verbose
)

# ========================================================================== #
#                    INICIALIZACIÓN TEMPRANA DE LOGGING                      #
# ========================================================================== #

# Crear carpeta de logs si no existe
$Global:ScriptDir = $PSScriptRoot
$Global:LogsDir = Join-Path $Global:ScriptDir "Logs"
if (-not (Test-Path $Global:LogsDir)) {
    New-Item -Path $Global:LogsDir -ItemType Directory -Force | Out-Null
}

# Nombre del log con fecha, hora y minuto
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$Global:LogFile = Join-Path $Global:LogsDir "LLEVAR_$timestamp.log"

# Iniciar transcript para capturar TODA la salida (incluyendo warnings de importación)
$TranscriptFile = Join-Path $Global:LogsDir "LLEVAR_TRANSCRIPT_$timestamp.log"
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
Add-Content -Path $Global:LogFile -Value $initLog -Encoding UTF8

# ========================================================================== #
#                   WRAPPER DE MANEJO DE ERRORES GLOBAL                      #
# ========================================================================== #

try {
    # Configurar preferencias de error para capturar todo
    $ErrorActionPreference = 'Continue'

    # ========================================================================== #
    #                        IMPORTAR TODOS LOS MÓDULOS                          #
    # ========================================================================== #

    $ModulesPath = Join-Path $PSScriptRoot "Modules"

    # Redirigir warnings durante importación de módulos
    $oldWarningPref = $WarningPreference
    $WarningPreference = 'Continue'

    # Módulos Core
    Import-Module (Join-Path $ModulesPath "Core\Validation.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Core\Config.psm1") -Force -Global -WarningVariable +importWarnings
    # TransferConfig.psm1 ya importado con "using module" al inicio del archivo

    # Módulos UI
    Import-Module (Join-Path $ModulesPath "UI\Console.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "UI\ProgressBar.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "UI\Banners.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "UI\Navigator.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "UI\Menus.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "UI\ConfigMenus.psm1") -Force -Global -WarningVariable +importWarnings

    # Módulos de Compresión
    Import-Module (Join-Path $ModulesPath "Compression\SevenZip.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Compression\NativeZip.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Compression\BlockSplitter.psm1") -Force -Global -WarningVariable +importWarnings

    # Módulos de Transferencia
    Import-Module (Join-Path $ModulesPath "Transfer\Local.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Transfer\FTP.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Transfer\UNC.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Transfer\OneDrive.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Transfer\Dropbox.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Transfer\Floppy.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Transfer\Unified.psm1") -Force -Global -WarningVariable +importWarnings

    # Módulos de Instalación
    Import-Module (Join-Path $ModulesPath "Installation\SystemInstall.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Installation\Installer.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Installation\ISO.psm1") -Force -Global -WarningVariable +importWarnings

    # Módulos de Utilidades
    Import-Module (Join-Path $ModulesPath "Utilities\Installation.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Utilities\Examples.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Utilities\Help.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Utilities\PathSelectors.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Utilities\VolumeManagement.psm1") -Force -Global -WarningVariable +importWarnings

    # Módulos del Sistema
    Import-Module (Join-Path $ModulesPath "System\Audio.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "System\FileSystem.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "System\Robocopy.psm1") -Force -Global -WarningVariable +importWarnings

    # Módulos de Parámetros
    Import-Module (Join-Path $ModulesPath "Parameters\Help.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Parameters\Install.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Parameters\Example.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Parameters\Test.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Parameters\Robocopy.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Parameters\InteractiveMenu.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Parameters\InstallationCheck.psm1") -Force -Global -WarningVariable +importWarnings
    Import-Module (Join-Path $ModulesPath "Parameters\NormalMode.psm1") -Force -Global -WarningVariable +importWarnings
    
    # Restaurar preferencia de warnings
    $WarningPreference = $oldWarningPref
    
    # Registrar warnings de importacion en el log (sin mostrar en consola)
    if ($importWarnings -and $importWarnings.Count -gt 0) {
        $warningLog = "`n[WARNINGS DURANTE IMPORTACION DE MODULOS]`n"
        foreach ($warning in $importWarnings) {
            $warningLog += "  - $warning`n"
        }
        Add-Content -Path $Global:LogFile -Value $warningLog -Encoding UTF8
        
        # Solo mostrar en verbose
        if ($Verbose) {
            Write-Host "[DEBUG] Se registraron $($importWarnings.Count) advertencias de módulos en el log" -ForegroundColor DarkGray
        }
    }

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

    # Solo pedir elevación si NO es administrador Y NO está en IDE
    $needsElevation = -not $isAdmin -and -not $isInIDE

    if ($needsElevation) {
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
        if ($Verbose) { $arguments += "-Verbose" }
    
        # Relanzar con privilegios de administrador
        Start-Process pwsh.exe -Verb RunAs -ArgumentList $arguments
        exit
    }

    # ========================================================================== #
    #                            INICIALIZACIÓN                                  #
    # ========================================================================== #

    # Inicializar sistema de logs
    Initialize-LogFile -Verbose:$Verbose

    # Inicializar consola si es necesario (solo si hay consola válida)
    $hostName = $host.Name
    if ($hostName -and ($hostName -ilike '*consolehost*' -or $hostName -ilike '*visual studio code host*')) {
        try {
            $rawUI = $host.UI.RawUI
            if ($rawUI) {
                $rawUI.BackgroundColor = 'Black'
                $rawUI.ForegroundColor = 'White'
                Clear-Host
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
    $hasExecutionParams = ($Origen -or $Destino -or $RobocopyMirror -or $Ejemplo -or $Ayuda -or $Instalar -or $Test)

    # ========================================================================== #
    #                        LOGO Y MENSAJE DE BIENVENIDA                        #
    # ========================================================================== #
    
    # Variable para rastrear si se mostró el logo
    $script:LogoWasShown = $false
    
    # Mostrar logo ASCII si existe (solo si NO está en IDE y NO hay parámetros de ejecución)
    if (-not $isInIDE -and -not $hasExecutionParams) {
        $logoPath = Join-Path $PSScriptRoot "Data\alexsoft.txt"
        if (Test-Path $logoPath) {
            try {
                # Usar Show-AsciiLogo como renderer unificado para el logo con sonidos estilo DOS    
                Show-AsciiLogo -Path $logoPath -DelayMs 30 -ShowProgress $true -Label "Cargando..." -ForegroundColor Gray -PlaySound $true
                $script:LogoWasShown = $true
                    
                # Limpiar pantalla después de cargar el logo
                Clear-Host
                
                # Mostrar mensaje de bienvenida personalizado parpadeante
                Show-WelcomeMessage -BlinkCount 3 -VisibleDelayMs 450 -TextColor Cyan
                
                # Limpiar para mostrar el menú
                Clear-Host
            }
            catch {
                # Si hay error en el logo, simplemente continuar
                Write-Log "Error mostrando logo ASCII: $($_.Exception.Message)" "WARNING"
                Clear-Host
            }
        }
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

    # 3. Verificar parámetro -RobocopyMirror
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

    # 6. Verificar si no hay parámetros (modo interactivo)
    $menuConfig = Invoke-InteractiveMenu -Ayuda:$Ayuda -Instalar:$Instalar -RobocopyMirror:$RobocopyMirror -Ejemplo:$Ejemplo -Origen $Origen -Destino $Destino -Iso:$Iso

    # Variable para almacenar el TransferConfig (tipada)
    [TransferConfig]$transferConfig = $null

    # Si el menú interactivo devolvió configuración, extraerla
    if ($null -ne $menuConfig) {
        # Verificar si es modo ejemplo o ayuda (sin TransferConfig)
        if ($menuConfig.Action -eq "Example") {
            $Ejemplo = $menuConfig.Ejemplo
        }
        elseif ($menuConfig.Action -eq "Execute" -and $menuConfig.ContainsKey('TransferConfig')) {
            # Usar TransferConfig del menú interactivo (ya viene configurado)
            $transferConfig = [TransferConfig]$menuConfig.TransferConfig
        }
    }

    # Si no hay TransferConfig del menú y hay parámetros, crear TransferConfig
    # Detectar tipo automáticamente según parámetros disponibles
    if (-not $transferConfig -and ($Origen -or $Destino -or $OnedriveOrigen -or $OnedriveDestino -or $DropboxOrigen -or $DropboxDestino)) {
        $transferConfig = [TransferConfig](New-TransferConfig)
        
        # ===== DETECTAR Y CONFIGURAR ORIGEN =====
        if ($Origen) {
            # Detectar tipo de origen según formato del path
            if ($Origen -match '^ftp(s)?://') {
                # Es FTP - parsear URL
                if ($Origen -match '^(ftp(s)?)://([^:/]+):?(\d+)?(/.*)?$') {
                    $ftpScheme = $matches[1]
                    $ftpServer = $matches[3]
                    $ftpPort = if ($matches[4]) { [int]$matches[4] } else { 21 }
                    $ftpDirectory = if ($matches[5]) { $matches[5] } else { "/" }
                    
                    # Extraer credenciales si existen
                    $ftpUser = if ($SourceCredentials) { $SourceCredentials.UserName } else { "" }
                    $ftpPass = if ($SourceCredentials) { $SourceCredentials.GetNetworkCredential().Password } else { "" }
                    
                    Set-TransferConfigOrigen -Config $transferConfig -Tipo "FTP" -Parametros @{
                        Server    = $ftpServer
                        Port      = $ftpPort
                        User      = $ftpUser
                        Password  = $ftpPass
                        UseSsl    = ($ftpScheme -eq "ftps")
                        Directory = $ftpDirectory
                    }
                }
            }
            elseif ($Origen -match '^\\\\') {
                # Es UNC - ruta de red
                Set-TransferConfigOrigen -Config $transferConfig -Tipo "UNC" -Parametros @{
                    Path        = $Origen
                    Credentials = $SourceCredentials
                }
            }
            elseif ($OnedriveOrigen) {
                # OneDrive especificado por parámetro
                Set-TransferConfigOrigen -Config $transferConfig -Tipo "OneDrive" -Parametros @{
                    Path = $Origen
                }
            }
            elseif ($DropboxOrigen) {
                # Dropbox especificado por parámetro
                Set-TransferConfigOrigen -Config $transferConfig -Tipo "Dropbox" -Parametros @{
                    Path = $Origen
                }
            }
            else {
                # Es Local por defecto
                Set-TransferConfigOrigen -Config $transferConfig -Tipo "Local" -Parametros @{ 
                    Path = $Origen 
                }
            }
        }
        
        # ===== DETECTAR Y CONFIGURAR DESTINO =====
        if ($Destino) {
            # Detectar tipo de destino según formato y parámetros
            if ($Iso) {
                # ISO especificado explícitamente
                Set-TransferConfigDestino -Config $transferConfig -Tipo "ISO" -Parametros @{ 
                    OutputPath = $Destino
                    Size       = $IsoDestino
                }
            }
            elseif ($Destino -match '^ftp(s)?://') {
                # Es FTP - parsear URL
                if ($Destino -match '^(ftp(s)?)://([^:/]+):?(\d+)?(/.*)?$') {
                    $ftpScheme = $matches[1]
                    $ftpServer = $matches[3]
                    $ftpPort = if ($matches[4]) { [int]$matches[4] } else { 21 }
                    $ftpDirectory = if ($matches[5]) { $matches[5] } else { "/" }
                    
                    # Extraer credenciales si existen
                    $ftpUser = if ($DestinationCredentials) { $DestinationCredentials.UserName } else { "" }
                    $ftpPass = if ($DestinationCredentials) { $DestinationCredentials.GetNetworkCredential().Password } else { "" }
                    
                    Set-TransferConfigDestino -Config $transferConfig -Tipo "FTP" -Parametros @{
                        Server    = $ftpServer
                        Port      = $ftpPort
                        User      = $ftpUser
                        Password  = $ftpPass
                        UseSsl    = ($ftpScheme -eq "ftps")
                        Directory = $ftpDirectory
                    }
                }
            }
            elseif ($Destino -match '^\\\\') {
                # Es UNC - ruta de red
                Set-TransferConfigDestino -Config $transferConfig -Tipo "UNC" -Parametros @{
                    Path        = $Destino
                    Credentials = $DestinationCredentials
                }
            }
            elseif ($OnedriveDestino) {
                # OneDrive especificado por parámetro
                Set-TransferConfigDestino -Config $transferConfig -Tipo "OneDrive" -Parametros @{
                    Path = $Destino
                }
            }
            elseif ($DropboxDestino) {
                # Dropbox especificado por parámetro
                Set-TransferConfigDestino -Config $transferConfig -Tipo "Dropbox" -Parametros @{
                    Path = $Destino
                }
            }
            elseif ($Destino -ieq "FLOPPY") {
                # Diskette especificado
                Set-TransferConfigDestino -Config $transferConfig -Tipo "Diskette" -Parametros @{
                    OutputPath = $env:TEMP
                    MaxDisks   = 30
                }
            }
            else {
                # Es Local por defecto
                Set-TransferConfigDestino -Config $transferConfig -Tipo "Local" -Parametros @{ 
                    Path = $Destino 
                }
            }
        }
        
        # Configurar opciones generales
        $transferConfig.Opciones.BlockSizeMB = $BlockSizeMB
        $transferConfig.Opciones.Clave = $Clave
        $transferConfig.Opciones.UseNativeZip = $UseNativeZip
        $transferConfig.Opciones.RobocopyMirror = $RobocopyMirror
    }

    # ========================================================================== #
    #                     MODO NORMAL - EJECUCIÓN PRINCIPAL                      #
    # ========================================================================== #

    # Invocar modo normal con TransferConfig unificado
    if ($transferConfig) {
        Invoke-NormalMode -TransferConfig $transferConfig
    }

    # ========================================================================== #
    #                         FINALIZACIÓN Y LIMPIEZA                            #
    # ========================================================================== #

    # Registrar finalización en el log
    $endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $Global:LogFile -Value "`n========================================" -Encoding UTF8
    Add-Content -Path $Global:LogFile -Value "Finalización: $endTime" -Encoding UTF8
    Add-Content -Path $Global:LogFile -Value "========================================" -Encoding UTF8

}
catch {
    # Capturar cualquier error no manejado
    $errorTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $errorLog = @"

========================================
ERROR CRÍTICO NO MANEJADO
Fecha/Hora: $errorTime
========================================
Mensaje: $($_.Exception.Message)
Tipo: $($_.Exception.GetType().FullName)
Línea: $($_.InvocationInfo.ScriptLineNumber)
Comando: $($_.InvocationInfo.Line)

Stack Trace:
$($_.ScriptStackTrace)

Detalle completo:
$($_ | Out-String)
========================================
"@
    
    Add-Content -Path $Global:LogFile -Value $errorLog -Encoding UTF8
    
    # Mostrar error en consola con formato visible
    Write-Host "`n" -ForegroundColor Red
    Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║    ❌ ERROR CRÍTICO NO MANEJADO      ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "Mensaje: " -NoNewline -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor White
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

    # Detener transcript
    try {
        if ($TranscriptFile) {
            Stop-Transcript | Out-Null
        }
    }
    catch {
        # Transcript puede no estar activo en algunos contextos
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
