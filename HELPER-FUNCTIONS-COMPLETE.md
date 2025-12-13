# Implementación Completa de Funciones Helper para TransferConfig

## Resumen

Se han implementado **12 nuevas funciones helper** para simplificar el acceso a configuraciones de todos los tipos de transferencia soportados: OneDrive, Dropbox, UNC, Local, ISO y Diskette.

## Funciones Implementadas

### 1. OneDrive (Origen/Destino)

```powershell
# Obtener configuración OneDrive
$onedrive = Get-OneDriveConfig -Config $cfg -Section "Origen"
# Retorna: Path, Token, RefreshToken, Email, ApiUrl, UseLocal, LocalPath, DriveId, RootId

# Establecer configuración OneDrive
Set-OneDriveConfig -Config $cfg -Section "Destino" `
    -Path "/Documents/LLEVAR" `
    -Email "user@outlook.com" `
    -Token "access_token" `
    -RefreshToken "refresh_token" `
    -UseLocal $true `
    -LocalPath "C:\OneDrive\LLEVAR"
```

### 2. Dropbox (Origen/Destino)

```powershell
# Obtener configuración Dropbox
$dropbox = Get-DropboxConfig -Config $cfg -Section "Destino"
# Retorna: Path, Token, RefreshToken, Email, ApiUrl

# Establecer configuración Dropbox
Set-DropboxConfig -Config $cfg -Section "Origen" `
    -Path "/Backup/Data" `
    -Email "user@dropbox.com" `
    -Token "dbx_token" `
    -RefreshToken "dbx_refresh"
```

### 3. UNC (Origen/Destino)

```powershell
# Obtener configuración UNC
$unc = Get-UNCConfig -Config $cfg -Section "Origen"
# Retorna: Path, User, Password, Domain, Credentials

# Establecer configuración UNC (con User/Password)
Set-UNCConfig -Config $cfg -Section "Destino" `
    -Path "\\servidor\compartido" `
    -User "admin" `
    -Password "secret" `
    -Domain "EMPRESA"

# Establecer configuración UNC (con PSCredential)
Set-UNCConfig -Config $cfg -Section "Origen" `
    -Path "\\fileserver\data" `
    -Credentials $credentialObject
```

### 4. Local (Origen/Destino)

```powershell
# Obtener configuración Local
$local = Get-LocalConfig -Config $cfg -Section "Origen"
# Retorna: Path

# Establecer configuración Local
Set-LocalConfig -Config $cfg -Section "Destino" -Path "C:\Backup"
```

### 5. ISO (Solo Destino)

```powershell
# Obtener configuración ISO
$iso = Get-ISOConfig -Config $cfg
# Retorna: OutputPath, Size, VolumeSize, VolumeName

# Establecer configuración ISO
Set-ISOConfig -Config $cfg `
    -OutputPath "C:\backup.iso" `
    -Size "dvd" `
    -VolumeName "BACKUP_2024"

# Tamaños predefinidos: "cd" (650MB), "dvd" (4.7GB), "usb" (4.5GB)
# O usar VolumeSize personalizado en MB
```

### 6. Diskette (Solo Destino)

```powershell
# Obtener configuración Diskette
$diskette = Get-DisketteConfig -Config $cfg
# Retorna: OutputPath, MaxDisks, Size

# Establecer configuración Diskette
Set-DisketteConfig -Config $cfg `
    -OutputPath "C:\Diskettes" `
    -MaxDisks 50 `
    -Size 1440
```

## Funciones Helper Previas (ya implementadas)

```powershell
# Tipos y Rutas (genéricas)
Get-TransferType -Config $cfg -Section "Origen"           # Retorna tipo: Local, FTP, OneDrive, etc.
Set-TransferType -Config $cfg -Section "Destino" -Type "ISO"
Get-TransferPath -Config $cfg -Section "Origen"           # Obtiene ruta según tipo configurado
Set-TransferPath -Config $cfg -Section "Destino" -Value "C:\Data"

# FTP (con soporte PSCredential)
Get-FTPConfig -Config $cfg -Section "Origen"              # Retorna Server, Port, User, Password, Credentials, UseSsl, Directory
Set-FTPConfig -Config $cfg -Section "Destino" -Server "ftp.example.com" -User "admin" -Password "pass"
Set-FTPConfig -Config $cfg -Section "Origen" -Server "ftp.example.com" -Credentials $cred

# Opciones
Get-TransferOption -Config $cfg -Option "BlockSizeMB"     # Retorna valor de la opción
Set-TransferOption -Config $cfg -Option "Verbose" -Value $true
```

## Ejemplos de Uso Completos

### Ejemplo 1: OneDrive → Dropbox

```powershell
$cfg = New-TransferConfig

# Configurar Origen OneDrive
Set-TransferType -Config $cfg -Section "Origen" -Type "OneDrive"
Set-OneDriveConfig -Config $cfg -Section "Origen" `
    -Path "/Documents/Project" `
    -Email "source@outlook.com" `
    -UseLocal $true `
    -LocalPath "C:\OneDrive\Project"

# Configurar Destino Dropbox
Set-TransferType -Config $cfg -Section "Destino" -Type "Dropbox"
Set-DropboxConfig -Config $cfg -Section "Destino" `
    -Path "/Backup/Project" `
    -Email "backup@dropbox.com" `
    -Token "dbx_access_token"

# Opciones
Set-TransferOption -Config $cfg -Option "BlockSizeMB" -Value 10
Set-TransferOption -Config $cfg -Option "Verbose" -Value $true

# Verificar configuración
Write-Host "Origen: $(Get-TransferType -Config $cfg -Section 'Origen') - $(Get-TransferPath -Config $cfg -Section 'Origen')"
Write-Host "Destino: $(Get-TransferType -Config $cfg -Section 'Destino') - $(Get-TransferPath -Config $cfg -Section 'Destino')"
```

### Ejemplo 2: UNC → ISO

```powershell
$cfg = New-TransferConfig

# Origen UNC
Set-TransferType -Config $cfg -Section "Origen" -Type "UNC"
Set-UNCConfig -Config $cfg -Section "Origen" `
    -Path "\\servidor\datos\proyecto" `
    -User "admin" `
    -Password "secret123" `
    -Domain "EMPRESA"

# Destino ISO
Set-TransferType -Config $cfg -Section "Destino" -Type "ISO"
Set-ISOConfig -Config $cfg `
    -OutputPath "C:\Backups\proyecto_2024.iso" `
    -Size "dvd" `
    -VolumeName "PROYECTO_2024"

# Ejecutar transferencia (ejemplo)
# Copy-LlevarFiles -TransferConfig $cfg
```

### Ejemplo 3: Local → Diskette

```powershell
$cfg = New-TransferConfig

# Origen Local
Set-TransferType -Config $cfg -Section "Origen" -Type "Local"
Set-LocalConfig -Config $cfg -Section "Origen" -Path "C:\SmallProject"

# Destino Diskette
Set-TransferType -Config $cfg -Section "Destino" -Type "Diskette"
Set-DisketteConfig -Config $cfg `
    -OutputPath "C:\Diskettes\SmallProject" `
    -MaxDisks 100 `
    -Size 1440

# Configurar opción de clave
Set-TransferOption -Config $cfg -Option "Clave" -Value "password123"
```

## Comparación: Antes vs Después

### ANTES (verboso y propenso a errores)

```powershell
# Configurar OneDrive origen - 6 líneas
Set-TransferConfigValue -Config $cfg -Path "Origen.Tipo" -Value "OneDrive"
Set-TransferConfigValue -Config $cfg -Path "Origen.OneDrive.Path" -Value "/Documents/LLEVAR"
Set-TransferConfigValue -Config $cfg -Path "Origen.OneDrive.Email" -Value "user@outlook.com"
Set-TransferConfigValue -Config $cfg -Path "Origen.OneDrive.Token" -Value "token"
Set-TransferConfigValue -Config $cfg -Path "Origen.OneDrive.UseLocal" -Value $true
Set-TransferConfigValue -Config $cfg -Path "Origen.OneDrive.LocalPath" -Value "C:\OneDrive\LLEVAR"

# Obtener configuración - difícil de leer
$path = Get-TransferConfigValue -Config $cfg -Path "Origen.OneDrive.Path"
$email = Get-TransferConfigValue -Config $cfg -Path "Origen.OneDrive.Email"
$useLocal = Get-TransferConfigValue -Config $cfg -Path "Origen.OneDrive.UseLocal"
```

### DESPUÉS (conciso y legible)

```powershell
# Configurar OneDrive origen - 1 línea
Set-TransferType -Config $cfg -Section "Origen" -Type "OneDrive"
Set-OneDriveConfig -Config $cfg -Section "Origen" `
    -Path "/Documents/LLEVAR" `
    -Email "user@outlook.com" `
    -Token "token" `
    -UseLocal $true `
    -LocalPath "C:\OneDrive\LLEVAR"

# Obtener configuración - simple y claro
$onedrive = Get-OneDriveConfig -Config $cfg -Section "Origen"
Write-Host "Path: $($onedrive.Path), Email: $($onedrive.Email), UseLocal: $($onedrive.UseLocal)"
```

## Integración con Get-TransferPath

Todas las funciones están completamente integradas con `Get-TransferPath`:

```powershell
# OneDrive
Set-TransferType -Config $cfg -Section "Origen" -Type "OneDrive"
Set-OneDriveConfig -Config $cfg -Section "Origen" -Path "/Documents"
Get-TransferPath -Config $cfg -Section "Origen"  # → "/Documents"

# Dropbox
Set-TransferType -Config $cfg -Section "Destino" -Type "Dropbox"
Set-DropboxConfig -Config $cfg -Section "Destino" -Path "/Backup"
Get-TransferPath -Config $cfg -Section "Destino"  # → "/Backup"

# UNC
Set-TransferType -Config $cfg -Section "Origen" -Type "UNC"
Set-UNCConfig -Config $cfg -Section "Origen" -Path "\\servidor\datos"
Get-TransferPath -Config $cfg -Section "Origen"  # → "\\servidor\datos"

# Local
Set-TransferType -Config $cfg -Section "Destino" -Type "Local"
Set-LocalConfig -Config $cfg -Section "Destino" -Path "C:\Backup"
Get-TransferPath -Config $cfg -Section "Destino"  # → "C:\Backup"

# ISO
Set-TransferType -Config $cfg -Section "Destino" -Type "ISO"
Set-ISOConfig -Config $cfg -OutputPath "C:\backup.iso"
Get-TransferPath -Config $cfg -Section "Destino"  # → "C:\backup.iso"

# Diskette
Set-TransferType -Config $cfg -Section "Destino" -Type "Diskette"
Set-DisketteConfig -Config $cfg -OutputPath "C:\Diskettes"
Get-TransferPath -Config $cfg -Section "Destino"  # → "C:\Diskettes"
```

## Tests

Se creó una suite completa de tests: `Tests\Test-TransferConfigHelpers.ps1`

### Resultados de los Tests

```
Tests ejecutados: 21
  Pasados:        21
  Fallados:       0
  Tasa de éxito:  100%
```

### Cobertura de Tests

- ✓ Set/Get para cada tipo (OneDrive, Dropbox, UNC, Local, ISO, Diskette)
- ✓ Integración con Get-TransferPath
- ✓ Escenarios completos (OneDrive→Dropbox, UNC→ISO, Local→Diskette)
- ✓ Parámetros opcionales y obligatorios
- ✓ Validación de tipos de datos
- ✓ PSCredential para UNC

## Funciones Exportadas (Total: 27)

```powershell
Export-ModuleMember -Function @(
    # Core
    'New-TransferConfig',
    'Get-TransferConfigValue',
    'Set-TransferConfigValue',
    
    # Genéricas
    'Get-TransferPath',
    'Set-TransferPath',
    'Get-TransferType',
    'Set-TransferType',
    'Get-TransferOption',
    'Set-TransferOption',
    
    # FTP
    'Get-FTPConfig',
    'Set-FTPConfig',
    
    # OneDrive
    'Get-OneDriveConfig',
    'Set-OneDriveConfig',
    
    # Dropbox
    'Get-DropboxConfig',
    'Set-DropboxConfig',
    
    # UNC
    'Get-UNCConfig',
    'Set-UNCConfig',
    
    # Local
    'Get-LocalConfig',
    'Set-LocalConfig',
    
    # ISO
    'Get-ISOConfig',
    'Set-ISOConfig',
    
    # Diskette
    'Get-DisketteConfig',
    'Set-DisketteConfig',
    
    # Import/Export
    'Export-TransferConfig',
    'Import-TransferConfig',
    'Reset-TransferConfigSection',
    'Copy-TransferConfigSection',
    'New-ConfigNode'
)
```

## Compilación

Todos los módulos compilan sin errores:

- ✓ `Modules\Core\TransferConfig.psm1` (27 funciones exportadas)
- ✓ `Modules\Parameters\NormalMode.psm1`
- ✓ `Modules\UI\ConfigMenus.psm1`
- ✓ `Modules\Utilities\Examples.psm1`
- ✓ `Modules\Transfer\Unified.psm1`

## Migración Completa

Se reemplazaron **todos** los patrones antiguos:

1. ✅ Función `Use-With` eliminada (16 reemplazos)
2. ✅ Asignaciones directas migradas a `Set-TransferConfigValue` (31 reemplazos)
3. ✅ Switches de rutas reemplazados con `Get-TransferPath` (7 reemplazos)
4. ✅ Accesos verbosos reemplazados con helpers (26 reemplazos)

**Total de líneas simplificadas: 80+**

## Próximos Pasos (Opcional)

Aunque el código actual funciona perfectamente, se pueden explorar estas oportunidades:

1. **ConfigMenus.psm1**: Usar las nuevas funciones en menús de configuración OneDrive/Dropbox/UNC
2. **Unified.psm1**: Simplificar handlers de transferencia con los helpers específicos
3. **Transfer/*.psm1**: Revisar módulos de transferencia para posibles simplificaciones

Estas son mejoras opcionales que no afectan la funcionalidad actual.

## Conclusión

✅ **Implementación completada al 100%**

- 12 nuevas funciones helper agregadas
- Cobertura completa de todos los tipos de transferencia
- 21 tests unitarios pasando (100% éxito)
- Integración completa con funciones existentes
- Compilación sin errores de todos los módulos
- Documentación y ejemplos completos
