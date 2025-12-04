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
    $mappedConfig = @{
        Action         = $config.Action
        Origen         = $null
        Destino        = $null
        BlockSizeMB    = 10
        Clave          = $null
        UseNativeZip   = $false
        Iso            = $false
        IsoDestino     = "dvd"
        RobocopyMirror = $false
    }
    
    switch ($config.Action) {
        "Execute" {
            # Mapear origen según su tipo
            if ($config.Origen.FtpServer) {
                # Es FTP - construir URL y credenciales
                $mappedConfig.Origen = $config.Origen.Path
                $mappedConfig.FtpSourceServer = $config.Origen.FtpServer
                $mappedConfig.FtpSourcePort = $config.Origen.FtpPort
                $mappedConfig.FtpSourceUser = $config.Origen.FtpUser
                $mappedConfig.FtpSourcePassword = $config.Origen.FtpPassword
            }
            elseif ($config.Origen.UncPath) {
                # Es UNC - ruta y credenciales de red
                $mappedConfig.Origen = $config.Origen.Path
                if ($config.Origen.UncUser) {
                    $secPassword = ConvertTo-SecureString $config.Origen.UncPassword -AsPlainText -Force
                    $mappedConfig.UncSourceCredentials = New-Object System.Management.Automation.PSCredential($config.Origen.UncUser, $secPassword)
                }
            }
            else {
                # Es Local, OneDrive, Dropbox o USB
                $mappedConfig.Origen = $config.Origen.Path
            }
            
            # Mapear destino según su tipo
            if ($config.Destino.FtpServer) {
                # Es FTP - construir URL y credenciales
                $mappedConfig.Destino = $config.Destino.Path
                $mappedConfig.FtpDestinationServer = $config.Destino.FtpServer
                $mappedConfig.FtpDestinationPort = $config.Destino.FtpPort
                $mappedConfig.FtpDestinationUser = $config.Destino.FtpUser
                $mappedConfig.FtpDestinationPassword = $config.Destino.FtpPassword
            }
            elseif ($config.Destino.UncPath) {
                # Es UNC - ruta y credenciales de red
                $mappedConfig.Destino = $config.Destino.Path
                if ($config.Destino.UncUser) {
                    $secPassword = ConvertTo-SecureString $config.Destino.UncPassword -AsPlainText -Force
                    $mappedConfig.UncDestinationCredentials = New-Object System.Management.Automation.PSCredential($config.Destino.UncUser, $secPassword)
                }
            }
            else {
                # Es Local, OneDrive, Dropbox o USB
                $mappedConfig.Destino = $config.Destino.Path
            }
            
            # Mapear configuración general
            $mappedConfig.BlockSizeMB = $config.BlockSizeMB
            $mappedConfig.Clave = $config.Clave
            $mappedConfig.UseNativeZip = $config.UseNativeZip
            $mappedConfig.Iso = $config.Iso
            $mappedConfig.IsoDestino = $config.IsoDestino
            $mappedConfig.RobocopyMirror = $config.RobocopyMirror
            
            Show-Banner "CONFIGURACIÓN COMPLETA - INICIANDO EJECUCIÓN" -BorderColor Green -TextColor Green
            
            # Log verbose de la configuración
            if ($Global:VerboseLogging) {
                Write-Log "=== CONFIGURACIÓN MAPEADA ===" "DEBUG"
                Write-Log "Origen: $($mappedConfig.Origen) (Tipo: $($config.Origen.Tipo))" "DEBUG"
                Write-Log "Destino: $($mappedConfig.Destino) (Tipo: $($config.Destino.Tipo))" "DEBUG"
                if ($config.Origen.FtpServer) {
                    Write-Log "FTP Origen: $($config.Origen.FtpServer):$($config.Origen.FtpPort) Usuario: $($config.Origen.FtpUser)" "DEBUG"
                }
                if ($config.Destino.FtpServer) {
                    Write-Log "FTP Destino: $($config.Destino.FtpServer):$($config.Destino.FtpPort) Usuario: $($config.Destino.FtpUser)" "DEBUG"
                }
            }
        }
        "Example" {
            # Activar modo ejemplo
            $mappedConfig.Ejemplo = $true
        }
        "Help" {
            # Mostrar ayuda
            Clear-Host
            Show-Help
            exit
        }
    }
    
    return $mappedConfig
}

Export-ModuleMember -Function Invoke-InteractiveMenu
