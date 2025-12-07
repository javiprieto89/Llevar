param (
    [string]$Path = ".\Modules",
    [string]$BackupDir = ".\Backup-CleanModules"
)

Write-Host "=== LIMPIANDO CARACTERES INVISIBLES ===" -ForegroundColor Cyan

# Crear backup
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

# ==============================
# DEFINIR CARACTERES INVÁLIDOS
# ==============================

$Invalid = New-Object System.Collections.Generic.HashSet[int]

# Rango 0–8
0..8 | ForEach-Object { $Invalid.Add($_) | Out-Null }
# 11–12
11..12 | ForEach-Object { $Invalid.Add($_) | Out-Null }
# 14–31
14..31 | ForEach-Object { $Invalid.Add($_) | Out-Null }

# ASCII problemáticos específicos
$Invalid.Add(127) | Out-Null
$Invalid.Add(129) | Out-Null
$Invalid.Add(141) | Out-Null
$Invalid.Add(143) | Out-Null
$Invalid.Add(144) | Out-Null
$Invalid.Add(157) | Out-Null

# Procesar archivos
Get-ChildItem $Path -Recurse -Include *.ps1, *.psm1 | ForEach-Object {

    $file = $_.FullName
    Write-Host "`nProcesando: $file" -ForegroundColor Yellow

    # Backup
    $destBackup = Join-Path $BackupDir $_.Name
    Copy-Item $file -Destination $destBackup -Force

    $bytes = [System.IO.File]::ReadAllBytes($file)
    $clean = New-Object System.Collections.Generic.List[byte]

    $removed = 0

    foreach ($b in $bytes) {
        if ($Invalid.Contains($b)) {
            $removed++
        }
        else {
            $clean.Add($b)
        }
    }

    # Reescribir archivo limpio
    [System.IO.File]::WriteAllBytes($file, $clean.ToArray())

    if ($removed -gt 0) {
        $color = "Green"
    }
    else {
        $color = "DarkGray"
    }

    Write-Host (" → Eliminados: {0} caracteres inválidos" -f $removed) -ForegroundColor $color
}

Write-Host "`n=== PROCESO COMPLETADO ===" -ForegroundColor Cyan
Write-Host "Backup en: $BackupDir" -ForegroundColor Gray
