param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

if (-not (Test-Path $Path)) {
    Write-Host "El archivo no existe: $Path" -ForegroundColor Red
    exit
}

Write-Host "Convirtiendo archivo a UTF-8 limpio..." -ForegroundColor Cyan

# Leer texto usando distintas codificaciones seguras
$encodings = @(
    [System.Text.Encoding]::UTF8,
    [System.Text.Encoding]::GetEncoding(1252),
    [System.Text.Encoding]::ASCII,
    [System.Text.Encoding]::GetEncoding("iso-8859-1"),
    [System.Text.Encoding]::GetEncoding(850)
)

$content = $null

foreach ($enc in $encodings) {
    try {
        $tmp = $enc.GetString([System.IO.File]::ReadAllBytes($Path))
        if ($tmp -notmatch "�{2,}") {
            $content = $tmp
            break
        }
    }
    catch {}
}

if (-not $content) {
    $content = [System.Text.Encoding]::GetEncoding("iso-8859-1").GetString(
        [System.IO.File]::ReadAllBytes($Path)
    )
}

# Guardar en UTF-8 sin BOM
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($Path, $content, $utf8)

Write-Host "Conversión completada." -ForegroundColor Green
