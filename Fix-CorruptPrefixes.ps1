param(
    [Parameter(Mandatory)]
    [string]$Path,

    [switch]$Recurse
)

Write-Host "=== Reparador de prefijos corruptos dentro de cadenas (\"`nTexto\" / \"nTexto\") ===" -ForegroundColor Cyan

$extensions = @(".ps1", ".psm1", ".psd1")

# Obtener archivos
if (Test-Path $Path -PathType Leaf) {
    $files = @(Get-Item -LiteralPath $Path)
}
else {
    $files = Get-ChildItem -LiteralPath $Path -Recurse:$Recurse -File |
    Where-Object { $extensions -contains $_.Extension.ToLower() }
}

if ($files.Count -eq 0) {
    Write-Host "❌ No se encontraron archivos válidos." -ForegroundColor Red
    exit
}

Write-Host "Archivos encontrados: $($files.Count)" -ForegroundColor Yellow


function Repair-CorruptStringPrefixes {
    param([string]$FilePath)

    Write-Host "`n→ Analizando: $FilePath" -ForegroundColor Cyan

    $lines = Get-Content -LiteralPath $FilePath -Encoding UTF8
    $newLines = @()
    $changed = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {

        $original = $lines[$i]
        $cleaned = $original
        $modified = $false

        $index = 0

        while ($index -lt $cleaned.Length) {

            # encontrar comilla "
            $q = $cleaned.IndexOf('"', $index)
            if ($q -lt 0) { break }

            # buscar primer caracter no blanco después de "
            $j = $q + 1
            while ($j -lt $cleaned.Length -and [char]::IsWhiteSpace($cleaned[$j])) {
                $j++
            }

            if ($j -ge $cleaned.Length) { break }

            # caso 1: "`nTexto"
            if ($cleaned[$j] -eq '`' -and 
                $j + 1 -lt $cleaned.Length -and 
                $cleaned[$j + 1] -eq 'n' -and 
                $j + 2 -lt $cleaned.Length -and 
                [char]::IsLetter($cleaned[$j + 2])) {

                $cleaned = $cleaned.Remove($j, 2)
                $modified = $true
                $index = $q + 1
                continue
            }

            # caso 2: "nTexto
            if ($cleaned[$j] -eq 'n' -and
                $j + 1 -lt $cleaned.Length -and
                [char]::IsLetter($cleaned[$j + 1])) {

                $cleaned = $cleaned.Remove($j, 1)
                $modified = $true
                $index = $q + 1
                continue
            }

            $index = $q + 1
        }

        if ($modified) {
            Write-Host ""
            Write-Host "⚠ Prefijo corrupto detectado en línea $($i+1):" -ForegroundColor Yellow
            Write-Host "   Original:  $original" -ForegroundColor DarkYellow
            Write-Host "   Propuesta: $cleaned"  -ForegroundColor Cyan

            $ans = Read-Host "¿Aplicar corrección? (s/n)"
            if ($ans -notin @('s', 'S')) {
                $cleaned = $original
            }
            else {
                $changed = $true
            }
        }

        $newLines += $cleaned
    }

    if (-not $changed) {
        Write-Host "✔ Archivo sin prefijos corruptos." -ForegroundColor Green
        return "SKIPPED"
    }

    # Backup antes de sobrescribir
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backup = "$FilePath.bak_$timestamp"
    Copy-Item -LiteralPath $FilePath -Destination $backup -Force
    Write-Host "✔ Backup creado: $backup" -ForegroundColor DarkYellow

    # Guardar archivo corregido
    $utf8bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllLines($FilePath, $newLines, $utf8bom)

    Write-Host "✔ Archivo corregido y guardado." -ForegroundColor Green
    return "FIXED"
}



# -------------------------------------------------------------------
# PROCESO GLOBAL
# -------------------------------------------------------------------

$fixed = 0
$skipped = 0

foreach ($f in $files) {
    $result = Repair-CorruptStringPrefixes -FilePath $f.FullName
    if ($result -eq "FIXED") { $fixed++ }
    if ($result -eq "SKIPPED") { $skipped++ }
}

Write-Host "`n=== RESUMEN ===" -ForegroundColor Cyan
Write-Host "Archivos corregidos:   $fixed"   -ForegroundColor Green
Write-Host "Archivos sin cambios:  $skipped" -ForegroundColor Yellow
Write-Host "Total procesados:      $($files.Count)"
Write-Host "========================================" -ForegroundColor Cyan
