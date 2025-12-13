# AUDITORÍA DE IMPORTS Y EXPORTS - PROYECTO LLEVAR.PS1

## ⚠️ PROBLEMAS CRÍTICOS DETECTADOS

### 1. **Clase TransferConfig no se exporta correctamente**

**Ubicación:** `Modules/Core/TransferConfig.psm1`

**Problema:**
```powershell
# ACTUAL (líneas 562-568)
$ExecutionContext.SessionState.PSVariable.Set('TransferConfig', [TransferConfig])
if ($PSVersionTable.PSVersion.Major -ge 5) {
    $null = [TransferConfig]
}
```

**Solución Requerida:**
```powershell
# Después del Export-ModuleMember, agregar:
$ExecutionContext.SessionState.Module.OnRemove = {
    Remove-TypeData -TypeName TransferConfig -ErrorAction SilentlyContinue
}

# Exportar la clase explícitamente
$script:TransferConfigType = [TransferConfig]
Export-ModuleMember -Function @(...) -Variable TransferConfigType
```

---

### 2. **Imports Silenciados Ocultan Errores**

**Ubicación:** `Llevar.ps1` líneas 219-260

**Problema:**
```powershell
# TODOS los imports usan:
-ErrorAction SilentlyContinue -WarningAction SilentlyContinue
```

Esto oculta errores CRÍTICOS como:
- Módulos que no existen
- Errores de sintaxis en .psm1
- Funciones no exportadas
- Clases no disponibles

**Solución Requerida:**
```powershell
# Cambiar TODOS los imports a:
-ErrorAction Continue -WarningAction Continue

# Los errores se capturan en $importErrors y se muestran INMEDIATAMENTE
# No después del logo cuando ya es tarde
```

---

### 3. **Dependencias Circulares**

**Detectado en:**

```
Banners.psm1 → Console.psm1
                ↓
ConfigMenus.psm1 → Banners.psm1
                    ↓
Navigator.psm1 ← ConfigMenus.psm1
```

**Impacto:** Puede causar fallos de importación impredecibles

---

### 4. **Rutas Inconsistentes en Imports Internos**

#### ❌ INCORRECTO:
```powershell
# Banners.psm1 línea 8
$ModulesPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ModulesPath "Modules\UI\Console.psm1")
# Esto crea ruta: Q:\Utilidad\Llevar\Modules\Modules\UI\Console.psm1 ❌
```

#### ✅ CORRECTO:
```powershell
# Browser.psm1 línea 10
$ModulesPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ModulesPath "Modules\Core\Logger.psm1")
# Esto crea ruta: Q:\Utilidad\Llevar\Modules\Core\Logger.psm1 ✅
```

---

## 📋 INVENTARIO COMPLETO DE MÓDULOS

### Core (3 módulos)
- ✅ **Logger.psm1** - Exporta 3 funciones
- ⚠️ **TransferConfig.psm1** - Exporta 9 funciones + clase (PROBLEMA)
- ✅ **Validation.psm1** - Exporta 7 funciones

### UI (6 módulos)
- ⚠️ **Banners.psm1** - Exporta 4 funciones (ruta import incorrecta)
- ✅ **Console.psm1** - Exporta 6 funciones
- ⚠️ **ConfigMenus.psm1** - Exporta 8 funciones (dependencia circular)
- ✅ **Menus.psm1** - Exporta 8 funciones
- ⚠️ **Navigator.psm1** - Exporta 2 funciones (dependencia circular)
- ✅ **ProgressBar.psm1** - Exporta 2 funciones

### System (4 módulos)
- ✅ **Audio.psm1** - Exporta 1 función
- ✅ **Browser.psm1** - Exporta 6 funciones
- ✅ **FileSystem.psm1** - Exporta 9 funciones
- ✅ **Robocopy.psm1** - Exporta 3 funciones

### Transfer (8 módulos)
- ✅ **Dropbox.psm1** - Exporta 5 funciones
- ✅ **Floppy.psm1** - Exporta 14 funciones
- ✅ **FTP.psm1** - Exporta 6 funciones
- ✅ **Local.psm1** - Exporta 4 funciones
- ✅ **OneDrive.psm1** - Wrapper (21 funciones re-exportadas)
  - ✅ **OneDrive/OneDriveAuth.psm1** - Exporta 6 funciones
  - ✅ **OneDrive/OneDriveTransfer.psm1** - Exporta 15 funciones
- ✅ **UNC.psm1** - Exporta 9 funciones
- ✅ **Unified.psm1** - Exporta 7 funciones

### Compression (3 módulos)
- ✅ **BlockSplitter.psm1** - Exporta 3 funciones
- ✅ **NativeZip.psm1** - Exporta 2 funciones
- ✅ **SevenZip.psm1** - Exporta 4 funciones

### Installation (3 módulos)
- ✅ **Installer.psm1** - Exporta 10 funciones
- ✅ **ISO.psm1** - Exporta 7 funciones
- ✅ **SystemInstall.psm1** - Exporta 5 funciones

### Parameters (8 módulos)
- ✅ **Example.psm1** - Exporta 1 función
- ✅ **Help.psm1** - Exporta 1 función
- ✅ **Install.psm1** - Exporta 1 función
- ✅ **InstallationCheck.psm1** - Exporta 1 función
- ✅ **InteractiveMenu.psm1** - Exporta 1 función
- ✅ **NormalMode.psm1** - Exporta 1 función
- ✅ **Robocopy.psm1** - Exporta 1 función
- ✅ **Test.psm1** - Exporta 1 función

### Utilities (5 módulos)
- ✅ **Examples.psm1** - Exporta 4 funciones
- ✅ **Help.psm1** - Exporta 5 funciones
- ✅ **Installation.psm1** - Exporta 2 funciones
- ✅ **PathSelectors.psm1** - Exporta 2 funciones
- ✅ **VolumeManagement.psm1** - Exporta 15 funciones

---

## 🔧 ACCIONES CORRECTIVAS REQUERIDAS

### PRIORIDAD ALTA (Crítico)

1. **Corregir export de clase TransferConfig**
   - Archivo: `Modules/Core/TransferConfig.psm1`
   - Líneas: 562-568
   - Ver solución arriba

2. **Eliminar -ErrorAction SilentlyContinue de imports**
   - Archivo: `Llevar.ps1`
   - Líneas: 219-260
   - Cambiar a `-ErrorAction Continue`

3. **Corregir rutas de import en Banners.psm1**
   - Archivo: `Modules/UI/Banners.psm1`
   - Líneas: 8-9
   - Eliminar el "Modules\" duplicado

### PRIORIDAD MEDIA (Importante)

4. **Resolver dependencias circulares**
   - Separar funciones compartidas a módulo común
   - O usar imports condicionales

5. **Agregar validación de clase TransferConfig en Llevar.ps1**
   ```powershell
   # Después de importar TransferConfig.psm1
   if (-not ([System.Management.Automation.PSTypeName]'TransferConfig').Type) {
       Write-Error "❌ CRÍTICO: Clase TransferConfig no disponible"
       exit 1
   }
   ```

### PRIORIDAD BAJA (Mejora)

6. **Estandarizar formato de Export-ModuleMember**
   - Algunos usan arrays multi-línea
   - Otros una sola línea
   - Unificar formato

---

## 📊 ESTADÍSTICAS

- **Total de módulos:** 41
- **Módulos con exports correctos:** 38 (93%)
- **Módulos con problemas:** 3 (7%)
- **Funciones totales exportadas:** ~180+
- **Clases exportadas:** 1 (TransferConfig)

---

## ✅ VERIFICACIÓN POST-CORRECCIÓN

Ejecutar este script para verificar:

```powershell
# Test-Imports.ps1
$ErrorActionPreference = 'Stop'
$ModulesPath = "Q:\Utilidad\Llevar\Modules"

Write-Host "Verificando imports..." -ForegroundColor Cyan

# Test 1: Importar TransferConfig
Import-Module "$ModulesPath\Core\TransferConfig.psm1" -Force
if (-not ([System.Management.Automation.PSTypeName]'TransferConfig').Type) {
    Write-Host "❌ FALLO: Clase TransferConfig no disponible" -ForegroundColor Red
    exit 1
}
Write-Host "✅ TransferConfig OK" -ForegroundColor Green

# Test 2: Crear instancia
try {
    $cfg = [TransferConfig]::new()
    Write-Host "✅ Instancia TransferConfig creada" -ForegroundColor Green
} catch {
    Write-Host "❌ FALLO: No se puede crear instancia: $_" -ForegroundColor Red
    exit 1
}

# Test 3: Importar todos los módulos Core
$coreModules = Get-ChildItem "$ModulesPath\Core\*.psm1"
foreach ($mod in $coreModules) {
    try {
        Import-Module $mod.FullName -Force -ErrorAction Stop
        Write-Host "✅ $($mod.Name)" -ForegroundColor Green
    } catch {
        Write-Host "❌ $($mod.Name): $_" -ForegroundColor Red
    }
}

Write-Host "`n✅ VERIFICACIÓN COMPLETA" -ForegroundColor Cyan
```

---

**Fecha de auditoría:** 11 de diciembre de 2025  
**Auditado por:** GitHub Copilot  
**Versión:** LLEVAR.PS1 PowerShell Modernizado
