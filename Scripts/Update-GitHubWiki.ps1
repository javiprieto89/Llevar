<#
.SYNOPSIS
    Sincroniza documentación local a GitHub Wiki
.DESCRIPTION
    Clona el repositorio Wiki, copia los archivos .md y hace push automático
    Los wikis de GitHub son repositorios Git separados (.wiki.git)
.PARAMETER RepoOwner
    Usuario o organización dueña del repositorio
.PARAMETER RepoName
    Nombre del repositorio (sin .wiki)
.PARAMETER DocsPath
    Ruta de la carpeta Docs/ local
.PARAMETER TempPath
    Carpeta temporal para clonar el wiki
.PARAMETER ExcludeFiles
    Archivos a excluir de la sincronización
.EXAMPLE
    .\Update-GitHubWiki.ps1 -RepoOwner "tuusuario" -RepoName "Llevar"
.EXAMPLE
    .\Update-GitHubWiki.ps1 -RepoOwner "alexsoft" -RepoName "Llevar" -DocsPath "Q:\Utilidad\Llevar\Docs"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$RepoOwner,
    
    [Parameter(Mandatory = $true)]
    [string]$RepoName,
    
    [string]$DocsPath = "$PSScriptRoot\..\Docs",
    [string]$TempPath = "$env:TEMP\LlevarWiki_$([guid]::NewGuid().ToString('N').Substring(0,8))",
    
    [string[]]$ExcludeFiles = @("README.md", "CHANGELOG.md", "TEMPLATE.md")
)

# ============================================================================ #
#                              FUNCIONES HELPER                                #
# ============================================================================ #

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Test-GitInstalled {
    try {
        $null = git --version 2>$null
        return $true
    }
    catch {
        return $false
    }
}

function Get-WikiPageName {
    param([string]$FileName)
    
    # GitHub Wiki convierte nombres de archivo:
    # - Espacios permitidos
    # - Guiones y guiones bajos permitidos
    # - Sin extensión .md en el nombre de página
    
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    return $baseName
}

# ============================================================================ #
#                              VALIDACIONES                                    #
# ============================================================================ #

try {
    Write-ColorOutput "`n╔════════════════════════════════════════════════════════════╗" "Cyan"
    Write-ColorOutput "║          SINCRONIZACIÓN GITHUB WIKI - LLEVAR               ║" "Cyan"
    Write-ColorOutput "╚════════════════════════════════════════════════════════════╝`n" "Cyan"
    
    # Verificar Git instalado
    if (-not (Test-GitInstalled)) {
        throw "Git no está instalado o no está en el PATH. Instala Git desde: https://git-scm.com/downloads"
    }
    
    Write-ColorOutput "✓ Git detectado" "Green"
    
    # Verificar carpeta Docs existe
    if (-not (Test-Path $DocsPath)) {
        throw "La carpeta de documentación no existe: $DocsPath"
    }
    
    Write-ColorOutput "✓ Carpeta Docs encontrada: $DocsPath" "Green"
    
    # URL del Wiki
    $wikiUrl = "https://github.com/$RepoOwner/$RepoName.wiki.git"
    
    Write-ColorOutput "`nRepositorio: $RepoOwner/$RepoName" "Yellow"
    Write-ColorOutput "Wiki URL: $wikiUrl`n" "Gray"
    
    # ============================================================================ #
    #                           CLONAR WIKI                                        #
    # ============================================================================ #
    
    # Limpiar carpeta temporal si existe
    if (Test-Path $TempPath) {
        Write-ColorOutput "Limpiando carpeta temporal previa..." "Gray"
        Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Clonar el Wiki
    Write-ColorOutput "Clonando Wiki..." "Yellow"
    
    $gitOutput = git clone $wikiUrl $TempPath 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        # Verificar si el error es porque el wiki no existe aún
        if ($gitOutput -match "not found|does not exist") {
            Write-ColorOutput "`n⚠️  El Wiki no existe todavía." "Yellow"
            Write-ColorOutput "   Para crearlo:" "Yellow"
            Write-ColorOutput "   1. Ve a https://github.com/$RepoOwner/$RepoName/wiki" "Cyan"
            Write-ColorOutput "   2. Haz clic en 'Create the first page'" "Cyan"
            Write-ColorOutput "   3. Vuelve a ejecutar este script`n" "Cyan"
            exit 1
        }
        
        throw "Error al clonar el Wiki: $gitOutput"
    }
    
    Write-ColorOutput "✓ Wiki clonado exitosamente`n" "Green"
    
    # ============================================================================ #
    #                        COPIAR ARCHIVOS                                       #
    # ============================================================================ #
    
    Push-Location $TempPath
    
    Write-ColorOutput "Copiando archivos de documentación...`n" "Yellow"
    
    $mdFiles = Get-ChildItem -Path $DocsPath -Filter "*.md" -File
    $copiedCount = 0
    $skippedCount = 0
    $copiedFiles = @()
    
    foreach ($file in $mdFiles) {
        # Saltar archivos excluidos
        if ($file.Name -in $ExcludeFiles) {
            Write-ColorOutput "  ⊘ $($file.Name) (excluido)" "DarkGray"
            $skippedCount++
            continue
        }
        
        # Convertir nombre a formato Wiki
        $wikiName = Get-WikiPageName -FileName $file.Name
        $destPath = Join-Path $TempPath "$wikiName.md"
        
        # Copiar archivo
        Copy-Item -Path $file.FullName -Destination $destPath -Force
        
        Write-ColorOutput "  ✓ $($file.Name) → $wikiName.md" "Green"
        $copiedCount++
        $copiedFiles += $wikiName
    }
    
    Write-ColorOutput "`nArchivos procesados: $copiedCount copiados, $skippedCount excluidos" "Cyan"
    
    if ($copiedCount -eq 0) {
        Write-ColorOutput "`n⚠️  No hay archivos para actualizar." "Yellow"
        Pop-Location
        Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue
        exit 0
    }
    
    # ============================================================================ #
    #                        CREAR/ACTUALIZAR HOME                                 #
    # ============================================================================ #
    
    $homePath = Join-Path $TempPath "Home.md"
    
    Write-ColorOutput "`nActualizando página principal (Home)..." "Yellow"
    
    $homeContent = @"
# 📦 Llevar - Documentación

Sistema de transferencia y compresión de archivos en PowerShell 7.

**Versión PowerShell requerida:** 7.0 o superior  
**Plataforma:** Windows 10+  
**Instalación:** C:\Llevar

---

## 📚 Documentación Disponible

"@
    
    # Agregar enlaces a todas las páginas copiadas
    foreach ($pageName in ($copiedFiles | Sort-Object)) {
        $homeContent += "`n- [[$pageName]]"
    }
    
    $homeContent += @"


---

## 🚀 Inicio Rápido

1. **Instalar**: Ejecuta ``INSTALAR.CMD`` como administrador
2. **Usar**: Clic derecho en carpetas → "Llevar a..."
3. **Desinstalar**: Ejecuta ``DESINSTALAR.CMD``

## 📖 Documentación Completa

Explora las páginas del menú lateral para información detallada sobre:
- Configuración de transferencias
- Módulos del sistema
- Testing y desarrollo
- Arquitectura del proyecto

---

**Última actualización:** $(Get-Date -Format "dd/MM/yyyy HH:mm")  
**Repositorio:** https://github.com/$RepoOwner/$RepoName
"@
    
    $homeContent | Out-File -FilePath $homePath -Encoding UTF8
    Write-ColorOutput "✓ Página Home actualizada" "Green"
    
    # ============================================================================ #
    #                        COMMIT Y PUSH                                         #
    # ============================================================================ #
    
    Write-ColorOutput "`nSubiendo cambios al Wiki..." "Yellow"
    
    # Agregar todos los archivos
    git add . 2>&1 | Out-Null
    
    # Verificar si hay cambios
    $status = git status --porcelain 2>&1
    
    if ([string]::IsNullOrWhiteSpace($status)) {
        Write-ColorOutput "`n✓ No hay cambios para subir. El Wiki está actualizado." "Green"
    }
    else {
        # Commit
        $commitMessage = "Actualización automática de documentación - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        git commit -m $commitMessage 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            # Push
            $pushOutput = git push origin master 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "`n╔════════════════════════════════════════════════════════════╗" "Green"
                Write-ColorOutput "║               ✓ WIKI ACTUALIZADO EXITOSAMENTE              ║" "Green"
                Write-ColorOutput "╚════════════════════════════════════════════════════════════╝" "Green"
                Write-ColorOutput "`nVer en: https://github.com/$RepoOwner/$RepoName/wiki`n" "Cyan"
            }
            else {
                throw "Error al hacer push al Wiki: $pushOutput"
            }
        }
        else {
            throw "Error al hacer commit: $(git status 2>&1)"
        }
    }
    
}
catch {
    Write-ColorOutput "`n╔════════════════════════════════════════════════════════════╗" "Red"
    Write-ColorOutput "║                      ✗ ERROR                               ║" "Red"
    Write-ColorOutput "╚════════════════════════════════════════════════════════════╝" "Red"
    Write-ColorOutput "`n$_`n" "Red"
    
    if ($_.Exception.Message -match "could not read Username") {
        Write-ColorOutput "💡 Tip: Configura tus credenciales de Git:" "Yellow"
        Write-ColorOutput "   git config --global user.name `"Tu Nombre`"" "Cyan"
        Write-ColorOutput "   git config --global user.email `"tu@email.com`"`n" "Cyan"
    }
    
    exit 1
}
finally {
    # Volver a la ubicación original
    Pop-Location -ErrorAction SilentlyContinue
    
    # Limpiar carpeta temporal
    if (Test-Path $TempPath) {
        Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
