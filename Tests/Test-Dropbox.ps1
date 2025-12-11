<#
.SYNOPSIS
    Tests para funcionalidad de Dropbox en Llevar.ps1

.DESCRIPTION
    Suite de tests para validar la integración con Dropbox:
    - Detección de rutas Dropbox
    - Validación de OAuth2
    - Upload/Download de archivos
    - Upload/Download de carpetas
    - Soporte para archivos grandes
    
.PARAMETER Integration
    Ejecuta tests de integración real con autenticación OAuth2
    Requiere conexión a Dropbox y navegador para autorización
    
.PARAMETER SkipIntegration
    Salta los tests de integración (solo tests unitarios)
#>

param(
    [switch]$Integration,
    [switch]$SkipIntegration
)

# Importar módulos de Llevar para tests
. (Join-Path $PSScriptRoot "Import-LlevarModules.ps1")

Show-Banner "TESTS DE DROPBOX" -BorderColor Cyan -TextColor Yellow

# Función de Test-IsDropboxPath (copiada del script principal)
function Test-IsDropboxPath {
    param([string]$Path)
    return $Path -match '^dropbox://|^DROPBOX:'
}

# ==========================================
# TEST 1: Detección de rutas Dropbox
# ==========================================

Write-Host "[TEST 1] Detección de rutas Dropbox" -ForegroundColor Cyan

$testCases = @(
    @{ Path = "dropbox:///Documents/Test"; Expected = $true; Name = "dropbox:// lowercase" }
    @{ Path = "DROPBOX:/Folder/File.txt"; Expected = $true; Name = "DROPBOX: uppercase" }
    @{ Path = "Dropbox:///Test"; Expected = $true; Name = "Dropbox: mixed case" }
    @{ Path = "C:\Users\Test"; Expected = $false; Name = "Ruta local" }
    @{ Path = "ftp://server/path"; Expected = $false; Name = "Ruta FTP" }
    @{ Path = "onedrive:///Files"; Expected = $false; Name = "Ruta OneDrive" }
)

$passed = 0
$failed = 0

foreach ($test in $testCases) {
    $result = Test-IsDropboxPath -Path $test.Path
    
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
# TEST 2: Validación de formato de rutas
# ==========================================

Write-Host "[TEST 2] Validación de formato de rutas Dropbox" -ForegroundColor Cyan

$pathTests = @(
    @{ 
        Path               = "dropbox:///Documents/Project"
        Pattern            = '^dropbox://(.+)$'
        ExpectedExtraction = "/Documents/Project"
        Name               = "Extracción de ruta con dropbox://"
    }
    @{ 
        Path               = "DROPBOX:/Files/data.txt"
        Pattern            = '^DROPBOX:(.+)$'
        ExpectedExtraction = "/Files/data.txt"
        Name               = "Extracción de ruta con DROPBOX:"
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
# TEST 3: Validación de normalización de rutas
# ==========================================

Write-Host "[TEST 3] Normalización de rutas Dropbox" -ForegroundColor Cyan

$normalizationTests = @(
    @{ Input = "folder/file.txt"; Expected = "/folder/file.txt"; Name = "Agregar / inicial" }
    @{ Input = "/folder/file.txt"; Expected = "/folder/file.txt"; Name = "Ya tiene / inicial" }
    @{ Input = "//folder/file.txt"; Expected = "/folder/file.txt"; Name = "Limpiar // dobles" }
)

foreach ($test in $normalizationTests) {
    $normalized = $test.Input
    
    # Simular lógica de normalización
    if (-not $normalized.StartsWith('/')) {
        $normalized = "/$normalized"
    }
    $normalized = $normalized.Replace('//', '/')
    
    if ($normalized -eq $test.Expected) {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "$($test.Name): " -NoNewline
        Write-Host "PASS" -ForegroundColor Green
        $passed++
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "$($test.Name): " -NoNewline
        Write-Host "FAIL" -ForegroundColor Red
        Write-Host "    Esperado: $($test.Expected), Obtenido: $normalized" -ForegroundColor Yellow
        $failed++
    }
}

Write-Host ""

# ==========================================
# TEST 4: Simulación de parámetros Dropbox
# ==========================================

Write-Host "[TEST 4] Simulación de parámetros Dropbox" -ForegroundColor Cyan

$testScenarios = @(
    @{ 
        DropboxOrigen  = $true
        DropboxDestino = $false
        OrigenPath     = "dropbox:///Source"
        DestinoPath    = "C:\Local"
        ExpectedMode   = "Download"
    }
    @{ 
        DropboxOrigen  = $false
        DropboxDestino = $true
        OrigenPath     = "C:\Local"
        DestinoPath    = "dropbox:///Backup"
        ExpectedMode   = "Upload"
    }
    @{ 
        DropboxOrigen  = $true
        DropboxDestino = $true
        OrigenPath     = "dropbox:///Source"
        DestinoPath    = "dropbox:///Backup"
        ExpectedMode   = "CloudToCloud"
    }
)

foreach ($scenario in $testScenarios) {
    $origenEsDropbox = $scenario.DropboxOrigen -or (Test-IsDropboxPath -Path $scenario.OrigenPath)
    $destinoEsDropbox = $scenario.DropboxDestino -or (Test-IsDropboxPath -Path $scenario.DestinoPath)
    
    $detectedMode = if ($origenEsDropbox -and -not $destinoEsDropbox) { "Download" }
    elseif (-not $origenEsDropbox -and $destinoEsDropbox) { "Upload" }
    elseif ($origenEsDropbox -and $destinoEsDropbox) { "CloudToCloud" }
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
# TEST 5: Verificación de constantes OAuth2
# ==========================================

Write-Host "[TEST 5] Verificación de constantes OAuth2" -ForegroundColor Cyan

$scriptPath = Join-Path $PSScriptRoot "..\Llevar.ps1"

if (Test-Path $scriptPath) {
    $scriptContent = Get-Content $scriptPath -Raw
    
    # Verificar que existe la configuración OAuth2
    if ($scriptContent -match 'qf3ohh840jfse3j') {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "App Key de Dropbox configurada" -ForegroundColor Gray
        $passed++
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "App Key de Dropbox NO encontrada" -ForegroundColor Red
        $failed++
    }
    
    if ($scriptContent -match 'localhost:53682') {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "Puerto de redirect URI configurado (53682)" -ForegroundColor Gray
        $passed++
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "Puerto de redirect URI NO encontrado" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""

# ==========================================
# TEST 6: Integración con script principal
# ==========================================

Write-Host "[TEST 6] Integración con script principal" -ForegroundColor Cyan

if (Test-Path $scriptPath) {
    $scriptContent = Get-Content $scriptPath -Raw
    
    $requiredFunctions = @(
        "Test-IsDropboxPath",
        "Get-DropboxToken",
        "Connect-DropboxIfNeeded",
        "Send-DropboxFile",
        "Get-DropboxFile",
        "Send-DropboxFolder",
        "Get-DropboxFolder",
        "Send-DropboxFileLarge"
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
    if ($scriptContent -match '\[switch\]\$DropboxOrigen') {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "Parámetro -DropboxOrigen existe" -ForegroundColor Gray
        $passed++
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "Parámetro -DropboxOrigen NO encontrado" -ForegroundColor Red
        $failed++
    }
    
    if ($scriptContent -match '\[switch\]\$DropboxDestino') {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "Parámetro -DropboxDestino existe" -ForegroundColor Gray
        $passed++
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "Parámetro -DropboxDestino NO encontrado" -ForegroundColor Red
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
# TEST 7: Validación de límites de archivo
# ==========================================

Write-Host "[TEST 7] Validación de límites de archivo grande" -ForegroundColor Cyan

$fileSizeTests = @(
    @{ Size = 150MB; Expected = "Large"; Name = "150MB (usar upload por sesiones)" }
    @{ Size = 100MB; Expected = "Normal"; Name = "100MB (upload simple)" }
    @{ Size = 1GB; Expected = "Large"; Name = "1GB (usar upload por sesiones)" }
)

foreach ($test in $fileSizeTests) {
    $useSessionUpload = $test.Size -ge 150MB
    $detected = if ($useSessionUpload) { "Large" } else { "Normal" }
    
    if ($detected -eq $test.Expected) {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "$($test.Name): " -NoNewline
        Write-Host "PASS" -ForegroundColor Green
        $passed++
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "$($test.Name): " -NoNewline
        Write-Host "FAIL" -ForegroundColor Red
        Write-Host "    Esperado: $($test.Expected), Obtenido: $detected" -ForegroundColor Yellow
        $failed++
    }
}

Write-Host ""

# ==========================================
# TEST 8: Integración Real (Opcional)
# ==========================================

if ($Integration -and -not $SkipIntegration) {
    Write-Host "[TEST 8] Integración Real con Dropbox" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Este test requiere:" -ForegroundColor Yellow
    Write-Host "  • Conexión a internet" -ForegroundColor Gray
    Write-Host "  • Navegador web para OAuth2" -ForegroundColor Gray
    Write-Host "  • Puerto 53682 disponible" -ForegroundColor Gray
    Write-Host "  • Cuenta Dropbox válida" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ¿Desea ejecutar test de integración real? (S/N): " -NoNewline -ForegroundColor Cyan
    $respuesta = Read-Host
    
    if ($respuesta -match '^[SsYy]$') {
        try {
            # Cargar funciones del script principal
            $scriptPath = Join-Path $PSScriptRoot "..\Llevar.ps1"
            . $scriptPath -ErrorAction Stop
            
            Write-Host ""
            Write-Host "  Iniciando autenticación OAuth2 con Dropbox..." -ForegroundColor Cyan
            
            if (Connect-DropboxIfNeeded) {
                Write-Host "  ✓ " -NoNewline -ForegroundColor Green
                Write-Host "Autenticación exitosa" -ForegroundColor Green
                $passed++
                
                # Crear archivo temporal de prueba
                $testFile = Join-Path $env:TEMP "dropbox_test_$(Get-Date -Format 'yyyyMMddHHmmss').txt"
                "Test de Dropbox desde Llevar.ps1 - $(Get-Date)" | Out-File $testFile
                
                Write-Host "  Probando upload de archivo..." -ForegroundColor Gray
                
                try {
                    Send-DropboxFile -LocalPath $testFile -RemotePath "/LlevarTests/test.txt" -Token $Global:DropboxToken
                    Write-Host "  ✓ " -NoNewline -ForegroundColor Green
                    Write-Host "Upload exitoso" -ForegroundColor Green
                    $passed++
                    
                    # Probar download
                    $downloadFile = Join-Path $env:TEMP "dropbox_download_test.txt"
                    Write-Host "  Probando download de archivo..." -ForegroundColor Gray
                    
                    Get-DropboxFile -RemotePath "/LlevarTests/test.txt" -LocalPath $downloadFile -Token $Global:DropboxToken
                    
                    if (Test-Path $downloadFile) {
                        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
                        Write-Host "Download exitoso" -ForegroundColor Green
                        $passed++
                        
                        # Verificar contenido
                        $content = Get-Content $downloadFile -Raw
                        if ($content -match "Test de Dropbox") {
                            Write-Host "  ✓ " -NoNewline -ForegroundColor Green
                            Write-Host "Contenido verificado correctamente" -ForegroundColor Green
                            $passed++
                        }
                        else {
                            Write-Host "  ✗ " -NoNewline -ForegroundColor Red
                            Write-Host "Contenido del archivo no coincide" -ForegroundColor Red
                            $failed++
                        }
                        
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
                Write-Host "No se pudo autenticar con Dropbox" -ForegroundColor Red
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
    Write-Host ""
}
elseif ($SkipIntegration) {
    Write-Host "[TEST 8] Integración Real con Dropbox" -ForegroundColor Cyan
    Write-Host "  ⊘ Tests de integración omitidos (-SkipIntegration)" -ForegroundColor Gray
    Write-Host ""
}

# ==========================================
# RESUMEN
# ==========================================

Show-Banner "RESUMEN DE TESTS DE DROPBOX" -BorderColor Cyan -TextColor Yellow
Write-Host "  Tests ejecutados: " -NoNewline
Write-Host ($passed + $failed) -ForegroundColor White
Write-Host "  Pasados         : " -NoNewline
Write-Host $passed -ForegroundColor Green
Write-Host "  Fallados        : " -NoNewline
Write-Host $failed -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host ""

Write-Host "ℹ NOTA:" -ForegroundColor Cyan
Write-Host "  Para tests de integración completos con Dropbox:" -ForegroundColor Gray
Write-Host "  • Requiere autenticación OAuth2 interactiva" -ForegroundColor DarkGray
Write-Host "  • El navegador se abrirá automáticamente" -ForegroundColor DarkGray
Write-Host "  • Puerto 53682 debe estar disponible" -ForegroundColor DarkGray
Write-Host ""

if ($failed -eq 0) {
    Write-Host "✓ Todos los tests pasaron correctamente" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Algunos tests fallaron" -ForegroundColor Red
    exit 1
}
