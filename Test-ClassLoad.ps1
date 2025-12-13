$classLines = Get-Content 'Q:\Utilidad\Llevar\Modules\Core\TransferConfig.psm1'
$startLine = -1
$endLine = -1
$braceCount = 0

for ($i = 0; $i -lt $classLines.Count; $i++) {
    if ($classLines[$i] -match '^class TransferConfig') {
        $startLine = $i
        $braceCount = 1
        Write-Host "Found class start at line $i"
    }
    elseif ($startLine -ge 0) {
        $braceCount += ([regex]::Matches($classLines[$i], '\{').Count)
        $braceCount -= ([regex]::Matches($classLines[$i], '\}').Count)
        
        if ($braceCount -eq 0) {
            $endLine = $i
            Write-Host "Found class end at line $i"
            break
        }
    }
}

Write-Host "Start: $startLine, End: $endLine"

if ($startLine -ge 0 -and $endLine -ge 0) {
    $classDefinition = $classLines[$startLine..$endLine] -join "`n"
    Write-Host "Class definition length: $($classDefinition.Length) characters"
    
    # Intentar ejecutar
    try {
        Invoke-Expression $classDefinition
        Write-Host "Class loaded successfully!" -ForegroundColor Green
        
        # Probar crear instancia
        $test = [TransferConfig]::new()
        Write-Host "Instance created successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "ERROR: No se encontró la clase" -ForegroundColor Red
}
