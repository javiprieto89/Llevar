# ========================================================================== #
#    VERIFICACIÓN DE USO CORRECTO DE TRANSFERCONFIG EN MÓDULOS               #
# ========================================================================== #
# Propósito: Detectar funciones que reciben parámetros individuales cuando
#            deberían recibir objetos TransferConfig completos
# ========================================================================== #

$ErrorActionPreference = 'Continue'
$issues = @()

Write-Host "`n╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        VERIFICACIÓN DE USO DE TRANSFERCONFIG - LLEVAR.PS1             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# ========================================================================== #
#                1. BUSCAR FUNCIONES CON PARAMETROS INDIVIDUALES             #
# ========================================================================== #

Write-Host "🔍 Buscando funciones con parámetros individuales..." -ForegroundColor Yellow

$transferModules = Get-ChildItem "$PSScriptRoot\Modules\Transfer" -Filter "*.psm1" -Recurse

# Patrones de parámetros problemáticos (deberían usar TransferConfig)
$problematicPatterns = @(
    @{ Pattern = '\[string\]\$Token'; Description = "Token individual (debería estar en TransferConfig)" }
    @{ Pattern = '\[string\]\$RemoteFileName'; Description = "RemoteFileName individual" }
    @{ Pattern = '\[string\]\$LocalPath,\s*\[string\]\$RemotePath,\s*\[string\]\$Token'; Description = "LocalPath, RemotePath, Token separados" }
    @{ Pattern = '\[string\]\$LocalPath,\s*\[string\]\$DriveName'; Description = "LocalPath, DriveName separados" }
    @{ Pattern = '\[string\]\$Server.*\[string\]\$User.*\[string\]\$Password'; Description = "Credenciales FTP separadas" }
)

foreach ($module in $transferModules) {
    $content = Get-Content $module.FullName -Raw
    $moduleName = $module.Name
    
    Write-Host "`n  Analizando: $moduleName" -ForegroundColor Cyan
    
    # Extraer todas las funciones del módulo
    $functionMatches = [regex]::Matches($content, 'function\s+([\w-]+)\s*{(?:[^{}]|{(?:[^{}]|{[^{}]*})*})*}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    
    foreach ($funcMatch in $functionMatches) {
        $funcName = $funcMatch.Groups[1].Value
        $funcBody = $funcMatch.Value
        
        # Buscar bloque param()
        if ($funcBody -match 'param\s*\(((?:[^()]|\([^()]*\))*)\)') {
            $paramBlock = $Matches[1]
            
            # Verificar si la función debería usar TransferConfig pero no lo hace
            $shouldUseTransferConfig = $funcName -match '^(Send-|Receive-|Copy-Llevar)'
            
            if ($shouldUseTransferConfig) {
                # Verificar si ya usa TransferConfig
                $usesTransferConfig = $paramBlock -match '\[TransferConfig\]|\[psobject\]\$.*Config'
                
                if (-not $usesTransferConfig) {
                    # Verificar si tiene parámetros problemáticos
                    foreach ($pattern in $problematicPatterns) {
                        if ($paramBlock -match $pattern.Pattern) {
                            $issue = @{
                                Module      = $moduleName
                                Function    = $funcName
                                Issue       = $pattern.Description
                                Severity    = "HIGH"
                                Suggestion  = "Debería recibir [TransferConfig] en lugar de parámetros individuales"
                            }
                            $issues += $issue
                            
                            Write-Host "    ❌ " -NoNewline -ForegroundColor Red
                            Write-Host "$funcName" -NoNewline -ForegroundColor Yellow
                            Write-Host " - $($pattern.Description)" -ForegroundColor Red
                        }
                    }
                }
                else {
                    Write-Host "    ✓ " -NoNewline -ForegroundColor Green
                    Write-Host "$funcName usa TransferConfig correctamente" -ForegroundColor Gray
                }
            }
        }
    }
}

Write-Host ""

# ========================================================================== #
#                2. VERIFICAR FUNCIONES DESPUÉS DE EXPORT                    #
# ========================================================================== #

Write-Host "🔍 Verificando orden de funciones vs Export-ModuleMember..." -ForegroundColor Yellow

foreach ($module in (Get-ChildItem "$PSScriptRoot\Modules" -Filter "*.psm1" -Recurse)) {
    $content = Get-Content $module.FullName -Raw
    $moduleName = $module.Name
    
    # Buscar posición de Export-ModuleMember
    if ($content -match 'Export-ModuleMember') {
        $exportPos = $content.IndexOf('Export-ModuleMember')
        
        # Buscar funciones después del Export
        $functionsAfterExport = [regex]::Matches(
            $content.Substring($exportPos),
            'function\s+([\w-]+)'
        )
        
        if ($functionsAfterExport.Count -gt 0) {
            Write-Host "`n  ❌ " -NoNewline -ForegroundColor Red
            Write-Host "$moduleName tiene funciones DESPUÉS de Export-ModuleMember:" -ForegroundColor Red
            
            foreach ($match in $functionsAfterExport) {
                $funcName = $match.Groups[1].Value
                Write-Host "      • $funcName" -ForegroundColor Yellow
                
                $issues += @{
                    Module      = $moduleName
                    Function    = $funcName
                    Issue       = "Función definida DESPUÉS de Export-ModuleMember"
                    Severity    = "HIGH"
                    Suggestion  = "Mover la función ANTES de Export-ModuleMember"
                }
            }
        }
    }
}

Write-Host ""

# ========================================================================== #
#                3. VERIFICAR EXPORTS FALTANTES                              #
# ========================================================================== #

Write-Host "🔍 Verificando funciones sin exportar..." -ForegroundColor Yellow

foreach ($module in (Get-ChildItem "$PSScriptRoot\Modules" -Filter "*.psm1" -Recurse)) {
    $content = Get-Content $module.FullName -Raw
    $moduleName = $module.Name
    
    # Extraer funciones definidas
    $definedFunctions = [regex]::Matches($content, 'function\s+([\w-]+)') | 
        ForEach-Object { $_.Groups[1].Value }
    
    # Extraer funciones exportadas
    $exportedFunctions = @()
    if ($content -match "Export-ModuleMember.*?@\((.*?)\)") {
        $exportBlock = $Matches[1]
        $exportedFunctions = [regex]::Matches($exportBlock, "'([\w-]+)'") | 
            ForEach-Object { $_.Groups[1].Value }
    }
    
    # Buscar funciones públicas no exportadas (que empiezan con verbos aprobados)
    $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
    $missingExports = $definedFunctions | Where-Object {
        $funcName = $_
        $verb = $funcName -replace '-.*$', ''
        ($verb -in $approvedVerbs) -and ($_ -notin $exportedFunctions)
    }
    
    if ($missingExports) {
        Write-Host "`n  ⚠ " -NoNewline -ForegroundColor Yellow
        Write-Host "$moduleName tiene funciones sin exportar:" -ForegroundColor Yellow
        
        foreach ($funcName in $missingExports) {
            Write-Host "      • $funcName" -ForegroundColor Gray
            
            $issues += @{
                Module      = $moduleName
                Function    = $funcName
                Issue       = "Función pública sin exportar"
                Severity    = "MEDIUM"
                Suggestion  = "Agregar '$funcName' al Export-ModuleMember"
            }
        }
    }
}

Write-Host ""

# ========================================================================== #
#                4. VERIFICAR IMPORTS NECESARIOS                             #
# ========================================================================== #

Write-Host "🔍 Verificando imports de módulos compartidos..." -ForegroundColor Yellow

$sharedModules = @{
    "Write-LlevarProgressBar" = "Modules\UI\ProgressBar.psm1"
    "Write-Log"               = "Modules\Core\Logging.psm1"
    "Show-Banner"             = "Modules\UI\Banners.psm1"
    "Copy-LlevarLocalToLocal" = "Modules\Transfer\Local.psm1"
}

foreach ($module in $transferModules) {
    $content = Get-Content $module.FullName -Raw
    $moduleName = $module.Name
    
    foreach ($funcName in $sharedModules.Keys) {
        # Buscar si usa la función
        if ($content -match [regex]::Escape($funcName)) {
            # Verificar si tiene el import
            $requiredModule = $sharedModules[$funcName]
            
            if ($content -notmatch [regex]::Escape($requiredModule)) {
                Write-Host "`n  ⚠ " -NoNewline -ForegroundColor Yellow
                Write-Host "$moduleName usa $funcName pero no importa $requiredModule" -ForegroundColor Yellow
                
                $issues += @{
                    Module      = $moduleName
                    Function    = "N/A"
                    Issue       = "Falta import de $requiredModule para usar $funcName"
                    Severity    = "MEDIUM"
                    Suggestion  = "Agregar: Import-Module `"...\$requiredModule`""
                }
            }
        }
    }
}

Write-Host ""

# ========================================================================== #
#                5. RESUMEN FINAL                                            #
# ========================================================================== #

Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    RESUMEN DE VERIFICACIÓN                             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

if ($issues.Count -eq 0) {
    Write-Host "✅ NO SE ENCONTRARON PROBLEMAS" -ForegroundColor Green
    Write-Host ""
    Write-Host "Todos los módulos están correctamente estructurados:" -ForegroundColor Cyan
    Write-Host "  • Funciones usan TransferConfig donde corresponde" -ForegroundColor Gray
    Write-Host "  • Todas las funciones están antes de Export-ModuleMember" -ForegroundColor Gray
    Write-Host "  • Funciones públicas están exportadas" -ForegroundColor Gray
    Write-Host "  • Imports están correctos" -ForegroundColor Gray
}
else {
    Write-Host "❌ SE ENCONTRARON $($issues.Count) PROBLEMAS:" -ForegroundColor Red
    Write-Host ""
    
    # Agrupar por severidad
    $highSeverity = $issues | Where-Object { $_.Severity -eq "HIGH" }
    $mediumSeverity = $issues | Where-Object { $_.Severity -eq "MEDIUM" }
    
    if ($highSeverity) {
        Write-Host "🔴 ALTA PRIORIDAD ($($highSeverity.Count)):" -ForegroundColor Red
        foreach ($issue in $highSeverity) {
            Write-Host "  [$($issue.Module)]" -NoNewline -ForegroundColor Yellow
            Write-Host " $($issue.Function)" -NoNewline -ForegroundColor White
            Write-Host " - $($issue.Issue)" -ForegroundColor Red
            Write-Host "    💡 $($issue.Suggestion)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    
    if ($mediumSeverity) {
        Write-Host "🟡 PRIORIDAD MEDIA ($($mediumSeverity.Count)):" -ForegroundColor Yellow
        foreach ($issue in $mediumSeverity) {
            Write-Host "  [$($issue.Module)]" -NoNewline -ForegroundColor Cyan
            if ($issue.Function -ne "N/A") {
                Write-Host " $($issue.Function)" -NoNewline -ForegroundColor White
            }
            Write-Host " - $($issue.Issue)" -ForegroundColor Yellow
            Write-Host "    💡 $($issue.Suggestion)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    
    # Mostrar recomendaciones
    Write-Host "📋 RECOMENDACIONES:" -ForegroundColor Cyan
    Write-Host "  1. Funciones de transferencia deberían recibir [TransferConfig] o [PSCustomObject] con Tipo" -ForegroundColor Gray
    Write-Host "  2. Todas las funciones deben estar ANTES de Export-ModuleMember" -ForegroundColor Gray
    Write-Host "  3. Funciones públicas (con verbos aprobados) deben exportarse" -ForegroundColor Gray
    Write-Host "  4. Importar módulos compartidos cuando se usen sus funciones" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Retornar código de salida
if ($issues.Count -gt 0) { exit 1 } else { exit 0 }
