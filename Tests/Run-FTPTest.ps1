using module "../Modules/Core/TransferConfig.psm1"

param(
    [string]$ConfigPath = "..\Data\ftp-test-config.json",
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Cargar tipos y módulos necesarios
Import-Module "../Modules/Parameters/NormalMode.psm1" -Force -Global

# Leer configuración
if (-not (Test-Path $ConfigPath)) {
    Write-Host "No se encontró el archivo de configuración: $ConfigPath" -ForegroundColor Red
    exit 1
}
$configJson = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# Construir TransferConfig tipado
$tc = New-TransferConfig

# Origen FTP
Set-TransferConfigOrigen -Config $tc -Tipo "FTP" -Parametros @{
    Server    = $configJson.Origen.Server
    Port      = $configJson.Origen.Port
    User      = $configJson.Origen.User
    Password  = $configJson.Origen.Password
    UseSsl    = $configJson.Origen.UseSsl
    Directory = $configJson.Origen.Directory
}

# Destino FTP
Set-TransferConfigDestino -Config $tc -Tipo "FTP" -Parametros @{
    Server    = $configJson.Destino.Server
    Port      = $configJson.Destino.Port
    User      = $configJson.Destino.User
    Password  = $configJson.Destino.Password
    UseSsl    = $configJson.Destino.UseSsl
    Directory = $configJson.Destino.Directory
}

# Opciones
$tc.Opciones.BlockSizeMB = $configJson.Opciones.BlockSizeMB
$tc.Opciones.UseNativeZip = $configJson.Opciones.UseNativeZip
$tc.Opciones.RobocopyMirror = $configJson.Opciones.RobocopyMirror
$tc.Opciones.TransferMode = $configJson.Opciones.TransferMode  # "Direct" evita popup

# Ejecutar
Write-Host "Ejecutando prueba FTP -> FTP con config: $ConfigPath" -ForegroundColor Cyan
Invoke-NormalMode -TransferConfig $tc -Verbose:$Verbose
