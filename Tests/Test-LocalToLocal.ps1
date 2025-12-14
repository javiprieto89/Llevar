<#
.SYNOPSIS
    Test individual: Local → Local

.DESCRIPTION
    Prueba transferencia desde carpeta local a otra carpeta local.
    Genera datos de prueba pequeños y ejecuta la transferencia.

.EXAMPLE
    .\Test-LocalToLocal.ps1
#>

param(
    [string]$LlevarPath = "..\Llevar.ps1"
)

# Importar módulos necesarios
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$ModulesPath = Join-Path $ProjectRoot "Modules"

# Importar TransferConfig explícitamente
Import-Module (Join-Path $ModulesPath "Core\TransferConfig.psm1") -Force -Global

# Importar todos los módulos de Llevar
. (Join-Path $ProjectRoot "Import-LlevarModules.ps1")

Show-Banner "TEST: Local → Local" -BorderColor Cyan -TextColor Yellow

# Verificar Llevar.ps1
$llevarScript = Join-Path $PSScriptRoot $LlevarPath
if (-not (Test-Path $llevarScript)) {
    Write-Host "✗ No se encuentra Llevar.ps1 en: $llevarScript" -ForegroundColor Red
    exit 1
}

# Crear directorio de origen con datos de prueba
$testSourcePath = Join-Path $env:TEMP "LLEVAR_TEST_LOCAL_SOURCE"
if (Test-Path $testSourcePath) {
    Remove-Item $testSourcePath -Recurse -Force
}
New-Item -ItemType Directory -Path $testSourcePath -Force | Out-Null

Write-Host "Generando datos de prueba..." -ForegroundColor Cyan

# Crear estructura de carpetas y archivos
New-Item -ItemType Directory -Path (Join-Path $testSourcePath "Documentos") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $testSourcePath "Imagenes") -Force | Out-Null

# Generar algunos archivos de texto
@(
    "documento1.txt"
    "documento2.txt"
    "readme.md"
) | ForEach-Object {
    $content = "Archivo de prueba: $_`nFecha: $(Get-Date)`nContenido de prueba para validar transferencia Local → Local"
    $filePath = Join-Path $testSourcePath "Documentos\$_"
    Set-Content -Path $filePath -Value $content
}

# Generar archivos binarios pequeños (5MB cada uno)
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$buffer = New-Object byte[] (5 * 1024 * 1024)

for ($i = 1; $i -le 3; $i++) {
    $fileName = "imagen{0:D2}.bin" -f $i
    $filePath = Join-Path $testSourcePath "Imagenes\$fileName"
    $rng.GetBytes($buffer)
    [System.IO.File]::WriteAllBytes($filePath, $buffer)
}
$rng.Dispose()

# Calcular tamaño total
$archivos = Get-ChildItem -Path $testSourcePath -File -Recurse
$tamañoTotal = ($archivos | Measure-Object -Property Length -Sum).Sum
Write-Host ("✓ Datos generados: {0} archivos, {1:N2} MB total" -f $archivos.Count, ($tamañoTotal / 1MB)) -ForegroundColor Green
Write-Host ""

# Crear directorio de destino
$testDestinationPath = Join-Path $env:TEMP "LLEVAR_TEST_LOCAL_DESTINATION"
if (Test-Path $testDestinationPath) {
    Remove-Item $testDestinationPath -Recurse -Force
}
New-Item -ItemType Directory -Path $testDestinationPath -Force | Out-Null

Write-Host "Origen: $testSourcePath" -ForegroundColor Cyan
Write-Host "Destino: $testDestinationPath" -ForegroundColor Cyan
Write-Host ""

# Configurar TransferConfig usando las funciones del módulo
Write-Host "Configurando transferencia..." -ForegroundColor Cyan

$config = New-TransferConfig

# Configurar origen Local
Set-TransferConfigValue -Config $config -Path "Origen.Tipo" -Value "Local"
Set-TransferConfigValue -Config $config -Path "Origen.Local.Path" -Value $testSourcePath
Set-TransferConfigValue -Config $config -Path "OrigenIsSet" -Value $true

# Configurar destino Local
Set-TransferConfigValue -Config $config -Path "Destino.Tipo" -Value "Local"
Set-TransferConfigValue -Config $config -Path "Destino.Local.Path" -Value $testDestinationPath
Set-TransferConfigValue -Config $config -Path "DestinoIsSet" -Value $true

# Configurar opciones
Set-TransferConfigValue -Config $config -Path "Opciones.BlockSizeMB" -Value 100
Set-TransferConfigValue -Config $config -Path "Opciones.UseNativeZip" -Value $false

Write-Host "✓ Configuración creada" -ForegroundColor Green
Write-Host ""

# Ejecutar transferencia
try {
    Write-Host "Iniciando transferencia..." -ForegroundColor Yellow
    Write-Host ("=" * 80) -ForegroundColor Gray
    
    $startTime = Get-Date
    
    # Invocar modo normal directamente con el objeto config
    Invoke-NormalMode -TransferConfig $config
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host ""
    
    # Verificar resultados
    Show-Banner "VERIFICACIÓN DE RESULTADOS" -BorderColor Green -TextColor Yellow
    
    if (Test-Path $testDestinationPath) {
        $destinoArchivos = Get-ChildItem -Path $testDestinationPath -File -Recurse
        
        if ($destinoArchivos) {
            $destinoSize = ($destinoArchivos | Measure-Object -Property Length -Sum).Sum
            
            Write-Host "✓ Transferencia completada exitosamente" -ForegroundColor Green
            Write-Host "  Tiempo: $($duration.TotalSeconds) segundos" -ForegroundColor Cyan
            Write-Host "  Archivos en destino: $($destinoArchivos.Count)" -ForegroundColor Cyan
            Write-Host "  Tamaño destino: $([math]::Round($destinoSize / 1MB, 2)) MB" -ForegroundColor Cyan
            
            # Comparar tamaños
            $origenSize = ($archivos | Measure-Object -Property Length -Sum).Sum
            if ($destinoSize -eq $origenSize) {
                Write-Host "  ✓ Tamaño coincide con origen" -ForegroundColor Green
            }
            else {
                Write-Host "  ⚠ Tamaño difiere del origen (Origen: $([math]::Round($origenSize / 1MB, 2)) MB)" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "✗ No se encontraron archivos en el destino" -ForegroundColor Red
        }
    }
    else {
        Write-Host "✗ El directorio de destino no existe" -ForegroundColor Red
    }
    
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "✗ Error durante la transferencia:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "StackTrace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 1
}
finally {
    # Limpiar archivos de prueba
    Write-Host "Limpiando archivos de prueba..." -ForegroundColor Gray
    
    if (Test-Path $testSourcePath) {
        Remove-Item $testSourcePath -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $testDestinationPath) {
        # Comentar esta línea si quieres inspeccionar el resultado
        # Remove-Item $testDestinationPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "✓ Test completado" -ForegroundColor Green
}
