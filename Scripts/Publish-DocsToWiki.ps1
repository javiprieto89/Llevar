<#
.SYNOPSIS
    Publica toda la documentación a GitHub Wiki con un solo comando
.DESCRIPTION
    Wrapper simplificado que carga configuración desde wiki-config.json
    y ejecuta la sincronización automática
.PARAMETER ConfigFile
    Ruta al archivo de configuración JSON
.PARAMETER Force
    Fuerza la recreación del archivo de configuración
.EXAMPLE
    .\Publish-DocsToWiki.ps1
.EXAMPLE
    .\Publish-DocsToWiki.ps1 -Force
#>

param(
    [string]$ConfigFile = "$PSScriptRoot\..\Data\wiki-config.json",
    [switch]$Force
)

# ============================================================================ #
#                         CREAR CONFIGURACIÓN                                  #
# ============================================================================ #

if ($Force -or -not (Test-Path $ConfigFile)) {
    Write-Host "`n⚙️  Configuración de GitHub Wiki`n" -ForegroundColor Cyan
    
    if ($Force) {
        Write-Host "Recreando archivo de configuración..." -ForegroundColor Yellow
    }
    else {
        Write-Host "No existe wiki-config.json. Creando plantilla..." -ForegroundColor Yellow
    }
    
    # Crear configuración por defecto
    $config = @{
        repoOwner    = "tuusuario"
        repoName     = "Llevar"
        docsPath     = "Q:\Utilidad\Llevar\Docs"
        excludeFiles = @("README.md", "CHANGELOG.md", "TEMPLATE.md")
    }
    
    # Asegurar que existe la carpeta Data
    $dataDir = Split-Path -Parent $ConfigFile
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    
    # Guardar configuración
    $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigFile -Encoding UTF8
    
    Write-Host "`n✓ Plantilla creada en: $ConfigFile`n" -ForegroundColor Green
    
    # Pedir datos al usuario
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "Configuración interactiva (Enter para usar valor por defecto)" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor DarkGray
    
    $owner = Read-Host "Usuario/Organización GitHub [$($config.repoOwner)]"
    if (-not [string]::IsNullOrWhiteSpace($owner)) {
        $config.repoOwner = $owner
    }
    
    $repo = Read-Host "Nombre del repositorio [$($config.repoName)]"
    if (-not [string]::IsNullOrWhiteSpace($repo)) {
        $config.repoName = $repo
    }
    
    $docs = Read-Host "Ruta de carpeta Docs [$($config.docsPath)]"
    if (-not [string]::IsNullOrWhiteSpace($docs)) {
        $config.docsPath = $docs
    }
    
    # Guardar configuración actualizada
    $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigFile -Encoding UTF8
    
    Write-Host "`n✓ Configuración guardada" -ForegroundColor Green
    Write-Host "`nPara ejecutar la sincronización, vuelve a ejecutar este script.`n" -ForegroundColor Cyan
    exit 0
}

# ============================================================================ #
#                         CARGAR Y VALIDAR                                     #
# ============================================================================ #

try {
    $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    
    # Validar campos requeridos
    if ([string]::IsNullOrWhiteSpace($config.repoOwner)) {
        throw "repoOwner no está configurado en $ConfigFile"
    }
    
    if ([string]::IsNullOrWhiteSpace($config.repoName)) {
        throw "repoName no está configurado en $ConfigFile"
    }
    
    if ([string]::IsNullOrWhiteSpace($config.docsPath)) {
        throw "docsPath no está configurado en $ConfigFile"
    }
    
    if (-not (Test-Path $config.docsPath)) {
        throw "La carpeta de documentación no existe: $($config.docsPath)"
    }
    
}
catch {
    Write-Host "`n✗ Error al cargar configuración: $_`n" -ForegroundColor Red
    Write-Host "Ejecuta con -Force para recrear la configuración:`n" -ForegroundColor Yellow
    Write-Host "  .\Publish-DocsToWiki.ps1 -Force`n" -ForegroundColor Cyan
    exit 1
}

# ============================================================================ #
#                         EJECUTAR SINCRONIZACIÓN                              #
# ============================================================================ #

$updateScript = Join-Path $PSScriptRoot "Update-GitHubWiki.ps1"

if (-not (Test-Path $updateScript)) {
    Write-Host "`n✗ No se encuentra Update-GitHubWiki.ps1`n" -ForegroundColor Red
    exit 1
}

# Preparar parámetros
$params = @{
    RepoOwner = $config.repoOwner
    RepoName  = $config.repoName
    DocsPath  = $config.docsPath
}

if ($config.excludeFiles) {
    $params.ExcludeFiles = $config.excludeFiles
}

# Ejecutar
& $updateScript @params

exit $LASTEXITCODE
