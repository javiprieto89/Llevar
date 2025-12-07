# ========================================================================== #
#                   MÓDULO: SELECTORES DE RUTAS                              #
# ========================================================================== #
# Propósito: Funciones para seleccionar carpetas y rutas
# Funciones:
#   - Select-LlevarFolder: Selector de carpetas simplificado
#   - Get-PathOrPrompt: Obtiene o solicita ruta según parámetro
# ========================================================================== #

function Select-LlevarFolder {
    <#
    .SYNOPSIS
        Selector de carpetas simplificado usando Select-PathNavigator
    .DESCRIPTION
        Wrapper que llama a Select-PathNavigator con AllowFiles=$false
        para selección exclusiva de carpetas.
    .PARAMETER Prompt
        Mensaje a mostrar al usuario
    .OUTPUTS
        String con la ruta seleccionada
    #>
    param([string]$Prompt)
    return Select-PathNavigator -Prompt $Prompt -AllowFiles $false
}

function Get-PathOrPrompt {
    <#
    .SYNOPSIS
        Obtiene ruta o la solicita si no está definida
    .DESCRIPTION
        Si $Path está vacío, solicita al usuario seleccionar una carpeta.
        Si la ruta no existe, vuelve a solicitarla hasta obtener una válida.
    .PARAMETER Path
        Ruta opcional previa
    .PARAMETER Tipo
        Tipo de ruta (Origen/Destino) para mensajes
    .OUTPUTS
        String con la ruta validada
    #>
    param([string]$Path, [string]$Tipo)

    if (-not $Path) {
        $Path = Select-LlevarFolder "Seleccione carpeta de $Tipo"
    }

    while (-not (Test-Path $Path)) {
        Write-Host "Ruta no válida: $Path" -ForegroundColor Yellow
        $Path = Select-LlevarFolder "Seleccione carpeta de $Tipo"
    }

    return $Path
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Select-LlevarFolder',
    'Get-PathOrPrompt'
)
