<#
.SYNOPSIS
    Test de compresión: Local → Local

.DESCRIPTION
    Prueba transferencia desde carpeta local a otra carpeta local CON COMPRESIÓN.
    Genera datos de prueba y ejecuta compresión + transferencia.

.EXAMPLE
    & 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File 'Tests\Test-LocalToLocal-Compression.ps1'
#>

# Importar módulos necesarios
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$ModulesPath = Join-Path $ProjectRoot "Modules"

# Importar módulos core
Import-Module (Join-Path $ModulesPath "Core\TransferConfig.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Core\Validation.psm1") -Force -Global

# Importar módulos UI
Import-Module (Join-Path $ModulesPath "UI\Banners.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "UI\ProgressBar.psm1") -Force -Global

# Importar módulos System
Import-Module (Join-Path $ModulesPath "System\FileSystem.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "System\Robocopy.psm1") -Force -Global

# Importar módulos Compression
Import-Module (Join-Path $ModulesPath "Compression\SevenZip.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Compression\NativeZip.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Compression\BlockSplitter.psm1") -Force -Global

# Importar módulos Transfer
Import-Module (Join-Path $ModulesPath "Transfer\Local.psm1") -Force -Global

Write-Host "✓ Módulos cargados para test de compresión" -ForegroundColor Green
Write-Host ""

Show-Banner "TEST: Local → Local (con Compresión)" -BorderColor Cyan -TextColor Yellow

# Crear directorio de origen con datos de prueba
$testSourcePath = Join-Path $env:TEMP "LLEVAR_TEST_COMPRESSION_SOURCE"
if (Test-Path $testSourcePath) {
    Remove-Item $testSourcePath -Recurse -Force
}
New-Item -ItemType Directory -Path $testSourcePath -Force | Out-Null

Write-Host "Generando datos de prueba..." -ForegroundColor Cyan

# Crear archivos de texto grandes
New-Item -ItemType Directory -Path "$testSourcePath\Documentos" -Force | Out-Null
1..50 | ForEach-Object {
    $content = "Este es un archivo de prueba número $_`n" * 5000
    $content | Set-Content "$testSourcePath\Documentos\documento$_.txt" -Encoding UTF8
}

# Crear archivos binarios grandes (datos ALEATORIOS para menor compresión)
New-Item -ItemType Directory -Path "$testSourcePath\Imagenes" -Force | Out-Null
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

for ($i = 1; $i -le 15; $i++) {
    # 15 archivos de 10MB cada uno = 150MB total
    # Datos aleatorios comprimen muy poco, el .7z será ~140MB
    $fileName = "imagen{0:D2}.bin" -f $i
    $filePath = Join-Path $testSourcePath "Imagenes\$fileName"
    $buffer = New-Object byte[] (10 * 1024 * 1024)
    $rng.GetBytes($buffer)
    [System.IO.File]::WriteAllBytes($filePath, $buffer)
    Write-Host "  Generando $fileName..." -ForegroundColor Gray -NoNewline
    Write-Host " ✓" -ForegroundColor Green
}
$rng.Dispose()

Write-Host ""

# Calcular tamaño total
$archivos = Get-ChildItem -Path $testSourcePath -File -Recurse
$tamañoTotal = ($archivos | Measure-Object -Property Length -Sum).Sum
Write-Host ("✓ Datos generados: {0} archivos, {1:N2} MB total" -f $archivos.Count, ($tamañoTotal / 1MB)) -ForegroundColor Green
Write-Host ""

# Crear directorio de destino
$testDestinationPath = Join-Path $env:TEMP "LLEVAR_TEST_COMPRESSION_DEST"
if (Test-Path $testDestinationPath) {
    Remove-Item $testDestinationPath -Recurse -Force
}
New-Item -ItemType Directory -Path $testDestinationPath -Force | Out-Null

Write-Host "Origen: $testSourcePath" -ForegroundColor Cyan
Write-Host "Destino: $testDestinationPath" -ForegroundColor Cyan
Write-Host ""

# Configurar TransferConfig
Write-Host "Configurando transferencia con compresión..." -ForegroundColor Cyan

$config = New-TransferConfig

# Configurar origen Local
Set-TransferConfigValue -Config $config -Path "Origen.Tipo" -Value "Local"
Set-TransferConfigValue -Config $config -Path "Origen.Local.Path" -Value $testSourcePath
Set-TransferConfigValue -Config $config -Path "OrigenIsSet" -Value $true

# Configurar destino Local
Set-TransferConfigValue -Config $config -Path "Destino.Tipo" -Value "Local"
Set-TransferConfigValue -Config $config -Path "Destino.Local.Path" -Value $testDestinationPath
Set-TransferConfigValue -Config $config -Path "DestinoIsSet" -Value $true

# Configurar opciones de COMPRESIÓN con división en bloques
Set-TransferConfigValue -Config $config -Path "Opciones.BlockSizeMB" -Value 10  # Bloques de 10MB
Set-TransferConfigValue -Config $config -Path "Opciones.UseNativeZip" -Value $false  # Usar 7-Zip
Set-TransferConfigValue -Config $config -Path "Opciones.TransferMode" -Value "Compress"  # ACTIVAR COMPRESIÓN

Write-Host "✓ Configuración creada (Modo: Compress, bloques de 10MB, 7-Zip)" -ForegroundColor Green
Write-Host ""

# Crear directorio temporal para compresión
$tempCompression = Join-Path $env:TEMP "LLEVAR_TEST_TEMP_COMPRESSION"
if (Test-Path $tempCompression) {
    Remove-Item $tempCompression -Recurse -Force
}
New-Item -ItemType Directory -Path $tempCompression -Force | Out-Null

# Ejecutar compresión
try {
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "FASE 1: Comprimir archivos" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    
    $startTime = Get-Date
    
    # Ejecutar 7-Zip directamente (no usar Compress-Folder para ver salida)
    $sevenZipPath = Join-Path $ProjectRoot "7za.exe"
    
    Write-Host "Comprimiendo con 7-Zip ($sevenZipPath)..." -ForegroundColor Cyan
    Write-Host "Comando: & '$sevenZipPath' a -t7z -mx=9 -v10m '$tempCompression\LLEVAR_TEST_COMPRESSION_SOURCE.7z' '$testSourcePath'" -ForegroundColor DarkGray
    Write-Host "" 
    
    # Ejecutar 7-Zip mostrando salida directamente
    & $sevenZipPath a -t7z -mx=9 -v10m "$tempCompression\LLEVAR_TEST_COMPRESSION_SOURCE.7z" "$testSourcePath"
    
    Write-Host ""
    Write-Host "Presione una tecla para continuar y verificar archivos generados..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
    
    # Verificar archivos generados
    Write-Host "Archivos generados en $tempCompression :" -ForegroundColor Cyan
    $filesGenerated = Get-ChildItem $tempCompression -ErrorAction SilentlyContinue
    if ($filesGenerated) {
        $filesGenerated | ForEach-Object { 
            Write-Host "  - $($_.Name)" -ForegroundColor Gray -NoNewline
            Write-Host " ($([math]::Round($_.Length/1MB, 2)) MB)" -ForegroundColor Cyan
        }
        $totalSize = ($filesGenerated | Measure-Object -Property Length -Sum).Sum
        Write-Host "  Total: $([math]::Round($totalSize/1MB, 2)) MB" -ForegroundColor Green
    }
    else {
        Write-Host "  (directorio vacío)" -ForegroundColor Red
    }
    Write-Host ""
    
    # Obtener archivos .7z generados
    $archivos7z = Get-ChildItem -Path $tempCompression -Filter "*.7z*" -File | Sort-Object Name
    
    if ($archivos7z -and $archivos7z.Count -gt 0) {
        $compressTime = (Get-Date) - $startTime
        Write-Host "✓ Compresión completada en $([math]::Round($compressTime.TotalSeconds, 2)) segundos" -ForegroundColor Green
        
        $totalComprimido = ($archivos7z | Measure-Object -Property Length -Sum).Sum
        Write-Host "  Archivos .7z generados: $($archivos7z.Count)" -ForegroundColor Cyan
        Write-Host "  Tamaño comprimido total: $([math]::Round($totalComprimido / 1MB, 2)) MB" -ForegroundColor Cyan
        Write-Host "  Ratio: $([math]::Round(($totalComprimido / $tamañoTotal) * 100, 1))%" -ForegroundColor Cyan
        Write-Host ""
        
        # FASE 2: Copiar archivos comprimidos al destino
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host "FASE 2: Copiar archivos comprimidos" -ForegroundColor Yellow
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host ""
        
        # Copiar con Robocopy
        $copyParams = @{
            SourcePath      = $tempCompression
            DestinationPath = $testDestinationPath
            ShowProgress    = $true
        }
    
        Copy-LlevarLocalToLocal @copyParams
        Write-Host ""
        
        # FASE 3: Verificar resultados
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host "FASE 3: Verificación" -ForegroundColor Yellow
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host ""
        
        if (Test-Path $testDestinationPath) {
            $destinoArchivos = Get-ChildItem -Path $testDestinationPath -Filter "*.7z*" -File
            
            if ($destinoArchivos) {
                $destinoSize = ($destinoArchivos | Measure-Object -Property Length -Sum).Sum
                
                Write-Host "✓ Transferencia exitosa" -ForegroundColor Green
                Write-Host "  Archivos en destino: $($destinoArchivos.Count)" -ForegroundColor Cyan
                Write-Host "  Tamaño destino: $([math]::Round($destinoSize / 1MB, 2)) MB" -ForegroundColor Cyan
                
                # Comparar tamaños comprimidos
                if ($destinoSize -eq $totalComprimido) {
                    Write-Host "✓ Verificación de integridad: OK (tamaños coinciden)" -ForegroundColor Green
                }
                else {
                    Write-Host "⚠ Advertencia: Tamaños no coinciden" -ForegroundColor Yellow
                    Write-Host "  Origen comprimido: $([math]::Round($totalComprimido / 1MB, 2)) MB" -ForegroundColor Yellow
                    Write-Host "  Destino: $([math]::Round($destinoSize / 1MB, 2)) MB" -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "✗ No se encontraron archivos comprimidos en el destino" -ForegroundColor Red
            }
        }
        else {
            Write-Host "✗ El directorio de destino no existe" -ForegroundColor Red
        }
    }
    else {
        Write-Host "✗ No se generaron archivos .7z" -ForegroundColor Red
    }
}
catch {
    Write-Host ""
    Write-Host "✗ Error durante el test: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Línea: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Gray
}
finally {
    Write-Host ""
    Write-Host "Presione una tecla para limpiar archivos de prueba..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
    Write-Host "Limpiando archivos de prueba..." -ForegroundColor Cyan
    
    # Limpiar origen
    if (Test-Path $testSourcePath) {
        Remove-Item $testSourcePath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Limpiar temporal de compresión
    if (Test-Path $tempCompression) {
        Remove-Item $tempCompression -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Dejar destino para inspección manual si se desea
    # if (Test-Path $testDestinationPath) {
    #     Remove-Item $testDestinationPath -Recurse -Force -ErrorAction SilentlyContinue
    # }
    
    Write-Host "✓ Test completado" -ForegroundColor Green
    Write-Host ""
    Write-Host "Nota: Los archivos comprimidos permanecen en:" -ForegroundColor Yellow
    Write-Host "  $testDestinationPath" -ForegroundColor Gray
    Write-Host "  (Puedes eliminarlos manualmente)" -ForegroundColor Gray
}
