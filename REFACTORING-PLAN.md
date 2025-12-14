# 🔧 PLAN DE REFACTORIZACIÓN: FLUJO UNIFICADO CON TransferConfig

## 📋 OBJETIVO
Asegurar que TODOS los módulos sigan el patrón unificado:
- **RECIBEN** TransferConfig como parámetro (no lo crean)
- **MODIFICAN** el objeto directamente si es necesario
- **DEVUELVEN** valores/resultados, NO nuevos configs
- **Se llaman desde NormalMode.psm1** como orquestador central

---

## ✅ PATRÓN CORRECTO

### **Módulos de Transfer/ (FTP, OneDrive, Dropbox, Local, UNC)**

```powershell
function Send-LlevarXXXFile {
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Llevar,  # ← RECIBE (no crea)
        
        [Parameter(Mandatory = $true)]
        [string]$LocalPath,
        
        [Parameter(Mandatory = $true)]
        [string]$RemotePath
    )
    
    # ✅ CORRECTO: Extrae configuración del objeto recibido
    $config = $Llevar.Destino.XXX
    $token = $config.Token
    
    # ✅ CORRECTO: Usa la configuración
    # Sube el archivo
    
    # ✅ CORRECTO: Devuelve resultado, NO modifica config
    return @{
        Success = $true
        BytesTransferred = $bytes
    }
}
```

### **Módulos de Compression/ (SevenZip, BlockSplitter)**

```powershell
function Compress-Folder {
    param(
        [string]$Origen,
        [string]$Temp,
        [string]$SevenZ,
        [string]$Clave,
        [int]$BlockSizeMB
    )
    
    # ❌ NO necesitan TransferConfig
    # ✅ Son funciones utilitarias independientes
    # ✅ Devuelven resultados
    
    return @{
        Files = $bloques
        CompressionType = "7-Zip"
    }
}
```

### **Módulos de System/ (ISO, Audio, FileSystem)**

```powershell
function New-LlevarIsoMain {
    param(
        [string]$Origen,
        [string]$Destino,
        [string]$Temp,
        [string]$SevenZ,
        [int]$BlockSizeMB,
        [string]$Clave,
        [string]$IsoDestino
    )
    
    # ❌ NO necesitan TransferConfig
    # ✅ Son funciones de sistema independientes
    # ✅ Reciben parámetros primitivos
}
```

---

## 📊 ESTADO ACTUAL DE MÓDULOS

### ✅ **CORRECTOS** (ya siguen el patrón)

| Módulo | Estado | Notas |
|--------|--------|-------|
| **FTP.psm1** | ✅ | Recibe `[TransferConfig]$Llevar`, NO crea instancias |
| **Dropbox.psm1** | ✅ | Recibe `[TransferConfig]$Llevar`, NO crea instancias |
| **Unified.psm1** | ✅ | Todas las funciones reciben `[TransferConfig]$Llevar` |
| **Compression/** | ✅ | NO usan TransferConfig (funciones utilitarias) |
| **System/ISO.psm1** | ✅ | NO usa TransferConfig (función de sistema) |

### ⚠️ **REQUIEREN REVISIÓN**

| Módulo | Problema | Acción Requerida |
|--------|----------|------------------|
| **OneDriveTransfer.psm1** | Import condicional innecesario (líneas 14-21) | Eliminar import de TransferConfig |
| **OneDriveTransfer.psm1** | ¿Crea instancias internamente? | Verificar todas las funciones |
| **Local.psm1** | ¿Recibe TransferConfig? | Verificar firma de funciones |
| **UNC.psm1** | ¿Recibe TransferConfig? | Verificar firma de funciones |
| **Floppy.psm1** | No revisado | Verificar patrón |

---

## 🔍 ANÁLISIS POR MÓDULO

### **1. OneDrive/OneDriveTransfer.psm1**

**Problemas identificados:**
1. ✅ Import condicional de TransferConfig (líneas 14-21) - **ELIMINAR**
2. ❓ ¿Funciones crean instancias o reciben parámetro?

**Funciones clave a revisar:**
- `Send-LlevarOneDriveFile` → ¿Recibe `$Llevar`?
- `Receive-LlevarOneDriveFile` → ¿Recibe `$Llevar`?
- `Copy-LlevarLocalToOneDrive` → ¿Recibe `$Llevar`?
- `Copy-LlevarOneDriveToLocal` → ¿Recibe `$Llevar`?

**Acción:**
```powershell
# ❌ ELIMINAR (líneas 14-21):
if (-not (Get-Command New-TransferConfig -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $ModulesPath "Core\TransferConfig.psm1") -Force -Global
    if (-not (Get-Command New-TransferConfig -ErrorAction SilentlyContinue)) {
        throw "ERROR: No se pudo cargar TransferConfig.psm1"
    }
}

# ✅ VERIFICAR que todas las funciones reciban:
param([TransferConfig]$Llevar, ...)
```

---

### **2. Transfer/Local.psm1**

**Estado:** No revisado completamente

**Verificar:**
- ¿Tiene funciones de transferencia?
- ¿Reciben `[TransferConfig]$Llevar`?
- ¿Crean instancias internamente?

---

### **3. Transfer/UNC.psm1**

**Estado:** No revisado completamente

**Verificar:**
- ¿Tiene funciones de transferencia?
- ¿Reciben `[TransferConfig]$Llevar`?
- ¿Usa Mount-LlevarNetworkPath correctamente?

---

### **4. Transfer/Floppy.psm1**

**Estado:** No revisado

**Verificar:**
- ¿Es funcional o legacy?
- ¿Sigue el patrón correcto?

---

## 🎯 PLAN DE ACCIÓN

### **FASE 1: Limpieza de Imports** ✅ **COMPLETADA**

- [x] Eliminar import condicional de OneDriveTransfer.psm1 (líneas 14-21) ✅
- [x] Eliminar import condicional de Dropbox.psm1 ✅
- [x] Eliminar import condicional de FTP.psm1 ✅

### **FASE 2: Verificación de Firmas** ✅ **COMPLETADA**

- [x] OneDriveTransfer.psm1: ✅ Todas las funciones reciben `$Llevar` (Send-LlevarOneDriveFile, Copy-LlevarLocalToOneDrive, etc.)
- [x] Dropbox.psm1: ✅ Todas las funciones reciben `[TransferConfig]$Llevar`
- [x] FTP.psm1: ✅ Todas las funciones reciben `[TransferConfig]$Llevar`
- [x] Unified.psm1: ✅ Todas las funciones reciben `[TransferConfig]$Llevar`

### **FASE 3: Eliminación de Creación de Instancias** ✅ **COMPLETADA**

- [x] ✅ NO hay llamadas a `New-TransferConfig` en Transfer/
- [x] ✅ NO hay llamadas a `[TransferConfig]::new()` en Transfer/
- [x] ✅ Todas las funciones reciben el objeto como parámetro

### **FASE 4: Flujo desde NormalMode.psm1** ✅ **VERIFICADO**

- [x] NormalMode.psm1 crea UN SOLO TransferConfig al inicio
- [x] NormalMode.psm1 pasa el MISMO objeto a TODAS las funciones
- [x] NormalMode.psm1 NO crea configs temporales innecesarios
- [x] NormalMode.psm1 usa Get-TransferConfigValue correctamente

### **FASE 5: Testing** ⏳ **PENDIENTE**

- [ ] Ejecutar `.\Llevar.ps1 -Instalar`
- [ ] Ejecutar `.\Llevar.ps1 -Test FTP`
- [ ] Ejecutar `.\Llevar.ps1 -Test OneDrive`
- [ ] Verificar flujo completo Local→FTP
- [ ] Verificar flujo completo Local→OneDrive

---

## 📝 CHECKLIST DE VERIFICACIÓN

Para cada módulo en `Transfer/`:

```
[ ] ¿Tiene import condicional de TransferConfig? → ELIMINAR
[ ] ¿Las funciones principales reciben [TransferConfig]$Llevar? → SÍ
[ ] ¿Las funciones crean instancias con New-TransferConfig? → NO
[ ] ¿Las funciones modifican el objeto directamente? → SÍ (si es necesario)
[ ] ¿Las funciones devuelven resultados en lugar de configs? → SÍ
[ ] ¿Se llaman desde NormalMode.psm1 o Unified.psm1? → SÍ
```

Para cada módulo en `Compression/` y `System/`:

```
[ ] ¿Necesita TransferConfig? → Probablemente NO
[ ] ¿Es función utilitaria independiente? → SÍ
[ ] ¿Recibe parámetros primitivos? → SÍ
[ ] ¿Devuelve resultados? → SÍ
```

---

## 🚀 PRÓXIMOS PASOS

1. **Leer OneDriveTransfer.psm1 completo** para identificar creación de instancias
2. **Leer Local.psm1 completo** para verificar patrón
3. **Leer UNC.psm1 completo** para verificar patrón
4. **Aplicar correcciones** en orden:
   - Eliminar imports
   - Corregir firmas
   - Eliminar creación de instancias
5. **Testing end-to-end**

---

## ✅ RESULTADO ESPERADO

**Flujo unificado:**

```
Llevar.ps1
  ├→ Crea TransferConfig (NEW-TransferConfig)
  ├→ Configura origen/destino (menús interactivos)
  └→ Llama NormalMode.psm1 (pasa TransferConfig)
      ├→ Initialize-TransferPaths (modifica TransferConfig.Interno)
      ├→ Invoke-CompressedTransfer (pasa TransferConfig)
      │   ├→ Compress-Folder (parámetros primitivos, NO config)
      │   ├→ New-InstallerScript (parámetros primitivos)
      │   └→ Send-LlevarOneDriveFile (recibe TransferConfig)
      │       └→ Extrae config.Destino.OneDrive
      └→ Clear-TransferPaths (modifica TransferConfig.Interno)
```

**UN SOLO objeto TransferConfig** fluye por toda la aplicación.
**NINGUNA función** crea instancias nuevas.
**TODAS las funciones de Transfer/** reciben `[TransferConfig]$Llevar`.
