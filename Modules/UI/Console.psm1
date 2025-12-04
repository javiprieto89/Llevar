# ============================================================================ #
# Archivo: Q:\Utilidad\LLevar\Modules\UI\Console.psm1
# Descripción: Funciones de manipulación de consola, colores, sonidos y escalado
# ============================================================================ #

# Función universal para escribir texto con colores
function Write-ColorOutput {
    <#
    .SYNOPSIS
        Escribe texto con colores específicos, compatible con PowerShell 5.1 y 7+
    #>
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]$InputObject,
        
        [ValidateSet('Black', 'DarkBlue', 'DarkGreen', 'DarkCyan', 'DarkRed', 'DarkMagenta', 'DarkYellow', 'Gray', 'DarkGray', 'Blue', 'Green', 'Cyan', 'Red', 'Magenta', 'Yellow', 'White',
            'BrightBlack', 'BrightBlue', 'BrightGreen', 'BrightCyan', 'BrightRed', 'BrightMagenta', 'BrightYellow', 'BrightWhite')]
        [string]$ForegroundColor = 'White',
        
        [ValidateSet('Black', 'DarkBlue', 'DarkGreen', 'DarkCyan', 'DarkRed', 'DarkMagenta', 'DarkYellow', 'Gray', 'DarkGray', 'Blue', 'Green', 'Cyan', 'Red', 'Magenta', 'Yellow', 'White',
            'BrightBlack', 'BrightBlue', 'BrightGreen', 'BrightCyan', 'BrightRed', 'BrightMagenta', 'BrightYellow', 'BrightWhite')]
        [string]$BackgroundColor = 'Black',
        
        [switch]$NoNewline
    )
    
    begin {
        # Detectar si estamos en PowerShell 7+ con $PSStyle disponible
        $usePSStyle = ($PSVersionTable.PSVersion.Major -ge 7) -and ($null -ne $PSStyle)
    }
    
    process {
        if ($_ -ne $null) {
            $text = $_
        }
        elseif ($null -ne $InputObject) {
            $text = $InputObject
        }
        else {
            $text = ""
        }
        
        if ($usePSStyle) {
            # Usar $PSStyle para colores ANSI en PowerShell 7+
            $fg = $PSStyle.Foreground.$ForegroundColor
            $bg = $PSStyle.Background.$BackgroundColor
            $reset = $PSStyle.Reset
            
            if ($NoNewline) {
                Write-Host "$fg$bg$text$reset" -NoNewline
            }
            else {
                Write-Host "$fg$bg$text$reset"
            }
        }
        else {
            # Fallback para PowerShell 5.1
            if ($NoNewline) {
                Write-Host $text -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor -NoNewline
            }
            else {
                Write-Host $text -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
            }
        }
    }
    
    end {
        # Limpiar si es necesario
    }
}

# Función para calcular el porcentaje al que hay que achicar el codigo ASCII lo más/menos posible
# Para el logo ASCII de alexsoft.txt para que se vea lo más fiel a la imagen real, permite redimenzionar
# Se trata de devolver siempre la proporción 1:1
function Get-AsciiScalingRatios {
    <#
    .SYNOPSIS
        Calcula ratios de escalado para logos ASCII
    #>
    param(
        [int]$OriginalWidth,
        [int]$OriginalHeight,
        [int]$ConsoleWidth,
        [int]$ConsoleHeight
    )
      
    # Intentar que el logo quepa sin reducción
    # Solo reducir si es absolutamente necesario
    
    $widthRatio = 1
    $heightRatio = 1
    $maxWidth = $ConsoleWidth - 2
    
    # Si el logo es más ancho que la consola, reducir horizontalmente
    if ($OriginalWidth -gt $ConsoleWidth) {
        $widthRatio = [Math]::Ceiling($OriginalWidth / ($ConsoleWidth - 2))
    }
    
    # Si el logo es más alto que la consola, reducir verticalmente
    if ($OriginalHeight -gt $ConsoleHeight - 5) {
        $heightRatio = [Math]::Ceiling($OriginalHeight / ($ConsoleHeight - 5))
    }
    
    return @{
        WidthRatio  = $widthRatio
        HeightRatio = $heightRatio
        MaxWidth    = $maxWidth
    }
}

function Resize-Console {
    <#
    .SYNOPSIS
        Redimensiona la consola al tamaño especificado (función legacy)
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Width,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Height
    )

    if ($host.Name -ne 'ConsoleHost') {
        return
    }

    try {
        # Ajustar buffer si es necesario
        if ($Width -gt $host.UI.RawUI.BufferSize.Width) {
            $host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size($Width, $host.UI.RawUI.BufferSize.Height)
        }

        # Limitar al tamaño máximo físico
        if ($Width -gt $host.UI.RawUI.MaxPhysicalWindowSize.Width) {
            $Width = $host.UI.RawUI.MaxPhysicalWindowSize.Width
        }
        if ($Height -gt $host.UI.RawUI.MaxPhysicalWindowSize.Height) {
            $Height = $host.UI.RawUI.MaxPhysicalWindowSize.Height
        }

        # Aplicar nuevo tamaño
        $host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size($Width, $Height)
    }
    catch {
        # Silenciar errores - no es crítico
    }
}

function Set-ConsoleSize {
    <#
    .SYNOPSIS
        Redimensiona la ventana de consola
    #>
    param(
        [int]$Width = 120,
        [int]$Height = 40
    )
    
    try {
        # Verificar si estamos en PowerShell ISE (no se puede redimensionar)
        if ($host.Name -match 'ISE') {
            Write-Verbose "PowerShell ISE detectado - no se puede redimensionar la consola"
            return $false
        }
        
        # Verificar si estamos en una sesión de terminal moderna (PowerShell 7+)
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            # PowerShell 7+ puede usar ANSI escapes para redimensionar
            $esc = [char]27
            Write-Host "${esc}[8;${Height};${Width}t" -NoNewline
            Start-Sleep -Milliseconds 50
            return $true
        }
        
        # Para PowerShell 5.1, usar métodos de .NET
        $rawUI = $host.UI.RawUI
        
        # Obtener tamaño actual
        $currentBuffer = $rawUI.BufferSize
        
        # Ajustar buffer primero (debe ser >= ventana)
        $newBufferWidth = [Math]::Max($currentBuffer.Width, $Width)
        $newBufferHeight = [Math]::Max($currentBuffer.Height, $Height + 100) # Buffer más grande para scroll
        
        try {
            $rawUI.BufferSize = New-Object System.Management.Automation.Host.Size($newBufferWidth, $newBufferHeight)
        }
        catch {
            Write-Verbose "No se pudo ajustar buffer: $($_.Message)"
        }
        
        # Ajustar ventana
        try {
            $rawUI.WindowSize = New-Object System.Management.Automation.Host.Size($Width, $Height)
            Start-Sleep -Milliseconds 50
            return $true
        }
        catch {
            # Intentar con métodos de Console directamente
            try {
                [Console]::SetWindowSize($Width, $Height)
                Start-Sleep -Milliseconds 50
                return $true
            }
            catch {
                Write-Verbose "No se pudo redimensionar ventana: $($_.Message)"
            }
        }
        
        return $false
    }
    catch {
        Write-Verbose "Error en Set-ConsoleSize: $($_.Message)"
        return $false
    }
}

# Invoke-DOSBeep → Migrado a Modules/System/Audio.psm1

# Exportar funciones
Export-ModuleMember -Function @(
    'Write-ColorOutput',
    'Get-AsciiScalingRatios',
    'Resize-Console',
    'Set-ConsoleSize'
)
