<#
.SYNOPSIS
    Demo de menús y popups con los nuevos bordes box-drawing

.DESCRIPTION
    Muestra ejemplos de Show-DosMenu y Show-ConsolePopup con los nuevos caracteres ╔ ═ ╗ ║ ╚ ╝
#>

# Importar funciones desde Llevar.ps1
$scriptPath = Join-Path $PSScriptRoot "Llevar.ps1"
. $scriptPath

Clear-Host

Show-Banner "DEMO: MENÚS Y POPUPS CON BORDES BOX-DRAWING" -BorderColor Cyan -TextColor Cyan

# Demo 1: Popup Simple
Write-Host "1. Popup simple centrado..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500
$result = Show-ConsolePopup -Title "Bienvenido" -Message "Este es un popup con bordes box-drawing`n╔ ═ ╗ ║ ╚ ╝" -Options @("*Aceptar")
Write-Host "   Resultado: $result`n" -ForegroundColor Gray

# Demo 2: Popup con múltiples opciones
Write-Host "2. Popup con múltiples opciones..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500
$result = Show-ConsolePopup -Title "Confirmación" -Message "¿Desea continuar?" -Options @("*Sí", "*No", "*Cancelar") -TitleColor White -TitleBackgroundColor DarkBlue
Write-Host "   Resultado: $result`n" -ForegroundColor Gray

# Demo 3: Popup en posición personalizada
Write-Host "3. Popup en posición personalizada (X=15, Y=10)..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500
$result = Show-ConsolePopup -Title "Posicionado" -Message "Este popup está en X=15, Y=10" -Options @("*OK") -X 15 -Y 10 -BorderColor Green
Write-Host "   Resultado: $result`n" -ForegroundColor Gray

# Demo 4: Menú DOS simple
Write-Host "4. Menú DOS simple..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500
$options = @(
    "*Opción 1"
    "*Opción 2"
    "*Opción 3"
    "*Salir"
)
$result = Show-DosMenu -Title "MENÚ PRINCIPAL" -Items $options -CancelValue 0
Write-Host "   Seleccionó: $result`n" -ForegroundColor Gray

# Demo 5: Menú con colores personalizados
Write-Host "5. Menú con colores personalizados..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500
$options = @(
    "*Archivo"
    "*Editar"
    "*Ver"
    "*Ayuda"
)
$result = Show-DosMenu -Title "MENÚ DE APLICACIÓN" -Items $options -BorderColor Green -TextColor White -HighlightBackgroundColor DarkGreen
Write-Host "   Seleccionó: $result`n" -ForegroundColor Gray

# Demo 6: Menú en posición personalizada
Write-Host "6. Menú en posición personalizada (X=5, Y=3)..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500
$options = @(
    "*Nuevo"
    "*Abrir"
    "*Guardar"
)
$result = Show-DosMenu -Title "ARCHIVO" -Items $options -X 5 -Y 3 -BorderColor Cyan
Write-Host "   Seleccionó: $result`n" -ForegroundColor Gray

# Demo 7: Banner con el nuevo sistema
Write-Host "7. Banner formateado..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500
Show-Banner -Text @("SISTEMA DE MENÚS", "Versión 3.0") -BorderColor Cyan -TextColor Yellow

# Demo 8: Popup con advertencia
Write-Host "8. Popup de advertencia..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500
$result = Show-ConsolePopup -Title "⚠ ADVERTENCIA" -Message "Esta operación no se puede deshacer`n¿Está seguro?" -Options @("*Continuar", "*Cancelar") -TitleColor Yellow -TitleBackgroundColor DarkRed -BorderColor Red
Write-Host "   Resultado: $result`n" -ForegroundColor Gray

# Demo 9: Popup de éxito
Write-Host "9. Popup de éxito..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500
$result = Show-ConsolePopup -Title "✓ ÉXITO" -Message "La operación se completó correctamente" -Options @("*Aceptar") -TitleColor Black -TitleBackgroundColor Green -BorderColor Green
Write-Host "   Resultado: $result`n" -ForegroundColor Gray

Show-Banner "DEMO COMPLETADO" -BorderColor Green -TextColor Green
Write-Host "Características de los nuevos bordes:" -ForegroundColor White
Write-Host "  • Caracteres box-drawing Unicode: ╔ ═ ╗ ║ ╚ ╝" -ForegroundColor Gray
Write-Host "  • Menús siempre hacen Clear-Host" -ForegroundColor Gray
Write-Host "  • Posicionamiento X,Y desde esquina superior izquierda" -ForegroundColor Gray
Write-Host "  • Títulos centrados por default" -ForegroundColor Gray
Write-Host "  • Colores completamente personalizables" -ForegroundColor Gray
Write-Host ""
Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
