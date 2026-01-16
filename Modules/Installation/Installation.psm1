# ========================================================================== #
#                   MÓDULO: UTILIDADES DE INSTALACIÓN                        #
# ========================================================================== #
# Propósito: Verificación, prompts e instalación completa del sistema
# Funciones:
#   - Test-LlevarInstallation: Verifica si está en C:\Llevar
#   - Show-InstallationPrompt: Muestra prompt para instalar
#   - Install-LlevarToSystem: Realiza la instalación completa
# ========================================================================== #

function Test-LlevarInstallation {
    <#
    .SYNOPSIS
        Verifica si el script está ejecutándose desde C:\Llevar
    #>
    $currentPath = $PSCommandPath
    if (-not $currentPath) {
        $currentPath = $PSScriptRoot
    }
    
    $expectedPath = "C:\Llevar"
    
    # Normalizar rutas para comparación
    $currentDir = (Split-Path $currentPath -Parent).ToLower().TrimEnd('\')
    $expectedPathNormalized = $expectedPath.ToLower().TrimEnd('\')
    
    # Verificar si está en C:\Llevar
    $isInLlevarDir = ($currentDir -eq $expectedPathNormalized)
    
    # Verificar si C:\Llevar está en el PATH del sistema
    $systemPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $isInSystemPath = $systemPath -and ($systemPath.ToLower() -split ';' | Where-Object { $_.TrimEnd('\') -eq $expectedPathNormalized })
    
    return ($isInLlevarDir -or $isInSystemPath)
}

function Show-InstallationPrompt {
    <#
    .SYNOPSIS
        Muestra un diálogo preguntando si se quiere instalar el script
    #>
    
    $mensaje = @"
Este script no está instalado en C:\Llevar

¿Desea instalarlo en el sistema?

Esto copiará:
  • Llevar.ps1, Llevar.cmd, Llevar.inf
  • Módulos completos (Modules/)
  • Documentación de usuario (Docs/)
  • Datos y configuraciones (Data/)
  • Utilidades (7za.exe, arj.exe, arj32.exe)
  - Robocopy portable (robocopy\\robocopy.exe)
  • Agregará C:\Llevar al PATH del sistema
"@

    $respuesta = Show-ConsolePopup -Title "INSTALACIÓN DE LLEVAR EN EL SISTEMA" -Message $mensaje -Options @("*Sí, instalar", "*No, continuar sin instalar")
    
    return ($respuesta -eq 0)
}

function Install-LlevarToSystem {
    <#
    .SYNOPSIS
        Instala Llevar completamente en C:\Llevar
    .DESCRIPTION
        Copia todos los archivos necesarios, configura el PATH,
        y opcionalmente instala el menú contextual de Windows
    #>
    
    $origenDir = $PSScriptRoot | Split-Path | Split-Path  # Subir dos niveles desde Modules/Utilities
    $destinoDir = "C:\Llevar"
    
    Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  INSTALACIÓN DE LLEVAR EN EL SISTEMA" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Crear carpeta C:\Llevar si no existe
        if (-not (Test-Path $destinoDir)) {
            Write-Host "Creando carpeta $destinoDir..." -ForegroundColor Cyan
            New-Item -Path $destinoDir -ItemType Directory -Force | Out-Null
            Write-Host "✓ Carpeta creada" -ForegroundColor Green
        }
        else {
            Write-Host "✓ Carpeta $destinoDir ya existe" -ForegroundColor Green
        }
        
        # Copiar archivos principales
        Write-Host "`nCopiando archivos principales..." -ForegroundColor Cyan
        $archivosPrincipales = @("Llevar.ps1", "Llevar.cmd", "Llevar.inf")
        foreach ($archivo in $archivosPrincipales) {
            $origen = Join-Path $origenDir $archivo
            if (Test-Path $origen) {
                Copy-Item -Path $origen -Destination $destinoDir -Force
                Write-Host "  ✓ $archivo" -ForegroundColor Gray
            }
        }
        
        # Copiar script de instalación del menú contextual desde Modules/Installation
        $menuScriptOrigen = Join-Path (Join-Path $origenDir "Modules") "Installation\Instalar-MenuContextual.ps1"
        if (Test-Path $menuScriptOrigen) {
            Copy-Item -Path $menuScriptOrigen -Destination $destinoDir -Force
            Write-Host "  ✓ Instalar-MenuContextual.ps1" -ForegroundColor Gray
        }
        
        # Copiar ejecutables (7-Zip, ARJ)
        Write-Host "`nCopiando utilidades..." -ForegroundColor Cyan
        $ejecutables = @("7za.exe", "arj.exe", "arj32.exe")
        foreach ($exe in $ejecutables) {
            $origen = Join-Path $origenDir $exe
            if (Test-Path $origen) {
                Copy-Item -Path $origen -Destination $destinoDir -Force
                Write-Host "  ✓ $exe" -ForegroundColor Gray
            }
            else {
                Write-Host "  ⚠ $exe no encontrado (opcional)" -ForegroundColor Yellow
            }
        }
        
        # Copiar carpeta Modules completa
        Write-Host "`nCopiando módulos..." -ForegroundColor Cyan
        $origenModules = Join-Path $origenDir "Modules"
        $destinoModules = Join-Path $destinoDir "Modules"
        if (Test-Path $origenModules) {
            if (Test-Path $destinoModules) {
                Remove-Item -Path $destinoModules -Recurse -Force
            }
            Copy-Item -Path $origenModules -Destination $destinoModules -Recurse -Force
            Write-Host "  ✓ Modules/ (completa con subcarpetas)" -ForegroundColor Gray
        }
        
        # Copiar carpeta Data
        Write-Host "`nCopiando datos..." -ForegroundColor Cyan
        $origenData = Join-Path $origenDir "Data"
        $destinoData = Join-Path $destinoDir "Data"
        if (Test-Path $origenData) {
            if (Test-Path $destinoData) {
                Remove-Item -Path $destinoData -Recurse -Force
            }
            Copy-Item -Path $origenData -Destination $destinoData -Recurse -Force
            Write-Host "  V Data/" -ForegroundColor Gray
        }

        # Copiar carpeta Robocopy (si existe)
        Write-Host "`nCopiando robocopy..." -ForegroundColor Cyan
        $origenRobocopy = $null
        $robocopyCandidates = @(
            (Join-Path $origenDir "Robocopy"),
            (Join-Path $origenDir "robocopy")
        )
        foreach ($candidate in $robocopyCandidates) {
            if (Test-Path $candidate) {
                $origenRobocopy = $candidate
                break
            }
        }
        $destinoRobocopy = Join-Path $destinoDir "robocopy"
        if ($origenRobocopy) {
            if (Test-Path $destinoRobocopy) {
                Remove-Item -Path $destinoRobocopy -Recurse -Force
            }
            Copy-Item -Path $origenRobocopy -Destination $destinoRobocopy -Recurse -Force
            Write-Host "  V robocopy/ (completa con subcarpetas)" -ForegroundColor Gray
        }

        # Eliminar carpetas de trabajo si existen en destino
        $cleanupDirs = @(".git", ".vscode", ".cursor")
        foreach ($dir in $cleanupDirs) {
            $path = Join-Path $destinoDir $dir
            if (Test-Path $path) {
                Remove-Item -Path $path -Recurse -Force
            }
        }

        # Copiar carpeta Docs (solo documentos de usuario)
        Write-Host "`nCopiando documentación de usuario..." -ForegroundColor Cyan
        $origenDocs = Join-Path $origenDir "Docs"
        $destinoDocs = Join-Path $destinoDir "Docs"
        if (Test-Path $origenDocs) {
            if (-not (Test-Path $destinoDocs)) {
                New-Item -Path $destinoDocs -ItemType Directory -Force | Out-Null
            }
            
            # Documentos para usuario final (no desarrollo)
            $docsUsuario = @(
                "README.md", 
                "ONEDRIVE-README.md", 
                "MENU-INTERACTIVO.md", 
                "NAVEGADOR.md",
                "MODULE-LOADER-VALIDATION.md"
            )
            foreach ($doc in $docsUsuario) {
                $origenDoc = Join-Path $origenDocs $doc
                if (Test-Path $origenDoc) {
                    Copy-Item -Path $origenDoc -Destination $destinoDocs -Force
                    Write-Host "  ✓ $doc" -ForegroundColor Gray
                }
            }
        }
        
        # Crear carpeta Logs si no existe
        $logsDir = Join-Path $destinoDir "Logs"
        if (-not (Test-Path $logsDir)) {
            New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
            Write-Host "`n✓ Carpeta Logs/ creada" -ForegroundColor Green
        }
        
        # Agregar al PATH del sistema
        Write-Host "`nConfigurando PATH del sistema..." -ForegroundColor Cyan
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$destinoDir*") {
            $newPath = "$currentPath;$destinoDir"
            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
            
            # Actualizar PATH de la sesión actual
            $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
            
            Write-Host "✓ C:\Llevar agregado al PATH del sistema" -ForegroundColor Green
        }
        else {
            Write-Host "✓ C:\Llevar ya está en el PATH del sistema" -ForegroundColor Green
        }
        
        # Crear acceso directo en el escritorio
        Write-Host "`nCreando acceso directo..." -ForegroundColor Cyan
        $escritorio = [Environment]::GetFolderPath("Desktop")
        $accesoDirecto = Join-Path $escritorio "Llevar.lnk"
        
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($accesoDirecto)
        $shortcut.TargetPath = "pwsh.exe"
        $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$destinoDir\Llevar.ps1`""
        $shortcut.WorkingDirectory = $destinoDir
        $shortcut.Description = "Sistema de transferencia y compresión Llevar"        
        # Asignar icono personalizado si existe
        $iconoPath = Join-Path $destinoDir "Data\Llevar.ico"
        if (Test-Path $iconoPath) {
            $shortcut.IconLocation = $iconoPath
        }
        $shortcut.Save()
        
        Write-Host "✓ Acceso directo creado en el escritorio" -ForegroundColor Green
        
        # Configurar icono de la carpeta C:\Llevar
        Write-Host "\nConfigurando icono de carpeta..." -ForegroundColor Cyan
        $iconoPath = Join-Path $destinoDir "Data\Llevar_AlexSoft.ico"
        if (Test-Path $iconoPath) {
            try {
                # Crear desktop.ini
                $desktopIni = Join-Path $destinoDir "desktop.ini"
                $iniContent = @"
[.ShellClassInfo]
IconResource=$iconoPath,0
IconFile=$iconoPath
IconIndex=0
"@
                Set-Content -Path $desktopIni -Value $iniContent -Force
                
                # Marcar desktop.ini como oculto y del sistema
                $desktopIniFile = Get-Item $desktopIni -Force
                $desktopIniFile.Attributes = 'Hidden,System'
                
                # Marcar la carpeta como de solo lectura (necesario para que Windows use desktop.ini)
                $folder = Get-Item $destinoDir -Force
                $folder.Attributes = $folder.Attributes -bor [System.IO.FileAttributes]::ReadOnly
                
                Write-Host "  ✓ Icono de carpeta configurado" -ForegroundColor Green
            }
            catch {
                Write-Host "  ⚠ No se pudo configurar el icono de carpeta: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "  ⚠ Icono no encontrado: $iconoPath" -ForegroundColor Yellow
        }
        
        # Instalar menú contextual (Opción 3)
        Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  MENÚ CONTEXTUAL DE WINDOWS" -ForegroundColor White
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        $esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($esAdmin) {
            Write-Host "¿Desea instalar el menú contextual 'Llevar A...' en Windows?" -ForegroundColor Cyan
            Write-Host "(Agrega opción al clic derecho en archivos y carpetas)" -ForegroundColor Gray
            $respuesta = Read-Host "`n[S/N]"
            
            if ($respuesta -eq "S" -or $respuesta -eq "s") {
                $menuScript = Join-Path $destinoDir "Instalar-MenuContextual.ps1"
                if (Test-Path $menuScript) {
                    Write-Host "`nInstalando menú contextual..." -ForegroundColor Cyan
                    & $menuScript
                }
                else {
                    Write-Host "⚠ No se encontró Instalar-MenuContextual.ps1" -ForegroundColor Yellow
                }
            }
        }
        else {
            Write-Host "NOTA: Para instalar el menú contextual, ejecute como administrador:" -ForegroundColor Yellow
            Write-Host "  cd C:\Llevar" -ForegroundColor Gray
            Write-Host "  .\Instalar-MenuContextual.ps1" -ForegroundColor Gray
        }
        
        # Resumen final
        Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  ✓ INSTALACIÓN COMPLETADA" -ForegroundColor Green
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Llevar instalado en: C:\Llevar" -ForegroundColor White
        Write-Host "Acceso directo:      Escritorio\Llevar.lnk" -ForegroundColor White
        Write-Host "PATH actualizado:    ✓" -ForegroundColor White
        Write-Host ""
        Write-Host "Para ejecutar desde cualquier ubicación, escriba:" -ForegroundColor Cyan
        Write-Host "  Llevar" -ForegroundColor White
        Write-Host ""
        
        return $true
    }
    catch {
        Write-Host "`n✗ Error durante la instalación:" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Test-LlevarInstallation',
    'Show-InstallationPrompt',
    'Install-LlevarToSystem'
)





