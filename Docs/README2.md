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
    ├─ Test.psm1           → Ejecuta pruebas individuales y sale
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

### 6. **Test.psm1** (900+ líneas) ⭐ **NUEVO**
**Función:** `Invoke-TestParameter`  
**Propósito:** Maneja el parámetro `-Test` para pruebas individuales de componentes
**Valores válidos:** Navigator, FTP, OneDrive, Dropbox, Compression, Robocopy, UNC, USB, ISO

### 7. **InteractiveMenu.psm1** (191 líneas)
**Función:** `Invoke-InteractiveMenu`  
**Propósito:** Maneja el modo sin parámetros (menú interactivo)

### 8. **NormalMode.psm1** (700+ líneas)
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
| **Test.psm1** | **900+** | **Alta** | **Pruebas individuales** |
| InteractiveMenu.psm1 | 191 | Alta | Menú configuración |
| NormalMode.psm1 | 700+ | Muy Alta | Lógica transferencia |
| **TOTAL** | **~2,200** | - | Toda la ejecución |

## 🚀 Resultado Final

**REDUCCIÓN TOTAL: 86%**
- **ANTES**: 1,218 líneas en script principal
- **AHORA**: 356 líneas en script principal
- **ELIMINADO**: 862 líneas (movidas a módulos)

El script principal ahora es **perfectamente legible** y solo contiene:
1. Encabezado y documentación
2. Declaración de parámetros
3. Importación de módulos
4. Verificación de permisos
5. Inicialización básica
6. Logo y bienvenida

## 🧪 Sistema de Pruebas (Test.psm1)

### Descripción
El módulo `Test.psm1` proporciona pruebas individuales para cada componente del sistema LLEVAR sin ejecutar el flujo completo. Ideal para desarrollo, debugging y validación.

### Características Especiales
- ✅ **No muestra logo ASCII** - Ejecución directa sin animaciones
- ✅ **Pruebas independientes** - Cada test simula su componente de forma aislada
- ✅ **Banners informativos** - Resultados claros con formato visual
- ✅ **Auto-limpieza** - Elimina archivos temporales automáticamente

### Sintaxis
```powershell
.\Llevar.ps1 -Test <TipoPrueba>
```

### Tipos de Pruebas Disponibles

#### 1. Navigator
```powershell
.\Llevar.ps1 -Test Navigator
```
Abre el navegador de archivos. Al seleccionar un archivo/carpeta, muestra un banner con toda la información.

#### 2. FTP
```powershell
.\Llevar.ps1 -Test FTP
```
Simula selección de destino FTP, solicita credenciales y prueba la conexión. Muestra si se pudo conectar y listar archivos.

#### 3. OneDrive
```powershell
.\Llevar.ps1 -Test OneDrive
```
Prueba autenticación OAuth con OneDrive. Muestra si se obtuvo el token correctamente.

#### 4. Dropbox
```powershell
.\Llevar.ps1 -Test Dropbox
```
Prueba autenticación OAuth con Dropbox. Muestra si se obtuvo el token correctamente.

#### 5. Compression
```powershell
.\Llevar.ps1 -Test Compression
```
Crea archivos de prueba (20MB), comprime con 7-Zip, divide en bloques de 5MB y muestra estadísticas.

#### 6. Robocopy
```powershell
.\Llevar.ps1 -Test Robocopy
```
Crea carpetas de prueba, ejecuta sincronización y muestra estadísticas de la operación.

#### 7. UNC
```powershell
.\Llevar.ps1 -Test UNC
```
Busca recursos de red compartidos y permite probar acceso a una ruta UNC específica.

#### 8. USB
```powershell
.\Llevar.ps1 -Test USB
```
Lista todos los dispositivos USB conectados con información detallada (tamaño, libre, usado, filesystem).

#### 9. ISO
```powershell
.\Llevar.ps1 -Test ISO
```
Genera una imagen ISO de prueba en %TEMP% y muestra información de la misma.

### Documentación Completa
Ver `TEST-SYSTEM.md` en la raíz del proyecto para documentación detallada, ejemplos y guía de desarrollo.
7. **7 llamadas a módulos** (toda la lógica está en módulos)
