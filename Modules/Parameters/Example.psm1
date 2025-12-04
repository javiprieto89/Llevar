function Invoke-ExampleParameter {
    param(
        [switch]$Ejemplo,
        [ValidateSet("local", "iso-cd", "iso-dvd", "ftp", "onedrive", "dropbox")]
        [string]$TipoEjemplo = "local"
    )
    
    if (-not $Ejemplo) { return $false }
    
    try {
        Show-Banner "MODO EJEMPLO AUTOMÁTICO" -BorderColor Magenta -TextColor Yellow
        Write-Host "Tipo: $($TipoEjemplo.ToUpper())" -ForegroundColor Cyan
        Write-Host ""
        
        switch ($TipoEjemplo) {
            "local" { Execute-LocalExample }
            "iso-cd" { Execute-IsoExample -IsoType "cd" }
            "iso-dvd" { Execute-IsoExample -IsoType "dvd" }
            default { 
                Write-Host "Tipo no implementado: $TipoEjemplo" -ForegroundColor Yellow
                Write-Host "Presione ENTER..." -ForegroundColor Gray
                Read-Host
            }
        }
        return $true
    }
    catch {
        Write-Host "ERROR: $_" -ForegroundColor Red
        return $true
    }
}

function Execute-LocalExample {
    Write-Host "Demostración LOCAL a LOCAL (simulando USB)" -ForegroundColor Gray
    Write-Host "Presione ENTER para continuar..." -ForegroundColor Yellow
    Read-Host
    
    $baseTemp = Join-Path $env:TEMP "LLEVAR_EJEMPLO"
    $origenPath = Join-Path $baseTemp "ORIGEN"
    $destinoPath = Join-Path $baseTemp "DESTINO"
    
    if (Test-Path $baseTemp) {
        Remove-Item $baseTemp -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    New-Item -ItemType Directory -Path $origenPath -Force | Out-Null
    New-Item -ItemType Directory -Path $destinoPath -Force | Out-Null
    
    Show-Banner "GENERANDO DATOS (50MB)" -BorderColor Cyan -TextColor Cyan
    
    $testFile = Join-Path $origenPath "DATOS_EJEMPLO.tmp"
    $stream = [System.IO.File]::Create($testFile)
    $stream.SetLength(50MB)
    $stream.Close()
    
    "Ejemplo README" | Out-File (Join-Path $origenPath "README.txt")
    
    Write-Host "V Datos generados" -ForegroundColor Green
    Write-Host ""
    
    $sevenZ = Get-7z-Llevar
    if (-not $sevenZ) {
        Write-Host "? No se pudo obtener 7-Zip" -ForegroundColor Red
        return
    }
    
    $tempBlocks = Join-Path $env:TEMP "LLEVAR_TEMP_EJEMPLO"
    if (Test-Path $tempBlocks) { Remove-Item $tempBlocks -Recurse -Force }
    New-Item -Type Directory $tempBlocks | Out-Null
    
    Show-Banner "COMPRIMIENDO Y DIVIDIENDO (10MB bloques)" -BorderColor Cyan -TextColor Cyan
    $compressionResult = Compress-Folder $origenPath $tempBlocks $sevenZ $null 10 $destinoPath
    $blocks = $compressionResult.Files
    
    Write-Host "V Bloques: $($blocks.Count)" -ForegroundColor Green
    Write-Host ""
    
    Show-Banner "COPIANDO AL DESTINO" -BorderColor Cyan -TextColor Cyan
    
    $installerScript = New-InstallerScript -Temp $tempBlocks -CompressionType $compressionResult.CompressionType
    
    foreach ($block in $blocks) {
        $fileName = [System.IO.Path]::GetFileName($block)
        Write-Host "-> $fileName" -ForegroundColor Gray
        Copy-Item $block $destinoPath -Force
    }
    
    if ($installerScript) {
        Copy-Item $installerScript $destinoPath -Force
        Write-Host "V INSTALAR.ps1" -ForegroundColor Green
    }
    
    if ($sevenZ -ne "NATIVE_ZIP" -and (Test-Path $sevenZ)) {
        Copy-Item $sevenZ $destinoPath -Force
        Write-Host "V 7z.exe" -ForegroundColor Green
    }
    
    # NO crear __EOF__ en modo ejemplo (todos los archivos están en carpeta local)
    Write-Host ""
    
    Show-Banner "COMPLETADO" -BorderColor Green -TextColor Green
    Write-Host "Archivos en: $destinoPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Para restaurar:" -ForegroundColor Yellow
    Write-Host "  cd `"$destinoPath`"" -ForegroundColor Gray
    Write-Host "  .\INSTALAR.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Presione ENTER para limpiar..." -ForegroundColor Yellow
    Read-Host
    
    Write-Host "Limpiando..." -ForegroundColor Gray
    Remove-Item $baseTemp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $tempBlocks -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "V Listo" -ForegroundColor Green
}

function Execute-IsoExample {
    param([string]$IsoType = "dvd")
    
    Write-Host "Ejemplo ISO-$($IsoType.ToUpper()) no implementado" -ForegroundColor Yellow
    Write-Host "Presione ENTER..." -ForegroundColor Gray
    Read-Host
}

Export-ModuleMember -Function Invoke-ExampleParameter
