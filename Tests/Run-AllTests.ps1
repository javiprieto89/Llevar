<#
.SYNOPSIS
    Runner principal para ejecutar todos los tests de Llevar.ps1

.DESCRIPTION
    Script master que ejecuta todos los tests disponibles:
    - Tests unitarios de funciones
    - Tests de simulación de USBs
    - Tests de integración end-to-end
    
.EXAMPLE
    .\Run-AllTests.ps1
    Ejecuta todos los tests
    
.EXAMPLE
    .\Run-AllTests.ps1 -TestType Unit
    Ejecuta solo tests unitarios
    
.EXAMPLE
    .\Run-AllTests.ps1 -TestType Integration
    Ejecuta solo tests de integración
    
.EXAMPLE
    .\Run-AllTests.ps1 -Verbose
    Ejecuta con salida detallada
#>

param(
    [ValidateSet('All', 'Unit', 'USB', 'Integration', 'LocalToFTP', 'FTPToLocal', 'LocalToISO', 'LocalToUSB', 'FTPToFTP', 'Scenarios', 'OneDrive', 'Dropbox', 'Robocopy')]
    [string]$TestType = 'All',
    
    [switch]$NoPause,
    
    [switch]$CleanupAfter,
    
    [switch]$Integration
)

# Importar módulos de Llevar para tests
. (Join-Path $PSScriptRoot "Import-LlevarModules.ps1")

# ==========================================
#  CONFIGURACIÓN
# ==========================================

$ErrorActionPreference = 'Continue'
$testScriptPath = $PSScriptRoot

# ==========================================
#  FUNCIONES HELPER
# ==========================================

function Write-TestBanner {
    param([string]$Message)
    
    $line = "═" * 55
    Write-Host ""
    Write-Host "╔$line╗" -ForegroundColor Cyan
    Write-Host "║" -ForegroundColor Cyan -NoNewline
    Write-Host ("{0,-55}" -f "  $Message") -ForegroundColor Yellow -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "╚$line╝" -ForegroundColor Cyan
}

function Write-TestSection {
    param([string]$Section)
    Write-Host "`n$Section" -ForegroundColor Cyan
    Write-Host ("─" * $Section.Length) -ForegroundColor Cyan
}

# ==========================================
#  TESTS DISPONIBLES
# ==========================================

$availableTests = @{
    Unit        = @{
        Name        = "Tests Unitarios de Funciones"
        Script      = "Test-Functions.ps1"
        Description = "Prueba funciones individuales: Format-LlevarBytes, Format-LlevarTime, Test-IsFtpPath, etc."
    }
    USB         = @{
        Name        = "Simulación de Dispositivos USB"
        Script      = "Mock-USBDevices.ps1"
        Description = "Crea y prueba dispositivos USB virtuales con diferentes capacidades"
    }
    Integration = @{
        Name        = "Tests de Integración End-to-End"
        Script      = "Test-Integration.ps1"
        Description = "Prueba el flujo completo: compresión → división → distribución en USBs"
    }
    OneDrive    = @{
        Name        = "Tests de OneDrive"
        Script      = "Test-OneDrive.ps1"
        Description = "Valida integración con OneDrive: detección de rutas, módulos Graph, upload/download"
    }
    Dropbox     = @{
        Name        = "Tests de Dropbox"
        Script      = "Test-Dropbox.ps1"
        Description = "Valida integración con Dropbox: OAuth2, detección de rutas, upload/download"
    }
    Robocopy    = @{
        Name        = "Tests de Robocopy Mirror"
        Script      = "Test-Robocopy.ps1"
        Description = "Valida modo de copia espejo: detección Robocopy, parámetros, códigos de salida"
    }
    LocalToFTP  = @{
        Name        = "Test Local → FTP"
        Script      = "Test-LocalToFTP.ps1"
        Description = "Genera 1GB de datos y transfiere desde carpeta local a servidor FTP"
    }
    FTPToLocal  = @{
        Name        = "Test FTP → Local"
        Script      = "Test-FTPToLocal.ps1"
        Description = "Descarga datos desde servidor FTP a carpeta local"
    }
    LocalToISO  = @{
        Name        = "Test Local → ISO"
        Script      = "Test-LocalToISO.ps1"
        Description = "Genera 1GB de datos y crea archivo ISO"
    }
    LocalToUSB  = @{
        Name        = "Test Local → USB"
        Script      = "Test-LocalToUSB.ps1"
        Description = "Genera 1GB de datos y transfiere a dispositivo USB"
    }
    FTPToFTP    = @{
        Name        = "Test FTP → FTP"
        Script      = "Test-FTPToFTP.ps1"
        Description = "Transfiere datos entre dos servidores FTP"
    }
}

# ==========================================
#  FUNCIÓN PRINCIPAL
# ==========================================

function Invoke-TestRunner {
    param([string]$Type)
    
    Write-TestBanner "LLEVAR.PS1 - SUITE DE TESTS"
    
    Write-Host ""
    Write-Host "Directorio de tests: " -NoNewline
    Write-Host $testScriptPath -ForegroundColor White
    Write-Host "Tipo de test:        " -NoNewline
    Write-Host $Type -ForegroundColor White
    Write-Host "Fecha/Hora:          " -NoNewline
    Write-Host (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -ForegroundColor White
    Write-Host ""
    
    $results = @{
        Total   = 0
        Passed  = 0
        Failed  = 0
        Skipped = 0
    }
    
    $testsToRun = @()
    
    # Determinar qué tests ejecutar
    if ($Type -eq 'All') {
        $testsToRun = @('Unit', 'USB', 'Integration', 'OneDrive', 'Dropbox', 'Robocopy')
    }
    elseif ($Type -eq 'Scenarios') {
        $testsToRun = @('LocalToFTP', 'FTPToLocal', 'LocalToISO', 'LocalToUSB', 'FTPToFTP')
    }
    else {
        $testsToRun = @($Type)
    }
    
    # Ejecutar cada test
    foreach ($testKey in $testsToRun) {
        $testInfo = $availableTests[$testKey]
        $testScriptFullPath = Join-Path $testScriptPath $testInfo.Script
        
        Write-TestSection $testInfo.Name
        Write-Host $testInfo.Description -ForegroundColor Gray
        Write-Host ""
        
        if (Test-Path $testScriptFullPath) {
            Write-Host "Ejecutando: $($testInfo.Script)" -ForegroundColor Cyan
            Write-Host ""
            
            try {
                # Ejecutar el script de test con parámetro -Integration si está habilitado
                $scriptParams = @{}
                if ($Integration) {
                    $scriptParams['Integration'] = $true
                }
                
                $exitCode = & $testScriptFullPath @scriptParams
                
                $results.Total++
                if ($exitCode -eq 0) {
                    $results.Passed++
                    Write-Host "`n✓ Test suite completado exitosamente" -ForegroundColor Green
                }
                else {
                    $results.Failed++
                    Write-Host "`n✗ Test suite falló con código: $exitCode" -ForegroundColor Red
                    Show-Banner "INFORMACIÓN DE DEBUG" -BorderColor Yellow -TextColor Yellow
                    Write-Host "Script ejecutado: $testScriptFullPath" -ForegroundColor White
                    Write-Host "Código de salida: $exitCode" -ForegroundColor White
                    Write-Host "Test suite:       $($testInfo.Name)" -ForegroundColor White
                    Write-Host ""
                    Write-Host "Presione ENTER para continuar o ESC para abortar..." -ForegroundColor Cyan
                    
                    # Esperar por tecla
                    do {
                        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                        if ($key.VirtualKeyCode -eq 27) {
                            # ESC
                            Write-Host ""
                            Write-Host "Tests abortados por el usuario" -ForegroundColor Yellow
                            Write-Host ""
                            exit 1
                        }
                    } while ($key.VirtualKeyCode -ne 13)  # ENTER
                    
                    Write-Host ""
                }
            }
            catch {
                $results.Total++
                $results.Failed++
                Write-Host "`n✗ Error al ejecutar test: $($_.Exception.Message)" -ForegroundColor Red
                Show-Banner "ERROR CRÍTICO EN EJECUCIÓN" -BorderColor Red -TextColor Red
                Write-Host "Script:         $testScriptFullPath" -ForegroundColor White
                Write-Host "Mensaje:        $($_.Exception.Message)" -ForegroundColor White
                Write-Host "Línea:          $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor White
                Write-Host "Stack trace:" -ForegroundColor Yellow
                Write-Host "$($_.ScriptStackTrace)" -ForegroundColor Gray
                Write-Host ""
                Write-Host "Presione ENTER para continuar o ESC para abortar..." -ForegroundColor Cyan
                
                # Esperar por tecla
                do {
                    $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                    if ($key.VirtualKeyCode -eq 27) {
                        # ESC
                        Write-Host ""
                        Write-Host "Tests abortados por el usuario" -ForegroundColor Yellow
                        Write-Host ""
                        exit 1
                    }
                } while ($key.VirtualKeyCode -ne 13)  # ENTER
                
                Write-Host ""
            }
        }
        else {
            Write-Host "⚠ Script no encontrado: $testScriptFullPath" -ForegroundColor Yellow
            $results.Total++
            $results.Skipped++
        }
        
        Write-Host ""
    }
    
    # ==========================================
    #  RESUMEN FINAL
    # ==========================================
    
    Write-TestBanner "RESUMEN FINAL DE TESTS"
    
    Write-Host ""
    Write-Host "Test Suites Ejecutadas: " -NoNewline
    Write-Host $results.Total -ForegroundColor White
    
    Write-Host "Pasadas:                " -NoNewline
    Write-Host $results.Passed -ForegroundColor Green
    
    Write-Host "Falladas:               " -NoNewline
    if ($results.Failed -gt 0) {
        Write-Host $results.Failed -ForegroundColor Red
    }
    else {
        Write-Host $results.Failed -ForegroundColor Gray
    }
    
    Write-Host "Omitidas:               " -NoNewline
    if ($results.Skipped -gt 0) {
        Write-Host $results.Skipped -ForegroundColor Yellow
    }
    else {
        Write-Host $results.Skipped -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Calcular porcentaje de éxito
    $successRate = 0
    if ($results.Total -gt 0) {
        $successRate = [math]::Round(($results.Passed / $results.Total) * 100, 2)
    }
    
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
    
    # Limpieza opcional
    if ($CleanupAfter) {
        Write-Host "Limpiando archivos temporales de tests..." -ForegroundColor Yellow
        
        $tempRoot = Join-Path $env:TEMP "LLEVAR_TEST_USB"
        if (Test-Path $tempRoot) {
            Remove-Item $tempRoot -Recurse -Force
            Write-Host "✓ USBs simulados limpiados" -ForegroundColor Green
        }
        
        $integrationRoot = Join-Path $env:TEMP "LLEVAR_INTEGRATION_TESTS"
        if (Test-Path $integrationRoot) {
            Remove-Item $integrationRoot -Recurse -Force
            Write-Host "✓ Tests de integración limpiados" -ForegroundColor Green
        }
        
        $llevarRoot = Join-Path $env:TEMP "LLEVAR_TEST_*"
        Get-Item $llevarRoot -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
        Write-Host "✓ Tests Llevar limpiados" -ForegroundColor Green
        
        Write-Host ""
    }
    
    # Información adicional
    Write-Host "Tests disponibles:" -ForegroundColor Cyan
    Write-Host "  .\Run-AllTests.ps1 -TestType Unit         # Solo tests unitarios" -ForegroundColor Gray
    Write-Host "  .\Run-AllTests.ps1 -TestType USB          # Solo simulación USB" -ForegroundColor Gray
    Write-Host "  .\Run-AllTests.ps1 -TestType Integration  # Solo integración" -ForegroundColor Gray
    Write-Host "  .\Run-AllTests.ps1 -TestType OneDrive     # Solo tests OneDrive" -ForegroundColor Gray
    Write-Host "  .\Run-AllTests.ps1 -TestType Dropbox      # Solo tests Dropbox" -ForegroundColor Gray
    Write-Host "  .\Run-AllTests.ps1 -TestType Robocopy     # Solo tests Robocopy" -ForegroundColor Gray
    Write-Host "  .\Run-AllTests.ps1 -TestType Scenarios    # Todos los escenarios individuales" -ForegroundColor Gray
    Write-Host "  .\Run-AllTests.ps1 -TestType All          # Todos los tests automáticos" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Tests con integración real (requiere autenticación):" -ForegroundColor Yellow
    Write-Host "  .\Run-AllTests.ps1 -TestType OneDrive -Integration  # Tests OneDrive con autenticación" -ForegroundColor Gray
    Write-Host "  .\Run-AllTests.ps1 -TestType Dropbox -Integration   # Tests Dropbox con OAuth2" -ForegroundColor Gray
    Write-Host "  .\Run-AllTests.ps1 -Integration                     # Todos los tests con integración real" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Tests de escenarios individuales (interactivos):" -ForegroundColor Yellow
    Write-Host "  .\Tests\Test-LocalToFTP.ps1   # Local → FTP (genera 1GB)" -ForegroundColor Gray
    Write-Host "  .\Tests\Test-FTPToLocal.ps1   # FTP → Local (descarga)" -ForegroundColor Gray
    Write-Host "  .\Tests\Test-LocalToISO.ps1   # Local → ISO (genera 1GB)" -ForegroundColor Gray
    Write-Host "  .\Tests\Test-LocalToUSB.ps1   # Local → USB (genera 1GB)" -ForegroundColor Gray
    Write-Host "  .\Tests\Test-FTPToFTP.ps1     # FTP → FTP (transferencia)" -ForegroundColor Gray
    Write-Host ""
    
    # Retornar código de salida
    if ($results.Failed -eq 0) {
        return 0
    }
    else {
        return 1
    }
}

# ==========================================
#  EJECUTAR
# ==========================================

try {
    $exitCode = Invoke-TestRunner -Type $TestType
    
    if (-not $NoPause) {
        Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    
    exit $exitCode
}
catch {
    Write-Host "`n✗ Error crítico: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    
    if (-not $NoPause) {
        Write-Host "`nPresione cualquier tecla para salir..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    
    exit 1
}
