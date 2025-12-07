# Cerrar VS Code para evitar archivos bloqueados
Get-Process code -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 1

# Carpetas de cache de VS Code (seguras)
$paths = @(
    "$env:APPDATA\Code\Cache",
    "$env:APPDATA\Code\CachedData",
    "$env:APPDATA\Code\User\workspaceStorage"
)

foreach ($p in $paths) {
    if (Test-Path $p) {
        Write-Host "Eliminando cache: $p" -ForegroundColor Yellow
        Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "No existe: $p" -ForegroundColor DarkGray
    }
}

Write-Host "`nCache limpiado sin tocar extensiones." -ForegroundColor Green
Write-Host "Ahora abrí VS Code." -ForegroundColor Green
