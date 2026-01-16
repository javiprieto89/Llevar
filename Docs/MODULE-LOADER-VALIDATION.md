# Validación de Importación de Módulos

## Descripción General

El sistema de carga de módulos de Llevar utiliza un patrón de validación explícito donde:
- `ModuleLoader.psm1` importa módulos y retorna un objeto con el estado
- Los scripts que lo usan **DEBEN** verificar `Success = true/false`
- Si `Success = false`, el script **DEBE** terminar la ejecución

## Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│ ModuleLoader.psm1                                           │
│                                                             │
│  1. Importa Logger.psm1 primero                            │
│  2. Importa módulos por categoría                          │
│  3. Valida cada módulo con Get-Module                      │
│  4. Si hay errores:                                        │
│     - Muestra mensaje detallado en consola                 │
│     - Registra en log                                      │
│     - Retorna Success = false                              │
│  5. NO termina la ejecución (no hace throw)                │
│                                                             │
│  Return: PSCustomObject {                                  │
│    Success: bool                                            │
│    Warnings: array                                          │
│    Errors: array                                            │
│    HasWarnings: bool                                        │
│    HasErrors: bool                                          │
│    LoadedModules: array                                     │
│    FailedModules: array                                     │
│    TotalModules: int                                        │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Script que usa ModuleLoader (Llevar.ps1, tests, etc.)      │
│                                                             │
│  $importResult = Import-LlevarModules ...                  │
│                                                             │
│  if (-not $importResult.Success) {                         │
│      Write-Host "Error..." -ForegroundColor Red            │
│      exit 1  ◄── RESPONSABILIDAD DEL SCRIPT                │
│  }                                                          │
│                                                             │
│  # Continuar solo si Success = true                        │
└─────────────────────────────────────────────────────────────┘
```

## Patrón de Uso Correcto

### En Scripts Principales (Llevar.ps1)

```powershell
# 1. Importar ModuleLoader
Import-Module (Join-Path $ModulesPath "Core\ModuleLoader.psm1") -Force -Global -ErrorAction Stop

# 2. Ejecutar importación
$importResult = Import-LlevarModules -ModulesPath $ModulesPath -Categories 'All' -Global

# 3. VALIDAR RESULTADO (OBLIGATORIO)
if (-not $importResult.Success) {
    Write-Host "No se pudo inicializar el sistema debido a errores en la carga de módulos." -ForegroundColor Red
    Write-Host "Presione ENTER para salir..." -ForegroundColor Yellow
    Read-Host
    exit 1  # ◄── TERMINAR EJECUCIÓN
}

# 4. Opcionalmente manejar warnings
if ($importResult.HasWarnings) {
    # Guardar para mostrar después del logo
    $script:HasImportWarnings = $true
    $importWarnings = $importResult.Warnings
}

# 5. Continuar solo si Success = true
# ... resto del código ...
```

### En Scripts de Test

```powershell
# Import-LlevarModules.ps1 (helper para tests)

Import-Module (Join-Path $ModulesPath "Core\ModuleLoader.psm1") -Force -Global -ErrorAction Stop

$importResult = Import-LlevarModules -ModulesPath $ModulesPath -Categories 'All' -Global

# VALIDAR - Tests no pueden ejecutarse sin módulos
if (-not $importResult.Success) {
    Write-Host "✗ Error crítico durante importación de módulos" -ForegroundColor Red
    Write-Host "Los tests no pueden ejecutarse sin los módulos requeridos." -ForegroundColor Yellow
    exit 1
}

# Mostrar warnings si existen
if ($importResult.HasWarnings) {
    Write-Host "⚠ Advertencias durante importación ($($importResult.Warnings.Count))" -ForegroundColor Yellow
    foreach ($warning in $importResult.Warnings) {
        Write-Host "  - $warning" -ForegroundColor Gray
    }
}

Write-Host "✓ Módulos cargados ($($importResult.LoadedModules.Count)/$($importResult.TotalModules))" -ForegroundColor Green
```

## Objeto de Retorno

El objeto retornado por `Import-LlevarModules` contiene:

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `Success` | bool | **true** si todos los módulos se cargaron correctamente<br>**false** si uno o más módulos fallaron |
| `Warnings` | array | Lista de advertencias (módulos opcionales que fallaron) |
| `Errors` | array | Lista detallada de errores con PSCustomObject por cada fallo |
| `HasWarnings` | bool | Indica si hay advertencias |
| `HasErrors` | bool | Indica si hay errores |
| `LoadedModules` | array | Nombres de módulos cargados exitosamente |
| `FailedModules` | array | Nombres de módulos que fallaron |
| `TotalModules` | int | Total de módulos que se intentaron cargar |

### Estructura de Errores

Cada error en el array `Errors` es un PSCustomObject con:

```powershell
@{
    Module           = "NombreDelModulo"
    Path             = "Core\ModuleName.psm1"
    FullPath         = "Q:\Utilidad\Llevar\Modules\Core\ModuleName.psm1"
    ErrorType        = "FileNotFound" | "ValidationFailed" | "ImportException"
    Exception        = [Exception object]
    ErrorMessage     = "Mensaje de error"
    ScriptStackTrace = "Stack trace del error"
}
```

## Casos de Uso

### 1. Importación Exitosa Sin Warnings

```powershell
$result = Import-LlevarModules -ModulesPath $path -Categories 'All' -Global

# Result:
# Success: true
# Warnings: @()
# HasWarnings: false
# HasErrors: false
# LoadedModules: @("Logger", "Console", "Banners", ...)
# FailedModules: @()
# TotalModules: 30
```

**Acción:** Continuar normalmente.

### 2. Importación con Warnings (módulos opcionales faltantes)

```powershell
$result = Import-LlevarModules -ModulesPath $path -Categories 'All' -Global

# Result:
# Success: true
# Warnings: @("Módulo no encontrado: System\Audio.psm1")
# HasWarnings: true
# HasErrors: false
# LoadedModules: @("Logger", "Console", ...)
# FailedModules: @()
# TotalModules: 30
```

**Acción:** Continuar, opcionalmente mostrar warnings al usuario.

### 3. Importación con Errores (módulos críticos fallidos)

```powershell
$result = Import-LlevarModules -ModulesPath $path -Categories 'All' -Global

# Result:
# Success: false
# Warnings: @()
# HasWarnings: false
# HasErrors: true
# LoadedModules: @("Logger", "Console", ...)
# FailedModules: @("TransferConfig", "Validation")
# TotalModules: 30
# Errors: @(
#   @{ Module="TransferConfig", ErrorType="FileNotFound", ... }
#   @{ Module="Validation", ErrorType="ImportException", ... }
# )
```

**Acción:** 
1. ModuleLoader ya mostró error en consola
2. Script verifica `Success = false`
3. Script termina con `exit 1`

## Beneficios del Patrón

✅ **Separación de responsabilidades:** ModuleLoader importa y reporta, scripts deciden si continuar

✅ **Validación explícita:** No hay ejecución silenciosa con módulos faltantes

✅ **Control granular:** Scripts pueden manejar warnings vs errors de forma diferente

✅ **Debugging mejorado:** Logs detallados con stack traces completos

✅ **Testing robusto:** Tests pueden verificar importación antes de ejecutar

## Anti-Patrones (NO HACER)

❌ **No validar Success:**
```powershell
# MAL - No verifica si falló
$importResult = Import-LlevarModules ...
# Continúa ejecutando código que necesita módulos
```

❌ **Validar solo warnings:**
```powershell
# MAL - Solo verifica warnings, ignora errores críticos
if ($importResult.HasWarnings) {
    Write-Host "Hay warnings"
}
# Falta validar Success
```

❌ **Try-Catch sin validación:**
```powershell
# MAL - ModuleLoader NO hace throw, esto no captura errores
try {
    $importResult = Import-LlevarModules ...
}
catch {
    # Nunca se ejecuta porque ModuleLoader no hace throw
}
```

## Migración de Código Existente

Si tienes código que asume que ModuleLoader hace `throw`:

**ANTES (antiguo):**
```powershell
# Asumía que ModuleLoader termina automáticamente si falla
Import-LlevarModules -ModulesPath $path -Categories 'All' -Global
# ... código continúa ...
```

**DESPUÉS (nuevo):**
```powershell
# Validación explícita requerida
$importResult = Import-LlevarModules -ModulesPath $path -Categories 'All' -Global

if (-not $importResult.Success) {
    Write-Host "Error en importación de módulos" -ForegroundColor Red
    exit 1
}

# ... código continúa solo si Success = true ...
```

## Ver También

- [POWERSHELL7-REQUIREMENT.md](POWERSHELL7-REQUIREMENT.md) - Requisitos de PowerShell
- [INSTALACION-Y-DESINSTALACION.md](INSTALACION-Y-DESINSTALACION.md) - Instalación del sistema
- [TESTING.md](TESTING.md) - Ejecución de tests
