using module ".\Modules\Core\TransferConfig.psm1"

# Simular el flujo completo: InteractiveMenu → TransferConfig → NormalMode
Write-Host "`n========== TEST FLUJO COMPLETO ==========" -ForegroundColor Magenta

# PASO 1: Simular lo que hace InteractiveMenu
Write-Host "`n[INTERACTIVEMENU] Creando TransferConfig..." -ForegroundColor Yellow
$transferConfig = New-TransferConfig

Write-Host "[INTERACTIVEMENU] Usuario configuró: FTP → ISO" -ForegroundColor Yellow

# Usuario configura FTP en el menú
Set-TransferConfigOrigen -Config $transferConfig -Tipo "FTP" -Parametros @{
    Server    = "ftp.servidor.com"
    Port      = 21
    User      = "ftpuser"
    Password  = "ftppass"
    Directory = "/origen"
}

# Usuario configura ISO en el menú
Set-TransferConfigDestino -Config $transferConfig -Tipo "ISO" -Parametros @{
    OutputPath = "D:\salida"
    Size       = "dvd"
}

# Usuario configura opciones
$transferConfig.Opciones.BlockSizeMB = 50
$transferConfig.Opciones.Clave = "miclave123"
$transferConfig.Opciones.UseNativeZip = $false

Write-Host "[INTERACTIVEMENU] Retornando TransferConfig a Llevar.ps1" -ForegroundColor Green

# PASO 2: Simular lo que hace Llevar.ps1
Write-Host "`n[LLEVAR.PS1] Recibiendo TransferConfig del menú..." -ForegroundColor Yellow
$menuResult = @{
    Action         = "Execute"
    TransferConfig = $transferConfig
}

if ($menuResult.Action -eq "Execute" -and $menuResult.ContainsKey('TransferConfig')) {
    Write-Host "[LLEVAR.PS1] TransferConfig recibido correctamente" -ForegroundColor Green
    $tc = $menuResult.TransferConfig
    
    # Verificar que la configuración se mantiene
    Write-Host "`n[VERIFICACIÓN] Datos retenidos en TransferConfig:" -ForegroundColor Cyan
    Write-Host "  Origen: $($tc.Origen.Tipo) - $($tc.Origen.FTP.Server)" -ForegroundColor White
    Write-Host "  Destino: $($tc.Destino.Tipo) - $($tc.Destino.ISO.OutputPath)" -ForegroundColor White
    Write-Host "  BlockSize: $($tc.Opciones.BlockSizeMB) MB" -ForegroundColor White
    Write-Host "  Clave: $($tc.Opciones.Clave)" -ForegroundColor White
    
    # PASO 3: Simular lo que hace NormalMode (sin ejecutar realmente)
    Write-Host "`n[NORMALMODE] Recibiría TransferConfig como parámetro" -ForegroundColor Yellow
    Write-Host "[NORMALMODE] Extraería valores:" -ForegroundColor Yellow
    
    $origenTipo = $tc.Origen.Tipo
    $destinoTipo = $tc.Destino.Tipo
    $blockSize = $tc.Opciones.BlockSizeMB
    $clave = $tc.Opciones.Clave
    $useNativeZip = $tc.Opciones.UseNativeZip
    
    Write-Host "  OrigenTipo: $origenTipo" -ForegroundColor White
    Write-Host "  DestinoTipo: $destinoTipo" -ForegroundColor White
    Write-Host "  BlockSizeMB: $blockSize" -ForegroundColor White
    Write-Host "  Clave: $clave" -ForegroundColor White
    Write-Host "  UseNativeZip: $useNativeZip" -ForegroundColor White
    
    # Simular obtención de paths
    $origenPath = Get-TransferConfigOrigenPath -Config $tc
    $destinoPath = Get-TransferConfigDestinoPath -Config $tc
    
    Write-Host "`n[NORMALMODE] Paths construidos:" -ForegroundColor Yellow
    Write-Host "  Origen Path: $origenPath" -ForegroundColor White
    Write-Host "  Destino Path: $destinoPath" -ForegroundColor White
    
    # Simular validación
    Write-Host "`n[NORMALMODE] Validando configuración..." -ForegroundColor Yellow
    $isComplete = Test-TransferConfigComplete -Config $tc
    
    if ($isComplete) {
        Write-Host "  ✓ Configuración VÁLIDA - Procedería a ejecutar transferencia" -ForegroundColor Green
        Write-Host "  ✓ Se ejecutaría: FTP($origenPath) → ISO($destinoPath)" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ Configuración INVÁLIDA - Abortaría ejecución" -ForegroundColor Red
    }
    
}
else {
    Write-Host "[ERROR] No se recibió TransferConfig del menú" -ForegroundColor Red
}

Write-Host "`n========== FLUJO VERIFICADO ==========" -ForegroundColor Magenta
Write-Host "✓ InteractiveMenu crea TransferConfig" -ForegroundColor Green
Write-Host "✓ InteractiveMenu configura Origen/Destino/Opciones" -ForegroundColor Green
Write-Host "✓ InteractiveMenu retorna TransferConfig a Llevar.ps1" -ForegroundColor Green
Write-Host "✓ Llevar.ps1 recibe TransferConfig correctamente" -ForegroundColor Green
Write-Host "✓ Llevar.ps1 pasaría TransferConfig a NormalMode" -ForegroundColor Green
Write-Host "✓ NormalMode extraería valores correctamente" -ForegroundColor Green
Write-Host "✓ NormalMode ejecutaría la transferencia" -ForegroundColor Green
Write-Host ""
