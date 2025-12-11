<#
.SYNOPSIS
    Escanea todos los módulos .ps1 y .psm1 buscando caracteres invisibles
    y genera un archivo de reporte InvisibleCharsReport.txt
#>

$Root = "Q:\Utilidad\LLevar\Modules"
$LogPath = Join-Path $PSScriptRoot "InvisibleCharsReport.txt"

# Borrar log previo si existe
if (Test-Path $LogPath) { Remove-Item $LogPath -Force }

# Lista de caracteres a detectar
$patterns = @(
    0x200B, # Zero Width Space
    0x200C, # Zero Width Non Joiner
    0x200D, # Zero Width Joiner
    0xFEFF, # BOM
    0x00A0, # Non-breaking space
    0x3000  # Fullwidth space
)

# Encabezado del log
$header = @"
===========================================================
   ESCÁNER DE CARACTERES INVISIBLES - LLEVAR
   Fecha: $(Get-Date)
   Carpeta analizada: $Root
===========================================================

"@
Add-Content -Path $LogPath -Value $header -Encoding UTF8

Write-Host "ESCANEANDO MÓDULOS EN: $Root" -ForegroundColor Cyan
Write-Host "Se generará un log en: $LogPath"
Write-Host ""

Get-ChildItem -Path $Root -Recurse -Include *.ps1, *.psm1, *.psd1 | ForEach-Object {
    $file = $_.FullName
    $lines = Get-Content $file -Raw

    $found = $false
    Add-Content $LogPath "`n--- Archivo: $file ---`n"

    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]

        for ($j = 0; $j -lt $line.Length; $j++) {
            $code = [int][char]$line[$j]
            $col = $j + 1
            $row = $i + 1
            $unicode = "U+$('{0:X4}' -f $code)"

            if ($code -lt 32 -and $code -notin @(9, 10, 13)) {
                $msg = "[CONTROL] $file (Línea $row, Col $col) -> $unicode"
                Write-Host $msg -ForegroundColor Red
                Add-Content $LogPath $msg
                $found = $true
            }
            elseif ($patterns -contains $code) {
                $msg = "[INVISIBLE] $file (Línea $row, Col $col) -> $unicode"
                Write-Host $msg -ForegroundColor Yellow
                Add-Content $LogPath $msg
                $found = $true
            }
            elseif ($code -gt 127) {
                $msg = "[UNICODE] $file (Línea $row, Col $col) -> $unicode '$($line[$j])'"
                Write-Host $msg -ForegroundColor Magenta
                Add-Content $LogPath $msg
                $found = $true
            }
        }
    }

    if ($found) {
        Add-Content $LogPath "→ Revisión recomendada de este archivo.`n"
    }
}

Write-Host "`n✓ Escaneo completado." -ForegroundColor Green
Write-Host "El reporte está en: $LogPath" -ForegroundColor Cyan
