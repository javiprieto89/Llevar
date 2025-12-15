# AGENTS.md - Guía para Agentes de IA trabajando en Llevar

## 📋 INFORMACIÓN DEL PROYECTO

**Llevar** es una modernización en PowerShell 7 del clásico LLEVAR.BAT de Alex Soft (Alejandro Nacir).
Sistema de transferencia y compresión de archivos con soporte para USB, FTP, OneDrive, Dropbox, ISO, y más.

**Versión PowerShell requerida:** 7.0 o superior  
**Plataforma:** Windows 10+  
**Ubicación de instalación:** C:\Llevar  
**Estructura modular:** Sí - 30+ módulos organizados por categorías

---

## 🏗️ ARQUITECTURA DEL PROYECTO

### Estructura de Carpetas

```
Llevar/
├── Llevar.ps1              # Script principal
├── Llevar.cmd              # Wrapper para ejecución rápida
├── Import-LlevarModules.ps1 # Importador de módulos (desarrollo)
├── Modules/                # Módulos organizados por categoría
│   ├── Core/               # TransferConfig, Validation, Logger
│   ├── Transfer/           # FTP, OneDrive, Dropbox, Local, UNC, Unified
│   ├── UI/                 # Banners, Menus, Console, Navigator, ProgressBar
│   ├── System/             # Audio, Browser, FileSystem, ISO, Robocopy
│   ├── Compression/        # SevenZip, NativeZip, BlockSplitter
│   ├── Installation/       # Install, Uninstall, InstallationCheck
│   ├── Parameters/         # Example, Help, Test, InteractiveMenu, NormalMode
│   └── Utilities/          # Examples, Help, PathSelectors, VolumeManagement
├── Data/                   # Configuraciones, iconos, banners
├── Docs/                   # Documentación de usuario
├── Scripts/                # Scripts de utilidad y demos
├── Tests/                  # Tests de integración y unitarios
└── Logs/                   # Logs generados (ignorados en git)
```

### Módulos Clave

#### **Core/TransferConfig.psm1** - CORAZÓN DEL SISTEMA
- Configuración unificada para todas las transferencias
- PSCustomObject con estructura estandarizada
- Fuente única de verdad (Single Source of Truth)
- **NUNCA duplicar esta lógica en otros módulos**

#### **Transfer/Unified.psm1** - DISPATCHER CENTRAL
- `Invoke-TransferDispatcher`: Enrutador principal de transferencias
- Detecta automáticamente tipo de origen/destino
- Coordina entre Local, FTP, OneDrive, Dropbox, UNC
- Wrappers como `Copy-LlevarLocalToFtp` son VÁLIDOS (llaman al dispatcher)

#### **Core/Validation.psm1** - VALIDACIONES CENTRALIZADAS
- `Test-IsFtpPath`, `Test-IsOneDrivePath`, `Test-IsDropboxPath`, `Test-IsUncPath`
- **Estas funciones NO deben duplicarse en otros módulos**
- Todos los módulos Transfer deben usar estas validaciones

#### **Installation/Installer.psm1** - EXCEPCIÓN ESPECIAL
- ⚠️ **ÚNICA EXCEPCIÓN a la regla de no duplicar**
- Genera scripts standalone que necesitan funciones embebidas
- Puede duplicar: `Get-SevenZip`, `Get-AllBlocks`, `Write-ErrorLog`, etc.
- **NO eliminar duplicados de este archivo**

---

## ⚠️ REGLAS CRÍTICAS

### 1. **NO Duplicar Código (excepto Installer.psm1)**
- ✅ Centralizar en módulos Core/
- ✅ Reutilizar funciones existentes
- ❌ NO duplicar Test-Is* en módulos Transfer
- ❌ NO duplicar lógica de TransferConfig
- ✅ EXCEPCIÓN: Installer.psm1 puede duplicar para scripts standalone

### 2. **Conservar Funciones Útiles No Usadas**
- ✅ Mantener funciones de export/import JSON aunque no estén en uso
- ✅ Mantener helpers y utilidades preparadas para casos futuros
- ✅ Mantener funciones de desarrollo/debugging
- ❌ Solo eliminar: duplicados exactos, legacy obsoleto, código muerto confirmado

### 3. **Capturar Resultados Booleanos**
```powershell
# ❌ MAL - imprime False/True en consola
if (-not (Test-SomeCondition)) { }

# ✅ BIEN - captura primero
$result = Test-SomeCondition
if (-not $result) { }
```

### 4. **Expresiones Booleanas Complejas**
```powershell
# ❌ MAL - puede imprimir resultado intermedio
$var = $condition1 -and $condition2

# ✅ BIEN - envolver en paréntesis dobles
$var = (($condition1) -and ($condition2))
```

### 5. **Importación de Módulos en Llevar.ps1**
- Orden importa: Core → UI básicos → Compression → Transfer → UI avanzados
- ConfigMenus.psm1 se importa DESPUÉS de Transfer (necesita funciones de transfer)
- Usar `-Force -Global` para sobrescribir y disponibilidad global
- SilentlyContinue para warnings/errors durante importación

---

## 🔧 FUNCIONES CENTRALIZADAS

### Validaciones (Core/Validation.psm1)
```powershell
Test-IsFtpPath -Path $ruta          # Detecta ftp:// o ftps://
Test-IsOneDrivePath -Path $ruta     # Detecta ONEDRIVE:
Test-IsDropboxPath -Path $ruta      # Detecta DROPBOX:
Test-IsUncPath -Path $ruta          # Detecta \\servidor
Test-IsRunningInIDE                 # Detecta VS Code, ISE, etc.
Test-LlevarInstallation             # Verifica C:\Llevar existe
Test-Windows10OrLater               # Valida Windows 10+
```

### UI Helpers (UI/ConfigMenus.psm1)
```powershell
Show-OrigenBloqueadoNotification -TransferConfig $config  # Notifica origen bloqueado
Show-MainMenu -TransferConfig $config                     # Menú principal interactivo
Show-IsoMenu -TransferConfig $config                      # Menú de configuración ISO
```

### Logging (Core/Logger.psm1)
```powershell
Write-Log "Mensaje" "INFO|WARNING|ERROR|DEBUG"
Write-ErrorLog "Mensaje de error"
Initialize-LogFile -Verbose:$Verbose
```

### TransferConfig (Core/TransferConfig.psm1)
```powershell
$config = New-TransferConfig
Set-TransferOrigin -Config $config -Type "Local" -Path "C:\Data"
Set-TransferDestination -Config $config -Type "FTP" -Server "ftp://example.com"
Get-TransferPath -Config $config -Section "Origen|Destino"
```

---

## 🧪 TESTING

### Estructura de Tests
- **Tests/Test-*.ps1**: Tests de integración por escenario
- **Tests/Run-AllTests.ps1**: Ejecutor de suite completa
- Tests pueden tener helpers duplicados (no aplicar regla de no duplicar)

### Ejecutar Tests
```powershell
# Test específico
.\Tests\Test-LocalToLocal.ps1

# Suite completa
.\Tests\Run-AllTests.ps1
```

---

## 📝 CONVENCIONES DE CÓDIGO

### Nombres de Funciones
- **Verbos aprobados:** Get-, Set-, New-, Test-, Invoke-, Copy-, Send-, Receive-, Show-, Mount-
- **Prefijo Llevar:** Usar en funciones específicas del proyecto (ej: `Copy-LlevarLocalToFtp`)
- **CamelCase:** Siempre para funciones y parámetros

### Comentarios
```powershell
# ========================================================================== #
#                          SECCIÓN PRINCIPAL                                 #
# ========================================================================== #

function Nombre-Funcion {
    <#
    .SYNOPSIS
        Descripción corta
    .DESCRIPTION
        Descripción detallada
    .PARAMETER Nombre
        Descripción del parámetro
    .EXAMPLE
        Ejemplo de uso
    #>
    param([string]$Nombre)
    
    # Lógica aquí
}
```

### Exports
```powershell
# Al final del módulo
Export-ModuleMember -Function @(
    'Funcion1',
    'Funcion2',
    'Funcion3'
)
```

---

## 🔍 BUSCAR DUPLICADOS

### Comando para encontrar funciones duplicadas
```powershell
$functions = Get-ChildItem "Q:\Utilidad\Llevar\Modules" -Filter "*.psm1" -Recurse | ForEach-Object { 
    Select-String -Path $_.FullName -Pattern '^function\s+([A-Za-z0-9-]+)' | ForEach-Object {
        [PSCustomObject]@{
            Function = $_.Matches.Groups[1].Value
            File = $_.Path
            Line = $_.LineNumber
        }
    }
}
$duplicates = $functions | Group-Object Function | Where-Object { $_.Count -gt 1 }
$duplicates | ForEach-Object { 
    Write-Host "`n=== $($_.Name) ($($_.Count) veces) ===" -ForegroundColor Cyan
    $_.Group | ForEach-Object { Write-Host "  - $($_.File):$($_.Line)" -ForegroundColor Yellow }
}
```

### Excluir de análisis de duplicados
- `Installation/Installer.psm1` - Genera scripts standalone
- `Tests/*.ps1` - Pueden tener helpers locales
- `Scripts/*.ps1` - Scripts de utilidad independientes

---

## 🚫 ARCHIVOS ELIMINADOS (NO RECREAR)

### Módulos Obsoletos
- ❌ `Installation/SystemInstall.psm1` - Reemplazado por Installation.psm1

### Documentación Legacy
- ❌ `Docs/HISTORIA-DEL-PROYECTO.md`
- ❌ `Docs/MENU-CONTEXTUAL-FIXES.md`
- ❌ `Docs/PROGRESS-IMPROVEMENTS.md`
- ❌ `Docs/README2.md`
- ❌ `Docs/POWERSHELL7-REQUIREMENT.md`
- ❌ `Docs/HELPER-FUNCTIONS.md`
- ❌ `Docs/ONEDRIVE-TOKEN-CACHE.md`
- ❌ `Docs/MENU-INTERACTIVO.md`
- ❌ `Docs/INSTALACION-Y-DESINSTALACION.md`

---

## 🎯 CASOS DE USO COMUNES

### Agregar Nueva Función de Validación
1. Agregar en `Core/Validation.psm1`
2. Exportar en Export-ModuleMember
3. Usar desde otros módulos (NO duplicar)

### Agregar Nuevo Tipo de Transfer
1. Crear módulo en `Transfer/NuevoTipo.psm1`
2. Implementar funciones Send-/Receive-
3. Agregar detección en `Transfer/Unified.psm1`
4. Actualizar `TransferConfig.psm1` si requiere nueva configuración

### Agregar Nueva UI
1. Crear en `UI/NuevoComponente.psm1`
2. Importar en Llevar.ps1 (orden correcto)
3. Exportar funciones Show-*

### Modificar TransferConfig
1. Actualizar estructura en `New-TransferConfig`
2. Actualizar getters/setters relacionados
3. Verificar todos los módulos que lo usan
4. **NO duplicar lógica de TransferConfig**

---

## 🔄 SINCRONIZACIÓN Q: → C:

### Comando estándar
```powershell
robocopy "Q:\Utilidad\Llevar" "C:\Llevar" /MIR /R:1 /W:1 /NFL /NDL /NP /XD "Llevar_Original" /XF "*.log" "*.tmp"
```

### Explicación
- `/MIR`: Mirror (copia todo, elimina extras)
- `/R:1 /W:1`: 1 reintento, 1 segundo de espera
- `/NFL /NDL /NP`: Sin listar archivos/directorios/progreso
- `/XD`: Excluir directorio Llevar_Original
- `/XF`: Excluir archivos .log y .tmp

---

## 📊 ESTADÍSTICAS DEL PROYECTO

- **Total módulos:** 30+
- **Total funciones:** 200+
- **Líneas de código:** ~85,000
- **Módulos Core:** 3 (TransferConfig, Validation, Logger)
- **Módulos Transfer:** 8 (Local, FTP, OneDrive, Dropbox, UNC, Floppy, Unified, OneDrive/)
- **Módulos UI:** 6 (Banners, ConfigMenus, Console, Menus, Navigator, ProgressBar)

---

## 🐛 DEBUGGING

### Activar Modo Verbose
```powershell
.\Llevar.ps1 -Verbose
```

### Ver Logs
```powershell
# Logs en carpeta
Get-ChildItem "Q:\Utilidad\Llevar\Logs" -Filter "LLEVAR_*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Transcript (captura todo)
Get-Content "Q:\Utilidad\Llevar\Logs\LLEVAR_*_TRANSCRIPT.log" -Tail 50
```

### Verificar Imports
```powershell
Get-Module -Name * | Where-Object { $_.Path -like "*Llevar*" }
```

---

## ✅ CHECKLIST PRE-COMMIT

- [ ] No hay duplicados (excepto Installer.psm1)
- [ ] Funciones de validación usan Core/Validation.psm1
- [ ] TransferConfig es fuente única de verdad
- [ ] Expresiones booleanas capturadas correctamente
- [ ] Logs actualizados sin errores críticos
- [ ] Tests ejecutados sin fallos
- [ ] Sincronizado Q: → C:
- [ ] Documentación actualizada si aplica

---

## 🎓 LECCIONES APRENDIDAS

1. **Capturar siempre resultados booleanos** antes de evaluarlos en `if` para evitar output no deseado
2. **Paréntesis dobles** en expresiones AND/OR complejas: `$(($cond1) -and ($cond2))`
3. **Installer.psm1 es especial** - necesita duplicados para scripts standalone
4. **Import order matters** - Core primero, UI avanzados al final
5. **Funciones útiles no usadas tienen valor** - no eliminar por no estar en uso actual
6. **Test-Is* van en Validation.psm1** - nunca duplicar en módulos Transfer
7. **SystemInstall.psm1 fue eliminado** - Installation.psm1 es el módulo actual

---

## 📞 CONTACTO DEL PROYECTO

**Autor original:** Alejandro Nacir (Alex Soft)  
**Versión PowerShell:** Modernización del clásico LLEVAR.BAT  
**Licencia:** Homenaje al trabajo original de Alejandro Nacir

---

**Última actualización:** 15 de diciembre de 2025
