<#
.SYNOPSIS
    Repara archivos PowerShell con problemas de encoding y caracteres corruptos

.DESCRIPTION
    - Convierte encoding a UTF-8 sin BOM
    - Reemplaza caracteres corruptos Unicode por sus equivalentes válidos
    - Arregla saltos de línea (CRLF a LF)
    - Limpia caracteres especiales problemáticos

.PARAMETER FilePath
    Ruta del archivo PSM1 o PS1 a reparar

.PARAMETER BackupOriginal
    Si $true, crea un backup del archivo original

.EXAMPLE
    .\Fix-PowerShellEncoding.ps1 -FilePath "C:\script.psm1" -BackupOriginal $true
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    
    [Parameter(Mandatory = $false)]
    [bool]$BackupOriginal = $true
)

# Validar que el archivo existe
if (-not (Test-Path $FilePath)) {
    Write-Host "ERROR: Archivo no encontrado: $FilePath" -ForegroundColor Red
    exit 1
}

Write-Host "Reparando archivo: $FilePath" -ForegroundColor Cyan
Write-Host ""

# Crear backup si se solicita
if ($BackupOriginal) {
    $backupPath = "$FilePath.bak"
    Copy-Item $FilePath $backupPath -Force
    Write-Host "Backup creado en: $backupPath" -ForegroundColor Green
}

# Leer el archivo con encoding UTF8
$content = Get-Content $FilePath -Raw -Encoding UTF8

Write-Host "Archivo leido" -ForegroundColor Green

Write-Host "Limpiando caracteres problematicos..." -ForegroundColor Yellow

# Remover caracteres de control problemáticos
$content = $content -replace '[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]', ''

# Reemplazar caracteres corruptos comunes con regex
$content = $content -replace [regex]::Escape([char]0xE2 + [char]0x80 + [char]0x9C), '"'  # Comilla izquierda
$content = $content -replace [regex]::Escape([char]0xE2 + [char]0x80 + [char]0x9D), '"'  # Comilla derecha
$content = $content -replace [regex]::Escape([char]0xE2 + [char]0x80 + [char]0x93), '-'  # Guion
$content = $content -replace [regex]::Escape([char]0xE2 + [char]0x80 + [char]0x94), '--' # Guion largo
$content = $content -replace [regex]::Escape([char]0xE2 + [char]0x80 + [char]0x98), "'"  # Comilla simple izq
$content = $content -replace [regex]::Escape([char]0xE2 + [char]0x80 + [char]0x99), "'"  # Comilla simple der
$content = $content -replace [regex]::Escape([char]0xE2 + [char]0x80 + [char]0xA2), '*'  # Bullet

Write-Host "Caracteres problematicos eliminados" -ForegroundColor Green

# Normalizar saltos de línea a LF
$originalContent = $content
$content = $content -replace "`r`n", "`n"

if ($originalContent -ne $content) {
    Write-Host "Saltos de linea normalizados a LF" -ForegroundColor Green
}

# Guardar archivo reparado en UTF-8 sin BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($FilePath, $content, $utf8NoBom)

Write-Host ""
Write-Host "Archivo guardado en UTF-8 sin BOM" -ForegroundColor Green

# Validar sintaxis
Write-Host ""
Write-Host "Validando sintaxis PowerShell..." -ForegroundColor Cyan

try {
    $tokens = @()
    $errors = @()
    $null = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors)
    
    if ($errors.Count -eq 0) {
        Write-Host "Sintaxis valida sin errores" -ForegroundColor Green
    }
    else {
        Write-Host "Se encontraron $($errors.Count) errores de sintaxis:" -ForegroundColor Yellow
        foreach ($err in $errors) {
            Write-Host "  Linea $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "Error al validar sintaxis: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Resumen:" -ForegroundColor Cyan
Write-Host "  - Encoding: UTF-8 sin BOM" -ForegroundColor White
Write-Host "  - Caracteres corruptos: Reparados" -ForegroundColor White
Write-Host "  - Backup: $(if ($BackupOriginal) { $backupPath } else { 'No creado' })" -ForegroundColor White
Write-Host ""
Write-Host "Intenta importar nuevamente:" -ForegroundColor Cyan
Write-Host "  Import-Module '$FilePath'" -ForegroundColor Gray
Write-Host ""