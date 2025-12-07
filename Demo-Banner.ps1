<#
.SYNOPSIS
    Demo de la función Show-Banner

.DESCRIPTION
    Muestra ejemplos de uso de la función Show-Banner con diferentes opciones de personalización.
#>

# Importar la función desde Llevar.ps1
$scriptPath = Join-Path $PSScriptRoot "Llevar.ps1"
. $scriptPath

Clear-Host

Write-Host "`n=== DEMO: Show-Banner ===`n" -ForegroundColor White

# Ejemplo 1: Banner simple centrado
Write-Host "1. Banner simple centrado:" -ForegroundColor Yellow
Show-Banner -Text "LLEVAR.PS1"
Start-Sleep -Milliseconds 500

# Ejemplo 2: Banner con múltiples líneas
Write-Host "`n2. Banner con múltiples líneas:" -ForegroundColor Yellow
Show-Banner -Text @("ROBOCOPY MIRROR", "COPIA ESPEJO") -BorderColor Yellow -TextColor Cyan
Start-Sleep -Milliseconds 500

# Ejemplo 3: Banner alineado a la izquierda
Write-Host "`n3. Banner alineado a la izquierda:" -ForegroundColor Yellow
Show-Banner -Text "INSTALACIÓN COMPLETA" -Alignment Left -BorderColor Green -TextColor Green
Start-Sleep -Milliseconds 500

# Ejemplo 4: Banner alineado a la derecha
Write-Host "`n4. Banner alineado a la derecha:" -ForegroundColor Yellow
Show-Banner -Text "ADVERTENCIA" -Alignment Right -BorderColor Red -TextColor Red
Start-Sleep -Milliseconds 500

# Ejemplo 5: Banner con caracteres personalizados
Write-Host "`n5. Banner con caracteres personalizados:" -ForegroundColor Yellow
Show-Banner -Text "PROGRESO" -BorderChar '-' -BorderColor Magenta -TextColor White
Start-Sleep -Milliseconds 500

# Ejemplo 6: Banner con padding amplio
Write-Host "`n6. Banner con padding amplio:" -ForegroundColor Yellow
Show-Banner -Text "IMPORTANTE" -Padding 5 -BorderColor Cyan -TextColor Yellow
Start-Sleep -Milliseconds 500

# Ejemplo 7: Banner con fondo de color
Write-Host "`n7. Banner con fondo de color:" -ForegroundColor Yellow
Show-Banner -Text "DESTACADO" -BorderColor White -TextColor Black -BackgroundColor DarkGray
Start-Sleep -Milliseconds 500

# Ejemplo 8: Banner posicionado manualmente
Write-Host "`n8. Banner posicionado manualmente (X=10, Y=2):" -ForegroundColor Yellow
Write-Host "`n`n"  # Espacio para posicionamiento
Show-Banner -Text "POSICIONADO" -X 10 -Y 2 -BorderColor DarkYellow -TextColor Yellow
Write-Host "`n`n`n"  # Espacio después

# Ejemplo 9: Banner estilo error
Write-Host "9. Banner estilo error:" -ForegroundColor Yellow
Show-Banner -Text "✗ ERROR" -BorderColor Red -TextColor White -BackgroundColor DarkRed
Start-Sleep -Milliseconds 500

# Ejemplo 10: Banner estilo éxito
Write-Host "`n10. Banner estilo éxito:" -ForegroundColor Yellow
Show-Banner -Text "✓ COMPLETADO" -BorderColor Green -TextColor White -BackgroundColor DarkGreen
Start-Sleep -Milliseconds 500

# Ejemplo 11: Banner multi-línea centrado
Write-Host "`n11. Banner multi-línea centrado:" -ForegroundColor Yellow
Show-Banner -Text @("SISTEMA DE TRANSFERENCIA", "LLEVAR.PS1", "Versión 3.0") -BorderColor Cyan -TextColor White
Start-Sleep -Milliseconds 500

# Ejemplo 12: Banner con emojis
Write-Host "`n12. Banner con caracteres especiales:" -ForegroundColor Yellow
Show-Banner -Text "⚡ ALTA VELOCIDAD ⚡" -BorderColor Yellow -TextColor Yellow
Start-Sleep -Milliseconds 500

Write-Host "`n=== FIN DEL DEMO ===`n" -ForegroundColor White
Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
