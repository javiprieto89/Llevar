# ============================================================================ #
# Demo de Banners Corregidos
# ============================================================================ #

# Importar módulo
Import-Module "$PSScriptRoot\Modules\UI\Banners.psm1" -Force

Clear-Host

Write-Host "`n════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
Write-Host "DEMOSTRACIÓN DE BANNERS CORREGIDOS" -ForegroundColor Yellow
Write-Host "Verificación de caracteres UTF-8 (╔ ╗ ╚ ╝ ═ ║) y centrado" -ForegroundColor White
Write-Host "`n════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Banner simple
Write-Host "`n1. Banner simple:" -ForegroundColor Green
Show-Banner "LLEVAR.PS1"

# Banner con título del mensaje del usuario
Write-Host "`n2. Banner del mensaje original del usuario:" -ForegroundColor Green
Show-Banner @(
    "LLEVAR-USB - Sistema de transporte de carpetas en múltiples USBs",
    "Versión PowerShell del clásico LLEVAR.BAT de Alex Soft"
) -BorderColor Cyan -TextColor White

# Banner con múltiples líneas de diferentes longitudes
Write-Host "`n3. Banner con líneas de diferentes longitudes (prueba de centrado):" -ForegroundColor Green
Show-Banner @(
    "Corta",
    "Esta es una línea mucho más larga",
    "Media línea",
    "XL"
) -BorderColor Yellow -TextColor Cyan

# Banner con colores diferentes
Write-Host "`n4. Banner con colores personalizados:" -ForegroundColor Green
Show-Banner @(
    "ROBOCOPY MIRROR",
    "COPIA ESPEJO"
) -BorderColor Magenta -TextColor Green

# Banner de éxito
Write-Host "`n5. Banner de éxito:" -ForegroundColor Green
Show-Banner "✓ OPERACIÓN COMPLETADA" -BorderColor Green -TextColor Green

# Banner de error
Write-Host "`n6. Banner de advertencia:" -ForegroundColor Green
Show-Banner "⚠ ADVERTENCIA" -BorderColor Red -TextColor Yellow

# Banner con padding personalizado
Write-Host "`n7. Banner con más padding:" -ForegroundColor Green
Show-Banner "Con padding extra" -BorderColor Cyan -TextColor White -Padding 5

Write-Host "`n════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
Write-Host "PRUEBA COMPLETADA" -ForegroundColor Green
Write-Host "Todos los banners deberían mostrar:" -ForegroundColor White
Write-Host "  • Caracteres de borde UTF-8: ╔ ╗ ╚ ╝ ═ ║" -ForegroundColor White
Write-Host "  • Texto centrado correctamente" -ForegroundColor White
Write-Host "  • Colores aplicados correctamente" -ForegroundColor White
Write-Host "`n════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "`nPresiona cualquier tecla para continuar..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
