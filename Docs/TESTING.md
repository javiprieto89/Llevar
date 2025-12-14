# Sistema de Pruebas - LLEVAR

## Descripción

Sistema modular de pruebas para validar componentes individuales sin ejecutar el flujo completo. Ideal para desarrollo, debugging y validación de funcionalidades específicas.

## Características

- **Sin logo ASCII**: Ejecución directa sin animaciones de inicio
- **Pruebas independientes**: Cada componente se prueba de forma aislada
- **Banners informativos**: Resultados claros y visibles
- **Fácil de usar**: Un solo parámetro `-Test`

## Uso

```powershell
.\Llevar.ps1 -Test <Tipo>
```

## Tipos de Pruebas

### 1. Navigator
Navegador de archivos estilo Norton Commander.

```powershell
.\Llevar.ps1 -Test Navigator
```

**Funcionalidad:**
- Navegación completa del sistema de archivos
- Selección de archivos o carpetas
- Cálculo de tamaño de directorios (ESPACIO)
- Búsqueda con filtrado (F4)
- Selector de unidades (F2)
- Búsqueda de recursos UNC (F3)

**Controles:**
- `↑↓` : Navegar
- `←` : Subir nivel
- `→` / `ENTER` : Entrar/Seleccionar
- `ESPACIO` : Calcular tamaño de carpeta
- `F2` : Selector de unidades
- `F3` : Recursos de red UNC
- `F4` : Buscar/filtrar
- `ESC` : Cancelar

### 2. FTP
Prueba de conexión a servidor FTP.

```powershell
.\Llevar.ps1 -Test FTP
```

**Solicita:**
- Servidor FTP (ej: ftp.ejemplo.com)
- Puerto (default: 21)
- Usuario y contraseña
- Ruta remota (default: /)

**Valida:**
- Conexión al servidor
- Autenticación
- Listado de directorio
- Muestra primeros archivos si tiene éxito

### 3. OneDrive
Autenticación con Microsoft OneDrive.

```powershell
.\Llevar.ps1 -Test OneDrive
```

**Funcionalidad:**
- Abre navegador para OAuth2
- Obtiene token de acceso
- Valida permisos Files.ReadWrite.All
- Muestra ruta montada

### 4. Dropbox
Autenticación con Dropbox.

```powershell
.\Llevar.ps1 -Test Dropbox
```

**Funcionalidad:**
- Flujo OAuth2 en navegador
- Obtención de token
- Validación de acceso
- Muestra configuración exitosa

### 5. Compression
Sistema de compresión y división en bloques.

```powershell
.\Llevar.ps1 -Test Compression
```

**Prueba:**
- Crear carpeta temporal con archivos de prueba
- Comprimir con 7-Zip o ZIP nativo
- Dividir en bloques del tamaño especificado
- Validar archivos generados
- Muestra estadísticas (tamaño, bloques, tiempo)

### 6. Robocopy
Sincronización con Robocopy.

```powershell
.\Llevar.ps1 -Test Robocopy
```

**Prueba:**
- Crear directorios de origen y destino temporales
- Copiar archivos con Robocopy
- Modo espejo opcional
- Muestra progreso y estadísticas

### 7. UNC
Acceso a recursos de red UNC.

```powershell
.\Llevar.ps1 -Test UNC
```

**Funcionalidad:**
- Navegador de rutas UNC
- Solicita credenciales si es necesario
- Valida acceso
- Monta como PSDrive temporal
- Lista contenido del recurso

### 8. USB
Detección de dispositivos USB.

```powershell
.\Llevar.ps1 -Test USB
```

**Muestra:**
- Todos los dispositivos USB conectados
- Información: Letra, Nombre, Tamaño, Espacio libre
- Estado de escritura
- Selección interactiva

### 9. ISO
Generación de imágenes ISO.

```powershell
.\Llevar.ps1 -Test ISO
```

**Prueba:**
- Crear archivos de prueba
- Generar imagen ISO
- Tamaños: CD (700MB), DVD (4.7GB), Bluray (25GB)
- Validar archivo generado

## Módulo de Pruebas

**Ubicación:** `Modules\Parameters\Test.psm1`

**Estructura:**
```powershell
# Función principal
function Invoke-TestParameter {
    param([string]$TestType)
    
    switch ($TestType) {
        "Navigator"   { Test-Navigator }
        "FTP"         { Test-FTP }
        "OneDrive"    { Test-OneDrive }
        "Dropbox"     { Test-Dropbox }
        "Compression" { Test-Compression }
        "Robocopy"    { Test-Robocopy }
        "UNC"         { Test-UNC }
        "USB"         { Test-USB }
        "ISO"         { Test-ISO }
    }
}
```

## Integración con Llevar.ps1

```powershell
# Parámetro -Test con valores válidos
param(
    [Parameter()]
    [ValidateSet("Navigator", "FTP", "OneDrive", "Dropbox", 
                 "Compression", "Robocopy", "UNC", "USB", "ISO")]
    [string]$Test
)

# Importar módulo de pruebas
if ($Test) {
    Import-Module "$ModulesPath\Parameters\Test.psm1" -Force
    Invoke-TestParameter -TestType $Test
    exit
}
```

## Agregar Nuevas Pruebas

### 1. Crear función en Test.psm1
```powershell
function Test-MiComponente {
    param()
    
    Show-Banner "PRUEBA: MI COMPONENTE" -BorderColor Cyan -TextColor White
    
    try {
        # Lógica de prueba aquí
        Write-Host "Ejecutando prueba..." -ForegroundColor Cyan
        
        # Simular funcionalidad
        $resultado = Invoke-MiComponente
        
        # Mostrar resultado
        Show-Banner "PRUEBA EXITOSA" -BorderColor Green -TextColor Green
        Write-Host "Resultado: $resultado" -ForegroundColor White
    }
    catch {
        Show-Banner "PRUEBA FALLIDA" -BorderColor Red -TextColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

### 2. Agregar al switch en Invoke-TestParameter
```powershell
function Invoke-TestParameter {
    switch ($TestType) {
        # ... pruebas existentes ...
        "MiComponente" { Test-MiComponente }
    }
}
```

### 3. Actualizar ValidateSet en Llevar.ps1
```powershell
[ValidateSet("Navigator", "FTP", ..., "MiComponente")]
[string]$Test
```

### 4. Exportar función en Test.psm1
```powershell
Export-ModuleMember -Function @(
    'Invoke-TestParameter',
    'Test-Navigator',
    # ... otras funciones ...
    'Test-MiComponente'
)
```

## Ejemplos de Uso

```powershell
# Probar navegador
.\Llevar.ps1 -Test Navigator

# Probar FTP con servidor personalizado
.\Llevar.ps1 -Test FTP
# Server: ftp.ejemplo.com
# Port: 21
# User: usuario
# Password: ****

# Probar compresión
.\Llevar.ps1 -Test Compression

# Probar recursos UNC
.\Llevar.ps1 -Test UNC
```

## Ventajas

✅ **Desarrollo rápido**: Prueba componentes sin configurar flujo completo
✅ **Debugging eficiente**: Aísla problemas en componentes específicos
✅ **Validación continua**: Verifica que cambios no rompan funcionalidades
✅ **Documentación viva**: Cada prueba demuestra cómo usar el componente
