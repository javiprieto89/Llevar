<#
.SYNOPSIS
    Maneja el parámetro -Ayuda para mostrar la ayuda del programa.

.DESCRIPTION
    Este módulo procesa el parámetro -Ayuda (-h) que muestra la documentación
    completa del programa y termina la ejecución.
#>

function Invoke-HelpParameter {
    <#
    .SYNOPSIS
        Procesa el parámetro -Ayuda y muestra la documentación.
    
    .PARAMETER Ayuda
        Switch que indica si se debe mostrar la ayuda.
    
    .EXAMPLE
        Invoke-HelpParameter -Ayuda
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Ayuda
    )
    
    if ($Ayuda) {
        Clear-Host
        Show-Help
        exit
    }
    
    return $false
}

Export-ModuleMember -Function Invoke-HelpParameter
