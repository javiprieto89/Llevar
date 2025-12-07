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
    
    # Posicionar y escribir barra completa primero
    try {
        [console]::SetCursorPosition($Left, $Top)
        Write-Host $bar -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor -NoNewline
        
        # Mostrar porcentaje al lado de la barra
        if ($ShowPercent) {
            Write-Host (" {0,3}%" -f [int]$Percent) -ForegroundColor $ForegroundColor -BackgroundColor Black -NoNewline
        }
        
        # Mostrar label como overlay SOBRE la barra si existe
        if ($Label -and $Label.Trim()) {
            try {
                # Calcular posición centrada para el label sobre la barra
                $labelText = $Label.Trim()
                # Centrar dentro de la barra (sin contar los corchetes [ ])
                $labelLeft = $Left + 1 + [Math]::Floor(($Width - $labelText.Length) / 2)
                if ($labelLeft -lt ($Left + 1)) { $labelLeft = $Left + 1 }
                
                # Dibujar cada caracter del label SOBRE la barra
                for ($i = 0; $i -lt $labelText.Length; $i++) {
                    $charPos = $labelLeft + $i
                    # Calcular si este caracter está en la parte llena o vacía de la barra
                    $relativePos = $charPos - ($Left + 1)  # Posición relativa dentro de la barra
                    
                    if ($relativePos -lt $filled) {
                        # Está en la parte llena - usar color de barra llena como fondo
                        [console]::SetCursorPosition($charPos, $Top)
                        Write-Host $labelText[$i] -ForegroundColor $OverlayTextColor -BackgroundColor $ForegroundColor -NoNewline
                    }
                    else {
                        # Está en la parte vacía - usar color de overlay
                        [console]::SetCursorPosition($charPos, $Top)
                        Write-Host $labelText[$i] -ForegroundColor $OverlayTextColor -BackgroundColor $OverlayBackgroundColor -NoNewline
                    }
                }
            }
            catch {}
        }
    }
    catch {
        # Ignorar errores de posicionamiento
    }

    # Mostrar información de tiempo en segunda línea (opcional)
    if ($ShowElapsed -or $ShowEstimated -or $ShowRemaining) {
        $infoParts = @()
        
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

function Show-CalculatingSpinner {
    <#
    .SYNOPSIS
        Muestra un diálogo con spinner mientras se calcula el tamaño
    .DESCRIPTION
        Crea una interfaz visual con spinner animado para operaciones largas
    .PARAMETER DirectoryName
        Nombre del directorio que se está calculando
    .PARAMETER Width
        Ancho del cuadro de diálogo
    .OUTPUTS
        Hashtable con información del estado del spinner
    #>
    param(
        [string]$DirectoryName,
        [int]$Width = 60
    )
    
    $spinnerChars = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
    $spinnerIndex = 0
    
    $borderLine = "═" * $Width
    
    # Limpiar área
    Clear-Host
    Write-Host ""
    Write-Host ""
    
    # Dibujar cuadro
    Write-Host "╔${borderLine}╗" -ForegroundColor Cyan
    
    $title = "CALCULANDO TAMAÑO DE DIRECTORIO"
    $titlePad = ($Width - $title.Length) / 2
    $titleLine = (" " * [Math]::Floor($titlePad)) + $title + (" " * [Math]::Ceiling($titlePad))
    Write-Host "║${titleLine}║" -ForegroundColor Cyan
    
    Write-Host "╠${borderLine}╣" -ForegroundColor Cyan
    Write-Host "║" -ForegroundColor Cyan -NoNewline
    Write-Host (" " * $Width) -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    
    # Línea con nombre de directorio
    $dirDisplay = $DirectoryName
    if ($dirDisplay.Length -gt ($Width - 4)) {
        $dirDisplay = $dirDisplay.Substring(0, $Width - 7) + "..."
    }
    $dirLine = "  " + $dirDisplay
    $dirLine = $dirLine.PadRight($Width)
    Write-Host "║" -ForegroundColor Cyan -NoNewline
    Write-Host $dirLine -ForegroundColor Yellow -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    
    Write-Host "║" -ForegroundColor Cyan -NoNewline
    Write-Host (" " * $Width) -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    
    # Guardar posición para el spinner
    $spinnerY = [Console]::CursorTop
    
    Write-Host "║" -ForegroundColor Cyan -NoNewline
    Write-Host (" " * $Width) -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    
    Write-Host "║" -ForegroundColor Cyan -NoNewline
    Write-Host (" " * $Width) -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    
    Write-Host "╠${borderLine}╣" -ForegroundColor Cyan
    
    $instruction = "Presione ESC para cancelar"
    $instrPad = ($Width - $instruction.Length) / 2
    $instrLine = (" " * [Math]::Floor($instrPad)) + $instruction + (" " * [Math]::Ceiling($instrPad))
    Write-Host "║${instrLine}║" -ForegroundColor Green
    
    Write-Host "╚${borderLine}╝" -ForegroundColor Cyan
    
    return @{
        SpinnerY     = $spinnerY
        SpinnerChars = $spinnerChars
        SpinnerIndex = $spinnerIndex
        Width        = $Width
    }
}

function Update-Spinner {
    <#
    .SYNOPSIS
        Actualiza el spinner con información de progreso
    .DESCRIPTION
        Actualiza la visualización del spinner con estadísticas actuales
    .PARAMETER SpinnerState
        Estado del spinner (hashtable retornado por Show-CalculatingSpinner)
    .PARAMETER CurrentSize
        Tamaño actual calculado en bytes
    .PARAMETER FileCount
        Cantidad de archivos procesados
    .PARAMETER DirCount
        Cantidad de directorios procesados
    #>
    param(
        [hashtable]$SpinnerState,
        [long]$CurrentSize,
        [int]$FileCount,
        [int]$DirCount
    )
    
    $spinnerChar = $SpinnerState.SpinnerChars[$SpinnerState.SpinnerIndex]
    $SpinnerState.SpinnerIndex = ($SpinnerState.SpinnerIndex + 1) % $SpinnerState.SpinnerChars.Count
    
    # Importar función de formato si no está disponible
    if (-not (Get-Command Format-FileSize -ErrorAction SilentlyContinue)) {
        # Función inline si no está importada
        if ($CurrentSize -ge 1TB) {
            $sizeStr = "{0:N2} TB" -f ($CurrentSize / 1TB)
        }
        elseif ($CurrentSize -ge 1GB) {
            $sizeStr = "{0:N2} GB" -f ($CurrentSize / 1GB)
        }
        elseif ($CurrentSize -ge 1MB) {
            $sizeStr = "{0:N2} MB" -f ($CurrentSize / 1MB)
        }
        elseif ($CurrentSize -ge 1KB) {
            $sizeStr = "{0:N2} KB" -f ($CurrentSize / 1KB)
        }
        else {
            $sizeStr = "$CurrentSize B"
        }
    }
    else {
        $sizeStr = Format-FileSize -Size $CurrentSize
    }
    
    $statusLine = "  $spinnerChar  $sizeStr - $FileCount archivos - $DirCount carpetas"
    $statusLine = $statusLine.PadRight($SpinnerState.Width)
    
    try {
        [Console]::SetCursorPosition(1, $SpinnerState.SpinnerY)
        Write-Host $statusLine -ForegroundColor White -NoNewline
    }
    catch {
        # Ignorar errores de posición
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Format-LlevarTime',
    'Write-LlevarProgressBar',
    'Show-CalculatingSpinner',
    'Update-Spinner'
)
