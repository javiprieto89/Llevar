# ========================================================================== #
#                   MÓDULO: INSTALACIÓN EN EL SISTEMA                        #
# ========================================================================== #
# Propósito: Instalar Llevar.ps1 en C:\Llevar con 7-Zip y agregar al PATH
# Funciones:
#   - Install-LlevarToSystem: Instalación completa del sistema
# ========================================================================== #

function Install-LlevarToSystem {
    <#
    .SYNOPSIS
        Instala el script Llevar.ps1 en C:\Llevar con 7-Zip y lo agrega al PATH
    .DESCRIPTION
        Copia Llevar.ps1, 7-Zip y Llevar.inf a C:\Llevar, agrega al PATH del sistema
        e instala el menú contextual "Llevar A..."
    .PARAMETER Silent
        Ejecutar en modo silencioso (sin confirmaciones)
    #>
    param([switch]$Silent)
    
    $installPath = "C:\Llevar"
    $scriptSource = $PSCommandPath
    $scriptName = Split-Path $scriptSource -Leaf
    
    Show-Banner -Message "INSTALACIÓN DE LLEVAR EN EL SISTEMA" -BorderColor Cyan -TextColor Yellow
    Write-Host "Esto instalará:" -ForegroundColor White
    Write-Host "  • Script Llevar.ps1 en C:\Llevar" -ForegroundColor Gray
    Write-Host "  • 7-Zip portable (si está disponible o se descarga)" -ForegroundColor Gray
    Write-Host "  • Agregará C:\Llevar al PATH del sistema" -ForegroundColor Gray
    Write-Host "  • Menú contextual 'Llevar A...' (si Llevar.inf existe)" -ForegroundColor Gray
    Write-Host ""
    
    # Crear carpeta C:\Llevar si no existe
    if (-not (Test-Path $installPath)) {
        try {
            New-Item -ItemType Directory -Path $installPath -Force | Out-Null
            Write-Host "✓ Carpeta creada: $installPath" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Error al crear carpeta: $_" -ForegroundColor Red
            return $false
        }
    }
    else {
        Write-Host "✓ Carpeta ya existe: $installPath" -ForegroundColor Green
    }
    
    # Copiar el script
    try {
        $destScript = Join-Path $installPath $scriptName
        Copy-Item -Path $scriptSource -Destination $destScript -Force
        Write-Host "✓ Script copiado: $destScript" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Error al copiar script: $_" -ForegroundColor Red
        return $false
    }
    
    # Buscar archivos de 7-Zip en la carpeta actual
    $currentDir = Split-Path $scriptSource -Parent
    $sevenZipFiles = @(
        "7z.exe", "7z.dll", "7za.exe",
        "7zCon.sfx", "7zS2.sfx", "7zS2con.sfx", "7zSD.sfx"
    )
    
    $foundFiles = @()
    foreach ($file in $sevenZipFiles) {
        $sourcePath = Join-Path $currentDir $file
        if (Test-Path $sourcePath) {
            $foundFiles += $sourcePath
        }
    }
    
    if ($foundFiles.Count -gt 0) {
        Write-Host "`nCopiando archivos de 7-Zip encontrados..." -ForegroundColor Cyan
        foreach ($file in $foundFiles) {
            try {
                $fileName = Split-Path $file -Leaf
                Copy-Item -Path $file -Destination (Join-Path $installPath $fileName) -Force
                Write-Host "  ✓ $fileName" -ForegroundColor Green
            }
            catch {
                Write-Host "  ✗ Error al copiar $fileName" -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host "`n⚠ No se encontraron archivos de 7-Zip en la carpeta actual" -ForegroundColor Yellow
        Write-Host "  Se intentará descargar 7-Zip portable..." -ForegroundColor Gray
        
        # Intentar descargar 7-Zip
        try {
            $7zUrl = "https://www.7-zip.org/a/7zr.exe"
            $7zDest = Join-Path $installPath "7z.exe"
            
            Write-Host "  Descargando desde $7zUrl..." -ForegroundColor Gray
            Invoke-WebRequest -Uri $7zUrl -OutFile $7zDest -UseBasicParsing
            
            if (Test-Path $7zDest) {
                Write-Host "  ✓ 7-Zip descargado exitosamente" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "  ✗ No se pudo descargar 7-Zip: $_" -ForegroundColor Yellow
            Write-Host "  El script funcionará con compresión ZIP nativa" -ForegroundColor Gray
        }
    }
    
    # Agregar al PATH del sistema
    try {
        $currentPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        
        if ($currentPath -notlike "*$installPath*") {
            $newPath = $currentPath + ";" + $installPath
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'Machine')
            
            # También actualizar PATH de la sesión actual
            $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
            
            Write-Host "`n✓ C:\Llevar agregado al PATH del sistema" -ForegroundColor Green
        }
        else {
            Write-Host "`n✓ C:\Llevar ya está en el PATH del sistema" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "`n✗ Error al modificar PATH (requiere permisos de administrador): $_" -ForegroundColor Red
        Write-Host "  Puede agregar manualmente C:\Llevar al PATH" -ForegroundColor Yellow
    }
    
    # Copiar e instalar archivo .inf para menú contextual
    Write-Host "`nInstalando menú contextual 'Llevar A...'..." -ForegroundColor Cyan
    $infSource = Join-Path $currentDir "Llevar.inf"
    $infDest = Join-Path $installPath "Llevar.inf"
    $menuScriptSource = Join-Path $currentDir "Instalar-MenuContextual.ps1"
    $menuScriptDest = Join-Path $installPath "Instalar-MenuContextual.ps1"
    
    # Copiar script de instalación manual del menú contextual
    if (Test-Path $menuScriptSource) {
        try {
            Copy-Item -Path $menuScriptSource -Destination $menuScriptDest -Force
            Write-Host "✓ Script Instalar-MenuContextual.ps1 copiado" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠ No se pudo copiar Instalar-MenuContextual.ps1" -ForegroundColor Yellow
        }
    }
    
    if (Test-Path $infSource) {
        try {
            # Copiar archivo .inf a C:\Llevar
            Copy-Item -Path $infSource -Destination $infDest -Force
            Write-Host "✓ Archivo Llevar.inf copiado" -ForegroundColor Green
            
            # Instalar el menú contextual usando el método correcto para Windows 10/11
            try {
                # Método 1: Usar el script PowerShell (más confiable en Windows 10/11)
                if (Test-Path $menuScriptDest) {
                    Write-Host "  Usando instalador PowerShell..." -ForegroundColor Gray
                    $result = Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$menuScriptDest`"" -Wait -PassThru -Verb RunAs -WindowStyle Hidden
                    
                    if ($result.ExitCode -eq 0) {
                        Write-Host "✓ Menú contextual 'Llevar A...' instalado exitosamente" -ForegroundColor Green
                        Write-Host "  Puede hacer clic derecho en carpetas/unidades → 'Llevar A...'" -ForegroundColor Gray
                    }
                    else {
                        throw "ExitCode: $($result.ExitCode)"
                    }
                }
                else {
                    # Método 2: Usar InfDefaultInstall.exe (fallback)
                    $infDefaultInstall = Join-Path $env:SystemRoot "System32\InfDefaultInstall.exe"
                    
                    if (Test-Path $infDefaultInstall) {
                        Write-Host "  Usando InfDefaultInstall.exe..." -ForegroundColor Gray
                        $result = Start-Process -FilePath $infDefaultInstall -ArgumentList "`"$infDest`"" -Wait -PassThru -Verb RunAs
                        
                        if ($result.ExitCode -eq 0) {
                            Write-Host "✓ Menú contextual 'Llevar A...' instalado exitosamente" -ForegroundColor Green
                            Write-Host "  Puede hacer clic derecho en carpetas/unidades → 'Llevar A...'" -ForegroundColor Gray
                        }
                        else {
                            throw "ExitCode: $($result.ExitCode)"
                        }
                    }
                    else {
                        # Método 3: Fallback a rundll32 (Windows 7/8)
                        Write-Host "  Usando rundll32.exe (método legacy)..." -ForegroundColor Gray
                        $result = Start-Process -FilePath "rundll32.exe" -ArgumentList "setupapi.dll,InstallHinfSection DefaultInstall 132 `"$infDest`"" -Wait -PassThru -Verb RunAs
                        
                        if ($result.ExitCode -eq 0) {
                            Write-Host "✓ Menú contextual 'Llevar A...' instalado exitosamente" -ForegroundColor Green
                            Write-Host "  Puede hacer clic derecho en carpetas/unidades → 'Llevar A...'" -ForegroundColor Gray
                        }
                        else {
                            throw "ExitCode: $($result.ExitCode)"
                        }
                    }
                }
                
                # Refrescar el shell para que los cambios se vean inmediatamente
                Write-Host "  Refrescando explorador de archivos..." -ForegroundColor Gray
                try {
                    $shell = New-Object -ComObject Shell.Application
                    $shell.Windows() | ForEach-Object { $_.Refresh() }
                }
                catch {
                    # Ignorar errores al refrescar
                }
            }
            catch {
                Write-Host "⚠ Error al instalar menú contextual: $_" -ForegroundColor Yellow
                Write-Host "  Puede instalarlo manualmente ejecutando como ADMINISTRADOR:" -ForegroundColor Gray
                Write-Host "    C:\Llevar\Instalar-MenuContextual.ps1" -ForegroundColor DarkGray
                Write-Host "  O haciendo clic derecho en: C:\Llevar\Llevar.inf → Instalar" -ForegroundColor DarkGray
            }
        }
        catch {
            Write-Host "✗ Error al copiar Llevar.inf: $_" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "⚠ No se encontró Llevar.inf en la carpeta actual" -ForegroundColor Yellow
        Write-Host "  El menú contextual no se instalará" -ForegroundColor Gray
    }
    
    Show-Banner "✓ INSTALACIÓN COMPLETADA" -BorderColor Green -TextColor Green
    Write-Host "Puede ejecutar 'Llevar.ps1' desde cualquier ubicación" -ForegroundColor White
    Write-Host ""
    
    return $true
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Install-LlevarToSystem'
)
