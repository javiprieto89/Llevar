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
    
    .PARAMETER TransferConfig
        Referencia al objeto TransferConfig que se modificará.
    
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
        $transferConfig = New-TransferConfig
        $action = Invoke-InteractiveMenu -TransferConfig $transferConfig -Origen "" -Destino ""
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $TransferConfig,
        
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
        [switch]$Iso,
        
        [Parameter(Mandatory = $false)]
        [switch]$OrigenBloqueado
    )
    
    # Detectar si se ejecutó sin parámetros principales (excepto si OrigenBloqueado está activo)
    $noParams = (
        -not $Ayuda -and
        -not $Instalar -and
        -not $RobocopyMirror -and
        -not $Ejemplo -and
        -not $Origen -and
        -not $Destino -and
        -not $Iso -and
        -not $OrigenBloqueado
    )
    
    if (-not $noParams -and -not $OrigenBloqueado) {
        return $null
    }
    
    # Mostrar banner apropiado según el contexto
    if ($OrigenBloqueado) {
        Show-Banner "CONFIGURACIÓN DE DESTINO" -BorderColor Yellow -TextColor Yellow
        Write-Host "Origen configurado y bloqueado. Configure el destino..." -ForegroundColor Gray
    }
    else {
        Show-Banner "MODO INTERACTIVO" -BorderColor Cyan -TextColor Cyan
        Write-Host "No se especificaron parámetros. Iniciando menú interactivo..." -ForegroundColor Gray
    }
    Write-Host ""
    
    # Mostrar menú principal pasando TransferConfig por referencia
    $menuResult = Show-MainMenu -TransferConfig $TransferConfig -OrigenBloqueado:$OrigenBloqueado
    
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
