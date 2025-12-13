<#
.SYNOPSIS
    Maneja el parámetro -RobocopyMirror para ejecutar copia espejo con Robocopy.

.DESCRIPTION
    Este módulo procesa el parámetro -RobocopyMirror que realiza una copia
    espejo exacta de origen a destino usando Robocopy, sincronizando archivos
    y eliminando lo que no existe en origen.
#>

# Importar dependencias
$ModulesPath = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $ModulesPath "Utilities\PathSelectors.psm1") -Force -Global

function Invoke-RobocopyParameter {
    <#
    .SYNOPSIS
        Procesa el parámetro -RobocopyMirror y ejecuta copia espejo.
    
    .PARAMETER RobocopyMirror
        Switch que indica si se debe ejecutar copia espejo con Robocopy.
    
    .PARAMETER Origen
        Ruta de origen (se pedirá si no está especificada).
    
    .PARAMETER Destino
        Ruta de destino (se pedirá si no está especificada).
    
    .EXAMPLE
        Invoke-RobocopyParameter -RobocopyMirror -Origen "C:\Data" -Destino "D:\Backup"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$RobocopyMirror,
        
        [Parameter(Mandatory = $false)]
        [string]$Origen,
        
        [Parameter(Mandatory = $false)]
        [string]$Destino
    )
    
    if (-not $RobocopyMirror) {
        return $false
    }
    
    # Solicitar origen y destino usando la función centralizada
    $Origen = Get-PathOrPrompt $Origen "ORIGEN"
    $Destino = Get-PathOrPrompt $Destino "DESTINO"
    
    # Ejecutar copia espejo
    Invoke-RobocopyMirror -Origen $Origen -Destino $Destino
    
    Write-Host ""
    Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Export-ModuleMember -Function Invoke-RobocopyParameter
