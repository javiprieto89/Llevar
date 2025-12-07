# ============================================================================ #
# Demostración del Navegador Mejorado con Nuevas Funcionalidades
# ============================================================================ #

Import-Module "$PSScriptRoot\Modules\UI\Navigator.psm1" -Force
Import-Module "$PSScriptRoot\Modules\UI\Banners.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Core\Logger.psm1" -Force
Import-Module "$PSScriptRoot\Modules\UI\Menus.psm1" -Force

Clear-Host

Show-Banner @(
    "NAVEGADOR MEJORADO - DEMO",
    "Nuevas funcionalidades agregadas"
) -BorderColor Cyan -TextColor Yellow

Write-Host ""
Write-Host "NUEVAS FUNCIONALIDADES:" -ForegroundColor Green
Write-Host ""
Write-Host "  📁 ESPACIO" -ForegroundColor Yellow -NoNewline
Write-Host "  - Calcular tamaño de carpeta seleccionada" -ForegroundColor White
Write-Host "             • Muestra spinner animado durante el cálculo" -ForegroundColor Gray
Write-Host "             • Se puede cancelar con ESC en cualquier momento" -ForegroundColor Gray
Write-Host "             • El resultado se guarda en caché" -ForegroundColor Gray
Write-Host "             • Formato inteligente (B, KB, MB, GB, TB)" -ForegroundColor Gray
Write-Host ""
Write-Host "  🔍 F4" -ForegroundColor Yellow -NoNewline
Write-Host "      - Activar buscador/filtro" -ForegroundColor White
Write-Host "             • Escribe para filtrar archivos y carpetas" -ForegroundColor Gray
Write-Host "             • Soporta expresiones regulares" -ForegroundColor Gray
Write-Host "             • Ejemplos: 'test', '\.ps1$', '^Demo'" -ForegroundColor Gray
Write-Host "             • ESC para salir, Enter para aplicar filtro" -ForegroundColor Gray
Write-Host ""
Write-Host "  ↑↓" -ForegroundColor Yellow -NoNewline
Write-Host "        - Navegar en modo búsqueda también" -ForegroundColor White
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "INSTRUCCIONES DE USO:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. El navegador se abrirá a continuación" -ForegroundColor White
Write-Host "2. Navega con las flechas hasta una carpeta" -ForegroundColor White
Write-Host "3. Presiona ESPACIO para calcular su tamaño" -ForegroundColor White
Write-Host "4. Presiona F4 y escribe para buscar/filtrar" -ForegroundColor White
Write-Host "5. Presiona F10 para seleccionar o ESC para salir" -ForegroundColor White
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Presiona cualquier tecla para continuar..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Iniciar navegador
$resultado = Select-PathNavigator -Prompt "DEMO: Navegador Mejorado" -AllowFiles $true

Clear-Host

Show-Banner "DEMO COMPLETADA" -BorderColor Green -TextColor White

Write-Host ""
if ($resultado) {
    Write-Host "✓ Seleccionaste: " -NoNewline -ForegroundColor Green
    Write-Host $resultado -ForegroundColor White
}
else {
    Write-Host "⚠ Operación cancelada" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "RESUMEN DE FUNCIONALIDADES:" -ForegroundColor Yellow
Write-Host ""
Write-Host "✓ Cálculo de tamaño de carpetas con ESPACIO" -ForegroundColor Green
Write-Host "✓ Buscador con filtrado en tiempo real (F4)" -ForegroundColor Green
Write-Host "✓ Soporte para expresiones regulares" -ForegroundColor Green
Write-Host "✓ Spinner animado durante cálculos" -ForegroundColor Green
Write-Host "✓ Caché de tamaños calculados" -ForegroundColor Green
Write-Host "✓ Formato inteligente de tamaños" -ForegroundColor Green
Write-Host "✓ Cancelación con ESC" -ForegroundColor Green
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
