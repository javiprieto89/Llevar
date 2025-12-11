# 🧹 Limpieza de Funciones Obsoletas - OneDrive y Dropbox

## 📋 Resumen

Se han eliminado funciones obsoletas de los módulos **OneDrive.psm1** y **Dropbox.psm1** que recibían parámetros individuales. Estas funciones han sido reemplazadas por las versiones modernas que usan objetos de configuración unificados (`PSCustomObject`).

---

## ✅ Cambios Realizados

### 1. **OneDrive.psm1**

#### Funciones Eliminadas (Obsoletas)
- ❌ `Send-OneDriveFile` (recibía Token, LocalPath, RemoteFileName)
- ❌ `Receive-OneDriveFile` (recibía Token, RemoteFileName, LocalPath)
- ❌ `Get-OneDriveFiles` (recibía Token)

#### Funciones Mantenidas (Modernas)
- ✅ `Get-OneDriveAuth` - Autenticación OAuth2
- ✅ `Test-OneDriveConnection` - Prueba completa (usa API directa internamente)
- ✅ `Copy-LlevarLocalToOneDrive` - Recibe `$OneDriveConfig` (objeto completo)
- ✅ `Copy-LlevarOneDriveToLocal` - Recibe solo `$OneDriveConfig` (sin `$DestinationPath` redundante)

#### Cambios en Firmas
**ANTES:**
```powershell
function Copy-LlevarOneDriveToLocal {
    param(
        [psobject]$OneDriveConfig,
        [string]$DestinationPath,  # ❌ REDUNDANTE
        ...
    )
}
```

**DESPUÉS:**
```powershell
function Copy-LlevarOneDriveToLocal {
    param(
        [psobject]$OneDriveConfig,  # ✅ Contiene TODO
        [datetime]$StartTime = (Get-Date),
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )
    
    # El destino se extrae del config:
    $destPath = if ($OneDriveConfig.DestinationPath) { 
        $OneDriveConfig.DestinationPath 
    } else { 
        $OneDriveConfig.Path 
    }
}
```

---

### 2. **Dropbox.psm1**

#### Funciones Eliminadas (Obsoletas)
- ❌ `Send-DropboxFile` (recibía LocalPath, RemotePath, Token)
- ❌ `Send-DropboxFileLarge` (recibía LocalPath, RemotePath, Token)
- ❌ `Receive-DropboxFile` (recibía RemotePath, LocalPath, Token)
- ❌ `Send-DropboxFolder` (recibía LocalFolder, RemotePath, Token)
- ❌ `Receive-DropboxFolder` (recibía RemotePath, LocalFolder, Token)

#### Funciones Mantenidas (Modernas)
- ✅ `Get-DropboxAuth` - Autenticación OAuth2
- ✅ `Get-DropboxToken` - Obtención de token
- ✅ `Connect-DropboxSession` - Validación de sesión
- ✅ `Copy-LlevarLocalToDropbox` - Recibe `$DropboxConfig` (objeto completo)
- ✅ `Copy-LlevarDropboxToLocal` - Recibe solo `$DropboxConfig` (sin `$DestinationPath` redundante)

#### Cambios en Firmas
**ANTES:**
```powershell
function Copy-LlevarDropboxToLocal {
    param(
        [psobject]$DropboxConfig,
        [string]$DestinationPath,  # ❌ REDUNDANTE
        ...
    )
}
```

**DESPUÉS:**
```powershell
function Copy-LlevarDropboxToLocal {
    param(
        [psobject]$DropboxConfig,  # ✅ Contiene TODO
        [datetime]$StartTime = (Get-Date),
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )
    
    # El destino se extrae del config:
    $destPath = if ($DropboxConfig.DestinationPath) { 
        $DropboxConfig.DestinationPath 
    } else { 
        $DropboxConfig.Path 
    }
}
```

---

### 3. **NormalMode.psm1**

#### Funciones Auxiliares Eliminadas
- ❌ `Send-ToOneDrive` (obsoleta)
- ❌ `Send-ToDropbox` (obsoleta)

#### Cambios en `Invoke-CompressedTransfer`

**ANTES:**
```powershell
if ($OrigenEsOneDrive) {
    Receive-OneDriveFolder -OneDrivePath "..." -LocalFolder $tempOrigenCloud  # ❌ Obsoleto
}

if ($DestinoEsOneDrive) {
    Send-ToOneDrive -Blocks $blocks ...  # ❌ Función obsoleta
}
```

**DESPUÉS:**
```powershell
if ($OrigenEsOneDrive) {
    # CORREGIDO: Usar función moderna con objeto config
    $oneDriveConfig = [PSCustomObject]@{
        Tipo              = "OneDrive"
        Path              = $OrigenMontado
        Token             = $TransferConfig.Origen.OneDrive.Token
        RefreshToken      = $TransferConfig.Origen.OneDrive.RefreshToken
        Email             = $TransferConfig.Origen.OneDrive.Email
        ApiUrl            = $TransferConfig.Origen.OneDrive.ApiUrl
        UseLocal          = $false
        DestinationPath   = $tempOrigenCloud
    }
    Copy-LlevarOneDriveToLocal -OneDriveConfig $oneDriveConfig
}

if ($DestinoEsOneDrive) {
    # CORREGIDO: Subir usando API directa
    $token = $TransferConfig.Destino.OneDrive.Token
    
    foreach ($block in $Blocks) {
        $fileContent = [System.IO.File]::ReadAllBytes($block)
        $uploadUrl = "https://graph.microsoft.com/v1.0/me/drive/root:${remotePath}/${fileName}:/content"
        $uploadHeaders = @{
            "Authorization" = "Bearer $token"
            "Content-Type"  = "application/octet-stream"
        }
        
        Invoke-RestMethod -Uri $uploadUrl -Headers $uploadHeaders -Method Put -Body $fileContent
    }
}
```

Lo mismo para **Dropbox**.

---

## 🎯 Razón de los Cambios

### Problema Original
1. **Duplicación**: Funciones antiguas con parámetros individuales vs. funciones modernas con objetos
2. **Redundancia**: Parámetros `$DestinationPath` cuando el config ya contiene toda la info
3. **Inconsistencia**: Algunas partes del código usaban funciones obsoletas

### Solución Implementada
1. **Eliminar funciones obsoletas** que reciben parámetros individuales
2. **Simplificar firmas** de funciones modernas: solo reciben el objeto config completo
3. **Actualizar llamadas** en `NormalMode.psm1` para usar:
   - Funciones modernas con objetos config
   - O llamadas directas a API cuando sea necesario (ej: upload de bloques)

---

## 📦 Estructura de Config Esperada

### OneDriveConfig
```powershell
[PSCustomObject]@{
    Tipo              = "OneDrive"
    Path              = "/Carpeta/Destino"
    Token             = "eyJ0eXAiOiJKV1QiLCJhbG..."
    RefreshToken      = "M.R3_BAY.CgAAAAAA..."
    Email             = "user@onedrive.com"
    ApiUrl            = "https://graph.microsoft.com/v1.0/me/drive"
    UseLocal          = $false
    LocalPath         = $null  # Solo si UseLocal=true
    DestinationPath   = "C:\DestinoLocal"  # Opcional: se extrae si falta
}
```

### DropboxConfig
```powershell
[PSCustomObject]@{
    Tipo              = "Dropbox"
    Path              = "/Carpeta/Destino"
    Token             = "sl.Bxxxxxxxxxxxxxxx..."
    RefreshToken      = $null
    Email             = $null
    ApiUrl            = "https://api.dropboxapi.com/2"
    UseLocal          = $false
    LocalPath         = $null  # Solo si UseLocal=true
    DestinationPath   = "C:\DestinoLocal"  # Opcional: se extrae si falta
}
```

---

## ✅ Tests Afectados

### Tests Que No Requieren Cambios
- ✅ `Test-OneDrive.ps1` - Usa `Get-OneDriveAuth` y `Test-OneDriveConnection` (correctas)
- ✅ `Test-Dropbox.ps1` - Busca funciones que ya no existen (se actualizará documento README)
- ✅ `Test.psm1` - Usa solo `Get-OneDriveAuth`, `Get-DropboxAuth`, `Test-OneDriveConnection` (correctas)

### Actualización Requerida en Tests
Los tests de Dropbox buscan funciones que ya no existen:
```powershell
$requiredFunctions = @(
    "Send-DropboxFile",        # ❌ Ya no existe
    "Get-DropboxFile",         # ❌ Ya no existe
    "Send-DropboxFolder",      # ❌ Ya no existe
    "Get-DropboxFolder",       # ❌ Ya no existe
    "Send-DropboxFileLarge"    # ❌ Ya no existe
)
```

**Solución**: Actualizar `Tests\Test-Dropbox.ps1` para verificar solo las funciones modernas exportadas.

---

## 📄 Archivos Modificados

1. ✅ `Modules\Transfer\OneDrive.psm1` - Eliminadas 3 funciones obsoletas
2. ✅ `Modules\Transfer\Dropbox.psm1` - Eliminadas 5 funciones obsoletas
3. ✅ `Modules\Parameters\NormalMode.psm1` - Corregido `Invoke-CompressedTransfer`
4. ✅ `LIMPIEZA-FUNCIONES-OBSOLETAS.md` - Este documento

---

## 🔄 Próximos Pasos

### Pendiente
1. Actualizar `Tests\Test-Dropbox.ps1` (TEST 6) para verificar funciones correctas
2. Actualizar `Tests\README.md` con nueva info de funciones

### Completado
- [x] Eliminar funciones obsoletas de OneDrive
- [x] Eliminar funciones obsoletas de Dropbox
- [x] Simplificar firmas de funciones modernas
- [x] Corregir `Invoke-CompressedTransfer` en NormalMode
- [x] Documentar cambios

---

## 💡 Lecciones Aprendidas

1. **Objetos unificados > Parámetros individuales**: Más mantenible y escalable
2. **Parámetros redundantes**: Evitar duplicar información que ya está en el config
3. **API directa vs. funciones wrapper**: Para casos simples (upload bloques), llamar directamente a la API
4. **Tests deben ser actualizados**: Cuando se eliminan funciones, actualizar tests en consecuencia

---

**Fecha**: 3 de diciembre de 2025  
**Autor**: Corrección de arquitectura unificada con TransferConfig
