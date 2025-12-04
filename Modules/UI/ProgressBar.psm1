# ============================================================================ #
# Archivo: Q:\Utilidad\LLevar\Modules\UI\ProgressBar.psm1
# Descripción: Barra de progreso visual con información de tiempo
# ============================================================================ #

function Format-LlevarTime {
    <#
    .SYNOPSIS
        Formatea segundos en formato HH:MM:SS
    #>
    param(
        [int]$Seconds
    )

    if ($Seconds -lt 0) { $Seconds = 0 }
    $ts = [TimeSpan]::FromSeconds($Seconds)
    return ("{0:00}:{1:00}:{2:00}" -f [int]$ts.Hours, [int]$ts.Minutes, [int]$ts.Seconds)
}

function Write-LlevarProgressBar {
    <#
    .SYNOPSIS
        Barra de progreso visual mejorada con overlay de texto y estadísticas de tiempo
    #>
    param(
        [double]$Percent,
        [datetime]$StartTime,        
        [int]$Width = 40,
        [bool]$ShowElapsed = $true,
        [bool]$ShowEstimated = $true,
        [bool]$ShowRemaining = $true,
        [bool]$ShowPercent = $true,
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::Cyan,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::DarkBlue,
        [int]$Top = -1,
        [int]$Left = 0,
        [string]$Label = "",
        [ConsoleColor]$OverlayTextColor = [ConsoleColor]::Yellow,    
        [ConsoleColor]$OverlayBackgroundColor = [ConsoleColor]::DarkBlue
    )

    if ($Percent -lt 0) { $Percent = 0 }
    if ($Percent -gt 100) { $Percent = 100 }
    if ($Width -lt 10) { $Width = 10 }

    $now = Get-Date
    $elapsed = $now - $StartTime
    $elapsedSec = [int][Math]::Floor($elapsed.TotalSeconds)

    $totalSec = 0
    $remainSec = 0
    if ($Percent -gt 0) {
        $totalSec = [int][Math]::Round($elapsedSec / ($Percent / 100.0))
        if ($totalSec -lt 0) { $totalSec = 0 }
        $remainSec = $totalSec - $elapsedSec
        if ($remainSec -lt 0) { $remainSec = 0 }
    }

    $consoleWidth = [console]::WindowWidth
    $bufferHeight = [console]::BufferHeight

    # Obtener posición actual si Top no está especificado
    if ($Top -lt 0) {
        $Top = [console]::CursorTop
        $Left = 0
    }

    # Validar límites
    if ($Top -ge $bufferHeight - 2) {
        $Top = $bufferHeight - 3
    }
    if ($Top -lt 0) {
        $Top = 0
    }

    # Dibujar barra de una sola vez
    $filled = [int][Math]::Round(($Percent / 100.0) * $Width)
    if ($filled -gt $Width) { $filled = $Width }
    if ($filled -lt 0) { $filled = 0 }

    $filledBar = "█" * $filled
    $emptyBar = "░" * ($Width - $filled)
    $bar = "[$filledBar$emptyBar]"
    
    # Mostrar porcentaje
    if ($ShowPercent) {
        $bar += " {0,3}%" -f [int]$Percent
    }
    
    # Posicionar y escribir barra completa
    try {
        [console]::SetCursorPosition($Left, $Top)
        Write-Host $bar -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor -NoNewline
    }
    catch {
        # Ignorar errores de posicionamiento
    }

    # Label se muestra en la línea de información de tiempo (no superpuesto)

    # Mostrar información de tiempo en segunda línea (opcional)
    if ($ShowElapsed -or $ShowEstimated -or $ShowRemaining -or $Label) {
        $infoParts = @()
        
        # Agregar label al inicio si existe
        if ($Label -and $Label.Trim()) {
            $infoParts += $Label.Trim()
        }
        
        if ($ShowElapsed) {
            $infoParts += ("Transcurrido: {0}" -f (Format-LlevarTime -Seconds $elapsedSec))
        }
        if ($ShowEstimated -and $totalSec -gt 0) {
            $infoParts += ("Estimado: {0}" -f (Format-LlevarTime -Seconds $totalSec))
        }
        if ($ShowRemaining -and $totalSec -gt 0) {
            $infoParts += ("Restante: {0}" -f (Format-LlevarTime -Seconds $remainSec))
        }

        $infoLine = ""
        if ($infoParts.Count -gt 0) {
            $infoLine = ($infoParts -join "  ")
        }

        try {
            $nextLine = $Top + 1
            if ($nextLine -lt $bufferHeight) {
                [console]::SetCursorPosition($Left, $nextLine)
                $infoClear = " " * ([Math]::Min($consoleWidth - 1, 100))
                Write-Host $infoClear -NoNewline -BackgroundColor Black -ForegroundColor Gray
                [console]::SetCursorPosition($Left, $nextLine)
                if ($infoLine) {
                    Write-Host $infoLine -NoNewline -ForegroundColor Gray -BackgroundColor Black
                }
            }
        }
        catch {}
    }

    # Posicionar para siguiente escritura
    try {
        [console]::SetCursorPosition($Left, $Top + 2)
    }
    catch {}
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Format-LlevarTime',
    'Write-LlevarProgressBar'
)
