# ============================================================================
# PowerShell7Installer.psm1
# Detecta, valida e instala PowerShell 7+ automáticamente
# ============================================================================

function Test-PowerShell7Installed {
    <#
    .SYNOPSIS
        Verifica si PowerShell 7+ está instalado en el sistema
    
    .DESCRIPTION
        Busca pwsh.exe en ubicaciones conocidas y verifica la versión
    
    .OUTPUTS
        PSCustomObject con propiedades: IsInstalled, Path, Version
    #>
    
    # Ubicaciones a verificar en orden de prioridad
    $locations = @(
        # Ubicación oficial
        "$env:ProgramFiles\PowerShell\7\pwsh.exe",
        
        # Otras versiones 7+
        "$env:ProgramFiles\PowerShell\7.*\pwsh.exe",
        
        # PATH (evitando WindowsApps que puede causar problemas)
        (Get-Command pwsh -ErrorAction SilentlyContinue | Where-Object { $_.Source -notlike "*WindowsApps*" }).Source
    )
    
    foreach ($location in $locations) {
        if ($location -and (Test-Path $location -ErrorAction SilentlyContinue)) {
            try {
                # Verificar versión
                $versionOutput = & $location -NoProfile -Command '$PSVersionTable.PSVersion.Major' 2>$null
                $majorVersion = [int]$versionOutput
                
                if ($majorVersion -ge 7) {
                    return [PSCustomObject]@{
                        IsInstalled = $true
                        Path        = $location
                        Version     = $majorVersion
                    }
                }
            }
            catch {
                continue
            }
        }
    }
    
    return [PSCustomObject]@{
        IsInstalled = $false
        Path        = $null
        Version     = 0
    }
}

function Install-PowerShell7WithWinget {
    <#
    .SYNOPSIS
        Intenta instalar PowerShell 7 usando winget
    
    .OUTPUTS
        Boolean - $true si la instalación fue exitosa
    #>
    
    Write-Host "  [Método 1/3] Intentando con winget..." -ForegroundColor Cyan
    
    try {
        $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $wingetPath) {
            Write-Host "    ⚠ winget no está disponible" -ForegroundColor Yellow
            return $false
        }
        
        Write-Host "    • Instalando Microsoft.PowerShell..." -ForegroundColor Gray
        & winget install --id Microsoft.PowerShell --silent --accept-source-agreements --accept-package-agreements 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Instalación con winget exitosa" -ForegroundColor Green
            Start-Sleep -Seconds 3
            return $true
        }
        else {
            Write-Host "    ⚠ winget falló con código: $LASTEXITCODE" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "    ⚠ Error con winget: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

function Install-PowerShell7WithChocolatey {
    <#
    .SYNOPSIS
        Intenta instalar PowerShell 7 usando Chocolatey
    
    .OUTPUTS
        Boolean - $true si la instalación fue exitosa
    #>
    
    Write-Host "  [Método 2/3] Intentando con Chocolatey..." -ForegroundColor Cyan
    
    try {
        $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
        if (-not $chocoPath) {
            Write-Host "    ⚠ Chocolatey no está instalado" -ForegroundColor Yellow
            return $false
        }
        
        Write-Host "    • Instalando powershell-core..." -ForegroundColor Gray
        & choco install powershell-core -y 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Instalación con Chocolatey exitosa" -ForegroundColor Green
            Start-Sleep -Seconds 3
            return $true
        }
        else {
            Write-Host "    ⚠ Chocolatey falló con código: $LASTEXITCODE" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "    ⚠ Error con Chocolatey: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

function Install-PowerShell7Direct {
    <#
    .SYNOPSIS
        Descarga e instala PowerShell 7 directamente desde GitHub
    
    .OUTPUTS
        Boolean - $true si la instalación fue exitosa
    #>
    
    Write-Host "  [Método 3/3] Descarga directa desde GitHub..." -ForegroundColor Cyan
    Write-Host "    Este proceso puede tardar varios minutos..." -ForegroundColor Gray
    Write-Host ""
    
    try {
        $tempDir = Join-Path $env:TEMP "PowerShell7Install"
        $msiFile = Join-Path $tempDir "PowerShell-7-win-x64.msi"
        
        # Crear directorio temporal
        if (-not (Test-Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }
        
        # Descargar MSI desde GitHub
        Write-Host "    • Descargando PowerShell 7 MSI..." -ForegroundColor Gray
        $downloadUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7-win-x64.msi"
        
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $downloadUrl -OutFile $msiFile -UseBasicParsing -ErrorAction Stop
        
        if (-not (Test-Path $msiFile)) {
            Write-Host "    ✗ Error: El archivo MSI no se descargó correctamente" -ForegroundColor Red
            return $false
        }
        
        Write-Host "    ✓ Descarga completada" -ForegroundColor Green
        Write-Host ""
        Write-Host "    • Instalando PowerShell 7..." -ForegroundColor Gray
        Write-Host "      (Esto puede requerir permisos de administrador)" -ForegroundColor DarkGray
        Write-Host ""
        
        # Instalar MSI silenciosamente
        $msiArgs = @("/i", "`"$msiFile`"", "/quiet", "/norestart")
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Host "    ✓ Instalación completada" -ForegroundColor Green
            
            # Limpiar archivos temporales
            Write-Host "    • Limpiando archivos temporales..." -ForegroundColor Gray
            Remove-Item -Path $msiFile -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            
            Start-Sleep -Seconds 3
            return $true
        }
        else {
            Write-Host "    ✗ La instalación falló con código: $($process.ExitCode)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "    ✗ Error durante la descarga/instalación: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Show-PowerShell7NotFoundMessage {
    <#
    .SYNOPSIS
        Muestra mensaje de error cuando no se pudo instalar PowerShell 7
    #>
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  NO SE PUDO INSTALAR POWERSHELL 7 AUTOMÁTICAMENTE" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-Host "LLEVAR requiere PowerShell 7 o superior para funcionar." -ForegroundColor White
    Write-Host "PowerShell 5 (incluido en Windows) no es compatible." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Opciones de instalación manual:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. Link directo:" -ForegroundColor White
    Write-Host "     https://github.com/PowerShell/PowerShell/releases/latest" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Comando con winget (como administrador):" -ForegroundColor White
    Write-Host "     winget install Microsoft.PowerShell" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. Comando con Chocolatey:" -ForegroundColor White
    Write-Host "     choco install powershell-core" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Después de instalar, ejecute LLEVAR.CMD nuevamente." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
}

function Assert-PowerShell7Required {
    <#
    .SYNOPSIS
        Verifica que PowerShell 7+ esté disponible y lo instala si es necesario
    
    .DESCRIPTION
        Función principal que:
        1. Verifica si se está ejecutando en PowerShell 7+
        2. Si sí, retorna $true
        3. Si no, verifica si PowerShell 7 está instalado
        4. Si está instalado, muestra mensaje de cómo ejecutarlo y retorna $false
        5. Si no está instalado, intenta instalarlo automáticamente
        6. Si la instalación falla, muestra mensaje de error y retorna $false
    
    .OUTPUTS
        Boolean - $true si está en PowerShell 7+, $false si debe salir
    #>
    
    # Si ya estamos en PowerShell 7+, todo bien
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        return $true
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  VERIFICANDO POWERSHELL 7" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Versión actual: PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "Versión requerida: PowerShell 7 o superior" -ForegroundColor Gray
    Write-Host ""
    
    # Verificar si PowerShell 7 está instalado
    $ps7Check = Test-PowerShell7Installed
    
    if ($ps7Check.IsInstalled) {
        Write-Host "✓ PowerShell 7 está instalado en el sistema" -ForegroundColor Green
        Write-Host "  Ubicación: $($ps7Check.Path)" -ForegroundColor Gray
        Write-Host "  Versión: PowerShell $($ps7Check.Version)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Por favor, ejecute el programa usando PowerShell 7:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Opción 1: Ejecutar LLEVAR.CMD (recomendado)" -ForegroundColor White
        Write-Host "            Este launcher usa automáticamente PowerShell 7" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Opción 2: Ejecutar directamente con pwsh.exe" -ForegroundColor White
        Write-Host "            pwsh.exe -File `"$PSCommandPath`"" -ForegroundColor Gray
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Cyan
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return $false
    }
    
    # PowerShell 7 no está instalado - intentar instalarlo
    Write-Host "✗ PowerShell 7 no está instalado en el sistema" -ForegroundColor Red
    Write-Host ""
    Write-Host "¿Desea instalar PowerShell 7 automáticamente? [S/N]: " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    Write-Host ""
    
    if ($response -ne 'S' -and $response -ne 's') {
        Show-PowerShell7NotFoundMessage
        Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Cyan
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return $false
    }
    
    Write-Host "Iniciando instalación automática de PowerShell 7..." -ForegroundColor Cyan
    Write-Host ""
    
    # Intentar métodos de instalación en orden
    $installed = $false
    
    # Método 1: winget
    if (-not $installed) {
        $installed = Install-PowerShell7WithWinget
        if ($installed) {
            # Verificar instalación
            $ps7Check = Test-PowerShell7Installed
            if ($ps7Check.IsInstalled) {
                Write-Host ""
                Write-Host "✓ PowerShell 7 instalado exitosamente con winget" -ForegroundColor Green
                Write-Host "  Ubicación: $($ps7Check.Path)" -ForegroundColor Gray
                Write-Host "  Versión: PowerShell $($ps7Check.Version)" -ForegroundColor Gray
                Write-Host ""
            }
        }
    }
    
    # Método 2: Chocolatey
    if (-not $installed) {
        Write-Host ""
        $installed = Install-PowerShell7WithChocolatey
        if ($installed) {
            # Verificar instalación
            $ps7Check = Test-PowerShell7Installed
            if ($ps7Check.IsInstalled) {
                Write-Host ""
                Write-Host "✓ PowerShell 7 instalado exitosamente con Chocolatey" -ForegroundColor Green
                Write-Host "  Ubicación: $($ps7Check.Path)" -ForegroundColor Gray
                Write-Host "  Versión: PowerShell $($ps7Check.Version)" -ForegroundColor Gray
                Write-Host ""
            }
        }
    }
    
    # Método 3: Descarga directa
    if (-not $installed) {
        Write-Host ""
        $installed = Install-PowerShell7Direct
        if ($installed) {
            # Verificar instalación
            $ps7Check = Test-PowerShell7Installed
            if ($ps7Check.IsInstalled) {
                Write-Host ""
                Write-Host "✓ PowerShell 7 instalado exitosamente (descarga directa)" -ForegroundColor Green
                Write-Host "  Ubicación: $($ps7Check.Path)" -ForegroundColor Gray
                Write-Host "  Versión: PowerShell $($ps7Check.Version)" -ForegroundColor Gray
                Write-Host ""
            }
        }
    }
    
    if ($installed) {
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host "  INSTALACIÓN COMPLETADA EXITOSAMENTE" -ForegroundColor Green
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host ""
        Write-Host "PowerShell 7 ha sido instalado correctamente." -ForegroundColor White
        Write-Host ""
        Write-Host "Por favor, ejecute LLEVAR.CMD nuevamente para continuar." -ForegroundColor Yellow
        Write-Host "El nuevo PowerShell 7 será usado automáticamente." -ForegroundColor Gray
        Write-Host ""
        Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Cyan
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return $false  # Debe salir y reiniciar con PowerShell 7
    }
    else {
        # No se pudo instalar
        Show-PowerShell7NotFoundMessage
        Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Cyan
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return $false
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Test-PowerShell7Installed',
    'Install-PowerShell7WithWinget',
    'Install-PowerShell7WithChocolatey',
    'Install-PowerShell7Direct',
    'Show-PowerShell7NotFoundMessage',
    'Assert-PowerShell7Required'
)
