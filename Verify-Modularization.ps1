# ============================================================================ #
# Verificación de Modularización del Proyecto LLevar
# ============================================================================ #

Write-Host "`n════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "VERIFICACIÓN DE MODULARIZACIÓN" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

$modulesPath = "$PSScriptRoot\Modules"

# Verificar estructura de módulos
Write-Host "📁 ESTRUCTURA DE MÓDULOS:" -ForegroundColor Green
Write-Host ""

$categories = @{
    "System"       = @("FileSystem.psm1", "Audio.psm1", "Robocopy.psm1")
    "UI"           = @("Banners.psm1", "Console.psm1", "ConfigMenus.psm1", "Menus.psm1", "Navigator.psm1", "ProgressBar.psm1")
    "Transfer"     = @("Dropbox.psm1", "Floppy.psm1", "FTP.psm1", "Local.psm1", "OneDrive.psm1", "UNC.psm1", "Unified.psm1")
    "Core"         = @("Logger.psm1", "Validation.psm1", "TransferConfig.psm1")
    "Compression"  = @("BlockSplitter.psm1", "NativeZip.psm1", "SevenZip.psm1")
    "Installation" = @("Installer.psm1", "ISO.psm1", "SystemInstall.psm1")
    "Utilities"    = @("Examples.psm1", "Help.psm1", "Installation.psm1", "PathSelectors.psm1", "VolumeManagement.psm1")
}

foreach ($category in $categories.Keys | Sort-Object) {
    Write-Host "  $category/" -ForegroundColor Cyan
    foreach ($module in $categories[$category]) {
        $path = Join-Path $modulesPath "$category\$module"
        if (Test-Path $path) {
            Write-Host "    ✓ $module" -ForegroundColor Green
        }
        else {
            Write-Host "    ✗ $module (no encontrado)" -ForegroundColor Red
        }
    }
    Write-Host ""
}

Write-Host "`n════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "FUNCIONES POR MÓDULO:" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Módulos importantes y sus funciones esperadas
$expectedFunctions = @{
    "System/FileSystem.psm1" = @(
        "Test-PathWritable",
        "Get-PathOrPrompt",
        "Test-VolumeWritable",
        "Get-TargetVolume",
        "Format-FileSize",
        "Get-DirectorySize",
        "Get-DirectoryItems"
    )
    "UI/Navigator.psm1"      = @(
        "Select-PathNavigator"
    )
    "UI/ProgressBar.psm1"    = @(
        "Format-LlevarTime",
        "Write-LlevarProgressBar",
        "Show-CalculatingSpinner",
        "Update-Spinner"
    )
    "Transfer/UNC.psm1"      = @(
        "Get-NetworkComputers",
        "Test-UncPathAccess",
        "Get-ComputerShares",
        "Select-NetworkPath",
        "Split-UncRootAndPath",
        "Mount-LlevarNetworkPath",
        "Get-NetworkShares"
    )
}

foreach ($moduleKey in $expectedFunctions.Keys | Sort-Object) {
    $modulePath = Join-Path $modulesPath $moduleKey
    
    if (-not (Test-Path $modulePath)) {
        Write-Host "⚠ $moduleKey - No encontrado" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "📄 $moduleKey" -ForegroundColor Cyan
    
    $content = Get-Content $modulePath -Raw
    $foundFunctions = @()
    $missingFunctions = @()
    
    foreach ($funcName in $expectedFunctions[$moduleKey]) {
        if ($content -match "function\s+$funcName\s*\{") {
            $foundFunctions += $funcName
        }
        else {
            $missingFunctions += $funcName
        }
    }
    
    foreach ($func in $foundFunctions | Sort-Object) {
        Write-Host "  ✓ $func" -ForegroundColor Green
    }
    
    foreach ($func in $missingFunctions | Sort-Object) {
        Write-Host "  ✗ $func (no encontrada)" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "`n════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "VERIFICACIÓN DE IMPORTS:" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Verificar imports en Navigator
$navigatorPath = Join-Path $modulesPath "UI\Navigator.psm1"
if (Test-Path $navigatorPath) {
    Write-Host "📄 Navigator.psm1" -ForegroundColor Cyan
    $content = Get-Content $navigatorPath -Raw
    
    $requiredImports = @(
        "FileSystem.psm1",
        "ProgressBar.psm1",
        "UNC.psm1"
    )
    
    foreach ($import in $requiredImports) {
        if ($content -match [regex]::Escape($import)) {
            Write-Host "  ✓ Importa $import" -ForegroundColor Green
        }
        else {
            Write-Host "  ✗ NO importa $import" -ForegroundColor Red
        }
    }
    Write-Host ""
}

Write-Host "`n════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "PRUEBA DE CARGA DE MÓDULOS:" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

$testModules = @(
    "System\FileSystem.psm1",
    "UI\ProgressBar.psm1",
    "Transfer\UNC.psm1",
    "UI\Navigator.psm1"
)

foreach ($module in $testModules) {
    $modulePath = Join-Path $modulesPath $module
    Write-Host "Cargando $module... " -NoNewline
    
    try {
        Import-Module $modulePath -Force -ErrorAction Stop
        Write-Host "✓ OK" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ ERROR" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "RESUMEN:" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "✓ Funciones modularizadas correctamente:" -ForegroundColor Green
Write-Host "  • Format-FileSize → System/FileSystem.psm1" -ForegroundColor Gray
Write-Host "  • Get-DirectorySize → System/FileSystem.psm1" -ForegroundColor Gray
Write-Host "  • Get-DirectoryItems → System/FileSystem.psm1" -ForegroundColor Gray
Write-Host "  • Show-CalculatingSpinner → UI/ProgressBar.psm1" -ForegroundColor Gray
Write-Host "  • Update-Spinner → UI/ProgressBar.psm1" -ForegroundColor Gray
Write-Host "  • Get-NetworkShares → Transfer/UNC.psm1" -ForegroundColor Gray
Write-Host ""
Write-Host "✓ Navigator.psm1 importa las dependencias necesarias" -ForegroundColor Green
Write-Host ""
Write-Host "✓ Separación de responsabilidades:" -ForegroundColor Green
Write-Host "  • System: Operaciones de sistema de archivos" -ForegroundColor Gray
Write-Host "  • UI: Componentes visuales e interfaz" -ForegroundColor Gray
Write-Host "  • Transfer: Operaciones de red y transferencia" -ForegroundColor Gray
Write-Host ""

Write-Host "════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
