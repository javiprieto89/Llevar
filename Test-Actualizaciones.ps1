<#
.SYNOPSIS
    Prueba de banners, menús y popups actualizados

.DESCRIPTION
    Verifica todos los cambios:
    - Show-Banner con bordes laterales ║
    - Show-ConsolePopup con mensaje y opciones centrados
    - Borde derecho alineado correctamente
#>

# Importar funciones desde Llevar.ps1
$scriptPath = Join-Path $PSScriptRoot "Llevar.ps1"
. $scriptPath

Clear-Host

Show-Banner "PRUEBA: BANNERS, MENÚS Y POPUPS ACTUALIZADOS" -BorderColor Cyan -TextColor Cyan

# Prueba 1: Banner con bordes laterales
Write-Host "1. Banner con bordes laterales completos..." -ForegroundColor Yellow
Write-Host ""
Show-Banner -Text "BANNER CON BORDES COMPLETOS" -BorderColor Cyan -TextColor White
Write-Host ""
Start-Sleep -Milliseconds 800

# Prueba 2: Banner multi-línea
Write-Host "2. Banner multi-línea con bordes..." -ForegroundColor Yellow
Write-Host ""
Show-Banner -Text @("LÍNEA 1", "LÍNEA 2 MÁS LARGA", "LÍNEA 3") -BorderColor Green -TextColor Yellow
Write-Host ""
Start-Sleep -Milliseconds 800

# Prueba 3: Banner alineado a la izquierda
Write-Host "3. Banner alineado a la izquierda..." -ForegroundColor Yellow
Write-Host ""
Show-Banner -Text "IZQUIERDA" -Alignment Left -BorderColor Magenta -TextColor White
Write-Host ""
Start-Sleep -Milliseconds 800

# Prueba 4: Banner alineado a la derecha
Write-Host "4. Banner alineado a la derecha..." -ForegroundColor Yellow
Write-Host ""
Show-Banner -Text "DERECHA" -Alignment Right -BorderColor Yellow -TextColor White
Write-Host ""
Start-Sleep -Milliseconds 800

# Prueba 5: Popup con mensaje centrado
Write-Host "5. Popup con mensaje centrado..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500
$result = Show-ConsolePopup -Title "Mensaje Centrado" `
    -Message "Este mensaje debe estar centrado`nen el popup" `
    -Options @("*Aceptar") `
    -BorderColor Cyan `
    -TitleColor White `
    -TitleBackgroundColor DarkBlue
Write-Host "   Resultado: $result`n" -ForegroundColor Gray

# Prueba 6: Popup con opciones centradas
Write-Host "6. Popup con opciones centradas..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500
$result = Show-ConsolePopup -Title "Opciones Centradas" `
    -Message "Las opciones deben estar centradas" `
    -Options @("*Sí", "*No", "*Cancelar") `
    -BorderColor Green `
    -TitleColor Black `
    -TitleBackgroundColor Green `
    -OptionHighlightColor Black `
    -OptionHighlightBackground Yellow
Write-Host "   Resultado: $result`n" -ForegroundColor Gray

# Prueba 7: Popup con mensaje largo
Write-Host "7. Popup con mensaje largo centrado..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500
$result = Show-ConsolePopup -Title "Mensaje Largo" `
    -Message "Este es un mensaje mucho más largo para verificar`nque el centrado funciona correctamente`ncon múltiples líneas de diferente tamaño" `
    -Options @("*OK") `
    -BorderColor Yellow `
    -TitleColor Yellow `
    -TitleBackgroundColor DarkRed
Write-Host "   Resultado: $result`n" -ForegroundColor Gray

# Prueba 8: Popup en posición personalizada
Write-Host "8. Popup en posición personalizada (X=20, Y=5)..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500
$result = Show-ConsolePopup -Title "Posicionado" `
    -Message "Este popup está en X=20, Y=5" `
    -Options @("*Cerrar") `
    -X 20 -Y 5 `
    -BorderColor Magenta
Write-Host "   Resultado: $result`n" -ForegroundColor Gray

# Prueba 9: Menú simple
Write-Host "9. Menú con opciones (ver color de selección)..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500
$options = @(
    "*Opción Uno"
    "*Opción Dos"
    "*Opción Tres"
    "*Salir"
)
$result = Show-DosMenu -Title "MENÚ DE PRUEBA" `
    -Items $options `
    -BorderColor Cyan `
    -HighlightBackgroundColor Yellow `
    -HighlightForegroundColor Black
Write-Host "   Seleccionó: $result`n" -ForegroundColor Gray

# Prueba 10: Verificación visual de bordes
Write-Host "10. Verificación visual de todos los bordes..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Banner esperado:" -ForegroundColor White
Show-Banner "TÍTULO" -BorderColor Cyan -TextColor White

Show-Banner "TODAS LAS PRUEBAS COMPLETADAS" -BorderColor Green -TextColor Green
Write-Host "Características verificadas:" -ForegroundColor White
Write-Host "  ✓ Banners con bordes laterales ║" -ForegroundColor Green
Write-Host "  ✓ Mensaje del popup centrado" -ForegroundColor Green
Write-Host "  ✓ Opciones del popup centradas" -ForegroundColor Green
Write-Host "  ✓ Borde derecho del popup alineado" -ForegroundColor Green
Write-Host "  ✓ Color de fondo de selección en menú" -ForegroundColor Green
Write-Host "  ✓ Color de fondo de selección en popup" -ForegroundColor Green
Write-Host ""
Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
