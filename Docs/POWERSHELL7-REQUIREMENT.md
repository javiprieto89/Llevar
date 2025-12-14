# Implementación de Requisito de PowerShell 7

## Resumen de Cambios

Se ha implementado la verificación obligatoria de PowerShell 7+ con capacidad de instalación automática.

## Archivos Creados

### 1. `Modules/System/PowerShellVersion.psm1`
Nuevo módulo dedicado a gestionar la versión de PowerShell:

**Funciones principales:**
- `Test-PowerShell7Available` - Verifica si PowerShell 7 está instalado
- `Test-IsPowerShell7` - Verifica si se está ejecutando en PowerShell 7+
- `Show-PowerShell7RequiredDialog` - Muestra diálogo de error si no se cumple el requisito
- `Install-PowerShell7` - Ofrece instalar PowerShell 7 automáticamente
- `Assert-PowerShell7` - Función principal que orquesta todo el proceso

**Métodos de instalación soportados:**
1. **winget** - Instalación automática (preferido)
2. **Descarga directa** - Descarga e instala el MSI automáticamente
3. **Navegador web** - Abre la página de descarga oficial

### 2. `Scripts/Test-PowerShellVersion.ps1`
Script de prueba para validar el módulo PowerShellVersion.

## Archivos Modificados

### 1. `Llevar.ps1`
**Cambios:**
- Reemplazada la verificación básica de PowerShell 7 con el nuevo módulo
- Agregado import del módulo `PowerShellVersion.psm1` al inicio
- Llamada a `Assert-PowerShell7` antes de continuar
- Si no se puede ejecutar en PowerShell 7, el script se detiene y ofrece instalarlo

**Ubicación:** Líneas 135-170 (aprox.)

### 2. `LLEVAR.CMD`
**Cambios:**
- Ya estaba configurado para usar PowerShell 7 (pwsh.exe)
- Verifica la existencia de pwsh.exe antes de ejecutar
- Busca en PATH y ubicaciones comunes
- Si no encuentra PowerShell 7, muestra error y abre página de descarga

**Características:**
- Elevación automática de permisos de administrador
- Verificación y configuración de ExecutionPolicy
- Manejo de parámetros (incluyendo archivos arrastrados)

### 3. `Llevar.inf`
**Cambios:**
- Actualizado para llamar a `LLEVAR.CMD` en lugar de llamar directamente a PowerShell
- Esto asegura que se use PowerShell 7 y se manejen correctamente los parámetros

**Antes:**
```ini
HKCR,"Directory\shell\Llevar\command",,0x00020000,"pwsh.exe -NoProfile -ExecutionPolicy Bypass -File ""C:\Llevar\Llevar.ps1"" -Origen ""%1"""
```

**Después:**
```ini
HKCR,"Directory\shell\Llevar\command",,0x00020000,"""C:\Llevar\LLEVAR.CMD"" ""%1"""
```

### 4. `Import-LlevarModules.ps1`
**Cambios:**
- Agregado import del módulo `PowerShellVersion.psm1`

## Flujo de Ejecución

### Cuando se ejecuta desde el menú contextual o arrastrando:

```
1. Usuario hace clic derecho → "Llevar A..."
   ↓
2. Windows ejecuta: C:\Llevar\LLEVAR.CMD "%1"
   ↓
3. LLEVAR.CMD verifica permisos de administrador
   ↓ (si no tiene permisos)
4. Se auto-eleva con UAC
   ↓
5. LLEVAR.CMD busca PowerShell 7 (pwsh.exe)
   ↓
6. Si NO encuentra PowerShell 7:
   → Muestra popup de error
   → Abre navegador con página de descarga
   → TERMINA
   ↓
7. Si encuentra PowerShell 7:
   → Verifica ExecutionPolicy
   → Ejecuta: pwsh.exe -File Llevar.ps1 -Origen "ruta"
   ↓
8. Llevar.ps1 carga el módulo PowerShellVersion
   ↓
9. Assert-PowerShell7 verifica la versión
   ↓
10. Si NO es PowerShell 7+ (fallback):
    → Muestra menú de instalación en consola
    → Ofrece instalar con winget o descarga directa
    → Si instala: el usuario debe reiniciar
    → Si no instala: muestra popup y TERMINA
    ↓
11. Si es PowerShell 7+:
    → Continúa con la ejecución normal ✓
```

### Cuando se ejecuta directamente (doble clic en Llevar.ps1):

```
1. Usuario ejecuta Llevar.ps1
   ↓
2. PowerShell carga el script
   ↓
3. Carga módulo PowerShellVersion
   ↓
4. Assert-PowerShell7 verifica versión
   ↓
5. Si NO es PowerShell 7:
   → Muestra menú en consola
   → Ofrece instalar
   → TERMINA
   ↓
6. Si es PowerShell 7:
   → Continúa normal ✓
```

## Características Implementadas

### ✅ Verificación Obligatoria
- El script NO se ejecuta si no es PowerShell 7+
- Verificación temprana antes de cargar módulos pesados

### ✅ Instalación Automática
- Detección de winget (Windows Package Manager)
- Descarga automática del instalador MSI oficial
- Instalación silenciosa con barra de progreso

### ✅ Fallback Robusto
- Si falla instalación automática → abre navegador
- Si no puede abrir navegador → muestra URL en consola
- Mensajes claros en cada etapa

### ✅ Experiencia de Usuario
- Mensajes amigables y claros
- Popups gráficos cuando es apropiado
- Consola con colores y formato cuando no hay GUI
- Instrucciones específicas según el contexto

### ✅ Modularidad
- Todo el código de verificación está en un módulo separado
- Llevar.ps1 se mantiene limpio y enfocado
- Fácil de mantener y probar

## Pruebas

### Probar el módulo:
```powershell
.\Scripts\Test-PowerShellVersion.ps1
```

### Probar instalación desde menú contextual:
1. Reinstalar Llevar con el nuevo Llevar.inf
2. Clic derecho en una carpeta → "Llevar A..."
3. Verificar que detecta PowerShell 7

### Simular PowerShell 5 (para testing):
```powershell
# Ejecutar Llevar.ps1 con Windows PowerShell 5
powershell.exe -File .\Llevar.ps1
# Debería mostrar el menú de instalación
```

## Notas Técnicas

### PowerShell 7 vs Windows PowerShell
- **Windows PowerShell**: Versión 5.1 (incluida en Windows, obsoleta)
- **PowerShell 7+**: Versión moderna, multiplataforma, basada en .NET Core
- Ejecutable: `pwsh.exe` vs `powershell.exe`

### Ubicaciones comunes de pwsh.exe:
- `%ProgramFiles%\PowerShell\7\pwsh.exe`
- `%ProgramFiles(x86)%\PowerShell\7\pwsh.exe`
- En PATH (si se instaló correctamente)

### ExecutionPolicy
- LLEVAR.CMD configura automáticamente ExecutionPolicy a RemoteSigned
- Requiere permisos de administrador
- Solo se hace una vez por sistema

## Migracion para Usuarios Existentes

Si un usuario ya tiene Llevar instalado:

1. **Opción automática**: Reinstalar usando el instalador actualizado
   ```cmd
   rundll32.exe setupapi.dll,InstallHinfSection DefaultUninstall 132 C:\Llevar\Llevar.inf
   rundll32.exe setupapi.dll,InstallHinfSection DefaultInstall 132 C:\Llevar\Llevar.inf
   ```

2. **Opción manual**: 
   - Copiar `PowerShellVersion.psm1` a `C:\Llevar\Modules\System\`
   - Reemplazar `Llevar.ps1` con la nueva versión
   - Reemplazar `LLEVAR.CMD` con la nueva versión
   - Ejecutar reinstalación del .inf

## Beneficios

✅ **Requisito claro**: No hay ambigüedad sobre qué versión de PowerShell se necesita
✅ **Auto-reparación**: Si falta PowerShell 7, ofrece instalarlo automáticamente  
✅ **Experiencia mejorada**: Mensajes claros en lugar de errores crípticos
✅ **Mantenimiento**: Código modular y fácil de actualizar
✅ **Confiabilidad**: LLEVAR.CMD maneja todos los casos edge (permisos, policy, etc.)

## Compatibilidad

- ✅ Windows 10 (1809+)
- ✅ Windows 11
- ✅ Windows Server 2019+
- ❌ Windows 7/8/8.1 (PowerShell 7 no es compatible)
