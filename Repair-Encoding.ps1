param(
    [Parameter(Mandatory)]
    [string]$Path,

    [switch]$Recurse
)

# TABLA DE REEMPLAZOS (caracteres corruptos → correctos)
$FixTable = @{

    # Acentos y caracteres latinos mal decodificados
    ([string][char]0xC3 + [char]0xA1) = "á";   # Ã¡
    ([string][char]0xC3 + [char]0xA9) = "é";   # Ã©
    ([string][char]0xC3 + [char]0xAD) = "í";   # Ã­
    ([string][char]0xC3 + [char]0xB3) = "ó";   # Ã³
    ([string][char]0xC3 + [char]0xBA) = "ú";   # Ãº
    ([string][char]0xC3 + [char]0xB1) = "ñ";   # Ã±
    ([string][char]0xC3 + [char]0x91) = "Ñ";   # Ã‘
    ([string][char]0xC3 + [char]0xBC) = "ü";   # Ã¼
    ([string][char]0xC3 + [char]0x9C) = "Ü";   # Ãœ

    # Puntuación maldecodificada
    ([string][char]0xE2 + [char]0x80 + [char]0x94) = "—";   # â€” 
    ([string][char]0xE2 + [char]0x80 + [char]0x93) = "–";   # â€“
    ([string][char]0xE2 + [char]0x80 + [char]0xA6) = "…";   # â€¦
    ([string][char]0xE2 + [char]0x80 + [char]0xA2) = "•";   # â€¢
    ([string][char]0xE2 + [char]0x9C + [char]0x93) = "✓";   # âœ“
	
	# -----------------------------
    # LÍNEAS SIMPLES (U+2500–U+257F)
    # -----------------------------
    ([string][char]0xE2 + [char]0x94 + [char]0x80) = "─";  # BOX DRAWINGS LIGHT HORIZONTAL
    ([string][char]0xE2 + [char]0x94 + [char]0x82) = "│";  # LIGHT VERTICAL
    ([string][char]0xE2 + [char]0x94 + [char]0x8C) = "┌";
    ([string][char]0xE2 + [char]0x94 + [char]0x90) = "┐";
    ([string][char]0xE2 + [char]0x94 + [char]0x94) = "└";
    ([string][char]0xE2 + [char]0x94 + [char]0x98) = "┘";

    ([string][char]0xE2 + [char]0x94 + [char]0x9C) = "├";
    ([string][char]0xE2 + [char]0x94 + [char]0xA4) = "┤";
    ([string][char]0xE2 + [char]0x94 + [char]0xAC) = "┬";
    ([string][char]0xE2 + [char]0x94 + [char]0xB4) = "┴";
    ([string][char]0xE2 + [char]0x94 + [char]0xBC) = "┼";

    # -----------------------------
    # LÍNEAS DOBLES (U+2550–U+256C)
    # -----------------------------
    ([string][char]0xE2 + [char]0x95 + [char]0x90) = "═"; # double horizontal
    ([string][char]0xE2 + [char]0x95 + [char]0x91) = "║"; # double vertical
    ([string][char]0xE2 + [char]0x95 + [char]0x94) = "╔";
    ([string][char]0xE2 + [char]0x95 + [char]0x97) = "╗";
    ([string][char]0xE2 + [char]0x95 + [char]0x9A) = "╚";
    ([string][char]0xE2 + [char]0x95 + [char]0x9D) = "╝";

    ([string][char]0xE2 + [char]0x95 + [char]0xA0) = "╠";
    ([string][char]0xE2 + [char]0x95 + [char]0xA3) = "╣";
    ([string][char]0xE2 + [char]0x95 + [char]0xA6) = "╦";
    ([string][char]0xE2 + [char]0x95 + [char]0xA9) = "╩";
    ([string][char]0xE2 + [char]0x95 + [char]0xAC) = "╬";

    # -----------------------------
    # LÍNEAS MIXTAS (DOBLE + SIMPLE)
    # -----------------------------
    ([string][char]0xE2 + [char]0x95 + [char]0x95) = "╕";
    ([string][char]0xE2 + [char]0x95 + [char]0x96) = "╖";
    ([string][char]0xE2 + [char]0x95 + [char]0x98) = "╘";
    ([string][char]0xE2 + [char]0x95 + [char]0x99) = "╙";
    ([string][char]0xE2 + [char]0x95 + [char]0x9B) = "╛";
    ([string][char]0xE2 + [char]0x95 + [char]0x9C) = "╜";

    ([string][char]0xE2 + [char]0x95 + [char]0x9E) = "╞";
    ([string][char]0xE2 + [char]0x95 + [char]0x9F) = "╟";
    ([string][char]0xE2 + [char]0x95 + [char]0xA1) = "╡";
    ([string][char]0xE2 + [char]0x95 + [char]0xA2) = "╢";

    ([string][char]0xE2 + [char]0x95 + [char]0xA4) = "╤";
    ([string][char]0xE2 + [char]0x95 + [char]0xA5) = "╥";
    ([string][char]0xE2 + [char]0x95 + [char]0xA7) = "╧";
    ([string][char]0xE2 + [char]0x95 + [char]0xA8) = "╨";    

    ([string][char]0xE2 + [char]0x95 + [char]0xAA) = "╪";
    ([string][char]0xE2 + [char]0x95 + [char]0xAB) = "╫";

    # -----------------------------
    # BLOQUES (U+2580–U+259F)
    # -----------------------------
    ([string][char]0xE2 + [char]0x96 + [char]0x80) = "▀";
    ([string][char]0xE2 + [char]0x96 + [char]0x84) = "▄";
    ([string][char]0xE2 + [char]0x96 + [char]0x88) = "█";
    ([string][char]0xE2 + [char]0x96 + [char]0x89) = "▉";
    ([string][char]0xE2 + [char]0x96 + [char]0x8A) = "▊";
    ([string][char]0xE2 + [char]0x96 + [char]0x8B) = "▋";
    ([string][char]0xE2 + [char]0x96 + [char]0x8C) = "▌";
    ([string][char]0xE2 + [char]0x96 + [char]0x8D) = "▍";
    ([string][char]0xE2 + [char]0x96 + [char]0x8E) = "▎";
    ([string][char]0xE2 + [char]0x96 + [char]0x8F) = "▏";

    ([string][char]0xE2 + [char]0x96 + [char]0x91) = "░";
    ([string][char]0xE2 + [char]0x96 + [char]0x92) = "▒";
    ([string][char]0xE2 + [char]0x96 + [char]0x93) = "▓";

    # -----------------------------
    # FLECHAS (U+2190–U+21AF)
    # -----------------------------
    ([string][char]0xE2 + [char]0x86 + [char]0x90) = "←";
    ([string][char]0xE2 + [char]0x86 + [char]0x91) = "↑";
    ([string][char]0xE2 + [char]0x86 + [char]0x92) = "→";
    ([string][char]0xE2 + [char]0x86 + [char]0x93) = "↓";
    ([string][char]0xE2 + [char]0x87 + [char]0x94) = "↔";
    ([string][char]0xE2 + [char]0x87 + [char]0x95) = "↕";
}


# ---------------------------------------------
function Test-BOM {
    param([string]$FilePath)

    try {
        $bytes = [IO.File]::ReadAllBytes($FilePath)

        if ($bytes.Length -lt 3) { 
            return @{ HasBOM = $false; Bytes = $bytes } 
        }

        $BOM = $bytes[0..2]
        $HasBOM = ($BOM[0] -eq 239 -and $BOM[1] -eq 187 -and $BOM[2] -eq 191)

        return @{
            HasBOM = $HasBOM
            Bytes  = $BOM
        }
    }
    catch {
        return @{ HasBOM = $false; Bytes = @() }
    }
}


# ---------------------------------------------
function Repair-File {
    param([string]$FilePath)

    Write-Host "`n→ Analizando archivo: $FilePath" -ForegroundColor Cyan

    # 1) Info de BOM
    $bomInfo = Test-BOM -FilePath $FilePath

    # 2) Leer texto tal como lo ve PowerShell
    $text = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8

    # 3) Detectar si tiene patrones corruptos conocidos
    $containsCorruption = $false
    foreach ($key in $FixTable.Keys) {
        if ($text.Contains($key)) {
            $containsCorruption = $true
            break
        }
    }

    # 4) Caso: archivo ya está OK → se saltea sin preguntar
    if ($bomInfo.HasBOM -and -not $containsCorruption) {
        Write-Host ("   ✔ Archivo OK (UTF-8 con BOM, sin patrones corruptos). " +
                    "BOM: {0}" -f ($bomInfo.Bytes -join ', ')) -ForegroundColor Green
        return
    }

    # 5) Caso: sospechoso (sin BOM o con patrones corruptos)
    if (-not $bomInfo.HasBOM) {
        Write-Host ("   ❗ No tiene BOM. Primeros bytes: {0}" -f ($bomInfo.Bytes -join ', ')) -ForegroundColor Yellow
    }
    if ($containsCorruption) {
        Write-Host "   ❗ Se detectaron secuencias corruptas conocidas." -ForegroundColor Yellow
    }

    # 6) Preguntar si se quiere reparar
    $answer = Read-Host "¿Deseás reparar este archivo? (s/n)"
    if ($answer -notin @('s','S')) {
        Write-Host "   → Archivo saltado por el usuario." -ForegroundColor DarkYellow
        return
    }

    # 7) Backup
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backup = "$FilePath.bak_$timestamp"
    Copy-Item -LiteralPath $FilePath -Destination $backup -Force
    Write-Host "   ✔ Backup creado: $backup" -ForegroundColor DarkYellow

    # 8) Aplicar reemplazos de FixTable
    $repaired = $text
    foreach ($key in $FixTable.Keys) {
        $repaired = $repaired.Replace($key, $FixTable[$key])
    }

    # 9) Guardar como UTF-8 con BOM
    $utf8bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($FilePath, $repaired, $utf8bom)

    Write-Host "   ✔ Reparación aplicada y guardada en UTF-8 con BOM." -ForegroundColor Green
}


# ---------------------------------------------
# PROCESAR ARCHIVO O CARPETA
# ---------------------------------------------
Write-Host "==== Reparador UTF-8 con BOM + corrección de caracteres ====" -ForegroundColor Cyan

if (-not (Test-Path $Path)) {
    Write-Host "❌ La ruta no existe: $Path" -ForegroundColor Red
    exit 1
}

$extensions = @(".ps1",".psm1",".psd1")

if (Test-Path $Path -PathType Leaf) {
    $files = @(Get-Item -LiteralPath $Path)
}
else {
    if ($Recurse) {
        $files = Get-ChildItem -LiteralPath $Path -Recurse -File |
                 Where-Object { $extensions -contains $_.Extension.ToLower() }
    }
    else {
        $files = Get-ChildItem -LiteralPath $Path -File |
                 Where-Object { $extensions -contains $_.Extension.ToLower() }
    }
}

if ($files.Count -eq 0) {
    Write-Host "❌ No se encontraron archivos .ps1/.psm1/.psd1 en la ruta." -ForegroundColor Red
    exit
}

Write-Host "Archivos encontrados: $($files.Count)" -ForegroundColor Cyan

$fixed = 0
$skipped = 0
$partial = 0

foreach ($f in $files) {
    $r = Repair-File $f.FullName
    switch ($r) {
        "FIXED"   { $fixed++ }
        "SKIPPED" { $skipped++ }
        "PARTIAL" { $partial++ }
    }
}

Write-Host "`n=========== RESUMEN ===========" -ForegroundColor Cyan
Write-Host "Reparados correctamente: $fixed" -ForegroundColor Green
Write-Host "Saltados por usuario:    $skipped" -ForegroundColor Yellow
Write-Host "Reparados parcialmente:  $partial" -ForegroundColor DarkYellow
Write-Host "Total archivos:          $($files.Count)"
Write-Host "================================" -ForegroundColor Cyan
