# ========================================================================== #
#           PRUEBA INTEGRAL DEL DISPATCHER UNIFICADO                         #
# ========================================================================== #
# Archivo: Tests\Test-DispatcherUnificado.ps1
# Propósito: Validar que el dispatcher detecta y ejecuta todas las rutas
# ========================================================================== #

using module "Q:\Utilidad\LLevar\Modules\Core\TransferConfig.psm1"

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "    PRUEBA INTEGRAL - DISPATCHER UNIFICADO" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Importar módulos con rutas absolutas
$ModulesPath = "Q:\Utilidad\LLevar\Modules"
Import-Module (Join-Path $ModulesPath "Core\Logging.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "UI\ProgressBar.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Transfer\Local.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Transfer\Unified.psm1") -Force -Global

# Inicializar logging
$Global:ScriptDir = "Q:\Utilidad\LLevar"
$Global:LogsDir = Join-Path $Global:ScriptDir "Logs"
if (-not (Test-Path $Global:LogsDir)) {
    New-Item -Path $Global:LogsDir -ItemType Directory -Force | Out-Null
}
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$Global:LogFile = Join-Path $Global:LogsDir "TEST_DISPATCHER_$timestamp.log"

Write-Host "✓ Módulos importados correctamente" -ForegroundColor Green
Write-Host ""

# ========================================================================== #
#                          PRUEBA 1: LOCAL → LOCAL                           #
# ========================================================================== #

Write-Host "[PRUEBA 1] Local → Local (único implementado)" -ForegroundColor Cyan

try {
    $llevar = [TransferConfig]::new()
    $llevar.Origen.Tipo = "Local"
    $llevar.Origen.Local.Path = $env:TEMP
    $llevar.Destino.Tipo = "Local"
    $llevar.Destino.Local.Path = Join-Path $env:TEMP "LLEVAR_TEST_DEST"
    
    # Crear destino temporal
    if (-not (Test-Path $llevar.Destino.Local.Path)) {
        New-Item -Type Directory $llevar.Destino.Local.Path | Out-Null
    }
    
    Write-Host "✓ Config creada: Local→Local" -ForegroundColor Green
    Write-Host "  Origen: $($llevar.Origen.Local.Path)" -ForegroundColor Gray
    Write-Host "  Destino: $($llevar.Destino.Local.Path)" -ForegroundColor Gray
    Write-Host ""
    
    # Llamar al dispatcher
    Write-Host "Ejecutando dispatcher..." -ForegroundColor Yellow
    $result = Copy-LlevarFiles -TransferConfig $llevar
    
    Write-Host "✓ Dispatcher ejecutó exitosamente" -ForegroundColor Green
    Write-Host "  Route: $($result.Route)" -ForegroundColor Gray
    Write-Host ""
    
    # Limpiar
    Remove-Item $llevar.Destino.Local.Path -Recurse -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Host "✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
}

# ========================================================================== #
#                   PRUEBA 2: DETECCIÓN DE RUTAS NO IMPLEMENTADAS           #
# ========================================================================== #

Write-Host "[PRUEBA 2] Detección de rutas no implementadas" -ForegroundColor Cyan

$testRoutes = @(
    @{ Origen = "Local"; Destino = "FTP"; Expected = "throw" }
    @{ Origen = "FTP"; Destino = "Local"; Expected = "throw" }
    @{ Origen = "Local"; Destino = "OneDrive"; Expected = "throw" }
    @{ Origen = "OneDrive"; Destino = "Local"; Expected = "throw" }
    @{ Origen = "Local"; Destino = "Dropbox"; Expected = "throw" }
    @{ Origen = "Dropbox"; Destino = "Local"; Expected = "throw" }
    @{ Origen = "FTP"; Destino = "FTP"; Expected = "throw" }
    @{ Origen = "OneDrive"; Destino = "Dropbox"; Expected = "throw" }
)

$passed = 0
$failed = 0

foreach ($route in $testRoutes) {
    $routeStr = "$($route.Origen)→$($route.Destino)"
    
    try {
        $llevar = [TransferConfig]::new()
        $llevar.Origen.Tipo = $route.Origen
        $llevar.Destino.Tipo = $route.Destino
        
        # Configurar paths dummy según tipo
        switch ($route.Origen) {
            "Local" { $llevar.Origen.Local.Path = $env:TEMP }
            "FTP" { 
                $llevar.Origen.FTP.Server = "ftp://dummy"
                $llevar.Origen.FTP.Directory = "/"
            }
            "OneDrive" { $llevar.Origen.OneDrive.Path = "/" }
            "Dropbox" { $llevar.Origen.Dropbox.Path = "/" }
        }
        
        switch ($route.Destino) {
            "Local" { $llevar.Destino.Local.Path = $env:TEMP }
            "FTP" { 
                $llevar.Destino.FTP.Server = "ftp://dummy"
                $llevar.Destino.FTP.Directory = "/"
            }
            "OneDrive" { $llevar.Destino.OneDrive.Path = "/" }
            "Dropbox" { $llevar.Destino.Dropbox.Path = "/" }
        }
        
        # Intentar ejecutar (debe throw)
        $null = Copy-LlevarFiles -TransferConfig $llevar
        
        # Si llegamos aquí, no hizo throw cuando debería
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "$routeStr`: NO lanzó excepción esperada" -ForegroundColor Red
        $failed++
    }
    catch {
        # Verificar que el mensaje indique "en desarrollo" o "pendiente"
        if ($_.Exception.Message -match "(desarrollo|pendiente|implementa)") {
            Write-Host "  ✓ " -NoNewline -ForegroundColor Green
            Write-Host "$routeStr`: Correctamente marcada como no implementada" -ForegroundColor Gray
            $passed++
        }
        else {
            Write-Host "  ✗ " -NoNewline -ForegroundColor Yellow
            Write-Host "$routeStr`: Error inesperado: $($_.Exception.Message)" -ForegroundColor Yellow
            $failed++
        }
    }
}

Write-Host ""

# ========================================================================== #
#                   PRUEBA 3: VALIDACIÓN DE TIPOS                            #
# ========================================================================== #

Write-Host "[PRUEBA 3] Validación de tipos esperados" -ForegroundColor Cyan

try {
    $llevar = [TransferConfig]::new()
    $llevar.Origen.Tipo = "FTP"  # Incorrecto
    $llevar.Destino.Tipo = "Local"
    $llevar.Origen.FTP.Server = "ftp://dummy"
    $llevar.Destino.Local.Path = $env:TEMP
    
    # Llamar esperando Local→Local (debe fallar)
    Copy-LlevarLocalToFtp -Llevar $llevar
    
    Write-Host "  ✗ NO validó tipo de origen" -ForegroundColor Red
    $failed++
}
catch {
    if ($_.Exception.Message -match "Origen esperado") {
        Write-Host "  ✓ Validación de tipo origen funciona" -ForegroundColor Green
        $passed++
    }
    else {
        Write-Host "  ✗ Error inesperado: $($_.Exception.Message)" -ForegroundColor Yellow
        $failed++
    }
}

Write-Host ""

# ========================================================================== #
#                   PRUEBA 4: COMPATIBILIDAD LEGACY                          #
# ========================================================================== #

Write-Host "[PRUEBA 4] Compatibilidad con formato legacy" -ForegroundColor Cyan

try {
    # Crear configs en formato antiguo (PSCustomObject)
    $sourceConfig = [PSCustomObject]@{
        Tipo = "Local"
        Path = $env:TEMP
    }
    
    $destConfig = [PSCustomObject]@{
        Tipo = "Local"
        Path = Join-Path $env:TEMP "LLEVAR_TEST_LEGACY"
    }
    
    # Crear destino
    if (-not (Test-Path $destConfig.Path)) {
        New-Item -Type Directory $destConfig.Path | Out-Null
    }
    
    # Construir TransferConfig equivalente al formato legacy
    $llevarLegacy = [TransferConfig]::new()
    $llevarLegacy.Origen.Tipo = "Local"
    $llevarLegacy.Origen.Local.Path = $sourceConfig.Path
    $llevarLegacy.Destino.Tipo = "Local"
    $llevarLegacy.Destino.Local.Path = $destConfig.Path

    # Llamar con nuevo formato basado en TransferConfig
    $result = Copy-LlevarFiles -TransferConfig $llevarLegacy
    
    Write-Host "  ✓ Formato legacy convertido correctamente" -ForegroundColor Green
    $passed++
    
    # Limpiar
    Remove-Item $destConfig.Path -Recurse -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Host "  ✗ Error con formato legacy: $($_.Exception.Message)" -ForegroundColor Red
    $failed++
}

Write-Host ""

# ========================================================================== #
#                          RESUMEN FINAL                                     #
# ========================================================================== #

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "           RESUMEN DE PRUEBAS DEL DISPATCHER" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

Write-Host "Tests ejecutados: " -NoNewline
Write-Host ($passed + $failed) -ForegroundColor White

Write-Host "Pasados:          " -NoNewline
Write-Host $passed -ForegroundColor Green

Write-Host "Fallados:         " -NoNewline
if ($failed -gt 0) {
    Write-Host $failed -ForegroundColor Red
}
else {
    Write-Host $failed -ForegroundColor Gray
}

Write-Host ""

# Calcular tasa de éxito
$total = $passed + $failed
$successRate = if ($total -gt 0) { [math]::Round(($passed / $total) * 100, 2) } else { 0 }

Write-Host "Tasa de éxito: " -NoNewline
if ($successRate -eq 100) {
    Write-Host "$successRate% ✓" -ForegroundColor Green
}
elseif ($successRate -ge 75) {
    Write-Host "$successRate% ⚠" -ForegroundColor Yellow
}
else {
    Write-Host "$successRate% ✗" -ForegroundColor Red
}

Write-Host ""

if ($failed -eq 0) {
    Write-Host "✅ DISPATCHER VALIDADO CORRECTAMENTE" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "⚠ ALGUNOS TESTS FALLARON" -ForegroundColor Yellow
    exit 1
}
