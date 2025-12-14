# TransferConfig - Sistema Unificado de Configuración

## Descripción

`TransferConfig` es una clase PowerShell que centraliza toda la configuración de transferencias en LLEVAR. Elimina conversiones manuales de tipos y errores de parámetros mediante el uso de objetos PSCustomObject anidados.

## Estructura

```powershell
class TransferConfig {
    [PSCustomObject]$Origen = @{
        Tipo     = "Local|FTP|OneDrive|Dropbox|UNC|USB"
        
        FTP = @{
            Server      = $null
            Port        = 21
            User        = $null
            Password    = $null
            Credentials = $null  # PSCredential
            UseSsl      = $false
            Directory   = "/"
        }
        
        UNC = @{
            Path        = $null
            User        = $null
            Password    = $null
            Domain      = $null
            Credentials = $null  # PSCredential
        }
        
        OneDrive = @{
            Path         = $null
            Token        = $null
            RefreshToken = $null
            Email        = $null
            ApiUrl       = "https://graph.microsoft.com/v1.0/me/drive"
            UseLocal     = $false
            LocalPath    = $null
        }
        
        Dropbox = @{
            Path         = $null
            Token        = $null
            RefreshToken = $null
            Email        = $null
            ApiUrl       = "https://api.dropboxapi.com/2"
        }
        
        Local = @{
            Path = $null
        }
        
        USB = @{
            Path = $null
        }
    }
    
    [PSCustomObject]$Destino = @{
        Tipo     = "Local|USB|FTP|OneDrive|Dropbox|UNC|ISO|Diskette"
        # Mismas subestructuras que Origen, más:
        
        ISO = @{
            OutputPath  = $null
            Size        = "dvd"  # cd, dvd, bluray
            VolumeSize  = 4700
            VolumeName  = "LLEVAR"
        }
        
        Diskette = @{
            MaxDisks   = 99
            Size       = 1440
            OutputPath = $null
        }
    }
    
    [PSCustomObject]$Opciones = @{
        BlockSizeMB    = 10
        Clave          = $null
        UseNativeZip   = $false
        RobocopyMirror = $false
        TransferMode   = "Compress"
        Verbose        = $false
    }
    
    [PSCustomObject]$Interno = @{
        OrigenMontado  = $null
        DestinoMontado = $null
        OrigenDrive    = $null
        DestinoDrive   = $null
        TempDir        = $null
        SevenZipPath   = $null
    }
}
```

## Funciones Helper

### Creación
```powershell
# Crear instancia con valores por defecto
$config = New-TransferConfig
```

### Configuración de Origen/Destino
```powershell
# Configurar FTP
Set-FTPConfig -Config $config -Section "Origen" `
    -Server "ftp.ejemplo.com" `
    -Port 21 `
    -User "usuario" `
    -Password "clave" `
    -Directory "/ruta"

# Configurar UNC
Set-UNCConfig -Config $config -Section "Destino" `
    -Path "\\servidor\compartido" `
    -User "dominio\usuario" `
    -Password "clave"

# Configurar OneDrive
Set-OneDriveConfig -Config $config -Section "Origen" `
    -Path "/Documents/LLEVAR" `
    -Email "user@outlook.com" `
    -Token "access_token"

# Configurar Local
Set-LocalConfig -Config $config -Section "Destino" `
    -Path "D:\Backup"

# Configurar ISO
Set-ISOConfig -Config $config `
    -OutputPath "D:\salida" `
    -Size "dvd"
```

### Obtener Configuración
```powershell
# Obtener subobjeto según tipo actual
$origen = Get-TransferConfigOrigen -Config $config
# Retorna: $config.Origen.FTP, .UNC, .OneDrive, etc. según Tipo

# Obtener path efectivo
$origenPath = Get-TransferConfigOrigenPath -Config $config
# Retorna: "ftp://servidor/ruta", "\\servidor\compartido", etc.

# Obtener valores específicos
$blockSize = Get-TransferConfigValue -Config $config -Path "Opciones.BlockSizeMB"
$ftpServer = Get-TransferConfigValue -Config $config -Path "Origen.FTP.Server"
```

### Validación
```powershell
# Validar configuración completa
$isValid = Test-TransferConfigComplete -Config $config
# Retorna: $true si Origen y Destino están configurados correctamente
```

## Uso en Funciones

### ✅ CORRECTO - Aceptar PSCustomObject
```powershell
function Copy-LlevarLocalToFtp {
    param(
        [string]$SourcePath,
        [psobject]$FtpConfig,  # Acepta PSCustomObject
        [bool]$ShowProgress = $true
    )
    
    # Validar tipo
    if ($FtpConfig.Tipo -ne "FTP") {
        throw "FtpConfig debe ser de tipo FTP"
    }
    
    # Acceder directamente a propiedades
    $ftpServer = $FtpConfig.Server
    $ftpUser = $FtpConfig.User
    $ftpPassword = $FtpConfig.Password
    
    # Usar Credentials si está disponible
    if ($FtpConfig.Credentials) {
        $ftpUser = $FtpConfig.Credentials.UserName
        $ftpPassword = $FtpConfig.Credentials.GetNetworkCredential().Password
    }
}
```

### ❌ INCORRECTO - Intentar conversión manual
```powershell
# NO HACER ESTO
function Copy-LlevarLocalToFtp {
    param(
        [hashtable]$FtpConfig  # ❌ Causa error de conversión
    )
}

# NO HACER ESTO
$tempHash = @{}
$config.Origen.FTP.PSObject.Properties | ForEach-Object {
    $tempHash[$_.Name] = $_.Value  # ❌ Conversión manual innecesaria
}
```

## Flujo de Datos

### Modo Interactivo
```
InteractiveMenu → Crea TransferConfig
                → Show-OrigenMenu configura Origen
                → Show-DestinoMenu configura Destino
                → Retorna TransferConfig completo
                ↓
Llevar.ps1      → Recibe TransferConfig
                → Pasa a Invoke-NormalMode
                ↓
NormalMode      → Extrae configuración
                → Ejecuta transferencia
```

### Modo CLI
```
Llevar.ps1      → Detecta tipo desde parámetros
                → Crea TransferConfig
                → Configura Origen/Destino
                → Pasa a Invoke-NormalMode
                ↓
NormalMode      → Extrae configuración
                → Ejecuta transferencia
```

## Credenciales

### FTP y UNC - Doble Formato
```powershell
# Opción 1: User/Password individuales
Set-FTPConfig -Config $config -Section "Origen" `
    -User "usuario" `
    -Password "clave"

# Opción 2: PSCredential
$cred = Get-Credential
Set-FTPConfig -Config $config -Section "Origen" `
    -Credentials $cred

# En las funciones de transferencia:
if ($FtpConfig.Credentials) {
    $user = $FtpConfig.Credentials.UserName
    $pass = $FtpConfig.Credentials.GetNetworkCredential().Password
} else {
    $user = $FtpConfig.User
    $pass = $FtpConfig.Password
}
```

### OneDrive/Dropbox - Tokens OAuth
```powershell
# Token de acceso y refresh
Set-OneDriveConfig -Config $config -Section "Origen" `
    -Token "access_token" `
    -RefreshToken "refresh_token" `
    -Email "user@outlook.com"
```

## Validación de Tipos

```powershell
# Tipos válidos para Origen
"Local", "FTP", "OneDrive", "Dropbox", "UNC", "USB"

# Tipos válidos para Destino
"Local", "USB", "FTP", "OneDrive", "Dropbox", "UNC", "ISO", "Diskette"

# Validación automática
Set-TransferType -Config $config -Section "Origen" -Type "InvalidType"
# Genera error: Tipo de origen no válido
```

## Ubicación

**Archivo:** `Modules\Core\TransferConfig.psm1`

**Importación:** Usar `using module` al inicio del script:
```powershell
using module "Q:\Utilidad\Llevar\Modules\Core\TransferConfig.psm1"
```
