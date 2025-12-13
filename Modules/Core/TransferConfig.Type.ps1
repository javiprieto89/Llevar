# ========================================================================== #
#                  MÓDULO: CONFIGURACIÓN DE TRANSFERENCIA                    #
# ========================================================================== #
# Propósito: Objeto unificado para toda la configuración de transferencia
# Estructura jerárquica que evita mezcla de parámetros
# ========================================================================== #

# ========================================================================== #
#                     DEFINICIÓN DEL TIPO TRANSFERCONFIG                     #
# ========================================================================== #

class TransferConfig {
    # ====== ESTADO DE CONFIGURACIÓN ======
    [bool]$OrigenIsSet = $false
    [bool]$DestinoIsSet = $false
    
    # ====== ORIGEN ======
    [PSCustomObject]$Origen = [PSCustomObject]@{
        Tipo     = $null  # "Local", "FTP", "UNC", "OneDrive", "Dropbox", "USB"
        
        # Subestructura FTP
        FTP      = [PSCustomObject]@{
            Server      = $null
            Port        = 21
            User        = $null
            Password    = $null
            Credentials = $null
            UseSsl      = $false
            Directory   = "/"
        }
        
        # Subestructura UNC
        UNC      = [PSCustomObject]@{
            Path        = $null
            User        = $null
            Password    = $null
            Domain      = $null
            Credentials = $null
        }
        
        # Subestructura OneDrive
        OneDrive = [PSCustomObject]@{
            Path         = $null
            Token        = $null
            RefreshToken = $null
            Email        = $null
            ApiUrl       = "https://graph.microsoft.com/v1.0/me/drive"
            UseLocal     = $false
            LocalPath    = $null
            DriveId      = $null
            RootId       = $null
        }
        
        # Subestructura Dropbox
        Dropbox  = [PSCustomObject]@{
            Path         = $null
            Token        = $null
            RefreshToken = $null
            Email        = $null
            ApiUrl       = "https://api.dropboxapi.com/2"
        }
        
        # Subestructura Local
        Local    = [PSCustomObject]@{
            Path = $null
        }
    }
    
    # ====== DESTINO ======
    [PSCustomObject]$Destino = [PSCustomObject]@{
        Tipo     = $null  # "Local", "USB", "FTP", "UNC", "OneDrive", "Dropbox", "ISO", "Diskette"
        
        # Subestructura FTP
        FTP      = [PSCustomObject]@{
            Server      = $null
            Port        = 21
            User        = $null
            Password    = $null
            Credentials = $null
            UseSsl      = $false
            Directory   = "/"
        }
        
        # Subestructura UNC
        UNC      = [PSCustomObject]@{
            Path        = $null
            User        = $null
            Password    = $null
            Domain      = $null
            Credentials = $null
        }
        
        # Subestructura OneDrive
        OneDrive = [PSCustomObject]@{
            Path         = $null
            Token        = $null
            RefreshToken = $null
            Email        = $null
            ApiUrl       = "https://graph.microsoft.com/v1.0/me/drive"
            UseLocal     = $false
            LocalPath    = $null
            DriveId      = $null
            RootId       = $null
        }
        
        # Subestructura Dropbox
        Dropbox  = [PSCustomObject]@{
            Path         = $null
            Token        = $null
            RefreshToken = $null
            Email        = $null
            ApiUrl       = "https://api.dropboxapi.com/2"
        }
        
        # Subestructura Local
        Local    = [PSCustomObject]@{
            Path = $null
        }
        
        # Subestructura ISO
        ISO      = [PSCustomObject]@{
            OutputPath = $null
            Size       = "dvd"
            VolumeSize = $null
            VolumeName = "LLEVAR"
        }
        
        # Subestructura Diskette
        Diskette = [PSCustomObject]@{
            MaxDisks   = 30
            Size       = 1440
            OutputPath = $null
        }
    }
    
    # ====== OPCIONES GENERALES ======
    [PSCustomObject]$Opciones = [PSCustomObject]@{
        BlockSizeMB    = 10
        Clave          = $null
        UseNativeZip   = $false
        RobocopyMirror = $false
        TransferMode   = "Compress"
        Verbose        = $false
    }
    
    # ====== INTERNO (uso del sistema) ======
    [PSCustomObject]$Interno = [PSCustomObject]@{
        OrigenDrive  = $null  # Drive temporal si origen es UNC
        DestinoDrive = $null  # Drive temporal si destino es UNC
        TempDir      = $null  # Directorio temporal para compresión
        SevenZipPath = $null  # Ruta a 7-Zip
    }
}
