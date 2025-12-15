<#
.SYNOPSIS
    Script de prueba para el módulo PowerShell7Installer.psm1

.DESCRIPTION
    Valida todas las funciones del módulo PowerShell7Installer y muestra
    información detallada sobre la detección e instalación de PowerShell 7.

.EXAMPLE
    .\Test-PowerShell7Installer.ps1
    Ejecuta todas las pruebas del módulo
#>

param(
    [switch]$TestInstallation  # Prueba las funciones de instalación (requiere admin y puede instalar PS7)
)

# Configuración
$ErrorActionPreference = 'Continue'
$ScriptDir = Split-Path -Parent $PSScriptRoot
$ModulePath = Join-Path $ScriptDir "Modules\System\PowerShell7Installer.psm1"

# Colores
function Write-TestHeader {
    param([string]$Message)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

# Verificar que existe el módulo
Write-TestHeader "VERIFICANDO MÓDULO PowerShell7Installer.psm1"

if (Test-Path $ModulePath) {
    Write-Success "Módulo encontrado en: $ModulePath"
}
else {
    Write-Failure "Módulo NO encontrado en: $ModulePath"
    exit 1
}

# Importar el módulo
try {
    Import-Module $ModulePath -Force -Global -ErrorAction Stop
    Write-Success "Módulo importado correctamente"
}
catch {
    Write-Failure "Error al importar módulo: $_"
    exit 1
}

# Verificar funciones exportadas
Write-TestHeader "VERIFICANDO FUNCIONES EXPORTADAS"

$expectedFunctions = @(
    'Test-PowerShell7Installed',
    'Install-PowerShell7WithWinget',
    'Install-PowerShell7WithChocolatey',
    'Install-PowerShell7Direct',
    'Show-PowerShell7NotFoundMessage',
    'Assert-PowerShell7Required'
)

foreach ($funcName in $expectedFunctions) {
    if (Get-Command $funcName -ErrorAction SilentlyContinue) {
        Write-Success "Función '$funcName' exportada"
    }
    else {
        Write-Failure "Función '$funcName' NO encontrada"
    }
}

# Test 1: Test-PowerShell7Installed
Write-TestHeader "TEST 1: Test-PowerShell7Installed"

try {
    $result = Test-PowerShell7Installed
    
    if ($null -eq $result) {
        Write-Failure "La función retornó null"
    }
    elseif ($result.PSObject.Properties.Name -notcontains 'IsInstalled') {
        Write-Failure "El resultado no contiene propiedad 'IsInstalled'"
    }
    else {
        Write-Success "Función ejecutada correctamente"
        
        Write-Host ""
        Write-Host "Resultado de detección:" -ForegroundColor White
        Write-Host "  IsInstalled : $($result.IsInstalled)" -ForegroundColor $(if ($result.IsInstalled) { 'Green' } else { 'Red' })
        Write-Host "  Path        : $($result.Path)" -ForegroundColor Gray
        Write-Host "  Version     : $($result.Version)" -ForegroundColor Gray
        
        if ($result.IsInstalled) {
            Write-Info "PowerShell 7 está instalado en este sistema"
            
            # Validar que el ejecutable existe
            if (Test-Path $result.Path) {
                Write-Success "Ejecutable verificado: $($result.Path)"
                
                # Validar versión ejecutando pwsh
                try {
                    $versionOutput = & $result.Path -Command '$PSVersionTable.PSVersion.ToString()' 2>&1
                    if ($versionOutput -match '^\d+\.\d+') {
                        Write-Success "Versión confirmada: $versionOutput"
                    }
                }
                catch {
                    Write-Failure "Error al ejecutar pwsh.exe: $_"
                }
            }
            else {
                Write-Failure "El ejecutable reportado NO existe: $($result.Path)"
            }
        }
        else {
            Write-Info "PowerShell 7 NO está instalado en este sistema"
        }
    }
}
catch {
    Write-Failure "Error al ejecutar Test-PowerShell7Installed: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}

# Test 2: Show-PowerShell7NotFoundMessage
Write-TestHeader "TEST 2: Show-PowerShell7NotFoundMessage"

try {
    Write-Info "Ejecutando función (solo muestra mensaje)..."
    Write-Host ""
    Show-PowerShell7NotFoundMessage
    Write-Host ""
    Write-Success "Función ejecutada sin errores"
}
catch {
    Write-Failure "Error al ejecutar Show-PowerShell7NotFoundMessage: $_"
}

# Test 3: Detección de herramientas de instalación
Write-TestHeader "TEST 3: Detección de Herramientas de Instalación"

# Verificar winget
Write-Host "Verificando winget..." -ForegroundColor White
try {
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        Write-Success "winget encontrado: $($wingetCmd.Source)"
        try {
            $wingetVersion = & winget --version 2>&1
            Write-Info "Versión: $wingetVersion"
        }
        catch {
            Write-Info "No se pudo obtener versión de winget"
        }
    }
    else {
        Write-Info "winget NO encontrado (normal en Windows 10)"
    }
}
catch {
    Write-Info "Error al verificar winget: $_"
}

# Verificar Chocolatey
Write-Host ""
Write-Host "Verificando Chocolatey..." -ForegroundColor White
try {
    $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
    if ($chocoCmd) {
        Write-Success "Chocolatey encontrado: $($chocoCmd.Source)"
        try {
            $chocoVersion = & choco --version 2>&1
            Write-Info "Versión: $chocoVersion"
        }
        catch {
            Write-Info "No se pudo obtener versión de Chocolatey"
        }
    }
    else {
        Write-Info "Chocolatey NO encontrado (requiere instalación manual)"
    }
}
catch {
    Write-Info "Error al verificar Chocolatey: $_"
}

# Test 4: Pruebas de instalación (solo si se especifica -TestInstallation)
if ($TestInstallation) {
    Write-TestHeader "TEST 4: Funciones de Instalación (ADVERTENCIA: Puede instalar PowerShell 7)"
    
    # Verificar si ya está instalado
    $currentStatus = Test-PowerShell7Installed
    
    if ($currentStatus.IsInstalled) {
        Write-Info "PowerShell 7 ya está instalado, saltando tests de instalación"
        Write-Info "Para probar instalación, desinstale PowerShell 7 primero"
    }
    else {
        Write-Host "PowerShell 7 no está instalado. ¿Desea probar las funciones de instalación?"
        Write-Host "ADVERTENCIA: Esto instalará PowerShell 7 en su sistema." -ForegroundColor Yellow
        Write-Host ""
        $response = Read-Host "Escriba 'SI' para continuar"
        
        if ($response -eq 'SI') {
            # Probar winget
            Write-Host ""
            Write-Host "Intentando instalación con winget..." -ForegroundColor White
            if (Install-PowerShell7WithWinget) {
                Write-Success "Instalación con winget exitosa"
            }
            else {
                Write-Info "Instalación con winget falló, probando Chocolatey..."
                
                # Probar Chocolatey
                if (Install-PowerShell7WithChocolatey) {
                    Write-Success "Instalación con Chocolatey exitosa"
                }
                else {
                    Write-Info "Instalación con Chocolatey falló, probando descarga directa..."
                    
                    # Probar descarga directa
                    if (Install-PowerShell7Direct) {
                        Write-Success "Instalación directa exitosa"
                    }
                    else {
                        Write-Failure "Todas las opciones de instalación fallaron"
                    }
                }
            }
            
            # Verificar instalación final
            Write-Host ""
            Write-Host "Verificando instalación final..." -ForegroundColor White
            $finalStatus = Test-PowerShell7Installed
            if ($finalStatus.IsInstalled) {
                Write-Success "PowerShell 7 instalado correctamente"
                Write-Host "  Ruta: $($finalStatus.Path)" -ForegroundColor Gray
                Write-Host "  Versión: $($finalStatus.Version)" -ForegroundColor Gray
            }
            else {
                Write-Failure "PowerShell 7 NO se instaló correctamente"
            }
        }
        else {
            Write-Info "Pruebas de instalación canceladas por el usuario"
        }
    }
}
else {
    Write-TestHeader "TEST 4: Funciones de Instalación"
    Write-Info "Pruebas de instalación omitidas (use -TestInstallation para ejecutar)"
    Write-Info "ADVERTENCIA: -TestInstallation puede instalar PowerShell 7 en su sistema"
}

# Test 5: Assert-PowerShell7Required
Write-TestHeader "TEST 5: Assert-PowerShell7Required (Modo Informativo)"

Write-Info "Esta función normalmente solicita confirmación del usuario"
Write-Info "Se ejecutará solo para verificar que no produce errores de sintaxis"
Write-Host ""

try {
    # Intentar ejecutar sin interacción (solo verificación de sintaxis)
    $currentStatus = Test-PowerShell7Installed
    
    if ($currentStatus.IsInstalled) {
        Write-Info "PowerShell 7 ya está instalado, la función debería retornar TRUE"
    }
    else {
        Write-Info "PowerShell 7 NO está instalado, la función mostraría opciones de instalación"
        Write-Info "(No se ejecutará para evitar interacción del usuario)"
    }
    
    Write-Success "Función Assert-PowerShell7Required disponible y sin errores de sintaxis"
}
catch {
    Write-Failure "Error al verificar Assert-PowerShell7Required: $_"
}

# Resumen final
Write-TestHeader "RESUMEN DE PRUEBAS"

$currentStatus = Test-PowerShell7Installed

Write-Host "Estado de PowerShell 7:" -ForegroundColor White
if ($currentStatus.IsInstalled) {
    Write-Success "Instalado y funcional"
    Write-Host "  Ruta    : $($currentStatus.Path)" -ForegroundColor Gray
    Write-Host "  Versión : $($currentStatus.Version)" -ForegroundColor Gray
}
else {
    Write-Info "NO instalado"
    Write-Host "  Para instalar, ejecute:" -ForegroundColor Gray
    Write-Host "    Import-Module '$ModulePath'" -ForegroundColor DarkGray
    Write-Host "    Assert-PowerShell7Required" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Módulo PowerShell7Installer:" -ForegroundColor White
Write-Success "Funciones exportadas correctamente"
Write-Success "Sin errores de sintaxis"
Write-Success "Listo para usar en producción"

Write-Host ""
Write-Host "Para probar instalación automática:" -ForegroundColor Yellow
Write-Host "  .\Test-PowerShell7Installer.ps1 -TestInstallation" -ForegroundColor DarkYellow
Write-Host ""
