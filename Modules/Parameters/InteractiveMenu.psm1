<#
.SYNOPSIS
    Maneja la detección de ejecución sin parámetros y muestra el menú interactivo.

.DESCRIPTION
    Este módulo detecta si el script se ejecutó sin parámetros principales
    y muestra el menú interactivo para configurar todas las opciones.
    Mapea la configuración del menú a las variables del script.
#>

$ModulesPath = Split-Path $PSScriptRoot -Parent
if (-not (Get-Module -Name 'TransferConfig')) {
    Import-Module (Join-Path $ModulesPath "Core\TransferConfig.psm1") -Force -Global
}

function Invoke-InteractiveMenu {
    <#
    .SYNOPSIS
        Detecta ejecución sin parámetros y muestra menú interactivo.
    
    .PARAMETER TransferConfig
        Referencia al objeto TransferConfig que se modificará (uso de [ref]).
    
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
        String indicando la acción a realizar: "Execute", "Example", "Help" o $null si se canceló.
    
    .EXAMPLE
        $transferConfig = [TransferConfig]::new()
        $action = Invoke-InteractiveMenu -TransferConfig $transferConfig -Origen "" -Destino ""
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$TransferConfig,
        
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
    
    # Mostrar menú principal pasando TransferConfig por referencia
    $menuResult = Show-MainMenu -TransferConfig $TransferConfig
    
    # Si el usuario canceló (salió del menú), terminar
    if ($null -eq $menuResult) {
        Write-Host ""
        Write-Host "Operación cancelada por el usuario." -ForegroundColor Yellow
        Write-Host ""
        exit
    }
    
    # Procesar acción del menú
    switch ($menuResult.Action) {
        "Execute" {
            Show-Banner "CONFIGURACIÓN COMPLETA - INICIANDO EJECUCIÓN" -BorderColor Green -TextColor Green
            return "Execute"
        }
        "Example" {
            return "Example"
        }
        "Help" {
            Clear-Host
            Show-Help
            exit
        }
    }
    
    return $null
}

Export-ModuleMember -Function Invoke-InteractiveMenu
