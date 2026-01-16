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
        Dibuja una barra de progreso de alta fidelidad con overlay de texto.
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
        [ConsoleColor]$OverlayBackgroundColor = [ConsoleColor]::DarkBlue,
        [switch]$CheckCancellation
    )
    
    # --- 1. Lógica de Cancelación ---
    if ($CheckCancellation -and [Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'Escape') { throw "Operación cancelada por el usuario (ESC)" }
    }

    # --- 2. Normalización de Valores ---
    $Percent = [Math]::Clamp($Percent, 0, 100)
    $now = Get-Date
    $elapsed = $now - $StartTime
    $elapsedSec = [int][Math]::Floor($elapsed.TotalSeconds)

    # --- 3. Cálculos de Tiempo ---
    $totalSec = 0; $remainSec = 0
    if ($Percent -gt 0) {
        $totalSec = [int][Math]::Round($elapsedSec / ($Percent / 100.0))
        $remainSec = [Math]::Max(0, ($totalSec - $elapsedSec))
    }

    # --- 4. Gestión de Posición del Cursor ---
    # Si no nos pasan una posición fija, usamos la actual pero la fijamos para la próxima vez
    if ($Top -lt 0) { $Top = [console]::CursorTop }
    $consoleWidth = [console]::WindowWidth

    # --- 5. Dibujo de la Barra (Capa Base) ---
    $filled = [int][Math]::Round(($Percent / 100.0) * $Width)
    $filledBar = "█" * $filled
    $emptyBar = "░" * ($Width - $filled)
    
    try {
        [console]::SetCursorPosition($Left, $Top)
        Write-Host "[" -NoNewline -ForegroundColor Gray
        Write-Host $filledBar -ForegroundColor $ForegroundColor -NoNewline
        Write-Host $emptyBar -ForegroundColor $BackgroundColor -NoNewline
        Write-Host "]" -NoNewline -ForegroundColor Gray
        
        if ($ShowPercent) {
            Write-Host (" {0,3}%" -f [int]$Percent) -ForegroundColor White -NoNewline
        }

        # --- 6. Overlay del Label (Encima de la barra) ---
        if ($Label) {
            $labelText = if ($Label.Length -gt ($Width - 2)) { $Label.Substring(0, $Width - 5) + "..." } else { $Label }
            $labelLeft = $Left + 1 + [Math]::Floor(($Width - $labelText.Length) / 2)
            
            for ($i = 0; $i -lt $labelText.Length; $i++) {
                $charPos = $labelLeft + $i
                $relativePos = $charPos - ($Left + 1)
                
                [console]::SetCursorPosition($charPos, $Top)
                # Si el carácter está en la zona llena, fondo de color barra, si no, fondo oscuro
                if ($relativePos -lt $filled) {
                    Write-Host $labelText[$i] -ForegroundColor $OverlayTextColor -BackgroundColor $ForegroundColor -NoNewline
                } else {
                    Write-Host $labelText[$i] -ForegroundColor $OverlayTextColor -BackgroundColor $BackgroundColor -NoNewline
                }
            }
        }

        # --- 7. Línea de Estadísticas (Debajo) ---
        if ($ShowElapsed -or $ShowEstimated -or $ShowRemaining) {
            $stats = @()
            if ($ShowElapsed)   { $stats += "T+ $(Format-LlevarTime -Seconds $elapsedSec)" }
            if ($remainSec -gt 0) { $stats += "Faltan: $(Format-LlevarTime -Seconds $remainSec)" }
            
            $infoLine = "  " + ($stats -join " | ")
            [console]::SetCursorPosition($Left, $Top + 1)
            # Limpiar línea de stats anterior
            Write-Host ($infoLine.PadRight($consoleWidth - 1)) -ForegroundColor Gray -NoNewline
        }
    }
    catch {
        # Fallback silencioso si la consola no permite reposicionar
    }
}

function Format-LlevarTime {
    param([int]$Seconds)
    $t = [TimeSpan]::FromSeconds($Seconds)
    if ($t.TotalHours -ge 1) { return "{0:00}:{1:00}:{2:00}" -f [int]$t.TotalHours, $t.Minutes, $t.Seconds }
    return "{0:00}:{1:00}" -f $t.Minutes, $t.Seconds
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

function Write-LlevarSpinner {
    <#
    .SYNOPSIS
        Muestra un spinner animado para operaciones sin progreso calculable
    #>
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$StartTime,
        [string]$Label = "Procesando",
        [int]$Top = -1,
        [int]$Left = 0,
        [switch]$CheckCancellation
    )
    
    # Verificar cancelación con ESC
    if ($CheckCancellation -and [Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'Escape') {
            throw "Operación cancelada por el usuario (ESC)"
        }
    }
    
    $spinnerChars = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
    $elapsed = (Get-Date) - $StartTime
    $index = [int]($elapsed.TotalSeconds * 10) % $spinnerChars.Count
    $spinnerChar = $spinnerChars[$index]
    
    # Formatear tiempo transcurrido
    $elapsedStr = Format-LlevarTime -Seconds ([int]$elapsed.TotalSeconds)
    
    $line = "  $spinnerChar  $Label... [$elapsedStr]"
    
    try {
        if ($Top -ge 0) {
            [Console]::SetCursorPosition($Left, $Top)
        }
        Write-Host $line -ForegroundColor Cyan -NoNewline
        Write-Host (" " * 20) -NoNewline  # Limpiar caracteres sobrantes
    }
    catch {
        # Ignorar errores de posicionamiento
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Format-LlevarTime',
    'Write-LlevarProgressBar',
    'Show-CalculatingSpinner',
    'Update-Spinner',
    'Write-LlevarSpinner'
)
