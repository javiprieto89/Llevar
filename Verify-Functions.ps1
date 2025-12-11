# ========================================================================== #
#         SCRIPT DE VERIFICACIÓN DE FUNCIONES Y MODULARIZACIÓN              #
# ========================================================================== #
# Verifica:
# 1. Que no haya funciones duplicadas
# 2. Que todos los verbos sean apropiados
# 3. Que las funciones estén en los módulos correctos
# 4. Que los imports estén correctos
# ========================================================================== #

$ErrorActionPreference = 'Continue'
$issues = @()

Write-Host "`n╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     VERIFICACIÓN DE FUNCIONES Y MODULARIZACIÓN - LLEVAR.PS1           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# ========================================================================== #
#                    1. RECOPILAR TODAS LAS FUNCIONES                        #
# ========================================================================== #

Write-Host "📋 Recopilando funciones..." -ForegroundColor Yellow

$functions = @{}
$exports = @{}
$imports = @{}

Get-ChildItem "$PSScriptRoot\Modules" -Recurse -Filter "*.psm1" | ForEach-Object {
    $modulePath = $_.FullName
    $moduleRelPath = $modulePath.Replace("$PSScriptRoot\", "")
    
    $content = Get-Content $modulePath -Raw
    
    # Extraer definiciones de funciones
    $matches = [regex]::Matches($content, 'function\s+([\w-]+)')
    foreach ($match in $matches) {
        $funcName = $match.Groups[1].Value
        if (-not $functions.ContainsKey($funcName)) {
            $functions[$funcName] = @()
        }
        $functions[$funcName] += $moduleRelPath
    }
    
    # Extraer exportaciones
    $exportMatches = [regex]::Matches($content, "Export-ModuleMember.*?'([\w-]+)'")
    foreach ($match in $exportMatches) {
        $funcName = $match.Groups[1].Value
        if (-not $exports.ContainsKey($funcName)) {
            $exports[$funcName] = @()
        }
        $exports[$funcName] += $moduleRelPath
    }
    
    # Extraer imports
    $importMatches = [regex]::Matches($content, 'Import-Module.*?"([^"]+)"')
    foreach ($match in $importMatches) {
        $importPath = $match.Groups[1].Value
        if (-not $imports.ContainsKey($moduleRelPath)) {
            $imports[$moduleRelPath] = @()
        }
        $imports[$moduleRelPath] += $importPath
    }
}

Write-Host "   ✓ $($functions.Count) funciones únicas encontradas" -ForegroundColor Green
Write-Host "   ✓ $($exports.Count) exportaciones encontradas" -ForegroundColor Green
Write-Host "   ✓ $($imports.Count) módulos con imports`n" -ForegroundColor Green

# ========================================================================== #
#                    2. VERIFICAR FUNCIONES DUPLICADAS                       #
# ========================================================================== #

Write-Host "🔍 Verificando funciones duplicadas..." -ForegroundColor Yellow

$duplicates = $functions.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }

if ($duplicates) {
    Write-Host "   ❌ FUNCIONES DUPLICADAS ENCONTRADAS:" -ForegroundColor Red
    foreach ($dup in $duplicates) {
        Write-Host "      • $($dup.Key)" -ForegroundColor Red
        foreach ($location in $dup.Value) {
            Write-Host "        - $location" -ForegroundColor Yellow
        }
        $issues += "DUPLICADO: $($dup.Key) en: $($dup.Value -join ', ')"
    }
    Write-Host ""
}
else {
    Write-Host "   ✓ No hay funciones duplicadas`n" -ForegroundColor Green
}

# ========================================================================== #
#                    3. VERIFICAR VERBOS APROBADOS                           #
# ========================================================================== #

Write-Host "📝 Verificando verbos aprobados por PowerShell..." -ForegroundColor Yellow

$approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
$invalidVerbs = @()

foreach ($func in $functions.Keys) {
    if ($func -match '^([\w]+)-') {
        $verb = $matches[1]
        if ($verb -notin $approvedVerbs) {
            $invalidVerbs += @{
                Function = $func
                Verb     = $verb
                Location = $functions[$func][0]
            }
        }
    }
}

if ($invalidVerbs.Count -gt 0) {
    Write-Host "   ⚠ VERBOS NO APROBADOS ENCONTRADOS:" -ForegroundColor Red
    foreach ($item in $invalidVerbs) {
        Write-Host "      • $($item.Function) (verbo: $($item.Verb))" -ForegroundColor Red
        Write-Host "        - $($item.Location)" -ForegroundColor Yellow
        $issues += "VERBO INAPROPIADO: $($item.Function) usa '$($item.Verb)' en $($item.Location)"
    }
    Write-Host ""
}
else {
    Write-Host "   ✓ Todos los verbos son aprobados por PowerShell`n" -ForegroundColor Green
}

# ========================================================================== #
#                    4. VERIFICAR UBICACIÓN DE FUNCIONES                     #
# ========================================================================== #

Write-Host "📂 Verificando ubicación de funciones según categoría..." -ForegroundColor Yellow

$categoryRules = @{
    'System/'       = @('Test-Path', 'Get-', 'Format-FileSize', 'Invoke-Robocopy')
    'UI/'           = @('Show-', 'Write-', 'Select-Path', 'Set-ConsoleSize')
    'Transfer/'     = @('Copy-Llevar', 'Send-', 'Receive-', 'Mount-', 'Connect-')
    'Compression/'  = @('Compress-', 'Expand-', 'Split-', 'Join-', 'Get-Blocks')
    'Installation/' = @('Install-', 'New-Installer')
    'Utilities/'    = @('Select-Llevar', 'Test-Volume', 'Get-Target')
    'Core/'         = @('Initialize-', 'Write-Log', 'Get-Config', 'Set-Config', 'Test-Is')
    'Parameters/'   = @('Invoke-', 'Execute-')
}

$misplaced = @()

foreach ($func in $functions.Keys) {
    $location = $functions[$func][0]
    
    # Encontrar categoría esperada
    $expectedCategory = $null
    foreach ($category in $categoryRules.Keys) {
        foreach ($pattern in $categoryRules[$category]) {
            if ($func -like "$pattern*") {
                $expectedCategory = $category
                break
            }
        }
        if ($expectedCategory) { break }
    }
    
    # Verificar si está en la categoría correcta
    if ($expectedCategory -and -not $location.StartsWith("Modules\$expectedCategory")) {
        $misplaced += @{
            Function         = $func
            CurrentLocation  = $location
            ExpectedCategory = $expectedCategory
        }
    }
}

if ($misplaced.Count -gt 0) {
    Write-Host "   ⚠ FUNCIONES EN UBICACIÓN INCORRECTA:" -ForegroundColor Yellow
    foreach ($item in $misplaced) {
        Write-Host "      • $($item.Function)" -ForegroundColor Yellow
        Write-Host "        Actual:   $($item.CurrentLocation)" -ForegroundColor Gray
        Write-Host "        Esperado: Modules\$($item.ExpectedCategory)xxx.psm1" -ForegroundColor Gray
        $issues += "UBICACIÓN: $($item.Function) está en $($item.CurrentLocation), esperado en $($item.ExpectedCategory)"
    }
    Write-Host ""
}
else {
    Write-Host "   ✓ Todas las funciones están en la categoría correcta`n" -ForegroundColor Green
}

# ========================================================================== #
#                    5. VERIFICAR EXPORTS VS DEFINICIONES                    #
# ========================================================================== #

Write-Host "📤 Verificando exportaciones..." -ForegroundColor Yellow

$exportIssues = @()

foreach ($func in $functions.Keys) {
    $definedIn = $functions[$func]
    $exportedFrom = $exports[$func]
    
    if (-not $exportedFrom) {
        # Función definida pero no exportada (puede ser interna, solo advertencia)
        # $exportIssues += "⚠ $func definida en $($definedIn[0]) pero no exportada"
    }
    elseif ($exportedFrom[0] -ne $definedIn[0]) {
        $exportIssues += "❌ $func definida en $($definedIn[0]) pero exportada desde $($exportedFrom[0])"
        $issues += "EXPORT MISMATCH: $func definida en $($definedIn[0]) pero exportada desde $($exportedFrom[0])"
    }
}

if ($exportIssues.Count -gt 0) {
    Write-Host "   ⚠ PROBLEMAS DE EXPORTACIÓN:" -ForegroundColor Red
    foreach ($issue in $exportIssues) {
        Write-Host "      $issue" -ForegroundColor Yellow
    }
    Write-Host ""
}
else {
    Write-Host "   ✓ Todas las exportaciones coinciden con definiciones`n" -ForegroundColor Green
}

# ========================================================================== #
#                    6. RESUMEN FINAL                                        #
# ========================================================================== #

Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                         RESUMEN DE VERIFICACIÓN                        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

if ($issues.Count -eq 0) {
    Write-Host "✅ VERIFICACIÓN COMPLETADA SIN PROBLEMAS" -ForegroundColor Green
    Write-Host ""
    Write-Host "Estadísticas:" -ForegroundColor Cyan
    Write-Host "  • Funciones únicas: $($functions.Count)" -ForegroundColor White
    Write-Host "  • Módulos analizados: $(($functions.Values | ForEach-Object { $_[0] } | Select-Object -Unique).Count)" -ForegroundColor White
    Write-Host "  • Funciones exportadas: $($exports.Count)" -ForegroundColor White
    Write-Host "  • Módulos con imports: $($imports.Count)" -ForegroundColor White
}
else {
    Write-Host "❌ SE ENCONTRARON $($issues.Count) PROBLEMAS:" -ForegroundColor Red
    Write-Host ""
    for ($i = 0; $i -lt $issues.Count; $i++) {
        Write-Host "  $($i + 1). $($issues[$i])" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
