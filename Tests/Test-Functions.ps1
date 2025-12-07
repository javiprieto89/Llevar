<#
.SYNOPSIS
    Suite de tests para las funciones de Llevar.ps1

.DESCRIPTION
    Tests unitarios para cada función del sistema LLEVAR.
    Incluye simulación de dispositivos USB, compresión, y transferencia.
#>

# Importar todos los módulos de Llevar
. (Join-Path $PSScriptRoot "Import-LlevarModules.ps1")

# ==========================================
#  TESTS UNITARIOS
# ==========================================
$parentProcess = (Get-Process -Id $PID).Parent
if ($parentProcess) {
    $parentName = $parentProcess.ProcessName
    if ($parentName -match 'code|devenv|rider|powershell_ise') {
        return $true
    }
}
}
catch {
    # Ignorar errores
}
    
return $false
}

# ==========================================
#  COLORES Y HELPERS
# ==========================================

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    if ($Passed) {
        Write-Host "✓ PASS: " -ForegroundColor Green -NoNewline
        Write-Host "$TestName" -ForegroundColor White
        if ($Message) {
            Write-Host "  → $Message" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "✗ FAIL: " -ForegroundColor Red -NoNewline
        Write-Host "$TestName" -ForegroundColor White
        if ($Message) {
            Write-Host "  → $Message" -ForegroundColor Yellow
        }
    }
}

function Write-TestHeader {
    param([string]$Header)
    
    Show-Banner "$Header" -BorderColor Cyan -TextColor Yellow
}

# ==========================================
#  VARIABLES GLOBALES DE TEST
# ==========================================

$script:TestResults = @{
    Passed = 0
    Failed = 0
    Total  = 0
}

# ==========================================
#  TEST: Format-LlevarBytes
# ==========================================

function Test-FormatBytes {
    Write-TestHeader "TEST: Format-LlevarBytes"
    
    # Test 1: Bytes
    $result = Format-LlevarBytes 512
    $script:TestResults.Total++
    if ($result -eq "512 B") {
        $script:TestResults.Passed++
        Write-TestResult "512 bytes" $true $result
    }
    else {
        $script:TestResults.Failed++
        Write-TestResult "512 bytes" $false "Esperado: 512 B, Obtenido: $result"
    }
    
    # Test 2: KB
    $result = Format-LlevarBytes 2048
    $script:TestResults.Total++
    if ($result -eq "2.00 KB") {
        $script:TestResults.Passed++
        Write-TestResult "2048 bytes (2 KB)" $true $result
    }
    else {
        $script:TestResults.Failed++
        Write-TestResult "2048 bytes (2 KB)" $false "Esperado: 2.00 KB, Obtenido: $result"
    }
    
    # Test 3: MB
    $result = Format-LlevarBytes (10 * 1024 * 1024)
    $script:TestResults.Total++
    if ($result -eq "10.00 MB") {
        $script:TestResults.Passed++
        Write-TestResult "10 MB" $true $result
    }
    else {
        $script:TestResults.Failed++
        Write-TestResult "10 MB" $false "Esperado: 10.00 MB, Obtenido: $result"
    }
    
    # Test 4: GB
    $result = Format-LlevarBytes (5L * 1024 * 1024 * 1024)
    $script:TestResults.Total++
    if ($result -eq "5.00 GB") {
        $script:TestResults.Passed++
        Write-TestResult "5 GB" $true $result
    }
    else {
        $script:TestResults.Failed++
        Write-TestResult "5 GB" $false "Esperado: 5.00 GB, Obtenido: $result"
    }
}

# ==========================================
#  TEST: Format-LlevarTime
# ==========================================

function Test-FormatTime {
    Write-TestHeader "TEST: Format-LlevarTime"
    
    # Test 1: Segundos
    $result = Format-LlevarTime 45
    $script:TestResults.Total++
    if ($result -eq "45s") {
        $script:TestResults.Passed++
        Write-TestResult "45 segundos" $true $result
    }
    else {
        $script:TestResults.Failed++
        Write-TestResult "45 segundos" $false "Esperado: 45s, Obtenido: $result"
    }
    
    # Test 2: Minutos y segundos
    $result = Format-LlevarTime 125
    $script:TestResults.Total++
    if ($result -eq "2m 5s") {
        $script:TestResults.Passed++
        Write-TestResult "125 segundos (2m 5s)" $true $result
    }
    else {
        $script:TestResults.Failed++
        Write-TestResult "125 segundos" $false "Esperado: 2m 5s, Obtenido: $result"
    }
    
    # Test 3: Horas, minutos y segundos
    $result = Format-LlevarTime 3665
    $script:TestResults.Total++
    if ($result -eq "1h 1m 5s") {
        $script:TestResults.Passed++
        Write-TestResult "3665 segundos (1h 1m 5s)" $true $result
    }
    else {
        $script:TestResults.Failed++
        Write-TestResult "3665 segundos" $false "Esperado: 1h 1m 5s, Obtenido: $result"
    }
}

# ==========================================
#  TEST: Test-Windows10OrLater
# ==========================================

function Test-Windows10Check {
    Write-TestHeader "TEST: Test-Windows10OrLater"
    
    try {
        $result = Test-Windows10OrLater
        $osVersion = [System.Environment]::OSVersion.Version
        
        $script:TestResults.Total++
        if ($result -is [bool]) {
            $script:TestResults.Passed++
            Write-TestResult "Detección de Windows 10+" $true "Resultado: $result (OS: $osVersion)"
        }
        else {
            $script:TestResults.Failed++
            Write-TestResult "Detección de Windows 10+" $false "No retornó booleano"
        }
    }
    catch {
        $script:TestResults.Total++
        $script:TestResults.Failed++
        Write-TestResult "Detección de Windows 10+" $false $_.Exception.Message
    }
}

# ==========================================
#  TEST: Test-IsFtpPath
# ==========================================

function Test-FtpPathDetection {
    Write-TestHeader "TEST: Test-IsFtpPath"
    
    # Test 1: FTP path válido
    $result = Test-IsFtpPath -Path "ftp://servidor.com/carpeta"
    $script:TestResults.Total++
    if ($result -eq $true) {
        $script:TestResults.Passed++
        Write-TestResult "Detectar FTP path" $true "ftp://servidor.com/carpeta"
    }
    else {
        $script:TestResults.Failed++
        Write-TestResult "Detectar FTP path" $false "No detectó FTP path válido"
    }
    
    # Test 2: FTPS path válido
    $result = Test-IsFtpPath -Path "ftps://servidor.com/carpeta"
    $script:TestResults.Total++
    if ($result -eq $true) {
        $script:TestResults.Passed++
        Write-TestResult "Detectar FTPS path" $true "ftps://servidor.com/carpeta"
    }
    else {
        $script:TestResults.Failed++
        Write-TestResult "Detectar FTPS path" $false "No detectó FTPS path válido"
    }
    
    # Test 3: Path local (no FTP)
    $result = Test-IsFtpPath -Path "C:\carpeta"
    $script:TestResults.Total++
    if ($result -eq $false) {
        $script:TestResults.Passed++
        Write-TestResult "Rechazar path local" $true "C:\carpeta no es FTP"
    }
    else {
        $script:TestResults.Failed++
        Write-TestResult "Rechazar path local" $false "Detectó incorrectamente como FTP"
    }
    
    # Test 4: Path UNC (no FTP)
    $result = Test-IsFtpPath -Path "\\servidor\carpeta"
    $script:TestResults.Total++
    if ($result -eq $false) {
        $script:TestResults.Passed++
        Write-TestResult "Rechazar path UNC" $true "\\servidor\carpeta no es FTP"
    }
    else {
        $script:TestResults.Failed++
        Write-TestResult "Rechazar path UNC" $false "Detectó incorrectamente como FTP"
    }
}

# ==========================================
#  TEST: Test-IsRunningInIDE
# ==========================================

function Test-IDEDetection {
    Write-TestHeader "TEST: Test-IsRunningInIDE"
    
    try {
        $result = Test-IsRunningInIDE
        $hostName = $host.Name
        
        $script:TestResults.Total++
        if ($result -is [bool]) {
            $script:TestResults.Passed++
            Write-TestResult "Detección de IDE" $true "Resultado: $result (Host: $hostName)"
        }
        else {
            $script:TestResults.Failed++
            Write-TestResult "Detección de IDE" $false "No retornó booleano"
        }
    }
    catch {
        $script:TestResults.Total++
        $script:TestResults.Failed++
        Write-TestResult "Detección de IDE" $false $_.Exception.Message
    }
}

# ==========================================
#  TEST FINAL SUMMARY
# ==========================================

function Show-TestSummary {
    Write-Host "`n"
    Show-Banner "RESUMEN DE TESTS" -BorderColor Cyan -TextColor Yellow
    Write-Host "Total de tests: " -NoNewline
    Write-Host "$($script:TestResults.Total)" -ForegroundColor White
    
    Write-Host "Pasados:        " -NoNewline
    Write-Host "$($script:TestResults.Passed)" -ForegroundColor Green
    
    Write-Host "Fallados:       " -NoNewline
    Write-Host "$($script:TestResults.Failed)" -ForegroundColor Red
    
    $percentage = if ($script:TestResults.Total -gt 0) {
        [math]::Round(($script:TestResults.Passed / $script:TestResults.Total) * 100, 2)
    }
    else { 0 }
    
    Write-Host "Tasa de éxito:  " -NoNewline
    if ($percentage -ge 90) {
        Write-Host "$percentage%" -ForegroundColor Green
    }
    elseif ($percentage -ge 70) {
        Write-Host "$percentage%" -ForegroundColor Yellow
    }
    else {
        Write-Host "$percentage%" -ForegroundColor Red
    }
    
    Write-Host ""
}

# ==========================================
#  EJECUTAR TODOS LOS TESTS
# ==========================================

function Invoke-AllTests {
    Show-Banner "SUITE DE TESTS - LLEVAR.PS1" -BorderColor Cyan -TextColor Yellow
    
    # Ejecutar tests de funciones utilitarias
    Test-FormatBytes
    Test-FormatTime
    Test-Windows10Check
    Test-FtpPathDetection
    Test-IDEDetection
    
    # Mostrar resumen
    Show-TestSummary
    
    # Retornar código de salida
    if ($script:TestResults.Failed -eq 0) {
        return 0
    }
    else {
        return 1
    }
}

# Ejecutar si se llama directamente
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Invoke-AllTests
    exit $exitCode
}
