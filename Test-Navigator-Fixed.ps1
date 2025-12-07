# ============================================================================ #
# Test del Navegador Corregido
# ============================================================================ #

Import-Module "$PSScriptRoot\Modules\UI\Navigator.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Core\Logger.psm1" -Force
Import-Module "$PSScriptRoot\Modules\UI\Menus.psm1" -Force

Clear-Host

Write-Host "`n════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
Write-Host "TEST DEL NAVEGADOR DE ARCHIVOS CORREGIDO" -ForegroundColor Yellow
Write-Host "`n════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "Este test verificará que:" -ForegroundColor White
Write-Host "  ✓ Los bordes derechos estén alineados correctamente" -ForegroundColor Green
Write-Host "  ✓ Todos los bordes tengan el color cyan consistente" -ForegroundColor Green
Write-Host "  ✓ Las líneas de contenido no se desborden" -ForegroundColor Green
Write-Host "  ✓ El ancho sea uniforme en toda la interfaz" -ForegroundColor Green

Write-Host "`n════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
Write-Host "Presiona cualquier tecla para iniciar el navegador..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Iniciar navegador
$resultado = Select-PathNavigator -Prompt "TEST: Seleccione archivo o carpeta" -AllowFiles $true

Clear-Host

Write-Host "`n════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

if ($resultado) {
    Write-Host "✓ Selección exitosa:" -ForegroundColor Green
    Write-Host "  $resultado" -ForegroundColor White
}
else {
    Write-Host "⚠ Operación cancelada por el usuario" -ForegroundColor Yellow
}

Write-Host "`n════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
Write-Host "TEST COMPLETADO" -ForegroundColor Green
Write-Host "`nPresiona cualquier tecla para salir..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
