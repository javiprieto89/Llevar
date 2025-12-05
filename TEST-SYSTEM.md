# Sistema de Pruebas - LLEVAR

## Descripción General

El sistema de pruebas de LLEVAR permite probar componentes individuales sin ejecutar el flujo completo. Es ideal para desarrollo, debugging y validación de funcionalidades específicas.

## Características

- **No muestra logo ASCII**: Las pruebas se ejecutan directamente sin animaciones de inicio
- **Pruebas independientes**: Cada prueba simula su componente de forma aislada
- **Banners informativos**: Cada prueba muestra claramente el resultado
- **Fácil de usar**: Un solo parámetro `-Test` con valores predefinidos

## Ubicación del Módulo

**Archivo:** `q:\Utilidad\LLevar\Modules\Parameters\Test.psm1`

## Uso Básico

```powershell
.\Llevar.ps1 -Test <TipoDePrueba>
```

## Tipos de Pruebas Disponibles

### 1. Navigator
Prueba el navegador de archivos estilo Norton Commander.

```powershell
.\Llevar.ps1 -Test Navigator
```

**Funcionalidad:**
- Abre el navegador interactivo completo
- Permite navegar por el sistema de archivos
- Permite seleccionar archivos o carpetas
- Al seleccionar, muestra un banner con la información del objeto seleccionado
- Muestra tipo, tamaño, fecha de modificación, etc.

**Controles:**
- ↑↓ : Navegar por la lista
- ← : Subir un nivel
- → o ENTER : Entrar a carpeta / Seleccionar
- ESC : Cancelar
- F2 : Selector de unidades
- F3 : Buscar recursos de red UNC

### 2. FTP
Prueba la conexión a un servidor FTP.

```powershell
.\Llevar.ps1 -Test FTP
```

**Funcionalidad:**
- Simula la selección de destino FTP como si se hubiera elegido en el menú
- Solicita configuración del servidor:
  - Servidor FTP (ej: ftp.ejemplo.com)
  - Puerto (default: 21)
  - Usuario
  - Contraseña
  - Ruta remota (default: /)
- Intenta conectar y listar el directorio
- Muestra banner de éxito o error con detalles
- Si tiene éxito, lista los primeros archivos encontrados

### 3. OneDrive
Prueba la autenticación con OneDrive.

```powershell
.\Llevar.ps1 -Test OneDrive
```

**Funcionalidad:**
- Intenta autenticar con OneDrive
- Abre el navegador web para el flujo OAuth
- Muestra si se obtuvo el token correctamente
- Indica la ruta montada si tiene éxito

### 4. Dropbox
Prueba la autenticación con Dropbox.

```powershell
.\Llevar.ps1 -Test Dropbox
```

**Funcionalidad:**
- Intenta autenticar con Dropbox
- Abre el navegador web para el flujo OAuth
- Muestra si se obtuvo el token correctamente
- Indica la ruta montada si tiene éxito

### 5. Compression
Prueba el sistema de compresión y división en bloques.

```powershell
.\Llevar.ps1 -Test Compression
```

**Funcionalidad:**
- Crea 5 archivos de prueba de 4MB cada uno (total 20MB)
- Comprime usando 7-Zip
- Divide en bloques de 5MB
- Muestra estadísticas:
  - Tipo de compresión utilizado
  - Cantidad de bloques generados
  - Tamaño de cada bloque
  - Tamaño total comprimido
- Limpia archivos temporales automáticamente

### 6. Robocopy
Prueba la funcionalidad de sincronización con Robocopy.

```powershell
.\Llevar.ps1 -Test Robocopy
```

**Funcionalidad:**
- Crea carpetas de origen y destino temporales
- Genera archivos de prueba con subcarpetas
- Ejecuta sincronización con Robocopy
- Muestra estadísticas:
  - Archivos copiados
  - Directorios procesados
  - Bytes transferidos
- Verifica que los archivos llegaron correctamente
- Limpia archivos temporales automáticamente

### 7. UNC
Prueba el acceso a recursos de red compartidos.

```powershell
.\Llevar.ps1 -Test UNC
```

**Funcionalidad:**
- Busca recursos compartidos en la red local
- Lista todos los servidores encontrados (\\servidor)
- Permite ingresar una ruta UNC específica para probar
- Si la ruta es accesible:
  - Muestra banner de éxito
  - Lista los primeros 10 archivos/carpetas
- Si no es accesible:
  - Muestra banner de error
  - Lista posibles causas del problema

### 8. USB
Prueba la detección de dispositivos USB.

```powershell
.\Llevar.ps1 -Test USB
```

**Funcionalidad:**
- Busca todos los dispositivos USB conectados
- Para cada USB muestra:
  - Letra de unidad
  - Etiqueta del volumen
  - Tamaño total
  - Espacio libre
  - Espacio usado (con porcentaje)
  - Sistema de archivos (NTFS, FAT32, etc.)
- Formato visual con recuadros para cada dispositivo

### 9. ISO
Prueba la generación de imágenes ISO.

```powershell
.\Llevar.ps1 -Test ISO
```

**Funcionalidad:**
- Crea 3 archivos de prueba
- Genera una imagen ISO en %TEMP%
- Muestra información de la ISO generada:
  - Ruta completa
  - Tamaño en MB
  - Etiqueta de volumen
- Deja la ISO en disco para inspección
- Limpia solo los archivos temporales de origen

## Estructura del Código

### Función Principal
```powershell
function Invoke-TestParameter {
    param(
        [ValidateSet("Navigator", "FTP", "OneDrive", "Dropbox", "Compression", "Robocopy", "UNC", "USB", "ISO")]
        [string]$Test
    )
    # Ejecuta la prueba correspondiente
}
```

### Funciones Individuales de Prueba
Cada tipo de prueba tiene su propia función:
- `Test-NavigatorComponent`
- `Test-FTPComponent`
- `Test-OneDriveComponent`
- `Test-DropboxComponent`
- `Test-CompressionComponent`
- `Test-RobocopyComponent`
- `Test-UNCComponent`
- `Test-USBComponent`
- `Test-ISOComponent`

### Formato de Salida
Todas las pruebas siguen el mismo patrón:
1. Header simple indicando qué se está probando
2. Ejecución de la prueba
3. Banner con el resultado (éxito/error/cancelado)
4. Detalles específicos del resultado
5. Limpieza automática de recursos temporales

## Integración en Llevar.ps1

### Parámetro
```powershell
param(
    ...
    [ValidateSet("Navigator", "FTP", "OneDrive", "Dropbox", "Compression", "Robocopy", "UNC", "USB", "ISO")]
    [string]$Test,
    ...
)
```

### Importación
```powershell
Import-Module (Join-Path $ModulesPath "Parameters\Test.psm1") -Force -Global
```

### Invocación
```powershell
# 5. Verificar parámetro -Test (modo pruebas individuales)
$testExecuted = Invoke-TestParameter -Test $Test
if ($testExecuted) {
    exit
}
```

### Supresión de Logo
El parámetro `-Test` está incluido en la verificación de parámetros de ejecución directa:
```powershell
$hasExecutionParams = ($Origen -or $Destino -or $RobocopyMirror -or $Ejemplo -or $Ayuda -or $Instalar -or $Test)
```

Esto asegura que cuando se ejecuta con `-Test`, no se muestre el logo ASCII ni el mensaje de bienvenida.

## Ejemplos de Uso

### Probar el navegador de archivos
```powershell
.\Llevar.ps1 -Test Navigator
# Navega, selecciona un archivo, y verás un banner con los detalles
```

### Probar conexión FTP a servidor de prueba
```powershell
.\Llevar.ps1 -Test FTP
# Ingresa: ftp://test.rebex.net
# Puerto: 21
# Usuario: demo
# Contraseña: password
# Ruta: /
```

### Verificar dispositivos USB disponibles
```powershell
.\Llevar.ps1 -Test USB
# Lista todos los USB conectados con sus características
```

### Verificar que la compresión funciona
```powershell
.\Llevar.ps1 -Test Compression
# Crea, comprime, divide y muestra estadísticas
```

## Ventajas del Sistema de Pruebas

1. **Aislamiento**: Cada prueba es independiente, no afecta al sistema real
2. **Rápido**: No hay que esperar logos ni menús
3. **Claro**: Cada prueba muestra exactamente qué está probando
4. **Limpio**: Limpieza automática de archivos temporales
5. **Documentado**: Cada función está completamente documentada
6. **Expandible**: Fácil agregar nuevas pruebas

## Agregar Nuevas Pruebas

Para agregar una nueva prueba:

1. Agregar el valor al ValidateSet en el parámetro:
```powershell
[ValidateSet("Navigator", "FTP", ..., "NuevaPrueba")]
```

2. Agregar el case en el switch:
```powershell
switch ($Test) {
    ...
    "NuevaPrueba" { Test-NuevaPruebaComponent }
}
```

3. Crear la función de prueba:
```powershell
function Test-NuevaPruebaComponent {
    <#
    .SYNOPSIS
        Descripción de la prueba
    .DESCRIPTION
        Detalles de qué prueba y cómo
    #>
    
    Write-Host "Probando nuevo componente..." -ForegroundColor Cyan
    
    try {
        # Lógica de la prueba
        
        Show-Banner "RESULTADO EXITOSO" -BorderColor Green -TextColor White
        # Mostrar detalles
    }
    catch {
        Show-Banner "ERROR EN PRUEBA" -BorderColor Red -TextColor White
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}
```

## Notas Técnicas

- Las pruebas usan las mismas funciones que el sistema real
- No se requieren archivos de configuración adicionales
- Los archivos temporales se crean en `$env:TEMP`
- Las pruebas no modifican configuración persistente
- Cada prueba es autocontenida y puede ejecutarse múltiples veces
- Las credenciales ingresadas en las pruebas no se guardan

## Solución de Problemas

### La prueba no se ejecuta
- Verifica que el parámetro esté escrito correctamente (case-sensitive)
- Asegúrate de usar uno de los valores válidos del ValidateSet

### Error de módulo no encontrado
- Verifica que Test.psm1 esté en `Modules\Parameters\`
- Verifica que el import esté en Llevar.ps1

### La prueba falla con error
- Lee el mensaje de error mostrado
- Verifica que tengas los permisos necesarios
- Algunas pruebas requieren internet (OneDrive, Dropbox, FTP)
- Algunas pruebas requieren hardware (USB)

## Autor

Sistema de pruebas modular para LLEVAR
Archivo: `q:\Utilidad\LLevar\Modules\Parameters\Test.psm1`
