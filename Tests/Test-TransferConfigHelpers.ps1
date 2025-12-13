<#
.SYNOPSIS
    Tests unitarios para las funciones helper de TransferConfig
.DESCRIPTION
    Valida todas las funciones Get/Set-*Config agregadas para OneDrive, Dropbox, UNC, Local, ISO y Diskette
#>

Import-Module "$PSScriptRoot\..\Modules\Core\TransferConfig.psm1" -Force

Write-Host "`n╔═══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  TESTS DE FUNCIONES HELPER TRANSFERCONFIG    ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Cyan

$testsPassed = 0
$testsFailed = 0

function Test-Helper {
    param($Name, $TestBlock)
    try {
        & $TestBlock
        Write-Host "  ✓ $Name" -ForegroundColor Green
        $script:testsPassed++
    }
    catch {
        Write-Host "  ✗ $Name - Error: $_" -ForegroundColor Red
        $script:testsFailed++
    }
}

# ========================================================================== #
#                           TESTS ONEDRIVE                                   #
# ========================================================================== #

Write-Host "`n[TEST 1] FTP - Get/Set Config con PSCredential" -ForegroundColor Yellow

Test-Helper "Set-FTPConfig con PSCredential" {
    $cfg = New-TransferConfig
    $securePass = ConvertTo-SecureString "ftppassword" -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential("ftpuser", $securePass)
    
    Set-FTPConfig -Config $cfg -Section "Origen" -Server "ftp.example.com" -Credentials $cred -Port 2121
    
    $ftp = Get-FTPConfig -Config $cfg -Section "Origen"
    if ($ftp.Server -ne "ftp.example.com") { throw "Server incorrecto" }
    if ($ftp.Port -ne 2121) { throw "Port incorrecto" }
    if ($ftp.Credentials.UserName -ne "ftpuser") { throw "Credentials.UserName incorrecto" }
    if (-not $ftp.Credentials) { throw "Credentials no guardado" }
}

Test-Helper "Set-FTPConfig con User/Password tradicional" {
    $cfg = New-TransferConfig
    Set-FTPConfig -Config $cfg -Section "Destino" -Server "ftp2.example.com" -User "admin" -Password "admin123" -UseSsl $true
    
    $ftp = Get-FTPConfig -Config $cfg -Section "Destino"
    if ($ftp.Server -ne "ftp2.example.com") { throw "Server incorrecto" }
    if ($ftp.User -ne "admin") { throw "User incorrecto" }
    if ($ftp.Password -ne "admin123") { throw "Password incorrecto" }
    if ($ftp.UseSsl -ne $true) { throw "UseSsl incorrecto" }
}

Test-Helper "Set-FTPConfig con todos los parámetros" {
    $cfg = New-TransferConfig
    Set-FTPConfig -Config $cfg -Section "Origen" -Server "ftps://secure.ftp.com" -User "secureuser" -Password "securepass" -Port 990 -Directory "/data" -UseSsl $true
    
    $ftp = Get-FTPConfig -Config $cfg -Section "Origen"
    if ($ftp.Server -ne "ftps://secure.ftp.com") { throw "Server incorrecto" }
    if ($ftp.Directory -ne "/data") { throw "Directory incorrecto" }
    if ($ftp.Port -ne 990) { throw "Port incorrecto" }
}

# ========================================================================== #
#                           TESTS ONEDRIVE                                   #
# ========================================================================== #

Write-Host "`n[TEST 2] OneDrive - Get/Set Config" -ForegroundColor Yellow

Test-Helper "Set-OneDriveConfig con todos los parámetros" {
    $cfg = New-TransferConfig
    Set-OneDriveConfig -Config $cfg -Section "Origen" `
        -Path "/Documents/LLEVAR" `
        -Email "test@outlook.com" `
        -Token "token123" `
        -RefreshToken "refresh456" `
        -UseLocal $true `
        -LocalPath "C:\OneDrive\LLEVAR"
    
    $onedrive = Get-OneDriveConfig -Config $cfg -Section "Origen"
    if ($onedrive.Path -ne "/Documents/LLEVAR") { throw "Path incorrecto" }
    if ($onedrive.Email -ne "test@outlook.com") { throw "Email incorrecto" }
    if ($onedrive.Token -ne "token123") { throw "Token incorrecto" }
    if ($onedrive.RefreshToken -ne "refresh456") { throw "RefreshToken incorrecto" }
    if ($onedrive.UseLocal -ne $true) { throw "UseLocal incorrecto" }
    if ($onedrive.LocalPath -ne "C:\OneDrive\LLEVAR") { throw "LocalPath incorrecto" }
}

Test-Helper "Get-OneDriveConfig en sección Destino" {
    $cfg = New-TransferConfig
    Set-OneDriveConfig -Config $cfg -Section "Destino" -Path "/Backup" -Email "dest@outlook.com"
    $onedrive = Get-OneDriveConfig -Config $cfg -Section "Destino"
    if ($onedrive.Path -ne "/Backup") { throw "Path incorrecto" }
    if ($onedrive.Email -ne "dest@outlook.com") { throw "Email incorrecto" }
}

Test-Helper "Integración OneDrive con Get-TransferPath" {
    $cfg = New-TransferConfig
    Set-TransferType -Config $cfg -Section "Origen" -Type "OneDrive"
    Set-OneDriveConfig -Config $cfg -Section "Origen" -Path "/Files/Data"
    $path = Get-TransferPath -Config $cfg -Section "Origen"
    if ($path -ne "/Files/Data") { throw "Get-TransferPath falló con OneDrive" }
}

# ========================================================================== #
#                           TESTS DROPBOX                                    #
# ========================================================================== #

Write-Host "`n[TEST 3] Dropbox - Get/Set Config" -ForegroundColor Yellow

Test-Helper "Set-DropboxConfig con todos los parámetros" {
    $cfg = New-TransferConfig
    Set-DropboxConfig -Config $cfg -Section "Destino" `
        -Path "/Backup/Data" `
        -Email "user@dropbox.com" `
        -Token "dbx_token123" `
        -RefreshToken "dbx_refresh456"
    
    $dropbox = Get-DropboxConfig -Config $cfg -Section "Destino"
    if ($dropbox.Path -ne "/Backup/Data") { throw "Path incorrecto" }
    if ($dropbox.Email -ne "user@dropbox.com") { throw "Email incorrecto" }
    if ($dropbox.Token -ne "dbx_token123") { throw "Token incorrecto" }
    if ($dropbox.RefreshToken -ne "dbx_refresh456") { throw "RefreshToken incorrecto" }
}

Test-Helper "Get-DropboxConfig en sección Origen" {
    $cfg = New-TransferConfig
    Set-DropboxConfig -Config $cfg -Section "Origen" -Path "/Source" -Email "src@dropbox.com"
    $dropbox = Get-DropboxConfig -Config $cfg -Section "Origen"
    if ($dropbox.Path -ne "/Source") { throw "Path incorrecto" }
}

Test-Helper "Integración Dropbox con Get-TransferPath" {
    $cfg = New-TransferConfig
    Set-TransferType -Config $cfg -Section "Destino" -Type "Dropbox"
    Set-DropboxConfig -Config $cfg -Section "Destino" -Path "/Archive/2024"
    $path = Get-TransferPath -Config $cfg -Section "Destino"
    if ($path -ne "/Archive/2024") { throw "Get-TransferPath falló con Dropbox" }
}

# ========================================================================== #
#                              TESTS UNC                                     #
# ========================================================================== #

Write-Host "`n[TEST 4] UNC - Get/Set Config" -ForegroundColor Yellow

Test-Helper "Set-UNCConfig con todos los parámetros" {
    $cfg = New-TransferConfig
    Set-UNCConfig -Config $cfg -Section "Origen" `
        -Path "\\servidor\compartido\datos" `
        -User "admin" `
        -Password "secret123" `
        -Domain "EMPRESA"
    
    $unc = Get-UNCConfig -Config $cfg -Section "Origen"
    if ($unc.Path -ne "\\servidor\compartido\datos") { throw "Path incorrecto" }
    if ($unc.User -ne "admin") { throw "User incorrecto" }
    if ($unc.Password -ne "secret123") { throw "Password incorrecto" }
    if ($unc.Domain -ne "EMPRESA") { throw "Domain incorrecto" }
}

Test-Helper "Set-UNCConfig con PSCredential" {
    $cfg = New-TransferConfig
    $securePass = ConvertTo-SecureString "password" -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential("testuser", $securePass)
    Set-UNCConfig -Config $cfg -Section "Destino" -Path "\\backup\share" -Credentials $cred
    
    $unc = Get-UNCConfig -Config $cfg -Section "Destino"
    if ($unc.Path -ne "\\backup\share") { throw "Path incorrecto" }
    if ($unc.Credentials.UserName -ne "testuser") { throw "Credentials incorrectas" }
}

Test-Helper "Integración UNC con Get-TransferPath" {
    $cfg = New-TransferConfig
    Set-TransferType -Config $cfg -Section "Origen" -Type "UNC"
    Set-UNCConfig -Config $cfg -Section "Origen" -Path "\\fileserver\data"
    $path = Get-TransferPath -Config $cfg -Section "Origen"
    if ($path -ne "\\fileserver\data") { throw "Get-TransferPath falló con UNC" }
}

# ========================================================================== #
#                             TESTS LOCAL                                    #
# ========================================================================== #

Write-Host "`n[TEST 5] Local - Get/Set Config" -ForegroundColor Yellow

Test-Helper "Set-LocalConfig con ruta Windows" {
    $cfg = New-TransferConfig
    Set-LocalConfig -Config $cfg -Section "Origen" -Path "C:\Data\Files"
    $local = Get-LocalConfig -Config $cfg -Section "Origen"
    if ($local.Path -ne "C:\Data\Files") { throw "Path incorrecto" }
}

Test-Helper "Set-LocalConfig en Destino" {
    $cfg = New-TransferConfig
    Set-LocalConfig -Config $cfg -Section "Destino" -Path "D:\Backup"
    $local = Get-LocalConfig -Config $cfg -Section "Destino"
    if ($local.Path -ne "D:\Backup") { throw "Path incorrecto" }
}

Test-Helper "Integración Local con Get-TransferPath" {
    $cfg = New-TransferConfig
    Set-TransferType -Config $cfg -Section "Origen" -Type "Local"
    Set-LocalConfig -Config $cfg -Section "Origen" -Path "C:\Projects\MyApp"
    $path = Get-TransferPath -Config $cfg -Section "Origen"
    if ($path -ne "C:\Projects\MyApp") { throw "Get-TransferPath falló con Local" }
}

# ========================================================================== #
#                              TESTS ISO                                     #
# ========================================================================== #

Write-Host "`n[TEST 6] ISO - Get/Set Config (solo Destino)" -ForegroundColor Yellow

Test-Helper "Set-ISOConfig con todos los parámetros" {
    $cfg = New-TransferConfig
    Set-ISOConfig -Config $cfg `
        -OutputPath "C:\Backups\backup_2024.iso" `
        -Size "dvd" `
        -VolumeSize 4700 `
        -VolumeName "BACKUP_2024"
    
    $iso = Get-ISOConfig -Config $cfg
    if ($iso.OutputPath -ne "C:\Backups\backup_2024.iso") { throw "OutputPath incorrecto" }
    if ($iso.Size -ne "dvd") { throw "Size incorrecto" }
    if ($iso.VolumeSize -ne 4700) { throw "VolumeSize incorrecto" }
    if ($iso.VolumeName -ne "BACKUP_2024") { throw "VolumeName incorrecto" }
}

Test-Helper "Set-ISOConfig con tamaños predefinidos" {
    $cfg1 = New-TransferConfig
    Set-ISOConfig -Config $cfg1 -OutputPath "C:\cd.iso" -Size "cd"
    if ((Get-ISOConfig -Config $cfg1).Size -ne "cd") { throw "Size CD incorrecto" }
    
    $cfg2 = New-TransferConfig
    Set-ISOConfig -Config $cfg2 -OutputPath "C:\usb.iso" -Size "usb"
    if ((Get-ISOConfig -Config $cfg2).Size -ne "usb") { throw "Size USB incorrecto" }
}

Test-Helper "Integración ISO con Get-TransferPath" {
    $cfg = New-TransferConfig
    Set-TransferType -Config $cfg -Section "Destino" -Type "ISO"
    Set-ISOConfig -Config $cfg -OutputPath "C:\output.iso"
    $path = Get-TransferPath -Config $cfg -Section "Destino"
    if ($path -ne "C:\output.iso") { throw "Get-TransferPath falló con ISO" }
}

# ========================================================================== #
#                           TESTS DISKETTE                                   #
# ========================================================================== #

Write-Host "`n[TEST 7] Diskette - Get/Set Config (solo Destino)" -ForegroundColor Yellow

Test-Helper "Set-DisketteConfig con todos los parámetros" {
    $cfg = New-TransferConfig
    Set-DisketteConfig -Config $cfg `
        -OutputPath "C:\Diskettes\Project" `
        -MaxDisks 50 `
        -Size 1440
    
    $diskette = Get-DisketteConfig -Config $cfg
    if ($diskette.OutputPath -ne "C:\Diskettes\Project") { throw "OutputPath incorrecto" }
    if ($diskette.MaxDisks -ne 50) { throw "MaxDisks incorrecto" }
    if ($diskette.Size -ne 1440) { throw "Size incorrecto" }
}

Test-Helper "Set-DisketteConfig con valores por defecto" {
    $cfg = New-TransferConfig
    Set-DisketteConfig -Config $cfg -OutputPath "C:\Floppies"
    $diskette = Get-DisketteConfig -Config $cfg
    if ($diskette.OutputPath -ne "C:\Floppies") { throw "OutputPath incorrecto" }
}

Test-Helper "Integración Diskette con Get-TransferPath" {
    $cfg = New-TransferConfig
    Set-TransferType -Config $cfg -Section "Destino" -Type "Diskette"
    Set-DisketteConfig -Config $cfg -OutputPath "C:\Floppy_Images"
    $path = Get-TransferPath -Config $cfg -Section "Destino"
    if ($path -ne "C:\Floppy_Images") { throw "Get-TransferPath falló con Diskette" }
}

# ========================================================================== #
#                        TESTS DE INTEGRACIÓN                                #
# ========================================================================== #

Write-Host "`n[TEST 8] Escenarios de Integración Completos" -ForegroundColor Yellow

Test-Helper "Escenario: OneDrive → Dropbox" {
    $cfg = New-TransferConfig
    
    # Origen OneDrive
    Set-TransferType -Config $cfg -Section "Origen" -Type "OneDrive"
    Set-OneDriveConfig -Config $cfg -Section "Origen" -Path "/Documents/Source" -Email "src@outlook.com"
    
    # Destino Dropbox
    Set-TransferType -Config $cfg -Section "Destino" -Type "Dropbox"
    Set-DropboxConfig -Config $cfg -Section "Destino" -Path "/Backup/Target" -Email "dst@dropbox.com"
    
    # Opciones
    Set-TransferOption -Config $cfg -Option "BlockSizeMB" -Value 20
    
    # Verificar
    if ((Get-TransferType -Config $cfg -Section "Origen") -ne "OneDrive") { throw "Tipo Origen incorrecto" }
    if ((Get-TransferType -Config $cfg -Section "Destino") -ne "Dropbox") { throw "Tipo Destino incorrecto" }
    if ((Get-TransferPath -Config $cfg -Section "Origen") -ne "/Documents/Source") { throw "Path Origen incorrecto" }
    if ((Get-TransferPath -Config $cfg -Section "Destino") -ne "/Backup/Target") { throw "Path Destino incorrecto" }
}

Test-Helper "Escenario: UNC → ISO" {
    $cfg = New-TransferConfig
    
    Set-TransferType -Config $cfg -Section "Origen" -Type "UNC"
    Set-UNCConfig -Config $cfg -Section "Origen" -Path "\\servidor\datos" -User "admin"
    
    Set-TransferType -Config $cfg -Section "Destino" -Type "ISO"
    Set-ISOConfig -Config $cfg -OutputPath "C:\backup.iso" -Size "dvd" -VolumeName "BACKUP"
    
    if ((Get-TransferPath -Config $cfg -Section "Origen") -ne "\\servidor\datos") { throw "Path UNC incorrecto" }
    if ((Get-ISOConfig -Config $cfg).VolumeName -ne "BACKUP") { throw "VolumeName incorrecto" }
}

Test-Helper "Escenario: Local → Diskette" {
    $cfg = New-TransferConfig
    
    Set-TransferType -Config $cfg -Section "Origen" -Type "Local"
    Set-LocalConfig -Config $cfg -Section "Origen" -Path "C:\Projects"
    
    Set-TransferType -Config $cfg -Section "Destino" -Type "Diskette"
    Set-DisketteConfig -Config $cfg -OutputPath "C:\Diskettes" -MaxDisks 100
    
    if ((Get-TransferPath -Config $cfg -Section "Origen") -ne "C:\Projects") { throw "Path Local incorrecto" }
    if ((Get-DisketteConfig -Config $cfg).MaxDisks -ne 100) { throw "MaxDisks incorrecto" }
}

# ========================================================================== #
#                          RESUMEN FINAL                                     #
# ========================================================================== #

Write-Host "`n╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  RESUMEN DE TESTS HELPER TRANSFERCONFIG       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Cyan

$total = $testsPassed + $testsFailed
$successRate = if ($total -gt 0) { [math]::Round(($testsPassed / $total) * 100, 1) } else { 0 }

Write-Host "`nTests ejecutados: $total" -ForegroundColor White
Write-Host "  Pasados:        $testsPassed" -ForegroundColor Green
Write-Host "  Fallados:       $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host "  Tasa de éxito:  $successRate%" -ForegroundColor $(if ($successRate -eq 100) { "Green" } else { "Yellow" })

if ($testsFailed -eq 0) {
    Write-Host "`n✓ Todos los tests pasaron exitosamente" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`n✗ Algunos tests fallaron" -ForegroundColor Red
    exit 1
}
