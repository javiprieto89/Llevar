# ========================================================================== #
#                  MÓDULO: CONFIGURACIÓN DE TRANSFERENCIA                    #
# ========================================================================== #
# Propósito: Funciones de helper que manipulan el tipo TransferConfig
# El tipo TransferConfig se define en Core\TransferConfig.Type.ps1 y debe cargarse
# antes de importar este módulo (Llevar.ps1 ya lo hace).
# ========================================================================== #
# ========================================================================== #
#                         FUNCIONES HELPER                                   #
# ========================================================================== #

function New-TransferConfig {
    <#
    .SYNOPSIS
        Crea un objeto de configuración unificado para transferencias
    .DESCRIPTION
        Crea una instancia del tipo TransferConfig con toda la estructura
        jerárquica inicializada. Este es el tipo de dato oficial para
        toda configuración de transferencia en LLEVAR.
    .OUTPUTS
        [TransferConfig] Objeto con estructura completa inicializada
    #>
    
    return [TransferConfig]::new()
}

function Get-TransferConfigValue {
    <#
    .SYNOPSIS
        Obtiene un valor de la configuración mediante notación de punto
    .DESCRIPTION
        Navega por la estructura de TransferConfig y retorna el valor solicitado.
        Soporta rutas como "Opciones.BlockSizeMB" o "Origen.FTP.Server"
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Path
        Ruta al valor usando notación de punto (ej: "Origen.FTP.Server", "Opciones.BlockSizeMB")
    .EXAMPLE
        $blockSize = Get-TransferConfigValue -Config $cfg -Path "Opciones.BlockSizeMB"
    .EXAMPLE
        $ftpServer = Get-TransferConfigValue -Config $cfg -Path "Origen.FTP.Server"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    $parts = $Path -split '\.'
    $current = $Config
    
    foreach ($part in $parts) {
        if ($current.PSObject.Properties.Name -contains $part) {
            $current = $current.$part
        }
        else {
            Write-Warning "Ruta no encontrada en TransferConfig: $Path (parte: $part)"
            return $null
        }
    }
    
    return $current
}

function Set-TransferConfigValue {
    <#
    .SYNOPSIS
        Establece un valor en la configuración mediante notación de punto
    .DESCRIPTION
        Navega por la estructura de TransferConfig y establece el valor solicitado.
        Soporta rutas como "Opciones.BlockSizeMB" o "Origen.FTP.Server"
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Path
        Ruta al valor usando notación de punto (ej: "Origen.FTP.Server", "Opciones.Clave")
    .PARAMETER Value
        Nuevo valor a establecer
    .EXAMPLE
        Set-TransferConfigValue -Config $cfg -Path "Opciones.BlockSizeMB" -Value 50
    .EXAMPLE
        Set-TransferConfigValue -Config $cfg -Path "Origen.FTP.Server" -Value "ftp.example.com"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        $Value
    )
    
    $parts = $Path -split '\.'
    $current = $Config
    
    # Navegar hasta el penúltimo elemento
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        $part = $parts[$i]
        if ($current.PSObject.Properties.Name -contains $part) {
            $current = $current.$part
        }
        else {
            throw "Ruta de configuración inválida en TransferConfig: $Path (parte: $part no existe)"
        }
    }
    
    # Establecer el valor en la última propiedad
    $lastPart = $parts[$parts.Count - 1]
    if ($current.PSObject.Properties.Name -contains $lastPart) {
        $current.$lastPart = $Value
    }
    else {
        throw "Propiedad no existe en TransferConfig: $lastPart en ruta $Path"
    }
}

function Get-TransferPath {
    <#
    .SYNOPSIS
        Obtiene la ruta de origen o destino según el tipo configurado
    .DESCRIPTION
        Simplifica el acceso a la ruta correcta según el tipo de transferencia.
        Detecta automáticamente qué propiedad usar (Path, Directory, OutputPath)
        según el tipo configurado (Local, FTP, OneDrive, ISO, etc.)
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        "Origen" o "Destino"
    .OUTPUTS
        [string] Ruta configurada según el tipo, o $null si no hay tipo configurado
    .EXAMPLE
        $origenPath = Get-TransferPath -Config $cfg -Section "Origen"
    .EXAMPLE
        $destinoPath = Get-TransferPath -Config $cfg -Section "Destino"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section
    )
    
    $tipo = Get-TransferConfigValue -Config $Config -Path "${Section}.Tipo"
    
    switch ($tipo) {
        "Local" { Get-TransferConfigValue -Config $Config -Path "${Section}.Local.Path" }
        "USB" { Get-TransferConfigValue -Config $Config -Path "${Section}.USB.Path" }
        "UNC" { Get-TransferConfigValue -Config $Config -Path "${Section}.UNC.Path" }
        "FTP" { Get-TransferConfigValue -Config $Config -Path "${Section}.FTP.Directory" }
        "OneDrive" { Get-TransferConfigValue -Config $Config -Path "${Section}.OneDrive.Path" }
        "Dropbox" { Get-TransferConfigValue -Config $Config -Path "${Section}.Dropbox.Path" }
        "ISO" { Get-TransferConfigValue -Config $Config -Path "${Section}.ISO.OutputPath" }
        "Diskette" { Get-TransferConfigValue -Config $Config -Path "${Section}.Diskette.OutputPath" }
        default { $null }
    }
}

function Set-TransferPath {
    <#
    .SYNOPSIS
        Establece la ruta de origen o destino según el tipo configurado
    .DESCRIPTION
        Detecta automáticamente qué propiedad usar (Path, Directory, OutputPath)
        según el tipo configurado y establece el valor.
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        "Origen" o "Destino"
    .PARAMETER Value
        Nueva ruta a establecer
    .EXAMPLE
        Set-TransferPath -Config $cfg -Section "Destino" -Value "C:\Temp"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section,
        
        [Parameter(Mandatory = $true)]
        [string]$Value
    )
    
    $tipo = Get-TransferConfigValue -Config $Config -Path "${Section}.Tipo"
    
    if (-not $tipo) {
        throw "No se ha configurado el tipo de ${Section}. Use Set-TransferType primero."
    }
    
    $path = switch ($tipo) {
        "Local" { "${Section}.Local.Path" }
        "USB" { "${Section}.USB.Path" }
        "UNC" { "${Section}.UNC.Path" }
        "FTP" { "${Section}.FTP.Directory" }
        "OneDrive" { "${Section}.OneDrive.Path" }
        "Dropbox" { "${Section}.Dropbox.Path" }
        "ISO" { "${Section}.ISO.OutputPath" }
        "Diskette" { "${Section}.Diskette.OutputPath" }
        default { throw "Tipo no válido para ${Section}: $tipo" }
    }
    
    Set-TransferConfigValue -Config $Config -Path $path -Value $Value
}

function Get-TransferType {
    <#
    .SYNOPSIS
        Obtiene el tipo de transferencia (Local, FTP, etc.)
    .DESCRIPTION
        Simplifica el acceso al tipo de origen o destino configurado.
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        "Origen" o "Destino"
    .OUTPUTS
        [string] Tipo configurado o $null si no está configurado
    .EXAMPLE
        $tipo = Get-TransferType -Config $cfg -Section "Origen"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section
    )
    
    return Get-TransferConfigValue -Config $Config -Path "${Section}.Tipo"
}

function Set-TransferType {
    <#
    .SYNOPSIS
        Establece el tipo de transferencia
    .DESCRIPTION
        Configura el tipo de origen o destino (Local, FTP, USB, etc.)
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        "Origen" o "Destino"
    .PARAMETER Type
        Tipo: "Local", "FTP", "USB", "UNC", "OneDrive", "Dropbox", "ISO", "Diskette"
    .EXAMPLE
        Set-TransferType -Config $cfg -Section "Destino" -Type "FTP"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Local", "FTP", "USB", "UNC", "OneDrive", "Dropbox", "ISO", "Diskette")]
        [string]$Type
    )
    
    Set-TransferConfigValue -Config $Config -Path "${Section}.Tipo" -Value $Type
}

function Get-FTPConfig {
    <#
    .SYNOPSIS
        Obtiene la configuración FTP completa
    .DESCRIPTION
        Retorna el objeto completo con la configuración FTP (Server, Port, User, Password, UseSsl, Directory)
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        "Origen" o "Destino"
    .OUTPUTS
        [PSCustomObject] Objeto con Server, Port, User, Password, Credentials, UseSsl, Directory
    .EXAMPLE
        $ftp = Get-FTPConfig -Config $cfg -Section "Origen"
        Write-Host $ftp.Server
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section
    )
    
    return Get-TransferConfigValue -Config $Config -Path "${Section}.FTP"
}

function Set-FTPConfig {
    <#
    .SYNOPSIS
        Establece la configuración FTP completa
    .DESCRIPTION
        Configura todos los parámetros FTP de una vez.
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        "Origen" o "Destino"
    .PARAMETER Server
        Servidor FTP
    .PARAMETER Port
        Puerto (por defecto 21)
    .PARAMETER User
        Usuario
    .PARAMETER Password
        Contraseña
    .PARAMETER Credentials
        Objeto PSCredential (alternativa a User/Password)
    .PARAMETER UseSsl
        Usar SSL (por defecto $false)
    .PARAMETER Directory
        Directorio inicial (por defecto "/")
    .EXAMPLE
        Set-FTPConfig -Config $cfg -Section "Origen" -Server "ftp.example.com" -User "user" -Password "pass"
    .EXAMPLE
        Set-FTPConfig -Config $cfg -Section "Destino" -Server "ftp.example.com" -Credentials $cred
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section,
        
        [Parameter(Mandatory = $true)]
        [string]$Server,
        
        [int]$Port = 21,
        [string]$User,
        [ArgumentTransformationAttribute({
            if ($_ -is [string]) {
                ConvertTo-SecureString -String $_ -AsPlainText -Force
            }
            else {
                $_
            }
        })]
        [SecureString]$Password,
        [PSCredential]$Credentials,
        [bool]$UseSsl = $false,
        [string]$Directory = "/"
    )
    
    Set-TransferConfigValue -Config $Config -Path "${Section}.FTP.Server" -Value $Server
    Set-TransferConfigValue -Config $Config -Path "${Section}.FTP.Port" -Value $Port
    
    if ($User) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.FTP.User" -Value $User
    }
    if ($Password) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.FTP.Password" -Value $Password
    }
    if ($Credentials) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.FTP.Credentials" -Value $Credentials
    }
    
    Set-TransferConfigValue -Config $Config -Path "${Section}.FTP.UseSsl" -Value $UseSsl
    Set-TransferConfigValue -Config $Config -Path "${Section}.FTP.Directory" -Value $Directory
}

function Get-TransferOption {
    <#
    .SYNOPSIS
        Obtiene una opción de transferencia
    .DESCRIPTION
        Simplifica el acceso a opciones comunes (BlockSizeMB, Clave, UseNativeZip, etc.)
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Option
        Nombre de la opción: BlockSizeMB, Clave, UseNativeZip, RobocopyMirror, TransferMode, Verbose
    .OUTPUTS
        Valor de la opción solicitada
    .EXAMPLE
        $blockSize = Get-TransferOption -Config $cfg -Option "BlockSizeMB"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("BlockSizeMB", "Clave", "UseNativeZip", "RobocopyMirror", "TransferMode", "Verbose")]
        [string]$Option
    )
    
    return Get-TransferConfigValue -Config $Config -Path "Opciones.$Option"
}

function Set-TransferOption {
    <#
    .SYNOPSIS
        Establece una opción de transferencia
    .DESCRIPTION
        Simplifica la configuración de opciones comunes.
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Option
        Nombre de la opción
    .PARAMETER Value
        Nuevo valor
    .EXAMPLE
        Set-TransferOption -Config $cfg -Option "BlockSizeMB" -Value 50
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("BlockSizeMB", "Clave", "UseNativeZip", "RobocopyMirror", "TransferMode", "Verbose")]
        [string]$Option,
        
        [Parameter(Mandatory = $true)]
        $Value
    )
    
    Set-TransferConfigValue -Config $Config -Path "Opciones.$Option" -Value $Value
}

# ========================================================================== #
#                FUNCIONES HELPER PARA CLOUD Y NETWORK                       #
# ========================================================================== #

function Get-OneDriveConfig {
    <#
    .SYNOPSIS
        Obtiene la configuración OneDrive completa
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        "Origen" o "Destino"
    .OUTPUTS
        [PSCustomObject] Objeto con Path, Token, RefreshToken, Email, ApiUrl, UseLocal, LocalPath, DriveId, RootId
    .EXAMPLE
        $onedrive = Get-OneDriveConfig -Config $cfg -Section "Origen"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section
    )
    
    return Get-TransferConfigValue -Config $Config -Path "${Section}.OneDrive"
}

function Set-OneDriveConfig {
    <#
    .SYNOPSIS
        Establece la configuración OneDrive
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        "Origen" o "Destino"
    .PARAMETER Path
        Ruta en OneDrive (ej: "/Documents/LLEVAR")
    .PARAMETER Token
        Token de acceso OAuth
    .PARAMETER RefreshToken
        Token de actualización OAuth
    .PARAMETER Email
        Email de la cuenta OneDrive
    .PARAMETER UseLocal
        Usar sincronización local ($true) o API ($false)
    .PARAMETER LocalPath
        Ruta local si UseLocal es $true
    .EXAMPLE
        Set-OneDriveConfig -Config $cfg -Section "Destino" -Path "/LLEVAR" -Token $token -Email "user@outlook.com"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section,
        
        [string]$Path,
        [string]$Token,
        [string]$RefreshToken,
        [string]$Email,
        [bool]$UseLocal,
        [string]$LocalPath
    )
    
    if ($Path) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.OneDrive.Path" -Value $Path
    }
    if ($Token) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.OneDrive.Token" -Value $Token
    }
    if ($RefreshToken) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.OneDrive.RefreshToken" -Value $RefreshToken
    }
    if ($Email) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.OneDrive.Email" -Value $Email
    }
    if ($PSBoundParameters.ContainsKey('UseLocal')) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.OneDrive.UseLocal" -Value $UseLocal
    }
    if ($LocalPath) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.OneDrive.LocalPath" -Value $LocalPath
    }
}

function Get-DropboxConfig {
    <#
    .SYNOPSIS
        Obtiene la configuración Dropbox completa
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        "Origen" o "Destino"
    .OUTPUTS
        [PSCustomObject] Objeto con Path, Token, RefreshToken, Email, ApiUrl
    .EXAMPLE
        $dropbox = Get-DropboxConfig -Config $cfg -Section "Origen"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section
    )
    
    return Get-TransferConfigValue -Config $Config -Path "${Section}.Dropbox"
}

function Set-DropboxConfig {
    <#
    .SYNOPSIS
        Establece la configuración Dropbox
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        "Origen" o "Destino"
    .PARAMETER Path
        Ruta en Dropbox (ej: "/LLEVAR")
    .PARAMETER Token
        Token de acceso OAuth
    .PARAMETER RefreshToken
        Token de actualización OAuth
    .PARAMETER Email
        Email de la cuenta Dropbox
    .EXAMPLE
        Set-DropboxConfig -Config $cfg -Section "Destino" -Path "/LLEVAR" -Token $token -Email "user@dropbox.com"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section,
        
        [string]$Path,
        [string]$Token,
        [string]$RefreshToken,
        [string]$Email
    )
    
    if ($Path) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.Dropbox.Path" -Value $Path
    }
    if ($Token) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.Dropbox.Token" -Value $Token
    }
    if ($RefreshToken) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.Dropbox.RefreshToken" -Value $RefreshToken
    }
    if ($Email) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.Dropbox.Email" -Value $Email
    }
}

function Get-UNCConfig {
    <#
    .SYNOPSIS
        Obtiene la configuración UNC completa
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        "Origen" o "Destino"
    .OUTPUTS
        [PSCustomObject] Objeto con Path, User, Password, Domain, Credentials
    .EXAMPLE
        $unc = Get-UNCConfig -Config $cfg -Section "Origen"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section
    )
    
    return Get-TransferConfigValue -Config $Config -Path "${Section}.UNC"
}

function Set-UNCConfig {
    <#
    .SYNOPSIS
        Establece la configuración UNC
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        "Origen" o "Destino"
    .PARAMETER Path
        Ruta UNC (ej: "\\\\servidor\\carpeta")
    .PARAMETER User
        Usuario para autenticación
    .PARAMETER Password
        Contraseña
    .PARAMETER Domain
        Dominio (opcional)
    .PARAMETER Credentials
        Objeto PSCredential (alternativa a User/Password)
    .EXAMPLE
        Set-UNCConfig -Config $cfg -Section "Origen" -Path "\\\\servidor\\share" -User "admin" -Password "pass"
    .EXAMPLE
        Set-UNCConfig -Config $cfg -Section "Origen" -Path "\\\\servidor\\share" -Credentials $cred
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section,
        
        [string]$Path,
        [string]$User,
        [ArgumentTransformationAttribute({
            if ($_ -is [string]) {
                ConvertTo-SecureString -String $_ -AsPlainText -Force
            }
            else {
                $_
            }
        })]
        [SecureString]$Password,
        [string]$Domain,
        [PSCredential]$Credentials
    )
    
    if ($Path) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.UNC.Path" -Value $Path
    }
    if ($User) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.UNC.User" -Value $User
    }
    if ($Password) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.UNC.Password" -Value $Password
    }
    if ($Domain) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.UNC.Domain" -Value $Domain
    }
    if ($Credentials) {
        Set-TransferConfigValue -Config $Config -Path "${Section}.UNC.Credentials" -Value $Credentials
    }
}

function Get-LocalConfig {
    <#
    .SYNOPSIS
        Obtiene la configuración Local (ruta local)
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        "Origen" o "Destino"
    .OUTPUTS
        [PSCustomObject] Objeto con Path
    .EXAMPLE
        $local = Get-LocalConfig -Config $cfg -Section "Origen"
        Write-Host $local.Path
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section
    )
    
    return Get-TransferConfigValue -Config $Config -Path "${Section}.Local"
}

function Set-LocalConfig {
    <#
    .SYNOPSIS
        Establece la configuración Local
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        "Origen" o "Destino"
    .PARAMETER Path
        Ruta local (ej: "C:\\Data")
    .EXAMPLE
        Set-LocalConfig -Config $cfg -Section "Origen" -Path "C:\\Data"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section,
        
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    Set-TransferConfigValue -Config $Config -Path "${Section}.Local.Path" -Value $Path
}

function Get-ISOConfig {
    <#
    .SYNOPSIS
        Obtiene la configuración ISO (solo para Destino)
    .PARAMETER Config
        Objeto TransferConfig
    .OUTPUTS
        [PSCustomObject] Objeto con OutputPath, Size, VolumeSize, VolumeName
    .EXAMPLE
        $iso = Get-ISOConfig -Config $cfg
        Write-Host $iso.OutputPath
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config
    )
    
    return Get-TransferConfigValue -Config $Config -Path "Destino.ISO"
}

function Set-ISOConfig {
    <#
    .SYNOPSIS
        Establece la configuración ISO
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER OutputPath
        Ruta donde crear la imagen ISO
    .PARAMETER Size
        Tamaño: "cd" (650MB), "dvd" (4.7GB), "usb" (4.5GB)
    .PARAMETER VolumeSize
        Tamaño personalizado en MB (anula Size)
    .PARAMETER VolumeName
        Nombre del volumen ISO (por defecto "LLEVAR")
    .EXAMPLE
        Set-ISOConfig -Config $cfg -OutputPath "C:\\backup.iso" -Size "dvd" -VolumeName "BACKUP"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [string]$OutputPath,
        [ValidateSet("cd", "dvd", "usb")]
        [string]$Size,
        [int]$VolumeSize,
        [string]$VolumeName
    )
    
    if ($OutputPath) {
        Set-TransferConfigValue -Config $Config -Path "Destino.ISO.OutputPath" -Value $OutputPath
    }
    if ($Size) {
        Set-TransferConfigValue -Config $Config -Path "Destino.ISO.Size" -Value $Size
    }
    if ($VolumeSize) {
        Set-TransferConfigValue -Config $Config -Path "Destino.ISO.VolumeSize" -Value $VolumeSize
    }
    if ($VolumeName) {
        Set-TransferConfigValue -Config $Config -Path "Destino.ISO.VolumeName" -Value $VolumeName
    }
}

function Get-DisketteConfig {
    <#
    .SYNOPSIS
        Obtiene la configuración Diskette (solo para Destino)
    .PARAMETER Config
        Objeto TransferConfig
    .OUTPUTS
        [PSCustomObject] Objeto con MaxDisks, Size, OutputPath
    .EXAMPLE
        $diskette = Get-DisketteConfig -Config $cfg
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config
    )
    
    return Get-TransferConfigValue -Config $Config -Path "Destino.Diskette"
}

function Set-DisketteConfig {
    <#
    .SYNOPSIS
        Establece la configuración Diskette
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER OutputPath
        Ruta donde guardar las imágenes de diskette
    .PARAMETER MaxDisks
        Número máximo de diskettes a crear (por defecto 30)
    .PARAMETER Size
        Tamaño del diskette en KB (por defecto 1440 = 1.44MB)
    .EXAMPLE
        Set-DisketteConfig -Config $cfg -OutputPath "C:\\Diskettes" -MaxDisks 50
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [string]$OutputPath,
        [int]$MaxDisks,
        [int]$Size
    )
    
    if ($OutputPath) {
        Set-TransferConfigValue -Config $Config -Path "Destino.Diskette.OutputPath" -Value $OutputPath
    }
    if ($MaxDisks) {
        Set-TransferConfigValue -Config $Config -Path "Destino.Diskette.MaxDisks" -Value $MaxDisks
    }
    if ($Size) {
        Set-TransferConfigValue -Config $Config -Path "Destino.Diskette.Size" -Value $Size
    }
}


function Export-TransferConfig {
    <#
    .SYNOPSIS
        Exporta TransferConfig a archivo JSON
    .DESCRIPTION
        Serializa el objeto TransferConfig completo a JSON y lo guarda en archivo.
        Útil para persistencia de configuraciones entre sesiones.
    .PARAMETER Config
        Objeto TransferConfig a exportar
    .PARAMETER Path
        Ruta del archivo JSON de salida
    .EXAMPLE
        Export-TransferConfig -Config $cfg -Path "C:\Temp\llevar-config.json"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        # Convertir TransferConfig a JSON con profundidad completa
        $json = $Config | ConvertTo-Json -Depth 10
        
        # Guardar en archivo
        $json | Out-File -FilePath $Path -Encoding UTF8 -Force
        
        Write-Log "TransferConfig exportado a: $Path" "INFO"
    }
    catch {
        Write-Log "Error exportando TransferConfig: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        throw "No se pudo exportar TransferConfig a $Path"
    }
}

function Import-TransferConfig {
    <#
    .SYNOPSIS
        Importa TransferConfig desde archivo JSON
    .DESCRIPTION
        Lee un archivo JSON y reconstruye el objeto TransferConfig.
        Útil para cargar configuraciones guardadas previamente.
    .PARAMETER Path
        Ruta del archivo JSON a importar
    .OUTPUTS
        [TransferConfig] Objeto reconstruido desde JSON
    .EXAMPLE
        $cfg = Import-TransferConfig -Path "C:\Temp\llevar-config.json"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        throw "Archivo de configuración no encontrado: $Path"
    }
    
    try {
        # Leer JSON
        $json = Get-Content -Path $Path -Raw -Encoding UTF8
        $data = $json | ConvertFrom-Json
        
        # Crear nueva instancia de TransferConfig
        $config = [TransferConfig]::new()
        
        # Copiar propiedades desde JSON a TransferConfig
        # Origen
        if ($data.Origen) {
            $config.Origen.Tipo = $data.Origen.Tipo
            foreach ($prop in $data.Origen.FTP.PSObject.Properties) {
                $config.Origen.FTP.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Origen.UNC.PSObject.Properties) {
                $config.Origen.UNC.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Origen.OneDrive.PSObject.Properties) {
                $config.Origen.OneDrive.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Origen.Dropbox.PSObject.Properties) {
                $config.Origen.Dropbox.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Origen.Local.PSObject.Properties) {
                $config.Origen.Local.$($prop.Name) = $prop.Value
            }
        }
        
        # Destino
        if ($data.Destino) {
            $config.Destino.Tipo = $data.Destino.Tipo
            foreach ($prop in $data.Destino.FTP.PSObject.Properties) {
                $config.Destino.FTP.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Destino.UNC.PSObject.Properties) {
                $config.Destino.UNC.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Destino.OneDrive.PSObject.Properties) {
                $config.Destino.OneDrive.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Destino.Dropbox.PSObject.Properties) {
                $config.Destino.Dropbox.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Destino.Local.PSObject.Properties) {
                $config.Destino.Local.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Destino.ISO.PSObject.Properties) {
                $config.Destino.ISO.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Destino.Diskette.PSObject.Properties) {
                $config.Destino.Diskette.$($prop.Name) = $prop.Value
            }
        }
        
        # Opciones
        if ($data.Opciones) {
            foreach ($prop in $data.Opciones.PSObject.Properties) {
                $config.Opciones.$($prop.Name) = $prop.Value
            }
        }
        
        Write-Log "TransferConfig importado desde: $Path" "INFO"
        return $config
    }
    catch {
        Write-Log "Error importando TransferConfig: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        throw "No se pudo importar TransferConfig desde $Path"
    }
}

function Reset-TransferConfigSection {
    <#
    .SYNOPSIS
        Reinicia una sección de TransferConfig a valores por defecto
    .DESCRIPTION
        Limpia todos los valores de Origen o Destino, dejándolos como una instancia nueva.
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        Sección a reiniciar: "Origen" o "Destino"
    .EXAMPLE
        Reset-TransferConfigSection -Config $cfg -Section "Origen"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section
    )
    
    # Crear instancia temporal para obtener valores por defecto
    $default = [TransferConfig]::new()
    
    # Copiar la sección por defecto
    if ($Section -eq "Origen") {
        $Config.Origen = $default.Origen
    }
    else {
        $Config.Destino = $default.Destino
    }
    
    Write-Log "Sección $Section reiniciada a valores por defecto" "INFO"
}

function Copy-TransferConfigSection {
    <#
    .SYNOPSIS
        Copia una sección de TransferConfig a otra
    .DESCRIPTION
        Duplica todos los valores de Origen a Destino o viceversa.
        Útil cuando origen y destino tienen configuración similar.
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER From
        Sección origen: "Origen" o "Destino"
    .PARAMETER To
        Sección destino: "Origen" o "Destino"
    .EXAMPLE
        Copy-TransferConfigSection -Config $cfg -From "Origen" -To "Destino"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$From,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$To
    )
    
    if ($From -eq $To) {
        Write-Warning "Origen y destino son la misma sección. No se realizó copia."
        return
    }
    
    # Serializar y deserializar para copia profunda
    $json = $Config.$From | ConvertTo-Json -Depth 10
    $Config.$To = $json | ConvertFrom-Json
    
    Write-Log "Sección $From copiada a $To" "INFO"
}

# ========================================================================== #
#                    HELPERS DE DSL PARA CONFIGURACIàN                       #
# ========================================================================== #

function New-ConfigNode {
    param([hashtable]$Initial = @{})

    $obj = [PSCustomObject]@{}
    foreach ($k in $Initial.Keys) {
        $obj | Add-Member -Name $k -Value $Initial[$k] -MemberType NoteProperty
    }
    return $obj
}

# Exportar funciones
Export-ModuleMember -Function @(
    'New-TransferConfig',
    'Get-TransferConfigValue',
    'Set-TransferConfigValue',
    'Get-TransferPath',
    'Set-TransferPath',
    'Get-TransferType',
    'Set-TransferType',
    'Get-FTPConfig',
    'Set-FTPConfig',
    'Get-TransferOption',
    'Set-TransferOption',
    'Get-OneDriveConfig',
    'Set-OneDriveConfig',
    'Get-DropboxConfig',
    'Set-DropboxConfig',
    'Get-UNCConfig',
    'Set-UNCConfig',
    'Get-LocalConfig',
    'Set-LocalConfig',
    'Get-ISOConfig',
    'Set-ISOConfig',
    'Get-DisketteConfig',
    'Set-DisketteConfig',
    'Export-TransferConfig',
    'Import-TransferConfig',
    'Reset-TransferConfigSection',
    'Copy-TransferConfigSection',
    'New-ConfigNode'
)

# ========================================================================== #
# HACER LA CLASE DISPONIBLE GLOBALMENTE (sin usar "using module")
# ========================================================================== #

# PowerShell requiere que las clases se definan en el scope global/script
# para que estén disponibles fuera del módulo sin "using module"
# Estrategia: Usar New-Module con -AsCustomObject para mantener la clase disponible

# Nada que hacer aquí - la clase ya está definida en el scope del módulo
# y será accesible cuando se importe con -Global
