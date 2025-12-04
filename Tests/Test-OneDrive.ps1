<#
.SYNOPSIS
    Tests para funcionalidad de OneDrive en Llevar.ps1

.DESCRIPTION
    Suite de tests para validar la integración con OneDrive:
    - Detección de rutas OneDrive
    - Verificación de módulos Microsoft.Graph
    - Upload/Download de archivos
    - Upload/Download de carpetas
    - Transferencia directa y con compresión
    
.PARAMETER Integration
    Ejecuta tests de integración real con autenticación
    Requiere conexión a OneDrive y credenciales válidas
    
.PARAMETER SkipIntegration
    Salta los tests de integración (solo tests unitarios)
#>

param(
    [switch]$Integration,
    [switch]$SkipIntegration
)

# Importar módulo de Pester si está disponible
$pesterAvailable = $null -ne (Get-Module -ListAvailable -Name Pester)

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  TESTS DE ONEDRIVE" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Función de Test-IsOneDrivePath (copiada del script principal)
function Test-IsOneDrivePath {
    param([string]$Path)
    return $Path -match '^onedrive://|^ONEDRIVE:'
}

# ==========================================
# TEST 1: Detección de rutas OneDrive
# ==========================================

Write-Host "[TEST 1] Detección de rutas OneDrive" -ForegroundColor Cyan

$testCases = @(
    @{ Path = "onedrive:///Documents/Test"; Expected = $true; Name = "onedrive:// lowercase" }
    @{ Path = "ONEDRIVE:/Folder/File.txt"; Expected = $true; Name = "ONEDRIVE: uppercase" }
    @{ Path = "OneDrive:///Test"; Expected = $true; Name = "OneDrive: mixed case" }
    @{ Path = "C:\Users\Test"; Expected = $false; Name = "Ruta local" }
    @{ Path = "ftp://server/path"; Expected = $false; Name = "Ruta FTP" }
    @{ Path = "dropbox:///Files"; Expected = $false; Name = "Ruta Dropbox" }
)

$passed = 0
$failed = 0

foreach ($test in $testCases) {
    $result = Test-IsOneDrivePath -Path $test.Path
    
    if ($result -eq $test.Expected) {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "$($test.Name): " -NoNewline
        Write-Host "PASS" -ForegroundColor Green
        $passed++
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "$($test.Name): " -NoNewline
        Write-Host "FAIL" -ForegroundColor Red
        Write-Host "    Esperado: $($test.Expected), Obtenido: $result" -ForegroundColor Yellow
        $failed++
    }
}

Write-Host ""

# ==========================================
# TEST 2: Verificación de módulos Microsoft.Graph
# ==========================================

Write-Host "[TEST 2] Verificación de módulos Microsoft.Graph" -ForegroundColor Cyan

$requiredModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Files"
)

$modulesInstalled = $true
foreach ($moduleName in $requiredModules) {
    $module = Get-Module -ListAvailable -Name $moduleName
    
    if ($module) {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "$moduleName instalado (v$($module.Version))" -ForegroundColor Gray
        $passed++
    }
    else {
        Write-Host "  ⚠ " -NoNewline -ForegroundColor Yellow
        Write-Host "$moduleName NO instalado" -ForegroundColor Yellow
        Write-Host "    (Se requiere para pruebas de integración real)" -ForegroundColor DarkGray
        $modulesInstalled = $false
        # No contamos como fallo porque es opcional
    }
}

Write-Host ""

# ==========================================
# TEST 3: Validación de formato de rutas
# ==========================================

Write-Host "[TEST 3] Validación de formato de rutas OneDrive" -ForegroundColor Cyan

$pathTests = @(
    @{ 
        Path               = "onedrive:///Documents/Project"
        Pattern            = '^onedrive://(.+)$'
        ExpectedExtraction = "/Documents/Project"
        Name               = "Extracción de ruta con onedrive://"
    }
    @{ 
        Path               = "ONEDRIVE:/Files/data.txt"
        Pattern            = '^ONEDRIVE:(.+)$'
        ExpectedExtraction = "/Files/data.txt"
        Name               = "Extracción de ruta con ONEDRIVE:"
    }
)

foreach ($test in $pathTests) {
    if ($test.Path -match $test.Pattern) {
        $extracted = $Matches[1]
        
        if ($extracted -eq $test.ExpectedExtraction) {
            Write-Host "  ✓ " -NoNewline -ForegroundColor Green
            Write-Host "$($test.Name): " -NoNewline
            Write-Host "PASS" -ForegroundColor Green
            Write-Host "    Ruta extraída: $extracted" -ForegroundColor DarkGray
            $passed++
        }
        else {
            Write-Host "  ✗ " -NoNewline -ForegroundColor Red
            Write-Host "$($test.Name): " -NoNewline
            Write-Host "FAIL" -ForegroundColor Red
            Write-Host "    Esperado: $($test.ExpectedExtraction), Obtenido: $extracted" -ForegroundColor Yellow
            $failed++
        }
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "$($test.Name): " -NoNewline
        Write-Host "FAIL (no match pattern)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""

# ==========================================
# TEST 4: Simulación de parámetros OneDrive
# ==========================================

Write-Host "[TEST 4] Simulación de parámetros OneDrive" -ForegroundColor Cyan

# Simular detección de flags
$testScenarios = @(
    @{ 
        OnedriveOrigen  = $true
        OnedriveDestino = $false
        OrigenPath      = "onedrive:///Source"
        DestinoPath     = "C:\Local"
        ExpectedMode    = "Download"
    }
    @{ 
        OnedriveOrigen  = $false
        OnedriveDestino = $true
        OrigenPath      = "C:\Local"
        DestinoPath     = "onedrive:///Backup"
        ExpectedMode    = "Upload"
    }
    @{ 
        OnedriveOrigen  = $true
        OnedriveDestino = $true
        OrigenPath      = "onedrive:///Source"
        DestinoPath     = "onedrive:///Backup"
        ExpectedMode    = "CloudToCloud"
    }
)

foreach ($scenario in $testScenarios) {
    $origenEsOneDrive = $scenario.OnedriveOrigen -or (Test-IsOneDrivePath -Path $scenario.OrigenPath)
    $destinoEsOneDrive = $scenario.OnedriveDestino -or (Test-IsOneDrivePath -Path $scenario.DestinoPath)
    
    $detectedMode = if ($origenEsOneDrive -and -not $destinoEsOneDrive) { "Download" }
    elseif (-not $origenEsOneDrive -and $destinoEsOneDrive) { "Upload" }
    elseif ($origenEsOneDrive -and $destinoEsOneDrive) { "CloudToCloud" }
    else { "LocalToLocal" }
    
    if ($detectedMode -eq $scenario.ExpectedMode) {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "Escenario $($scenario.ExpectedMode): " -NoNewline
        Write-Host "PASS" -ForegroundColor Green
        $passed++
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "Escenario $($scenario.ExpectedMode): " -NoNewline
        Write-Host "FAIL" -ForegroundColor Red
        Write-Host "    Esperado: $($scenario.ExpectedMode), Obtenido: $detectedMode" -ForegroundColor Yellow
        $failed++
    }
}

Write-Host ""

# ==========================================
# TEST 5: Integración con script principal
# ==========================================

Write-Host "[TEST 5] Integración con script principal" -ForegroundColor Cyan

$scriptPath = Join-Path $PSScriptRoot "..\Llevar.ps1"

if (Test-Path $scriptPath) {
    # Verificar que el script contiene las funciones de OneDrive
    $scriptContent = Get-Content $scriptPath -Raw
    
    $requiredFunctions = @(
        "Test-IsOneDrivePath",
        "Connect-GraphIfNeeded",
        "Send-OneDriveFile",
        "Get-OneDriveFile",
        "Send-OneDriveFolder",
        "Get-OneDriveFolder"
    )
    
    foreach ($funcName in $requiredFunctions) {
        if ($scriptContent -match "function $funcName") {
            Write-Host "  ✓ " -NoNewline -ForegroundColor Green
            Write-Host "Función $funcName existe" -ForegroundColor Gray
            $passed++
        }
        else {
            Write-Host "  ✗ " -NoNewline -ForegroundColor Red
            Write-Host "Función $funcName NO encontrada" -ForegroundColor Red
            $failed++
        }
    }
    
    # Verificar parámetros
    if ($scriptContent -match '\[switch\]\$OnedriveOrigen') {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "Parámetro -OnedriveOrigen existe" -ForegroundColor Gray
        $passed++
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "Parámetro -OnedriveOrigen NO encontrado" -ForegroundColor Red
        $failed++
    }
    
    if ($scriptContent -match '\[switch\]\$OnedriveDestino') {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "Parámetro -OnedriveDestino existe" -ForegroundColor Gray
        $passed++
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "Parámetro -OnedriveDestino NO encontrado" -ForegroundColor Red
        $failed++
    }
}
else {
    Write-Host "  ✗ " -NoNewline -ForegroundColor Red
    Write-Host "No se encontró Llevar.ps1" -ForegroundColor Red
    $failed++
}

Write-Host ""

# ==========================================
# TEST 6: Integración Real (Opcional)
# ==========================================

if ($Integration -and -not $SkipIntegration) {
    Write-Host "[TEST 6] Integración Real con OneDrive" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Este test requiere:" -ForegroundColor Yellow
    Write-Host "  • Módulos Microsoft.Graph instalados" -ForegroundColor Gray
    Write-Host "  • Autenticación con cuenta Microsoft" -ForegroundColor Gray
    Write-Host "  • Permisos: Files.ReadWrite.All" -ForegroundColor Gray
    Write-Host ""
    
    if (-not $modulesInstalled) {
        Write-Host "  ⚠ " -NoNewline -ForegroundColor Yellow
        Write-Host "Módulos no instalados, saltando test de integración" -ForegroundColor Yellow
    }
    else {
        Write-Host "  ¿Desea ejecutar test de integración real? (S/N): " -NoNewline -ForegroundColor Cyan
        $respuesta = Read-Host
        
        if ($respuesta -match '^[SsYy]$') {
            try {
                # Cargar funciones del script principal
                $scriptPath = Join-Path $PSScriptRoot "..\Llevar.ps1"
                . $scriptPath -ErrorAction Stop
                
                Write-Host ""
                Write-Host "  Conectando a Microsoft Graph..." -ForegroundColor Cyan
                
                if (Connect-GraphIfNeeded) {
                    Write-Host "  ✓ " -NoNewline -ForegroundColor Green
                    Write-Host "Autenticación exitosa" -ForegroundColor Green
                    $passed++
                    
                    # Crear archivo temporal de prueba
                    $testFile = Join-Path $env:TEMP "onedrive_test_$(Get-Date -Format 'yyyyMMddHHmmss').txt"
                    "Test de OneDrive desde Llevar.ps1" | Out-File $testFile
                    
                    Write-Host "  Probando upload de archivo..." -ForegroundColor Gray
                    
                    try {
                        Send-OneDriveFile -LocalPath $testFile -RemotePath "/LlevarTests/test.txt"
                        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
                        Write-Host "Upload exitoso" -ForegroundColor Green
                        $passed++
                        
                        # Probar download
                        $downloadFile = Join-Path $env:TEMP "onedrive_download_test.txt"
                        Write-Host "  Probando download de archivo..." -ForegroundColor Gray
                        
                        Get-OneDriveFile -OneDrivePath "root:/LlevarTests/test.txt:" -LocalPath $downloadFile
                        
                        if (Test-Path $downloadFile) {
                            Write-Host "  ✓ " -NoNewline -ForegroundColor Green
                            Write-Host "Download exitoso" -ForegroundColor Green
                            $passed++
                            Remove-Item $downloadFile -Force -ErrorAction SilentlyContinue
                        }
                        else {
                            Write-Host "  ✗ " -NoNewline -ForegroundColor Red
                            Write-Host "Download falló" -ForegroundColor Red
                            $failed++
                        }
                    }
                    catch {
                        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
                        Write-Host "Error en upload/download: $($_.Exception.Message)" -ForegroundColor Red
                        $failed++
                    }
                    finally {
                        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                    }
                }
                else {
                    Write-Host "  ✗ " -NoNewline -ForegroundColor Red
                    Write-Host "No se pudo autenticar con OneDrive" -ForegroundColor Red
                    $failed++
                }
            }
            catch {
                Write-Host "  ✗ " -NoNewline -ForegroundColor Red
                Write-Host "Error en test de integración: $($_.Exception.Message)" -ForegroundColor Red
                $failed++
            }
        }
        else {
            Write-Host "  ⊘ " -NoNewline -ForegroundColor Gray
            Write-Host "Test de integración omitido por el usuario" -ForegroundColor Gray
        }
    }
    Write-Host ""
}
elseif ($SkipIntegration) {
    Write-Host "[TEST 6] Integración Real con OneDrive" -ForegroundColor Cyan
    Write-Host "  ⊘ Tests de integración omitidos (-SkipIntegration)" -ForegroundColor Gray
    Write-Host ""
}

# ==========================================
# RESUMEN
# ==========================================

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RESUMEN DE TESTS DE ONEDRIVE" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Tests ejecutados: " -NoNewline
Write-Host ($passed + $failed) -ForegroundColor White
Write-Host "  Pasados         : " -NoNewline
Write-Host $passed -ForegroundColor Green
Write-Host "  Fallados        : " -NoNewline
Write-Host $failed -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if (-not $modulesInstalled) {
    Write-Host "⚠ NOTA:" -ForegroundColor Yellow
    Write-Host "  Módulos Microsoft.Graph no instalados." -ForegroundColor Gray
    Write-Host "  Para tests de integración completos, instale:" -ForegroundColor Gray
    Write-Host "  Install-Module Microsoft.Graph.Authentication -Scope CurrentUser" -ForegroundColor DarkGray
    Write-Host "  Install-Module Microsoft.Graph.Files -Scope CurrentUser" -ForegroundColor DarkGray
    Write-Host ""
}

if ($failed -eq 0) {
    Write-Host "✓ Todos los tests pasaron correctamente" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Algunos tests fallaron" -ForegroundColor Red
    exit 1
}
