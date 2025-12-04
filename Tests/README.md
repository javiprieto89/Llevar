# Tests para LLEVAR.PS1

Esta carpeta contiene la suite completa de tests para validar el funcionamiento de `Llevar.ps1`.

## 📁 Estructura de Tests

```
Tests/
├── Run-AllTests.ps1          # Runner principal - ejecuta todos los tests
├── Test-Functions.ps1        # Tests unitarios de funciones individuales
├── Mock-USBDevices.ps1       # Simulador de dispositivos USB
├── Test-Integration.ps1      # Tests de integración end-to-end
├── Test-OneDrive.ps1         # Tests de integración OneDrive ⭐ NUEVO
├── Test-Dropbox.ps1          # Tests de integración Dropbox ⭐ NUEVO
├── Test-Robocopy.ps1         # Tests de Robocopy Mirror ⭐ NUEVO
├── Test-LocalToFTP.ps1       # Test individual: Local → FTP
├── Test-FTPToLocal.ps1       # Test individual: FTP → Local
├── Test-LocalToISO.ps1       # Test individual: Local → ISO
├── Test-LocalToUSB.ps1       # Test individual: Local → USB
├── Test-FTPToFTP.ps1         # Test individual: FTP → FTP
└── README.md                 # Este archivo
```

## 🚀 Uso Rápido

### Ejecutar todos los tests automáticos:
```powershell
.\Run-AllTests.ps1
```

### Ejecutar solo tests unitarios:
```powershell
.\Run-AllTests.ps1 -TestType Unit
```

### Ejecutar solo simulación de USBs:
```powershell
.\Run-AllTests.ps1 -TestType USB
```

### Ejecutar solo tests de integración:
```powershell
.\Run-AllTests.ps1 -TestType Integration
```

### Ejecutar tests de cloud storage (OneDrive, Dropbox):
```powershell
.\Run-AllTests.ps1 -TestType OneDrive
.\Run-AllTests.ps1 -TestType Dropbox
```

### Ejecutar tests de Robocopy:
```powershell
.\Run-AllTests.ps1 -TestType Robocopy
```

### Ejecutar todos los tests de escenarios (interactivos):
```powershell
.\Run-AllTests.ps1 -TestType Scenarios
```

### Ejecutar test de escenario individual específico:
```powershell
.\Run-AllTests.ps1 -TestType LocalToFTP
.\Run-AllTests.ps1 -TestType FTPToLocal
.\Run-AllTests.ps1 -TestType LocalToISO
.\Run-AllTests.ps1 -TestType LocalToUSB
.\Run-AllTests.ps1 -TestType FTPToFTP
```

### Ejecutar tests individuales directamente:
```powershell
# Local → FTP (genera 1GB de datos)
.\Test-LocalToFTP.ps1

# FTP → Local (descarga desde servidor)
.\Test-FTPToLocal.ps1

# Local → ISO (genera 1GB y crea ISO)
.\Test-LocalToISO.ps1

# Local → USB (genera 1GB y copia a USB)
.\Test-LocalToUSB.ps1

# FTP → FTP (transferencia entre servidores)
.\Test-FTPToFTP.ps1
```

### Limpiar automáticamente después:
```powershell
.\Run-AllTests.ps1 -CleanupAfter
```

## 📋 Descripción de Tests

### 1. **Test-Functions.ps1** - Tests Unitarios
Valida el funcionamiento correcto de funciones individuales:

- ✅ `Format-LlevarBytes` - Formateo de tamaños (B, KB, MB, GB)
- ✅ `Format-LlevarTime` - Formateo de tiempo (s, m, h)
- ✅ `Test-Windows10OrLater` - Detección de versión de Windows
- ✅ `Test-IsFtpPath` - Detección de rutas FTP/FTPS
- ✅ `Test-IsRunningInIDE` - Detección de IDEs (VSCode, ISE, etc.)

**Ejemplo de salida:**
```
✓ PASS: 512 bytes
  → 512 B
✓ PASS: 10 MB
  → 10.00 MB
✓ PASS: Detectar FTP path
  → ftp://servidor.com/carpeta
```

### 4. **Test-OneDrive.ps1** - Tests de OneDrive ⭐ NUEVO
Valida la integración completa con Microsoft OneDrive:

**Tests Unitarios:**
- ✅ Detección de rutas OneDrive (`onedrive://`, `ONEDRIVE:`)
- ✅ Verificación de módulos Microsoft.Graph (Authentication, Files)
- ✅ Validación de formato y extracción de rutas
- ✅ Simulación de parámetros (-OnedriveOrigen, -OnedriveDestino)
- ✅ Verificación de funciones en script principal:
  - `Test-IsOneDrivePath`
  - `Connect-GraphIfNeeded`
  - `Send-OneDriveFile`
  - `Get-OneDriveFile`
  - `Send-OneDriveFolder`
  - `Get-OneDriveFolder`

**Tests de Integración Real** (con `-Integration`):
- 🔐 Autenticación con Microsoft Graph (con MFA)
- ⬆️ Upload de archivo de prueba a OneDrive
- ⬇️ Download del archivo desde OneDrive
- ✔️ Verificación de contenido

**Uso:**
```powershell
# Solo tests unitarios
.\Test-OneDrive.ps1

# Con tests de integración real (requiere autenticación)
.\Test-OneDrive.ps1 -Integration

# Omitir tests de integración explícitamente
.\Test-OneDrive.ps1 -SkipIntegration
```

**Requisitos para tests de integración:**
- Módulos Microsoft.Graph.Authentication y Microsoft.Graph.Files
- Cuenta Microsoft válida
- Permisos: Files.ReadWrite.All
- Conexión a internet

**Ejemplo de salida:**
```
═══════════════════════════════════════════════════
  TESTS DE ONEDRIVE
═══════════════════════════════════════════════════

[TEST 1] Detección de rutas OneDrive
  ✓ onedrive:// lowercase: PASS
  ✓ ONEDRIVE: uppercase: PASS
  ✓ Ruta local: PASS

[TEST 2] Verificación de módulos Microsoft.Graph
  ✓ Microsoft.Graph.Authentication instalado (v2.10.0)
  ✓ Microsoft.Graph.Files instalado (v2.10.0)

[TEST 5] Integración con script principal
  ✓ Función Test-IsOneDrivePath existe
  ✓ Función Send-OneDriveFile existe
  ✓ Parámetro -OnedriveOrigen existe

═══════════════════════════════════════════════════
  RESUMEN DE TESTS DE ONEDRIVE
═══════════════════════════════════════════════════

Tests ejecutados: 15
Pasados         : 15
Fallados        : 0

✓ Todos los tests pasaron correctamente
```

### 5. **Test-Dropbox.ps1** - Tests de Dropbox ⭐ NUEVO
Valida la integración completa con Dropbox:

**Tests Unitarios:**
- ✅ Detección de rutas Dropbox (`dropbox://`, `DROPBOX:`)
- ✅ Validación de formato y extracción de rutas
- ✅ Normalización de rutas (agregar `/` inicial)
- ✅ Simulación de parámetros (-DropboxOrigen, -DropboxDestino)
- ✅ Verificación de constantes OAuth2 (App Key, puerto 53682)
- ✅ Verificación de funciones en script principal:
  - `Test-IsDropboxPath`
  - `Get-DropboxToken`
  - `Connect-DropboxIfNeeded`
  - `Send-DropboxFile`
  - `Get-DropboxFile`
  - `Send-DropboxFolder`
  - `Get-DropboxFolder`
  - `Send-DropboxFileLarge`
- ✅ Validación de límites para archivos grandes (>150MB)

**Tests de Integración Real** (con `-Integration`):
- 🔐 Autenticación OAuth2 con Dropbox (abre navegador)
- ⬆️ Upload de archivo de prueba a Dropbox
- ⬇️ Download del archivo desde Dropbox
- ✔️ Verificación de contenido

**Uso:**
```powershell
# Solo tests unitarios
.\Test-Dropbox.ps1

# Con tests de integración real (requiere autenticación OAuth2)
.\Test-Dropbox.ps1 -Integration

# Omitir tests de integración explícitamente
.\Test-Dropbox.ps1 -SkipIntegration
```

**Requisitos para tests de integración:**
- Conexión a internet
- Navegador web para OAuth2
- Puerto 53682 disponible
- Cuenta Dropbox válida

**Ejemplo de salida:**
```
═══════════════════════════════════════════════════
  TESTS DE DROPBOX
═══════════════════════════════════════════════════

[TEST 1] Detección de rutas Dropbox
  ✓ dropbox:// lowercase: PASS
  ✓ DROPBOX: uppercase: PASS
  ✓ Ruta local: PASS

[TEST 5] Verificación de constantes OAuth2
  ✓ App Key de Dropbox configurada
  ✓ Puerto de redirect URI configurado (53682)

[TEST 7] Validación de límites de archivo grande
  ✓ 150MB (usar upload por sesiones): PASS
  ✓ 100MB (upload simple): PASS
  ✓ 1GB (usar upload por sesiones): PASS

═══════════════════════════════════════════════════
  RESUMEN DE TESTS DE DROPBOX
═══════════════════════════════════════════════════

Tests ejecutados: 24
Pasados         : 24
Fallados        : 0

✓ Todos los tests pasaron correctamente
```

### 6. **Test-Robocopy.ps1** - Tests de Robocopy Mirror ⭐ NUEVO
Valida el modo de copia espejo con Robocopy:

**Tests incluidos:**
- ✅ Verificación de Robocopy en el sistema
- ✅ Validación de versión de Robocopy
- ✅ Validación de parámetros configurados (`/MIR`, `/R:3`, `/W:5`, `/NP`)
- ✅ Interpretación de códigos de salida (0-3: éxito, 4+: error)
- ✅ Simulación de operación real con carpetas temporales
- ✅ Verificación de copia de archivos
- ✅ Verificación de funciones en script principal:
  - `Invoke-RobocopyMirror`
  - Parámetro `-RobocopyMirror`
  - Advertencia de seguridad
  - Confirmación de usuario
  - Uso de `Get-PathOrPrompt`

**Uso:**
```powershell
.\Test-Robocopy.ps1
```

**Ejemplo de salida:**
```
═══════════════════════════════════════════════════
  TESTS DE ROBOCOPY MIRROR
═══════════════════════════════════════════════════

[TEST 1] Verificación de Robocopy en el sistema
  ✓ Robocopy encontrado: C:\WINDOWS\system32\Robocopy.exe
  ✓ Versión: 10.0.22621.1

[TEST 3] Interpretación de códigos de salida de Robocopy
  ✓ Código 0 (No cambios): Success
  ✓ Código 1 (Archivos copiados): Success
  ✓ Código 2 (Extras eliminados): Success
  ✓ Código 3 (Copiados y eliminados): Success
  ✓ Código 8 (Algunos no se copiaron): Error

[TEST 4] Simulación de operación Robocopy
  ✓ Carpetas de prueba creadas
  ✓ Robocopy ejecutado exitosamente (código: 1)
  ✓ Archivos copiados correctamente

═══════════════════════════════════════════════════
  RESUMEN DE TESTS DE ROBOCOPY MIRROR
═══════════════════════════════════════════════════

Tests ejecutados: 20
Pasados         : 20
Fallados        : 0

✓ Todos los tests pasaron correctamente
```

### 7. **Mock-USBDevices.ps1** - Simulador de USBs
Crea dispositivos USB virtuales para simular escenarios reales:

**Características:**
- 🔹 Crea USBs virtuales con capacidades definidas (MB)
- 🔹 Simula espacio usado/libre
- 🔹 Maneja múltiples USBs simultáneamente
- 🔹 Copia archivos respetando límites de espacio
- 🔹 Genera archivos dummy de prueba

**Ejemplo:**
```powershell
# Crear USB de 100 MB
$usb = New-MockUSB -DriveLetter "E" -Label "USB_TEST" -CapacityMB 100

# Copiar archivo
$usb.CopyFile("C:\archivo.zip")

# Ver información
Get-MockUSBInfo -USB $usb
```

**Salida:**
```
╔══════════════════════════════════════════
║ USB: USB_TEST (E)
╠══════════════════════════════════════════
║ Capacidad Total: 100.00 MB
║ Espacio Usado:   45.30 MB
║ Espacio Libre:   54.70 MB
║ Archivos:        3
╚══════════════════════════════════════════
```

### 8. **Test-Integration.ps1** - Tests de Integración
Simula el flujo completo de trabajo:

**Flujo probado:**
1. 📦 Crear datos de prueba (50 MB en múltiples archivos)
2. 🗜️ Comprimir carpeta origen
3. ✂️ Dividir en bloques de 10 MB
4. 💾 Distribuir bloques en 2-3 USBs simulados
5. 🔄 Validar distribución correcta

**Estructura de datos de prueba:**
```
Origen/
├── Documentos/
│   ├── documento_1.txt
│   ├── documento_2.txt
│   └── documento_3.txt
├── Imagenes/
│   ├── imagen_1.jpg
│   ├── imagen_2.jpg
│   └── imagen_3.jpg
├── Videos/
│   ├── video_1.mp4
│   └── video_2.mp4
├── Datos/
│   ├── datos_1.db
│   └── datos_2.db
└── README.txt
```

### 9. **Tests de Escenarios Individuales** - Tests por Caso de Uso ⭐ NUEVO

Cada test de escenario valida una combinación específica de origen → destino, ejecutando `Llevar.ps1` REAL.

#### **Test-LocalToFTP.ps1** - Local → FTP
Genera 1GB de datos de prueba y transfiere a servidor FTP.

**Características:**
- 🔹 Genera 10 archivos × 100MB (1GB total)
- 🔹 Solicita URL FTP de destino
- 🔹 Usa `Connect-FtpServer` para configurar conexión (puerto, auth, SSL)
- 🔹 Ejecuta `Llevar.ps1` con parámetros `-Origen` y `-Destino`
- 🔹 Cronometra ejecución completa
- 🔹 Ofrece limpieza de datos de prueba

**Uso:**
```powershell
.\Test-LocalToFTP.ps1
```

**Ejemplo de salida:**
```
═══════════════════════════════════════════════════
  TEST: Local → FTP
═══════════════════════════════════════════════════

Generando datos de prueba (1GB)...
✓ Datos generados: 1.00 GB en 10 archivos

Ingrese URL FTP de destino (ej: ftp://servidor.com/backup): ftp://test.com/datos

Ejecutando Llevar.ps1...
  Origen: C:\Temp\LLEVAR_TEST_LOCAL_TO_FTP
  Destino: ftp://test.com/datos

[Llevar.ps1 se ejecuta, muestra popup, barra de progreso, etc.]

═══════════════════════════════════════════════════
  ✓ TEST COMPLETADO
═══════════════════════════════════════════════════

Tiempo total: 00:02:34

¿Eliminar datos de prueba? (S/N):
```

#### **Test-FTPToLocal.ps1** - FTP → Local
Descarga archivos desde servidor FTP a carpeta local.

**Características:**
- 🔹 Solicita URL FTP de origen
- 🔹 Crea directorio temporal de destino
- 🔹 Usa `Connect-FtpServer` para validar conexión
- 🔹 Ejecuta `Llevar.ps1` con descarga
- 🔹 Muestra archivos descargados y tamaños
- 🔹 Ofrece limpieza

**Uso:**
```powershell
.\Test-FTPToLocal.ps1
```

#### **Test-LocalToISO.ps1** - Local → ISO
Genera 1GB de datos y crea archivo ISO.

**Características:**
- 🔹 Genera 10 archivos × 100MB
- 🔹 Solicita ruta para archivo ISO (o usa predeterminada)
- 🔹 Ejecuta `Llevar.ps1` con creación de ISO
- 🔹 Verifica tamaño del ISO creado
- 🔹 Ofrece limpieza de datos y del ISO

**Uso:**
```powershell
.\Test-LocalToISO.ps1
```

#### **Test-LocalToUSB.ps1** - Local → USB
Genera 1GB de datos y transfiere a dispositivo USB.

**Características:**
- 🔹 Genera 10 archivos × 100MB
- 🔹 Detecta dispositivos USB disponibles (DriveType = Removable)
- 🔹 Solicita letra de unidad o ruta manual
- 🔹 Soporta modo MockUSB (-MockUSB) para simular USB
- 🔹 Verifica espacio disponible en USB
- 🔹 Ejecuta `Llevar.ps1` con transferencia
- 🔹 Ofrece limpieza de origen y destino

**Uso:**
```powershell
# Con USB real
.\Test-LocalToUSB.ps1

# Con USB simulado (MockUSB)
.\Test-LocalToUSB.ps1 -MockUSB
```

**Ejemplo de salida:**
```
Dispositivos USB detectados:
  E:\ - USB_BACKUP (54.70 GB libre de 128.00 GB)
  F:\ - USB_STORAGE (12.30 GB libre de 32.00 GB)

Ingrese letra de unidad USB (ej: E): E

Ejecutando Llevar.ps1...
  Origen: C:\Temp\LLEVAR_TEST_USB_SOURCE
  Destino: E:\LLEVAR_TEST

[Transferencia...]

Archivos transferidos:
  Cantidad: 10
  Tamaño: 1.00 GB
```

#### **Test-FTPToFTP.ps1** - FTP → FTP
Transfiere datos entre dos servidores FTP.

**Características:**
- 🔹 Solicita URL FTP de origen y destino
- 🔹 Valida que no sean el mismo servidor (con advertencia)
- 🔹 Usa `Connect-FtpServer` para ambas conexiones
- 🔹 Ejecuta `Llevar.ps1` con transferencia FTP→FTP
- 🔹 Cronometra operación
- 🔹 Nota al usuario para verificar manualmente en servidor destino

**Uso:**
```powershell
.\Test-FTPToFTP.ps1
```

**Ejemplo de salida:**
```
═══════════════════════════════════════════════════
  TEST: FTP → FTP
═══════════════════════════════════════════════════

ORIGEN FTP
Ingrese URL FTP de origen (ej: ftp://servidor1.com/datos): ftp://s1.com/data

DESTINO FTP
Ingrese URL FTP de destino (ej: ftp://servidor2.com/destino): ftp://s2.com/backup

Ejecutando Llevar.ps1...
  Origen: ftp://s1.com/data
  Destino: ftp://s2.com/backup

[Transferencia...]

═══════════════════════════════════════════════════
  ✓ TEST COMPLETADO
═══════════════════════════════════════════════════

Tiempo total: 00:05:12

Nota: Verificar manualmente en servidor destino
```

## 🎯 Escenarios de Test

### Escenario 1: Múltiples USBs con Capacidades Diferentes
```
USB 1: 100 MB → Bloques 1-3 (90 MB)
USB 2: 150 MB → Bloques 4-7 (140 MB)
USB 3: 200 MB → Bloques 8-9 + INSTALAR.ps1 + __EOF__
```

### Escenario 2: Distribución Óptima
Simula el algoritmo de distribución que:
- Llena cada USB hasta su capacidad
- Solicita siguiente USB cuando sea necesario
- Marca el último USB con `__EOF__`
- Incluye script de instalación en primer USB

### Escenario 3: FTP como Origen
```
FTP Server (/test-data/)
├── documento1.txt (1 KB)
├── documento2.txt (2 KB)
└── subfolder/
    └── archivo.dat (5 KB)

↓ Descargar desde FTP

Local Temp (C:\Temp\LLEVAR_FTP_TESTS\)
└── LocalData/ftp_download/
    ├── documento1.txt
    ├── documento2.txt
    └── archivo.dat

↓ Comprimir y dividir

TempBlocks/
├── FTP_DATA.alx0001 (10 MB)
├── FTP_DATA.alx0002 (10 MB)
└── FTP_DATA.alx0003 (10 MB)
```

### Escenario 4: FTP como Destino
```
Local Data (C:\Datos\)
├── testfile_1.dat (4 MB)
├── testfile_2.dat (4 MB)
├── testfile_3.dat (4 MB)
├── testfile_4.dat (4 MB)
└── testfile_5.dat (4 MB)

↓ Comprimir y dividir

TempBlocks/
├── LOCAL_DATA.alx0001 (10 MB)
├── LOCAL_DATA.alx0002 (10 MB)
├── LOCAL_DATA.alx0003 (10 MB)
└── LOCAL_DATA.alx0004 (10 MB)

↓ Subir a FTP

FTP Server (/upload_test/)
├── LOCAL_DATA.alx0001
├── LOCAL_DATA.alx0002
├── LOCAL_DATA.alx0003
└── LOCAL_DATA.alx0004
```

## 📊 Formato de Resultados

### Tests Unitarios:
```
═══════════════════════════════════════════════════
  RESUMEN DE TESTS
═══════════════════════════════════════════════════

Total de tests: 15
Pasados:        14
Fallados:       1
Tasa de éxito:  93.33%
```

### Tests de Integración:
```
╔═══════════════════════════════════════════════════╗
║  RESUMEN DE TESTS DE INTEGRACIÓN                  ║
╚═══════════════════════════════════════════════════╝

Total de tests: 3
Pasados:        3
Fallados:       0
Tasa de éxito:  100%
```

## 🔧 Personalización

### Crear tus propios tests:

```powershell
# Nuevo archivo: Test-MisFunciones.ps1

function Test-MiFuncion {
    $script:TestResults.Total++
    
    $resultado = MiFuncion -Parametro "valor"
    
    if ($resultado -eq "esperado") {
        $script:TestResults.Passed++
        Write-TestResult "Mi función" $true
    }
    else {
        $script:TestResults.Failed++
        Write-TestResult "Mi función" $false "Error: $resultado"
    }
}
```

### Agregar al runner:

Edita `Run-AllTests.ps1` y agrega:
```powershell
$availableTests = @{
    # ... tests existentes ...
    MiTest = @{
        Name = "Mis Tests Personalizados"
        Script = "Test-MisFunciones.ps1"
        Description = "Prueba mis funciones custom"
    }
}
```

## 🧹 Limpieza

Los tests crean archivos temporales en:
- `$env:TEMP\LLEVAR_TEST_USB\` - USBs simulados
- `$env:TEMP\LLEVAR_INTEGRATION_TESTS\` - Datos de integración
- `$env:TEMP\LLEVAR_TEST_LOCAL_TO_FTP\` - Test Local→FTP
- `$env:TEMP\LLEVAR_TEST_FTP_TO_LOCAL\` - Test FTP→Local
- `$env:TEMP\LLEVAR_TEST_ISO_SOURCE\` - Test Local→ISO (origen)
- `$env:TEMP\LLEVAR_TEST_USB_SOURCE\` - Test Local→USB (origen)
- `$env:TEMP\LLEVAR_TEST_MOCK_USB\` - Test Local→USB (destino mock)

**Limpieza manual:**
```powershell
Remove-AllMockUSBs  # Limpia USBs simulados
Remove-Item "$env:TEMP\LLEVAR_*" -Recurse -Force  # Limpia todo
```

**Limpieza automática:**
```powershell
.\Run-AllTests.ps1 -CleanupAfter
```

**Cada test individual ofrece limpieza al finalizar:**
- Eliminar datos de prueba generados
- Eliminar archivos descargados
- Eliminar archivos ISO creados
- Eliminar archivos en USB

## 📈 Métricas de Cobertura

| Componente | Cobertura | Tests |
|------------|-----------|-------|
| Funciones Utilitarias | 100% | 15 |
| Simulación USB | 100% | 5 |
| Integración E2E | 60% | 3 |
| **OneDrive** | **100%** | **15** ⭐ |
| **Dropbox** | **100%** | **24** ⭐ |
| **Robocopy Mirror** | **100%** | **20** ⭐ |
| **Tests de Escenarios** | **100%** | **5** |
| **Total** | **98%** | **87** |

### Tests de Escenarios:
1. ✅ Local → FTP (Test-LocalToFTP.ps1)
2. ✅ FTP → Local (Test-FTPToLocal.ps1)
3. ✅ Local → ISO (Test-LocalToISO.ps1)
4. ✅ Local → USB (Test-LocalToUSB.ps1)
5. ✅ FTP → FTP (Test-FTPToFTP.ps1)

## 🐛 Troubleshooting

### Error: "No se puede cargar Llevar.ps1"
**Solución:** Asegúrate de que `Llevar.ps1` está en la carpeta padre:
```powershell
# Desde Tests/
Test-Path ..\Llevar.ps1  # Debe retornar True
```

### Error: "Permiso denegado en $env:TEMP"
**Solución:** Ejecuta con permisos o cambia `$script:TestRoot`:
```powershell
$script:TestRoot = "C:\Temp\LLEVAR_TESTS"
```

### Los USBs simulados no se limpian
**Solución:** Ejecuta manualmente:
```powershell
Remove-Item "$env:TEMP\LLEVAR_TEST_USB" -Recurse -Force
```

## 📚 Recursos Adicionales

- [Pester](https://pester.dev/) - Framework de testing para PowerShell
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) - Análisis estático
- [PowerShell Testing Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/writing-portable-modules)

## 🤝 Contribuir

Para agregar nuevos tests:

1. Crea un nuevo archivo `Test-*.ps1`
2. Sigue el formato de `Test-Functions.ps1`
3. Usa `Write-TestResult` para reportar
4. Actualiza `Run-AllTests.ps1`
5. Documenta en este README

## 📝 Notas

- Los tests son **no destructivos** - no afectan archivos reales
- Los USBs simulados son **carpetas temporales**
- La limpieza es **opcional** al finalizar
- Los tests pueden ejecutarse **en paralelo** (con cuidado)

---

**Última actualización:** 2 de diciembre de 2025
**Versión de tests:** 1.0.0

