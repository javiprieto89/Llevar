# Módulos de Parámetros

Este directorio contiene todos los módulos que manejan los diferentes modos de ejecución de LLEVAR.

## 📋 Arquitectura

El script principal (`Llevar.ps1`) actúa como **orquestador**, delegando toda la lógica de ejecución a estos módulos:

```
Llevar.ps1 (294 líneas - SOLO orquestación)
    ↓
    ├─ InstallationCheck.psm1 → Verifica instalación (si no es Ejemplo/Ayuda)
    ├─ Help.psm1           → Muestra ayuda y sale
    ├─ Install.psm1        → Instala en C:\Llevar y sale
    ├─ Robocopy.psm1       → Ejecuta mirror y sale
    ├─ Example.psm1        → Demo automático y sale
    ├─ InteractiveMenu.psm1 → Menú si no hay parámetros
    └─ NormalMode.psm1     → TODA la lógica de transferencia
```

## 📦 Módulos Disponibles

### 1. **InstallationCheck.psm1** (90 líneas) ⭐ **NUEVO**
**Función:** `Invoke-InstallationCheck`  
**Propósito:** Verifica si el script está instalado en C:\Llevar

### 2. **Help.psm1** (33 líneas)
**Función:** `Invoke-HelpParameter`  
**Propósito:** Maneja el parámetro `-Ayuda`

### 3. **Install.psm1** (72 líneas)
**Función:** `Invoke-InstallParameter`  
**Propósito:** Maneja el parámetro `-Instalar`

### 4. **Robocopy.psm1** (54 líneas)
**Función:** `Invoke-RobocopyParameter`  
**Propósito:** Maneja el parámetro `-RobocopyMirror`

### 5. **Example.psm1** (168 líneas)
**Función:** `Invoke-ExampleParameter`  
**Propósito:** Maneja el parámetro `-Ejemplo`

### 6. **InteractiveMenu.psm1** (191 líneas)
**Función:** `Invoke-InteractiveMenu`  
**Propósito:** Maneja el modo sin parámetros (menú interactivo)

### 7. **NormalMode.psm1** (700+ líneas)
**Función:** `Invoke-NormalMode`  
**Propósito:** Contiene **TODA** la lógica del modo normal de ejecución

## 📊 Estadísticas

| Módulo | Líneas | Complejidad | Propósito |
|--------|--------|-------------|-----------|
| **InstallationCheck.psm1** | **90** | **Media** | **Verificar instalación** |
| Help.psm1 | 33 | Baja | Mostrar ayuda |
| Install.psm1 | 72 | Media | Instalación sistema |
| Robocopy.psm1 | 54 | Baja | Mirror con robocopy |
| Example.psm1 | 168 | Media | Demo automático |
| InteractiveMenu.psm1 | 191 | Alta | Menú configuración |
| NormalMode.psm1 | 700+ | Muy Alta | Lógica transferencia |
| **TOTAL** | **~1,300** | - | Toda la ejecución |

## 🚀 Resultado Final

**REDUCCIÓN TOTAL: 76%**
- **ANTES**: 1,218 líneas en script principal
- **AHORA**: 294 líneas en script principal
- **ELIMINADO**: 924 líneas (movidas a módulos)

El script principal ahora es **perfectamente legible** y solo contiene:
1. Encabezado y documentación
2. Declaración de parámetros
3. Importación de módulos
4. Verificación de permisos
5. Inicialización básica
6. Logo y bienvenida
7. **7 llamadas a módulos** (toda la lógica está en módulos)
