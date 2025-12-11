# Q:\Utilidad\LLevar\Modules\Core\Validation.psm1
# Módulo de validaciones para Llevar.ps1
# Proporciona funciones para validar rutas, permisos, versiones de Windows,
# detección de IDEs y validación de tipos de rutas (FTP, OneDrive, Dropbox, etc.)

# ========================================================================== #
#                          FUNCIONES DE VALIDACIÓN                           #
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

    # Si es consola clásica, trátalo como no-IDE (evita falsos positivos por env vars heredadas)
    if ($hostName -like '*ConsoleHost*') {
        return $false
    }

    # Verificar variables de entorno de VSCode (solo si no estamos en consola clásica)
    if ($env:VSCODE_PID -or $env:TERM_PROGRAM -eq 'vscode') {
        return $true
    }

    # Verificar por nombre de host
    foreach ($ide in $ideHosts) {
        if ($hostName -like "*$ide*") {
            return $true
        }
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

function Test-LlevarInstallation {
    <#
    .SYNOPSIS
        Verifica si Llevar está instalado en C:\Llevar
    .DESCRIPTION
        Comprueba la existencia del directorio de instalación
    #>
    
    $installPath = "C:\Llevar"
    return (Test-Path $installPath)
}

function Test-Windows10OrLater {
    <#
    .SYNOPSIS
        Detecta si el sistema operativo es Windows 10 o posterior
    .DESCRIPTION
        Verifica la versión del sistema operativo
    #>
    
    $version = [System.Environment]::OSVersion.Version
    return ($version.Major -ge 10)
}

# Test-PathWritable → Migrado a Modules/System/FileSystem.psm1

function Test-IsFtpPath {
    <#
    .SYNOPSIS
        Detecta si una ruta es de tipo FTP
    .DESCRIPTION
        Verifica si la ruta comienza con ftp:// o ftps://
    .PARAMETER Path
        Ruta a evaluar
    #>
    param([string]$Path)
    
    return ($Path -match '^ftp://|^ftps://')
}

function Test-IsOneDrivePath {
    <#
    .SYNOPSIS
        Detecta si una ruta es de tipo OneDrive
    .DESCRIPTION
        Verifica si la ruta comienza con ONEDRIVE:
    .PARAMETER Path
        Ruta a evaluar
    #>
    param([string]$Path)
    
    return ($Path -match '^ONEDRIVE:')
}

function Test-IsDropboxPath {
    <#
    .SYNOPSIS
        Detecta si una ruta es de tipo Dropbox
    .DESCRIPTION
        Verifica si la ruta comienza con DROPBOX:
    .PARAMETER Path
        Ruta a evaluar
    #>
    param([string]$Path)
    
    return ($Path -match '^DROPBOX:')
}

function Test-IsUncPath {
    <#
    .SYNOPSIS
        Detecta si una ruta es de tipo UNC (red)
    .DESCRIPTION
        Verifica si la ruta comienza con \\
    .PARAMETER Path
        Ruta a evaluar
    #>
    param([string]$Path)
    
    return ($Path -match '^\\\\')
}

function Test-DestinoType {
    <#
    .SYNOPSIS
        Determina el tipo de destino
    .DESCRIPTION
        Clasifica el destino como USB, FTP, Local u otro
    .PARAMETER Destino
        Ruta de destino a clasificar
    #>
    param([string]$Destino)

    if ($Destino -match '^[A-Z]:\\$') {
        $drive = Get-Volume -DriveLetter $Destino[0] -ErrorAction SilentlyContinue
        if ($drive -and $drive.DriveType -eq 'Removable') {
            return "USB"
        }
    }
    
    if (Test-Path $Destino -PathType Container) {
        return "Local"
    }
    
    return "Unknown"
}

# Test-PathWritable → Migrado a Modules/System/FileSystem.psm1

# ========================================================================== #
#                          EXPORTAR FUNCIONES                                #
# ========================================================================== #

Export-ModuleMember -Function @(
    'Test-IsRunningInIDE',
    'Test-LlevarInstallation',
    'Test-Windows10OrLater',
    'Test-IsFtpPath',
    'Test-IsOneDrivePath',
    'Test-IsDropboxPath',
    'Test-IsUncPath',
    'Test-DestinoType'
)
