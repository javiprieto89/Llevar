<#
.SYNOPSIS
  Compara archivos originales vs cifrados (.qXxhkPHLv) en el MISMO árbol
  de directorios, de forma recursiva y forense (solo lectura).

.DESCRIPTION
  - Original:  archivo.ext
  - Cifrado:   archivo.ext.qXxhkPHLv
  - Ambos conviven en el mismo directorio
  - Empareja por nombre exacto del original
  - Detecta invariantes (header/footer), delta de tamaño,
    y posibles IV/nonce repetidos

.USAGE
  Ejecutar desde el directorio raíz:
    .\Compare-LockbitPairs.ps1

  O especificar raíz:
    .\Compare-LockbitPairs.ps1 -RootPath "D:\Datos"

.OUTPUT
  analysis.csv en el mismo directorio del script
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Get-Location).Path,

    [string]$EncryptedExtension = ".qXxhkPHLv",

    [int]$HeaderBytes = 256,
    [int]$FooterBytes = 256,

    # Candidato a IV/nonce dentro del header
    [int]$CandidateOffset = 16,
    [int]$CandidateLength = 16,

    [string]$OutCsv = "analysis.csv"
)

function Read-Bytes {
    param(
        [string]$Path,
        [long]$Offset,
        [int]$Count
    )
    $fs = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
    try {
        if ($Offset -gt 0) { $fs.Seek($Offset, 'Begin') | Out-Null }
        $buf = New-Object byte[] $Count
        $read = $fs.Read($buf, 0, $Count)
        if ($read -lt $Count) {
            return $buf[0..($read - 1)]
        }
        return $buf
    }
    finally { $fs.Close() }
}

function To-Hex($Bytes) {
    if (-not $Bytes) { return "" }
    ($Bytes | ForEach-Object { $_.ToString("x2") }) -join ""
}

function Hash-SHA256($Bytes) {
    if (-not $Bytes) { return "" }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        ($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
    }
    finally { $sha.Dispose() }
}

Write-Host "== Analisis LockBit (.qXxhkPHLv) =="
Write-Host "Raiz: $RootPath"
Write-Host ""

# 1️ Recolectar originales (NO terminan en .qXxhkPHLv)
$originals = Get-ChildItem -Path $RootPath -Recurse -File |
Where-Object { -not $_.Name.EndsWith($EncryptedExtension) }

$results = New-Object System.Collections.Generic.List[object]

foreach ($orig in $originals) {

    $encPath = $orig.FullName + $EncryptedExtension

    if (-not (Test-Path -LiteralPath $encPath)) {
        continue
    }

    $origLen = $orig.Length
    $encLen = (Get-Item -LiteralPath $encPath).Length

    $delta = $encLen - $origLen
    $deltaPct = if ($origLen -gt 0) {
        [Math]::Round(($delta / $origLen) * 100, 4)
    }
    else { $null }

    # Header / Footer del cifrado
    $hb = [Math]::Min($HeaderBytes, $encLen)
    $fb = [Math]::Min($FooterBytes, $encLen)

    $header = Read-Bytes -Path $encPath -Offset 0 -Count $hb
    $footer = Read-Bytes -Path $encPath -Offset ([Math]::Max(0, $encLen - $fb)) -Count $fb

    $headerHash = Hash-SHA256 $header
    $footerHash = Hash-SHA256 $footer

    # Candidato a IV / nonce
    $candHex = ""
    if ($encLen -ge ($CandidateOffset + $CandidateLength)) {
        $cand = Read-Bytes -Path $encPath -Offset $CandidateOffset -Count $CandidateLength
        $candHex = To-Hex $cand
    }

    $results.Add([pscustomobject]@{
            RelativePath       = $orig.FullName.Substring($RootPath.Length).TrimStart('\')
            OriginalFile       = $orig.Name
            EncryptedFile      = (Split-Path $encPath -Leaf)

            OriginalBytes      = $origLen
            EncryptedBytes     = $encLen
            DeltaBytes         = $delta
            DeltaPercent       = $deltaPct

            HeaderHash         = $headerHash
            FooterHash         = $footerHash

            CandidateHex       = $candHex
            CandidateDuplicate = ""
        })
}

# 2 Detectar duplicados del candidato (IV/nonce)
$dups = $results |
Where-Object { $_.CandidateHex } |
Group-Object CandidateHex |
Where-Object { $_.Count -gt 1 }

$dupMap = @{}
foreach ($g in $dups) {
    $tag = "DUP_" + $g.Name.Substring(0, 12)
    foreach ($r in $g.Group) {
        $dupMap[$r.RelativePath] = $tag
    }
}

foreach ($r in $results) {
    if ($dupMap.ContainsKey($r.RelativePath)) {
        $r.CandidateDuplicate = $dupMap[$r.RelativePath]
    }
}

# 3️ Exportar CSV
$results | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8

Write-Host "== Analisis completado =="
Write-Host "Archivos analizados: $($results.Count)"
Write-Host "Salida: $OutCsv"
Write-Host ""

# Resumen rápido
Write-Host "Top Headers repetidos:"
$results | Group-Object HeaderHash | Sort-Object Count -Descending |
Select-Object -First 5 | ForEach-Object {
    Write-Host "  $($_.Count) archivos"
}

Write-Host ""
Write-Host "Top Footers repetidos:"
$results | Group-Object FooterHash | Sort-Object Count -Descending |
Select-Object -First 5 | ForEach-Object {
    Write-Host "  $($_.Count) archivos"
}

Write-Host ""
if ($dups.Count -gt 0) {
    Write-Host "⚠️ POSIBLES IV/NONCE DUPLICADOS DETECTADOS"
    $dups | ForEach-Object {
        Write-Host "  $($_.Count) archivos comparten CandidateHex=$($_.Name.Substring(0,16))..."
    }
}
else {
    Write-Host "✅ No se detectaron duplicados del candidato IV/nonce."
}

Write-Host ""
Write-Host "Sugerencia:"
Write-Host "  Repetir con -CandidateOffset 0, 8, 32, 64 y CandidateLength 12 o 16"
