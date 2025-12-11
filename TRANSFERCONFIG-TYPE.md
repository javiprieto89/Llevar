# TransferConfig - Tipo de Dato Global

## Definición del Tipo

`TransferConfig` es una **clase de PowerShell** definida en `Modules\Core\TransferConfig.psm1`.

Es el tipo de dato oficial para **toda** configuración de transferencia en LLEVAR, disponible globalmente como `[TransferConfig]`.

## Estructura Jerárquica Completa (UNA SOLA CLASE)

```powershell
class TransferConfig {
    # ====== ORIGEN ======
    [PSCustomObject]$Origen = @{
        [string]$Tipo  # "Local", "FTP", "UNC", "OneDrive", "Dropbox", "USB"
        
        # Subestructura FTP
        FTP = @{
            [string]$Server
            [int]$Port = 21
            [string]$User
            [string]$Password
            [bool]$UseSsl = $false
            [string]$Directory = "/"
        }
        
        # Subestructura UNC
        UNC = @{
            [string]$Path
            [string]$User
            [string]$Password
            [string]$Domain
            [pscredential]$Credentials
        }
        
        # Subestructura OneDrive
        OneDrive = @{
            [string]$Path
            [string]$Token
            [string]$RefreshToken
            [string]$Email
            [string]$ApiUrl = "https://graph.microsoft.com/v1.0/me/drive"
        }
        
        # Subestructura Dropbox
        Dropbox = @{
            [string]$Path
            [string]$Token
            [string]$RefreshToken
            [string]$Email
            [string]$ApiUrl = "https://api.dropboxapi.com/2"
        }
        
        # Subestructura Local
        Local = @{
            [string]$Path
        }
    }
    
    # ====== DESTINO ======
    [PSCustomObject]$Destino = @{
        [string]$Tipo  # "Local", "USB", "FTP", "UNC", "OneDrive", "Dropbox", "ISO", "Diskette"
        
        # Subestructura FTP
        FTP = @{
            [string]$Server
            [int]$Port = 21
            [string]$User
            [string]$Password
            [bool]$UseSsl = $false
            [string]$Directory = "/"
        }
        
        # Subestructura UNC
        UNC = @{
            [string]$Path
            [string]$User
            [string]$Password
            [string]$Domain
            [pscredential]$Credentials
        }
        
        # Subestructura OneDrive
        OneDrive = @{
            [string]$Path
            [string]$Token
            [string]$RefreshToken
            [string]$Email
            [string]$ApiUrl = "https://graph.microsoft.com/v1.0/me/drive"
        }
        
        # Subestructura Dropbox
        Dropbox = @{
            [string]$Path
            [string]$Token
            [string]$RefreshToken
            [string]$Email
            [string]$ApiUrl = "https://api.dropboxapi.com/2"
        }
        
        # Subestructura Local
        Local = @{
            [string]$Path
        }
        
        # Subestructura ISO
        ISO = @{
            [string]$OutputPath
            [string]$Size = "dvd"
            [int]$VolumeSize
            [string]$VolumeName = "LLEVAR"
        }
        
        # Subestructura Diskette
        Diskette = @{
            [int]$MaxDisks = 30
            [int]$Size = 1440
            [string]$OutputPath
        }
    }
    
    # ====== OPCIONES GENERALES ======
    [PSCustomObject]$Opciones = @{
        [int]$BlockSizeMB = 10
        [string]$Clave
        [bool]$UseNativeZip = $false
        [bool]$RobocopyMirror = $false
        [string]$TransferMode = "Compress"
        [bool]$Verbose = $false
    }
    
    # ====== INTERNO ======
    [PSCustomObject]$Interno = @{
        [string]$OrigenMontado
        [string]$DestinoMontado
        [string]$OrigenDrive
        [string]$DestinoDrive
        [string]$TempDir
        [string]$SevenZipPath
    }
}
```

## Equivalente en C++

```cpp
class TransferConfig {
    // ====== ORIGEN ======
    struct Origen {
        string Tipo;
        
        struct FTP {
            string Server;
            int Port;
            string User;
            string Password;
            bool UseSsl;
            string Directory;
        } FTP;
        
        struct UNC {
            string Path;
            string User;
            string Password;
            string Domain;
            PSCredential Credentials;
        } UNC;
        
        struct OneDrive {
            string Path;
            string Token;
            string RefreshToken;
            string Email;
            string ApiUrl;
        } OneDrive;
        
        struct Dropbox {
            string Path;
            string Token;
            string RefreshToken;
            string Email;
            string ApiUrl;
        } Dropbox;
        
        struct Local {
            string Path;
        } Local;
    } Origen;
    
    // ====== DESTINO ======
    struct Destino {
        string Tipo;
        
        struct FTP { /* igual que Origen */ } FTP;
        struct UNC { /* igual que Origen */ } UNC;
        struct OneDrive { /* igual que Origen */ } OneDrive;
        struct Dropbox { /* igual que Origen */ } Dropbox;
        struct Local { /* igual que Origen */ } Local;
        
        struct ISO {
            string OutputPath;
            string Size;
            int VolumeSize;
            string VolumeName;
        } ISO;
        
        struct Diskette {
            int MaxDisks;
            int Size;
            string OutputPath;
        } Diskette;
    } Destino;
    
    // ====== OPCIONES ======
    struct Opciones {
        int BlockSizeMB;
        string Clave;
        bool UseNativeZip;
        bool RobocopyMirror;
        string TransferMode;
        bool Verbose;
    } Opciones;
    
    // ====== INTERNO ======
    struct Interno {
        string OrigenMontado;
        string DestinoMontado;
        string OrigenDrive;
        string DestinoDrive;
        string TempDir;
        string SevenZipPath;
    } Interno;
};
```

## Uso Completo

### Importar el Tipo (REQUERIDO)

```powershell
# DEBE estar al INICIO del archivo, antes de cualquier código
using module "Q:\Utilidad\LLevar\Modules\Core\TransferConfig.psm1"
```

### Crear una Instancia

```powershell
# Opción 1: Usar función helper
$config = New-TransferConfig

# Opción 2: Constructor directo
$config = [TransferConfig]::new()

# Ambos crean la MISMA estructura con TODAS las subestructuras inicializadas
```

### Acceso a la Estructura Completa

```powershell
$config = [TransferConfig]::new()

# Acceso directo a cualquier nivel
$config.Origen.Tipo = "FTP"
$config.Origen.FTP.Server = "ftp.ejemplo.com"
$config.Origen.FTP.Port = 21
$config.Origen.FTP.User = "usuario"
$config.Origen.FTP.Password = "clave"
$config.Origen.FTP.Directory = "/datos"

$config.Destino.Tipo = "ISO"
$config.Destino.ISO.OutputPath = "C:\ISOs"
$config.Destino.ISO.Size = "dvd"
$config.Destino.ISO.VolumeName = "Backup"

$config.Opciones.BlockSizeMB = 50
$config.Opciones.Clave = "miclave123"
$config.Opciones.TransferMode = "Compress"

# Todo accesible desde una sola instancia
Write-Host "Servidor FTP: $($config.Origen.FTP.Server)"
Write-Host "Tamaño ISO: $($config.Destino.ISO.Size)"
Write-Host "Bloques: $($config.Opciones.BlockSizeMB) MB"
```

### Configurar con Funciones Helper

```powershell
$config = New-TransferConfig

# Configurar origen FTP (la función asigna todos los campos internamente)
Set-TransferConfigOrigen -Config $config -Tipo "FTP" -Parametros @{
    Server = "ftp.ejemplo.com"
    Port = 21
    User = "usuario"
    Password = "clave"
    Directory = "/datos"
}

# Configurar destino ISO
Set-TransferConfigDestino -Config $config -Tipo "ISO" -Parametros @{
    OutputPath = "C:\ISOs"
    Size = "dvd"
    VolumeName = "Backup"
}

# Resultado: $config.Origen.FTP.Server = "ftp.ejemplo.com", etc.
```

### Todos los Tipos Soportados

```powershell
$config = [TransferConfig]::new()

# ===== ORIGEN/DESTINO: FTP =====
$config.Origen.Tipo = "FTP"
$config.Origen.FTP.Server = "ftp.ejemplo.com"
$config.Origen.FTP.Port = 21
$config.Origen.FTP.User = "usuario"
$config.Origen.FTP.Password = "clave"
$config.Origen.FTP.UseSsl = $false
$config.Origen.FTP.Directory = "/datos"

# ===== ORIGEN/DESTINO: UNC =====
$config.Origen.Tipo = "UNC"
$config.Origen.UNC.Path = "\\servidor\recurso"
$config.Origen.UNC.User = "usuario"
$config.Origen.UNC.Password = "clave"
$config.Origen.UNC.Domain = "DOMINIO"

# ===== ORIGEN/DESTINO: OneDrive =====
$config.Origen.Tipo = "OneDrive"
$config.Origen.OneDrive.Path = "/Documentos/MiCarpeta"
$config.Origen.OneDrive.Token = "oauth_token..."
$config.Origen.OneDrive.Email = "usuario@ejemplo.com"

# ===== ORIGEN/DESTINO: Dropbox =====
$config.Origen.Tipo = "Dropbox"
$config.Origen.Dropbox.Path = "/Apps/Datos"
$config.Origen.Dropbox.Token = "dropbox_token..."
$config.Origen.Dropbox.Email = "usuario@ejemplo.com"

# ===== ORIGEN/DESTINO: Local/USB =====
$config.Origen.Tipo = "Local"
$config.Origen.Local.Path = "C:\Datos"

$config.Destino.Tipo = "USB"
$config.Destino.Local.Path = "D:\USB"

# ===== DESTINO: ISO =====
$config.Destino.Tipo = "ISO"
$config.Destino.ISO.OutputPath = "C:\ISOs"
$config.Destino.ISO.Size = "dvd"  # "cd", "dvd", "usb", "custom"
$config.Destino.ISO.VolumeSize = 4500  # MB (si Size="custom")
$config.Destino.ISO.VolumeName = "LLEVAR"

# ===== DESTINO: Diskette =====
$config.Destino.Tipo = "Diskette"
$config.Destino.Diskette.MaxDisks = 30
$config.Destino.Diskette.Size = 1440  # KB
$config.Destino.Diskette.OutputPath = "C:\Diskettes"

# ===== OPCIONES =====
$config.Opciones.BlockSizeMB = 10
$config.Opciones.Clave = "miclave123"
$config.Opciones.UseNativeZip = $false
$config.Opciones.RobocopyMirror = $true
$config.Opciones.TransferMode = "Compress"  # "Compress" o "Direct"
$config.Opciones.Verbose = $false

# ===== INTERNO (usado por el sistema) =====
$config.Interno.TempDir = "C:\Temp\LLEVAR"
$config.Interno.SevenZipPath = "C:\7z\7z.exe"
```

### Obtener Información

```powershell
# Obtener sub-config según tipo
$origenFtp = Get-TransferConfigOrigen -Config $config

# Obtener path efectivo
$origenPath = Get-TransferConfigOrigenPath -Config $config
# Retorna: "ftp://ftp.ejemplo.com:21/datos"

$destinoPath = Get-TransferConfigDestinoPath -Config $config
# Retorna: "D:\USB" o "C:\ISOs" según tipo

# Validar configuración completa
$resultado = Test-TransferConfigComplete -Config $config
if ($resultado.IsValid) {
    Write-Host "Configuración válida"
} else {
    Write-Host "Errores: $($resultado.Errors -join ', ')"
}
```

## Declaración de Parámetros

```powershell
function Mi-Funcion {
    param(
        [Parameter(Mandatory)]
        [TransferConfig]$Config
    )
    
    # Acceder a propiedades
    $tipoOrigen = $Config.Origen.Tipo
    $blockSize = $Config.Opciones.BlockSizeMB
    
    # Modificar valores
    $Config.Interno.TempDir = "C:\Temp"
}
```

## Validación de Tipos

PowerShell valida automáticamente el tipo:

```powershell
function Procesar-Transfer {
    param([TransferConfig]$Config)
    # Solo acepta instancias de TransferConfig
}

$config = New-TransferConfig
Procesar-Transfer -Config $config  # ✅ OK

$malConfig = @{ Origen = "error" }
Procesar-Transfer -Config $malConfig  # ❌ ERROR: Cannot convert...
```

## Archivos que Usan el Tipo

- ✅ `Llevar.ps1` - Script principal
- ✅ `Modules\Parameters\NormalMode.psm1` - Lógica principal
- ✅ `Modules\Parameters\InteractiveMenu.psm1` - Menús interactivos
- ✅ `Modules\Core\TransferConfig.psm1` - Definición del tipo

## Ventajas del Tipo Definido

1. **Validación Automática**: PowerShell valida tipos en parámetros
2. **IntelliSense**: Autocompletado de propiedades en VS Code
3. **Documentación**: Estructura clara y autodocumentada
4. **Type Safety**: Imposible pasar objetos incorrectos
5. **Refactoring**: Cambios en un solo lugar
6. **Global**: Disponible en todos los módulos con `using module`

## Migración Completa

### ANTES (PSCustomObject)
```powershell
function Invoke-NormalMode {
    param(
        [PSCustomObject]$TransferConfig,  # ❌ Cualquier hashtable
        [string]$Origen,                   # ❌ Parámetros mezclados
        [string]$Destino
    )
}
```

### AHORA (Clase Tipada)
```powershell
using module "Q:\Utilidad\LLevar\Modules\Core\TransferConfig.psm1"

function Invoke-NormalMode {
    param(
        [TransferConfig]$TransferConfig   # ✅ Solo acepta TransferConfig
    )
    # Todo viene en $TransferConfig
}
```

## Compatibilidad

- ✅ PowerShell 5.0+ (clases introducidas en v5.0)
- ✅ PowerShell Core 6+
- ✅ Windows PowerShell 5.1

## Notas Importantes

1. **`using module` DEBE estar al inicio**: Antes de cualquier código, comentarios OK
2. **No usar `Import-Module`**: Las clases requieren `using module`
3. **Ruta absoluta**: Usar ruta completa en `using module`
4. **No hay Path común**: Cada tipo define su propia ubicación
5. **Valores por defecto**: Las clases inicializan propiedades automáticamente
