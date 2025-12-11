using module "Q:\Utilidad\LLevar\Modules\Core\TransferConfig.psm1"

<#
.SYNOPSIS
    Maneja la detección de ejecución sin parámetros y muestra el menú interactivo.

.DESCRIPTION
    Este módulo detecta si el script se ejecutó sin parámetros principales
    y muestra el menú interactivo para configurar todas las opciones.
    Mapea la configuración del menú a las variables del script.
#>

function Invoke-InteractiveMenu {
    <#
    .SYNOPSIS
        Detecta ejecución sin parámetros y muestra menú interactivo.
    
    .PARAMETER Ayuda
        Parámetro -Ayuda.
    
    .PARAMETER Instalar
        Parámetro -Instalar.
    
    .PARAMETER RobocopyMirror
        Parámetro -RobocopyMirror.
    
    .PARAMETER Ejemplo
        Parámetro -Ejemplo.
    
    .PARAMETER Origen
        Ruta de origen.
    
    .PARAMETER Destino
        Ruta de destino.
    
    .PARAMETER Iso
        Switch para generar ISO.
    
    .OUTPUTS
            Hashtable con la configuración mapeada desde el menú, o $null si se canceló.
    
    .EXAMPLE
        $config = Invoke-InteractiveMenu -Origen "" -Destino ""
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Ayuda,
        
        [Parameter(Mandatory = $false)]
        [switch]$Instalar,
        
        [Parameter(Mandatory = $false)]
        [switch]$RobocopyMirror,
        
        [Parameter(Mandatory = $false)]
        [switch]$Ejemplo,
        
        [Parameter(Mandatory = $false)]
        [string]$Origen,
        
        [Parameter(Mandatory = $false)]
        [string]$Destino,
        
        [Parameter(Mandatory = $false)]
        [switch]$Iso
    )
    
    # Detectar si se ejecutó sin parámetros principales
    $noParams = (
        -not $Ayuda -and
        -not $Instalar -and
        -not $RobocopyMirror -and
        -not $Ejemplo -and
        -not $Origen -and
        -not $Destino -and
        -not $Iso
    )
    
    if (-not $noParams) {
        return $null
    }
    
    Show-Banner "MODO INTERACTIVO" -BorderColor Cyan -TextColor Cyan
    Write-Host "No se especificaron parámetros. Iniciando menú interactivo..." -ForegroundColor Gray
    Write-Host ""
    
    # Mostrar menú principal
    $config = Show-MainMenu
    
    # Si el usuario canceló (salió del menú), terminar
    if ($null -eq $config -or $config.Action -eq "Exit") {
        Write-Host ""
        Write-Host "Operación cancelada por el usuario." -ForegroundColor Yellow
        Write-Host ""
        exit
    }
    
    # Procesar configuración del menú según la acción seleccionada
    switch ($config.Action) {
        "Execute" {
            # Crear objeto TransferConfig unificado
            $transferConfig = New-TransferConfig
            
            # Configurar origen según su tipo
            switch ($config.Origen.Tipo) {
                "FTP" {
                    Set-TransferConfigOrigen -Config $transferConfig -Tipo "FTP" -Parametros @{
                        Server    = $config.Origen.FtpServer
                        Port      = $config.Origen.FtpPort
                        User      = $config.Origen.FtpUser
                        Password  = $config.Origen.FtpPassword
                        Directory = $config.Origen.FtpDirectory
                    }
                }
                "UNC" {
                    $uncCred = $null
                    if ($config.Origen.UncUser) {
                        $secPassword = ConvertTo-SecureString $config.Origen.UncPassword -AsPlainText -Force
                        $uncCred = New-Object System.Management.Automation.PSCredential($config.Origen.UncUser, $secPassword)
                    }
                    Set-TransferConfigOrigen -Config $transferConfig -Tipo "UNC" -Parametros @{
                        Path        = $config.Origen.UncPath
                        User        = $config.Origen.UncUser
                        Password    = $config.Origen.UncPassword
                        Domain      = $config.Origen.UncDomain
                        Credentials = $uncCred
                    }
                }
                "OneDrive" {
                    Set-TransferConfigOrigen -Config $transferConfig -Tipo "OneDrive" -Parametros @{
                        Path         = $config.Origen.Path
                        Email        = $config.Origen.OneDriveEmail
                        Token        = $config.Origen.OneDriveToken
                        RefreshToken = $config.Origen.OneDriveRefreshToken
                        ApiUrl       = $config.Origen.OneDriveApiUrl
                    }
                }
                "Dropbox" {
                    Set-TransferConfigOrigen -Config $transferConfig -Tipo "Dropbox" -Parametros @{
                        Path         = $config.Origen.Path
                        Email        = $config.Origen.DropboxEmail
                        Token        = $config.Origen.DropboxToken
                        RefreshToken = $config.Origen.DropboxRefreshToken
                        ApiUrl       = $config.Origen.DropboxApiUrl
                    }
                }
                default {
                    # Local o USB
                    Set-TransferConfigOrigen -Config $transferConfig -Tipo "Local" -Parametros @{
                        Path = $config.Origen.Path
                    }
                }
            }
            
            # Configurar destino según su tipo
            switch ($config.Destino.Tipo) {
                "FTP" {
                    Set-TransferConfigDestino -Config $transferConfig -Tipo "FTP" -Parametros @{
                        Server    = $config.Destino.FtpServer
                        Port      = $config.Destino.FtpPort
                        User      = $config.Destino.FtpUser
                        Password  = $config.Destino.FtpPassword
                        Directory = $config.Destino.FtpDirectory
                    }
                }
                "UNC" {
                    $uncCred = $null
                    if ($config.Destino.UncUser) {
                        $secPassword = ConvertTo-SecureString $config.Destino.UncPassword -AsPlainText -Force
                        $uncCred = New-Object System.Management.Automation.PSCredential($config.Destino.UncUser, $secPassword)
                    }
                    Set-TransferConfigDestino -Config $transferConfig -Tipo "UNC" -Parametros @{
                        Path        = $config.Destino.UncPath
                        User        = $config.Destino.UncUser
                        Password    = $config.Destino.UncPassword
                        Domain      = $config.Destino.UncDomain
                        Credentials = $uncCred
                    }
                }
                "OneDrive" {
                    Set-TransferConfigDestino -Config $transferConfig -Tipo "OneDrive" -Parametros @{
                        Path         = $config.Destino.Path
                        Email        = $config.Destino.OneDriveEmail
                        Token        = $config.Destino.OneDriveToken
                        RefreshToken = $config.Destino.OneDriveRefreshToken
                        ApiUrl       = $config.Destino.OneDriveApiUrl
                    }
                }
                "Dropbox" {
                    Set-TransferConfigDestino -Config $transferConfig -Tipo "Dropbox" -Parametros @{
                        Path         = $config.Destino.Path
                        Email        = $config.Destino.DropboxEmail
                        Token        = $config.Destino.DropboxToken
                        RefreshToken = $config.Destino.DropboxRefreshToken
                        ApiUrl       = $config.Destino.DropboxApiUrl
                    }
                }
                "ISO" {
                    Set-TransferConfigDestino -Config $transferConfig -Tipo "ISO" -Parametros @{
                        OutputPath = $config.Destino.Path
                        Size       = $config.IsoDestino
                    }
                }
                default {
                    # Local o USB
                    Set-TransferConfigDestino -Config $transferConfig -Tipo "Local" -Parametros @{
                        Path = $config.Destino.Path
                    }
                }
            }
            
            # Configurar opciones generales
            $transferConfig.Opciones.BlockSizeMB = $config.BlockSizeMB
            $transferConfig.Opciones.Clave = $config.Clave
            $transferConfig.Opciones.UseNativeZip = $config.UseNativeZip
            $transferConfig.Opciones.RobocopyMirror = $config.RobocopyMirror
            
            Show-Banner "CONFIGURACIÓN COMPLETA - INICIANDO EJECUCIÓN" -BorderColor Green -TextColor Green
            
            # Log verbose de la configuración
            if ($Global:VerboseLogging) {
                Write-Log "=== CONFIGURACIÓN TRANSFERCONFIG ===" "DEBUG"
                $origenPath = switch ($transferConfig.Origen.Tipo) {
                    "Local" { $transferConfig.Origen.Local.Path }
                    "UNC" { $transferConfig.Origen.UNC.Path }
                    "FTP" { $transferConfig.Origen.FTP.Directory }
                    "OneDrive" { $transferConfig.Origen.OneDrive.Path }
                    "Dropbox" { $transferConfig.Origen.Dropbox.Path }
                    default { $null }
                }
                $destinoPath = switch ($transferConfig.Destino.Tipo) {
                    "Local" { $transferConfig.Destino.Local.Path }
                    "USB" { $transferConfig.Destino.USB.Path }
                    "UNC" { $transferConfig.Destino.UNC.Path }
                    "FTP" { $transferConfig.Destino.FTP.Directory }
                    "OneDrive" { $transferConfig.Destino.OneDrive.Path }
                    "Dropbox" { $transferConfig.Destino.Dropbox.Path }
                    "ISO" { $transferConfig.Destino.ISO.OutputPath }
                    "Diskette" { $transferConfig.Destino.Diskette.OutputPath }
                    default { $null }
                }
                Write-Log "Origen Tipo: $($transferConfig.Origen.Tipo) Path: $origenPath" "DEBUG"
                Write-Log "Destino Tipo: $($transferConfig.Destino.Tipo) Path: $destinoPath" "DEBUG"
                if ($transferConfig.Origen.Tipo -eq "FTP") {
                    $ftpOrigen = Get-TransferConfigOrigen -Config $transferConfig
                    Write-Log "FTP Origen: $($ftpOrigen.Server):$($ftpOrigen.Port) Usuario: $($ftpOrigen.User)" "DEBUG"
                }
                if ($transferConfig.Destino.Tipo -eq "FTP") {
                    $ftpDestino = Get-TransferConfigDestino -Config $transferConfig
                    Write-Log "FTP Destino: $($ftpDestino.Server):$($ftpDestino.Port) Usuario: $($ftpDestino.User)" "DEBUG"
                }
            }
            
            # Retornar TransferConfig con metadatos de acción
            return @{
                Action         = "Execute"
                TransferConfig = $transferConfig
            }
        }
        "Example" {
            # Activar modo ejemplo
            return @{ 
                Action  = "Example"
                Ejemplo = $true 
            }
        }
        "Help" {
            # Mostrar ayuda
            Clear-Host
            Show-Help
            exit
        }
    }
    
    return $null
}

Export-ModuleMember -Function Invoke-InteractiveMenu
