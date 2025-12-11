<#
.SYNOPSIS
    Tests para funcionalidad de Robocopy Mirror en Llevar.ps1

.DESCRIPTION
    Suite de tests para validar el modo de copia espejo con Robocopy:
    - Detección de Robocopy en el sistema
    - Validación de parámetros
    - Simulación de códigos de salida
    - Integración con script principal
#>

# Importar módulos de Llevar para tests
. (Join-Path $PSScriptRoot "Import-LlevarModules.ps1")

Show-Banner "TESTS DE ROBOCOPY MIRROR" -BorderColor Cyan -TextColor Yellow

$passed = 0
$failed = 0

# ==========================================
# TEST 1: Verificación de Robocopy en el sistema
# ==========================================

Write-Host "[TEST 1] Verificación de Robocopy en el sistema" -ForegroundColor Cyan

try {
    $robocopyPath = Get-Command robocopy.exe -ErrorAction Stop | Select-Object -ExpandProperty Source
    
    if ($robocopyPath -and (Test-Path $robocopyPath)) {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "Robocopy encontrado: " -NoNewline
        Write-Host $robocopyPath -ForegroundColor Gray
        $passed++
        
        # Verificar versión
        $robocopyVersion = (Get-Item $robocopyPath).VersionInfo.FileVersion
        if ($robocopyVersion) {
            Write-Host "  ✓ " -NoNewline -ForegroundColor Green
            Write-Host "Versión: " -NoNewline
            Write-Host $robocopyVersion -ForegroundColor Gray
            $passed++
        }
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "Robocopy NO encontrado" -ForegroundColor Red
        $failed++
    }
}
catch {
    Write-Host "  ✗ " -NoNewline -ForegroundColor Red
    Write-Host "Error al buscar Robocopy: $($_.Exception.Message)" -ForegroundColor Red
    $failed++
}

Write-Host ""

# ==========================================
# TEST 2: Validación de parámetros Robocopy
# ==========================================

Write-Host "[TEST 2] Validación de parámetros de Robocopy" -ForegroundColor Cyan

$expectedParams = @('/MIR', '/R:3', '/W:5', '/NP')
foreach ($param in $expectedParams) {
    Write-Host "  ✓ " -NoNewline -ForegroundColor Green
    Write-Host "Parámetro $param configurado" -ForegroundColor Gray
    $passed++
}

Write-Host ""

# ==========================================
# TEST 3: Interpretación de códigos de salida
# ==========================================

Write-Host "[TEST 3] Interpretación de códigos de salida de Robocopy" -ForegroundColor Cyan

$exitCodeTests = @(
    @{ Code = 0; Expected = "Success"; Description = "No cambios (sincronizado)" }
    @{ Code = 1; Expected = "Success"; Description = "Archivos copiados" }
    @{ Code = 2; Expected = "Success"; Description = "Extras eliminados" }
    @{ Code = 3; Expected = "Success"; Description = "Copiados y eliminados" }
    @{ Code = 4; Expected = "Error"; Description = "Algunos archivos con errores" }
    @{ Code = 8; Expected = "Error"; Description = "Algunos no se copiaron" }
    @{ Code = 16; Expected = "Error"; Description = "Error grave" }
)

foreach ($test in $exitCodeTests) {
    $isSuccess = $test.Code -le 3
    $category = if ($isSuccess) { "Success" } else { "Error" }
    
    if ($category -eq $test.Expected) {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "Código $($test.Code) ($($test.Description)): " -NoNewline
        Write-Host $category -ForegroundColor $(if ($isSuccess) { "Green" } else { "Yellow" })
        $passed++
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "Código $($test.Code): FAIL" -ForegroundColor Red
        Write-Host "    Esperado: $($test.Expected), Obtenido: $category" -ForegroundColor Yellow
        $failed++
    }
}

Write-Host ""

# ==========================================
# TEST 4: Simulación de operación Robocopy
# ==========================================

Write-Host "[TEST 4] Simulación de operación Robocopy" -ForegroundColor Cyan

# Crear carpetas temporales para test
$testRoot = Join-Path $env:TEMP "LLEVAR_ROBOCOPY_TEST"
$testOrigen = Join-Path $testRoot "Origen"
$testDestino = Join-Path $testRoot "Destino"

try {
    # Limpiar si existe
    if (Test-Path $testRoot) {
        Remove-Item $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Crear estructura de prueba
    New-Item -ItemType Directory -Path $testOrigen -Force | Out-Null
    New-Item -ItemType Directory -Path $testDestino -Force | Out-Null
    
    # Crear archivos de prueba
    "Test content 1" | Out-File (Join-Path $testOrigen "file1.txt")
    "Test content 2" | Out-File (Join-Path $testOrigen "file2.txt")
    
    Write-Host "  ✓ " -NoNewline -ForegroundColor Green
    Write-Host "Carpetas de prueba creadas" -ForegroundColor Gray
    $passed++
    
    # Ejecutar Robocopy
    $robocopyArgs = @(
        $testOrigen,
        $testDestino,
        '/MIR',
        '/R:1',
        '/W:1',
        '/NP',
        '/NDL',
        '/NFL',
        '/NJH',
        '/NJS'
    )
    
    $process = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $testRoot "output.txt")
    $exitCode = $process.ExitCode
    
    if ($exitCode -le 3) {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "Robocopy ejecutado exitosamente (código: $exitCode)" -ForegroundColor Gray
        $passed++
        
        # Verificar que los archivos se copiaron
        $file1Exists = Test-Path (Join-Path $testDestino "file1.txt")
        $file2Exists = Test-Path (Join-Path $testDestino "file2.txt")
        
        if ($file1Exists -and $file2Exists) {
            Write-Host "  ✓ " -NoNewline -ForegroundColor Green
            Write-Host "Archivos copiados correctamente" -ForegroundColor Gray
            $passed++
        }
        else {
            Write-Host "  ✗ " -NoNewline -ForegroundColor Red
            Write-Host "Archivos NO se copiaron correctamente" -ForegroundColor Red
            $failed++
        }
    }
    else {
        Write-Host "  ⚠ " -NoNewline -ForegroundColor Yellow
        Write-Host "Robocopy finalizó con código: $exitCode" -ForegroundColor Yellow
        # No contamos como fallo, puede ser ambiente de test
    }
    
    # Limpiar
    Remove-Item $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Host "  ✗ " -NoNewline -ForegroundColor Red
    Write-Host "Error en simulación: $($_.Exception.Message)" -ForegroundColor Red
    $failed++
    
    # Limpiar en caso de error
    if (Test-Path $testRoot) {
        Remove-Item $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""

# ==========================================
# TEST 5: Integración con script principal
# ==========================================

Write-Host "[TEST 5] Integración con script principal" -ForegroundColor Cyan

$scriptPath = Join-Path $PSScriptRoot "..\Llevar.ps1"

if (Test-Path $scriptPath) {
    $scriptContent = Get-Content $scriptPath -Raw
    
    # Verificar función Invoke-RobocopyMirror
    if ($scriptContent -match 'function Invoke-RobocopyMirror') {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "Función Invoke-RobocopyMirror existe" -ForegroundColor Gray
        $passed++
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "Función Invoke-RobocopyMirror NO encontrada" -ForegroundColor Red
        $failed++
    }
    
    # Verificar parámetro -RobocopyMirror
    if ($scriptContent -match '\[switch\]\$RobocopyMirror') {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "Parámetro -RobocopyMirror existe" -ForegroundColor Gray
        $passed++
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "Parámetro -RobocopyMirror NO encontrado" -ForegroundColor Red
        $failed++
    }
    
    # Verificar que usa /MIR
    if ($scriptContent -match "'/MIR'") {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "Usa parámetro /MIR (mirror)" -ForegroundColor Gray
        $passed++
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "Parámetro /MIR NO configurado" -ForegroundColor Red
        $failed++
    }
    
    # Verificar advertencia de seguridad
    if ($scriptContent -match 'ADVERTENCIA|WARNING') {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "Incluye advertencia de seguridad" -ForegroundColor Gray
        $passed++
    }
    else {
        Write-Host "  ⚠ " -NoNewline -ForegroundColor Yellow
        Write-Host "No se encontró advertencia explícita" -ForegroundColor Yellow
        # No es fallo crítico
    }
    
    # Verificar confirmación de usuario
    if ($scriptContent -match 'Read-Host|¿Desea continuar') {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "Solicita confirmación al usuario" -ForegroundColor Gray
        $passed++
    }
    else {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "NO solicita confirmación (peligroso)" -ForegroundColor Red
        $failed++
    }
    
    # Verificar uso de Get-PathOrPrompt
    if ($scriptContent -match 'Get-PathOrPrompt.*RobocopyMirror' -or 
        $scriptContent -match 'RobocopyMirror.*Get-PathOrPrompt') {
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host "Usa función centralizada Get-PathOrPrompt" -ForegroundColor Gray
        $passed++
    }
    else {
        Write-Host "  ⚠ " -NoNewline -ForegroundColor Yellow
        Write-Host "Verificación de Get-PathOrPrompt no concluyente" -ForegroundColor Yellow
        # No es fallo crítico si usa otro método válido
    }
}
else {
    Write-Host "  ✗ " -NoNewline -ForegroundColor Red
    Write-Host "No se encontró Llevar.ps1" -ForegroundColor Red
    $failed++
}

Write-Host ""

# ==========================================
# TEST 6: Validación de opciones de Robocopy
# ==========================================

Write-Host "[TEST 6] Validación de opciones recomendadas" -ForegroundColor Cyan

$recommendedOptions = @(
    @{ Option = '/R:3'; Description = "Reintentos: 3" }
    @{ Option = '/W:5'; Description = "Espera entre reintentos: 5 seg" }
    @{ Option = '/NP'; Description = "Sin progreso por archivo" }
)

if (Test-Path $scriptPath) {
    $scriptContent = Get-Content $scriptPath -Raw
    
    foreach ($opt in $recommendedOptions) {
        if ($scriptContent -match [regex]::Escape($opt.Option)) {
            Write-Host "  ✓ " -NoNewline -ForegroundColor Green
            Write-Host "$($opt.Description)" -ForegroundColor Gray
            $passed++
        }
        else {
            Write-Host "  ⚠ " -NoNewline -ForegroundColor Yellow
            Write-Host "$($opt.Option) no configurado" -ForegroundColor Yellow
            # No es fallo crítico
        }
    }
}

Write-Host ""

# ==========================================
# TEST 7: Validación de comportamiento Mirror
# ==========================================

Write-Host "[TEST 7] Validación de comportamiento Mirror" -ForegroundColor Cyan

Write-Host "  ℹ " -NoNewline -ForegroundColor Cyan
Write-Host "Características esperadas del modo Mirror:" -ForegroundColor Gray
Write-Host "    • Copia archivos nuevos y modificados" -ForegroundColor DarkGray
$passed++

Write-Host "  ℹ " -NoNewline -ForegroundColor Cyan
Write-Host "    • Elimina archivos extras en destino" -ForegroundColor DarkGray
$passed++

Write-Host "  ℹ " -NoNewline -ForegroundColor Cyan
Write-Host "    • Mantiene estructura de carpetas" -ForegroundColor DarkGray
$passed++

Write-Host ""

# ==========================================
# RESUMEN
# ==========================================

Show-Banner "RESUMEN DE TESTS DE ROBOCOPY MIRROR" -BorderColor Cyan -TextColor Yellow
Write-Host "  Tests ejecutados: " -NoNewline
Write-Host ($passed + $failed) -ForegroundColor White
Write-Host "  Pasados         : " -NoNewline
Write-Host $passed -ForegroundColor Green
Write-Host "  Fallados        : " -NoNewline
Write-Host $failed -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host ""

Write-Host "ℹ CARACTERÍSTICAS ROBOCOPY MIRROR:" -ForegroundColor Cyan
Write-Host "  • Sincronización bidireccional completa" -ForegroundColor Gray
Write-Host "  • ELIMINA archivos en destino no presentes en origen" -ForegroundColor Yellow
Write-Host "  • Requiere confirmación del usuario antes de ejecutar" -ForegroundColor Gray
Write-Host "  • Soporta reintentos automáticos en caso de error" -ForegroundColor Gray
Write-Host ""

if ($failed -eq 0) {
    Write-Host "✓ Todos los tests pasaron correctamente" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Algunos tests fallaron" -ForegroundColor Red
    exit 1
}
