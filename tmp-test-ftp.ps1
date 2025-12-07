using module "Q:\Utilidad\LLevar\Modules\Core\TransferConfig.psm1"

$ErrorActionPreference = 'Stop'

$tc = New-TransferConfig
Set-TransferConfigOrigen -Config $tc -Tipo "FTP" -Parametros @{
    Server    = '192.168.7.107'
    Port      = 21
    User      = 'FTPUser'
    Password  = 'Estroncio24'
    Directory = '/Test'
}
Set-TransferConfigDestino -Config $tc -Tipo "FTP" -Parametros @{
    Server    = '192.168.136.128'
    Port      = 21
    User      = 'javierp'
    Password  = 'mw7oi12z88'
    Directory = '/'
}

$op = Test-TransferConfigComplete -Config $tc

Write-Host "Origen Path: $(Get-TransferConfigOrigenPath -Config $tc)" -ForegroundColor Cyan
Write-Host "Destino Path: $(Get-TransferConfigDestinoPath -Config $tc)" -ForegroundColor Cyan
Write-Host "Completo? $op" -ForegroundColor Yellow

Write-Host "\n=== Origen ===" -ForegroundColor Green
$tc.Origen | Format-List

Write-Host "\n=== Destino ===" -ForegroundColor Green
$tc.Destino | Format-List
