using module ".\Modules\Core\TransferConfig.psm1"

# Test completo del flujo TransferConfig
Write-Host "`n========== TEST TRANSFERCONFIG ==========" -ForegroundColor Magenta

# 1. Crear instancia
Write-Host "`n1. Creando TransferConfig..." -ForegroundColor Yellow
$tc = New-TransferConfig
Write-Host "   ✓ TransferConfig creado" -ForegroundColor Green

# 2. Configurar Origen FTP
Write-Host "`n2. Configurando Origen FTP..." -ForegroundColor Yellow
Set-TransferConfigOrigen -Config $tc -Tipo "FTP" -Parametros @{
    Server    = "ftp.ejemplo.com"
    Port      = 21
    User      = "usuario"
    Password  = "pass123"
    Directory = "/datos"
}
Write-Host "   ✓ Origen FTP configurado" -ForegroundColor Green

# 3. Configurar Destino ISO
Write-Host "`n3. Configurando Destino ISO..." -ForegroundColor Yellow
Set-TransferConfigDestino -Config $tc -Tipo "ISO" -Parametros @{
    OutputPath = "C:\temp\salida.iso"
    Size       = "dvd"
}
Write-Host "   ✓ Destino ISO configurado" -ForegroundColor Green

# 4. Verificar configuración
Write-Host "`n4. Verificando configuración..." -ForegroundColor Yellow
Write-Host "   Origen Tipo: $($tc.Origen.Tipo)" -ForegroundColor Cyan
Write-Host "   Origen Server: $($tc.Origen.FTP.Server)" -ForegroundColor Cyan
Write-Host "   Origen Port: $($tc.Origen.FTP.Port)" -ForegroundColor Cyan
Write-Host "   Origen User: $($tc.Origen.FTP.User)" -ForegroundColor Cyan
Write-Host "   Origen Directory: $($tc.Origen.FTP.Directory)" -ForegroundColor Cyan
Write-Host "`n   Destino Tipo: $($tc.Destino.Tipo)" -ForegroundColor Cyan
Write-Host "   Destino ISO OutputPath: $($tc.Destino.ISO.OutputPath)" -ForegroundColor Cyan
Write-Host "   Destino ISO Size: $($tc.Destino.ISO.Size)" -ForegroundColor Cyan

# 5. Probar funciones Get
Write-Host "`n5. Probando Get-TransferConfigOrigenPath..." -ForegroundColor Yellow
$origenPath = Get-TransferConfigOrigenPath -Config $tc
Write-Host "   Path Origen: $origenPath" -ForegroundColor Green

Write-Host "`n6. Probando Get-TransferConfigDestinoPath..." -ForegroundColor Yellow
$destinoPath = Get-TransferConfigDestinoPath -Config $tc
Write-Host "   Path Destino: $destinoPath" -ForegroundColor Green

# 7. Validar completitud
Write-Host "`n7. Validando configuración completa..." -ForegroundColor Yellow
$isComplete = Test-TransferConfigComplete -Config $tc
if ($isComplete) {
    Write-Host "   ✓ Configuración COMPLETA y VÁLIDA" -ForegroundColor Green
}
else {
    Write-Host "   ✗ Configuración INCOMPLETA" -ForegroundColor Red
}

Write-Host "`n========== TEST COMPLETADO ==========" -ForegroundColor Magenta
Write-Host ""
