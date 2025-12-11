using module ".\Modules\Core\TransferConfig.psm1"

# Test de parseo de URLs FTP
Write-Host "`n========== TEST PARSEO URL FTP ==========" -ForegroundColor Magenta

$testCases = @(
    @{ Url = "ftp://servidor.com/datos"; Expected = @{ Server = "servidor.com"; Port = 21; Directory = "/datos"; UseSsl = $false } }
    @{ Url = "ftps://servidor.com:990/datos"; Expected = @{ Server = "servidor.com"; Port = 990; Directory = "/datos"; UseSsl = $true } }
    @{ Url = "ftp://192.168.1.100:2121"; Expected = @{ Server = "192.168.1.100"; Port = 2121; Directory = ""; UseSsl = $false } }
    @{ Url = "ftp://ftp.ejemplo.com"; Expected = @{ Server = "ftp.ejemplo.com"; Port = 21; Directory = ""; UseSsl = $false } }
)

foreach ($test in $testCases) {
    Write-Host "`nProbando: $($test.Url)" -ForegroundColor Yellow
    
    $Origen = $test.Url
    
    # Parsear URL (mismo código que Llevar.ps1 - REGEX CORREGIDO)
    if ($Origen -match '^(ftp(s)?)://([^:/]+):?(\d+)?(/.*)?$') {
        $ftpScheme = $matches[1]
        $ftpServer = $matches[3]
        $ftpPort = if ($matches[4]) { [int]$matches[4] } else { 21 }
        $ftpDirectory = if ($matches[5]) { $matches[5] } else { "/" }
        $useSsl = ($ftpScheme -eq "ftps")
        
        # Verificar resultados
        $pass = $true
        
        if ($ftpServer -ne $test.Expected.Server) {
            Write-Host "  ✗ Server: esperado '$($test.Expected.Server)', obtenido '$ftpServer'" -ForegroundColor Red
            $pass = $false
        }
        
        if ($ftpPort -ne $test.Expected.Port) {
            Write-Host "  ✗ Port: esperado '$($test.Expected.Port)', obtenido '$ftpPort'" -ForegroundColor Red
            $pass = $false
        }
        
        if ($ftpDirectory -ne $test.Expected.Directory) {
            Write-Host "  ✗ Directory: esperado '$($test.Expected.Directory)', obtenido '$ftpDirectory'" -ForegroundColor Red
            $pass = $false
        }
        
        if ($useSsl -ne $test.Expected.UseSsl) {
            Write-Host "  ✗ UseSsl: esperado '$($test.Expected.UseSsl)', obtenido '$useSsl'" -ForegroundColor Red
            $pass = $false
        }
        
        if ($pass) {
            Write-Host "  ✓ Parseo correcto" -ForegroundColor Green
            Write-Host "    Server: $ftpServer" -ForegroundColor Gray
            Write-Host "    Port: $ftpPort" -ForegroundColor Gray
            Write-Host "    Directory: $ftpDirectory" -ForegroundColor Gray
            Write-Host "    UseSsl: $useSsl" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "  ✗ No coincide con el patrón FTP" -ForegroundColor Red
    }
}

Write-Host "`n========== TEST CREDENCIALES NULL ==========" -ForegroundColor Magenta

# Test con credenciales NULL (caso CLI sin credenciales)
$transferConfig = New-TransferConfig
$SourceCredentials = $null
$Origen = "ftp://test.com/datos"

Write-Host "`nProbando FTP sin credenciales (NULL)..." -ForegroundColor Yellow

if ($Origen -match '^(ftp(s)?)://([^:/]+):?(\d+)?(/.*)?$') {
    $ftpScheme = $matches[1]
    $ftpServer = $matches[3]
    $ftpPort = if ($matches[4]) { [int]$matches[4] } else { 21 }
    $ftpDirectory = if ($matches[5]) { $matches[5] } else { "/" }
    
    # Extraer credenciales si existen (NUEVA LÓGICA)
    $ftpUser = if ($SourceCredentials) { $SourceCredentials.UserName } else { "" }
    $ftpPass = if ($SourceCredentials) { $SourceCredentials.GetNetworkCredential().Password } else { "" }
    
    try {
        Set-TransferConfigOrigen -Config $transferConfig -Tipo "FTP" -Parametros @{
            Server    = $ftpServer
            Port      = $ftpPort
            User      = $ftpUser
            Password  = $ftpPass
            UseSsl    = ($ftpScheme -eq "ftps")
            Directory = $ftpDirectory
        }
        
        Write-Host "  ✓ Configuración exitosa con credenciales NULL" -ForegroundColor Green
        Write-Host "    User: '$($transferConfig.Origen.FTP.User)'" -ForegroundColor Gray
        Write-Host "    Password: '$($transferConfig.Origen.FTP.Password)'" -ForegroundColor Gray
    }
    catch {
        Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n========== TEST COMPLETADO ==========" -ForegroundColor Magenta
Write-Host ""
