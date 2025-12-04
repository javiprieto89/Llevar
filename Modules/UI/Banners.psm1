# ============================================================================ #
# Archivo: Q:\Utilidad\LLevar\Modules\UI\Banners.psm1
# Descripción: Funciones para mostrar banners, logos ASCII y mensajes de bienvenida
# ============================================================================ #

function Show-Banner {
    <#
    .SYNOPSIS
        Muestra un banner formateado con bordes automáticos y opciones de personalización.
    
    .DESCRIPTION
        Genera un banner con bordes automáticos, calculando el ancho según el texto más largo.
        Soporta múltiples líneas, alineación centrada, colores personalizables y posicionamiento opcional.
    
    .PARAMETER Message
        Mensaje o array de mensajes a mostrar en el banner. Siempre se muestra centrado.
    
    .PARAMETER BorderColor
        Color de los bordes. Default: Cyan
    
    .PARAMETER TextColor
        Color del texto. Default: White
    
    .PARAMETER BackgroundColor
        Color de fondo. Default: Black
    
    .PARAMETER Padding
        Espacios adicionales a cada lado del texto. Default: 2
    
    .PARAMETER X
        Posición horizontal (columna). Si no se especifica, usa el ancho actual.
    
    .PARAMETER Y
        Posición vertical (fila). Si no se especifica, usa la posición actual del cursor.
    
    .EXAMPLE
        Show-Banner "LLEVAR.PS1"
        
    .EXAMPLE
        Show-Banner @("ROBOCOPY MIRROR", "COPIA ESPEJO") -BorderColor Yellow -TextColor Cyan
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Message,
        
        [ConsoleColor]$BorderColor = [ConsoleColor]::Cyan,
        [ConsoleColor]$TextColor = [ConsoleColor]::White,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black,
        
        [int]$Padding = 2,
        
        [int]$X = -1,
        [int]$Y = -1
    )
    
    # Convertir texto a array si es string único
    if ($Message -is [string]) {
        $Message = @($Message)
    }
    
    # Calcular ancho máximo del texto
    $maxLength = 0
    foreach ($line in $Message) {
        if ($line.Length -gt $maxLength) {
            $maxLength = $line.Length
        }
    }
    
    # Ancho total del banner (texto + padding a ambos lados)
    $bannerWidth = $maxLength + ($Padding * 2)
    
    # Crear líneas de borde con caracteres box-drawing
    $topBorder = "╔" + ("═" * $bannerWidth) + "╗"
    $bottomBorder = "╚" + ("═" * $bannerWidth) + "╝"
    
    # Si se especificó posición, mover el cursor
    if ($X -ge 0 -and $Y -ge 0) {
        try {
            [Console]::SetCursorPosition($X, $Y)
        }
        catch {
            # Si falla, continuar con posición actual
        }
    }
    
    # Línea en blanco antes del banner
    Write-Host ""
    
    # Guardar colores originales
    $originalForeground = [Console]::ForegroundColor
    $originalBackground = [Console]::BackgroundColor
    
    try {
        # Mostrar borde superior
        [Console]::ForegroundColor = $BorderColor
        [Console]::BackgroundColor = $BackgroundColor
        Write-Host $topBorder
        
        # Mostrar cada línea de texto centrada con bordes laterales
        foreach ($line in $Message) {
            $spaces = $bannerWidth - $line.Length
            
            # Siempre centrar
            $leftPad = [Math]::Floor($spaces / 2)
            $rightPad = $spaces - $leftPad
            
            # Mostrar borde lateral izquierdo
            [Console]::ForegroundColor = $BorderColor
            [Console]::BackgroundColor = $BackgroundColor
            Write-Host -NoNewline "║"
            
            # Mostrar contenido de texto centrado
            [Console]::ForegroundColor = $TextColor
            [Console]::BackgroundColor = $BackgroundColor
            Write-Host -NoNewline ((' ' * $leftPad) + $line + (' ' * $rightPad))
            
            # Mostrar borde lateral derecho
            [Console]::ForegroundColor = $BorderColor
            [Console]::BackgroundColor = $BackgroundColor
            Write-Host "║"
        }
        
        # Mostrar borde inferior
        [Console]::ForegroundColor = $BorderColor
        [Console]::BackgroundColor = $BackgroundColor
        Write-Host $bottomBorder
    }
    finally {
        # Restaurar colores originales
        [Console]::ForegroundColor = $originalForeground
        [Console]::BackgroundColor = $originalBackground
    }
    
    # Línea en blanco después del banner
    Write-Host ""
}

function Show-WelcomeMessage {
    <#
    .SYNOPSIS
        Muestra un mensaje de bienvenida parpadeante centrado en la pantalla
    
    .DESCRIPTION
        Obtiene el nombre de usuario de la variable de entorno USERNAME
        y muestra "BIENVENIDO [USERNAME]" en letras grandes ASCII parpadeando
    #>
    
    param(
        [int]$BlinkCount = 3,
        [int]$VisibleDelayMs = 400,
        [ConsoleColor]$TextColor = [ConsoleColor]::Cyan
    )
    
    # Obtener nombre de usuario
    $username = $env:USERNAME
    if (-not $username) {
        $username = "USUARIO"
    }
    
    # Convertir texto a ASCII art grande (letras simples con bloques)
    function ConvertTo-BigLetters {
        param([string]$Text)
        
        if ([string]::IsNullOrWhiteSpace($text)) { return @("", "", "", "", "") }
        
        # Asegurar que $text es string y no null
        if ($null -eq $text) { $text = "" }
        $text = [string]$text
        
        if ($text.Length -eq 0) { return @("", "", "", "", "") }
        
        $text = $text.ToUpper()
        $lines = @("", "", "", "", "", "", "")
        
        foreach ($char in $text.ToCharArray()) {
            $letter = switch ($char) {
                'A' { @(" ███  ", "██ ██ ", "█████ ", "██ ██ ", "██ ██ ") }
                'B' { @("████  ", "██ ██ ", "████  ", "██ ██ ", "████  ") }
                'C' { @(" ███  ", "██    ", "██    ", "██    ", " ███  ") }
                'D' { @("████  ", "██ ██ ", "██ ██ ", "██ ██ ", "████  ") }
                'E' { @("█████ ", "██    ", "████  ", "██    ", "█████ ") }
                'F' { @("█████ ", "██    ", "████  ", "██    ", "██    ") }
                'G' { @(" ███  ", "██    ", "██ ██ ", "██ ██ ", " ███  ") }
                'H' { @("██ ██ ", "██ ██ ", "█████ ", "██ ██ ", "██ ██ ") }
                'I' { @("█████ ", "  ██  ", "  ██  ", "  ██  ", "█████ ") }
                'J' { @("  ███ ", "   ██ ", "   ██ ", "██ ██ ", " ███  ") }
                'K' { @("██ ██ ", "██ ██ ", "████  ", "██ ██ ", "██ ██ ") }
                'L' { @("██    ", "██    ", "██    ", "██    ", "█████ ") }
                'M' { @("█   █ ", "██ ██ ", "█ █ █ ", "█   █ ", "█   █ ") }
                'N' { @("██  ██", "███ ██", "██ ███", "██  ██", "██  ██") }
                'O' { @(" ███  ", "██ ██ ", "██ ██ ", "██ ██ ", " ███  ") }
                'P' { @("████  ", "██ ██ ", "████  ", "██    ", "██    ") }
                'Q' { @(" ███  ", "██ ██ ", "██ ██ ", "██ ██ ", " ████ ") }
                'R' { @("████  ", "██ ██ ", "████  ", "██ ██ ", "██ ██ ") }
                'S' { @(" ███  ", "██    ", " ███  ", "   ██ ", " ███  ") }
                'T' { @("█████ ", "  ██  ", "  ██  ", "  ██  ", "  ██  ") }
                'U' { @("██ ██ ", "██ ██ ", "██ ██ ", "██ ██ ", " ███  ") }
                'V' { @("██ ██ ", "██ ██ ", "██ ██ ", " ███  ", "  ██  ") }
                'W' { @("█   █ ", "█   █ ", "█ █ █ ", "██ ██ ", "█   █ ") }
                'X' { @("██ ██ ", "██ ██ ", " ███  ", "██ ██ ", "██ ██ ") }
                'Y' { @("██ ██ ", "██ ██ ", " ███  ", "  ██  ", "  ██  ") }
                'Z' { @("█████ ", "   ██ ", "  ██  ", "██    ", "█████ ") }
                ' ' { @("      ", "      ", "      ", "      ", "      ") }
                default { @("      ", "      ", "      ", "      ", "      ") }
            }
            
            for ($i = 0; $i -lt 5; $i++) {
                $lines[$i + 1] += $letter[$i]
            }
        }
        
        return $lines
    }
    
    # Generar el texto completo en ASCII
    $fullText = "BIENVENIDO $username"
    $asciiLines = ConvertTo-BigLetters -Text $fullText
    
    $winWidth = [Console]::WindowWidth
    $winHeight = [Console]::WindowHeight
    
    # Calcular posición centrada verticalmente
    $startY = [Math]::Max(0, [int][Math]::Floor(($winHeight - $asciiLines.Count) / 2))
    
    # Parpadear el mensaje
    for ($blink = 0; $blink -lt $BlinkCount; $blink++) {
        # Mostrar mensaje
        for ($i = 0; $i -lt $asciiLines.Count; $i++) {
            $line = $asciiLines[$i]
            $lineLength = $line.Length
            $startX = [Math]::Max(0, [int][Math]::Floor(($winWidth - $lineLength) / 2))
            
            try {
                [Console]::SetCursorPosition($startX, $startY + $i)
                Write-Host $line -ForegroundColor $TextColor -NoNewline
            }
            catch {
                # Ignorar errores de posicionamiento
            }
        }
        
        Start-Sleep -Milliseconds $VisibleDelayMs
        
        # Limpiar mensaje (excepto en el último parpadeo)
        if ($blink -lt ($BlinkCount - 1)) {
            for ($i = 0; $i -lt $asciiLines.Count; $i++) {
                $line = $asciiLines[$i]
                $lineLength = $line.Length
                $startX = [Math]::Max(0, [int][Math]::Floor(($winWidth - $lineLength) / 2))
                
                try {
                    [Console]::SetCursorPosition($startX, $startY + $i)
                    Write-Host (" " * $lineLength) -NoNewline
                }
                catch {
                    # Ignorar errores de posicionamiento
                }
            }
            
            Start-Sleep -Milliseconds ([int]($VisibleDelayMs * 0.4))
        }
    }
    
    # Pausa final antes de continuar
    Start-Sleep -Milliseconds 600
}

function Show-AsciiLogo {
    <#
    .SYNOPSIS
        Muestra un logo ASCII desde archivo con efectos visuales y sonoros
    #>
    param(
        [string]$Path,
        [int]$DelayMs = 300,
        [bool]$ShowProgress = $true,
        [string]$Label = "",
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::Gray,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black,
        [int]$FinalDelaySeconds = 3,
        [bool]$AutoSizeConsole = $true,
        [ConsoleColor]$BarForegroundColor = [ConsoleColor]::Gray,
        [ConsoleColor]$BarBackgroundColor = [ConsoleColor]::DarkGray,
        [ConsoleColor]$OverlayTextColor = [ConsoleColor]::Blue,
        [ConsoleColor]$OverlayBackgroundColor = [ConsoleColor]::Black,
        [bool]$PlaySound = $true
    )

    if (-not (Test-Path $Path)) { 
        Write-Host "Archivo no encontrado: $Path" -ForegroundColor Red
        return 
    }

    # === CONFIGURAR UTF-8 ===
    $originalOutputEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    try {
        $reader = New-Object System.IO.StreamReader($Path, $true)
        $content = $reader.ReadToEnd()
        $reader.Close()
        $lines = $content -split "`r?`n"
    }
    catch {
        [Console]::OutputEncoding = $originalOutputEncoding
        Write-Host "Error leyendo archivo: $_" -ForegroundColor Red
        return
    }

    if (-not $lines -or $lines.Count -eq 0) { 
        [Console]::OutputEncoding = $originalOutputEncoding
        return 
    }
    
    if ($lines -isnot [array]) { $lines = @($lines) }

    # === CALCULAR TAMAÑO DEL LOGO ===
    $maxLineLength = 0
    $effectiveLines = @()
    
    foreach ($line in $lines) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $lineLength = ($line -replace "[\u0000-\u001F]", "").Length
            if ($lineLength -gt $maxLineLength) {
                $maxLineLength = $lineLength
            }
            $effectiveLines += $line
        }
    }
    
    $logoHeight = $effectiveLines.Count
    $logoWidth = $maxLineLength
    
    # === OBTENER TAMAÑO ACTUAL DE LA CONSOLA ===
    $originalConsoleWidth = [Console]::WindowWidth
    $originalConsoleHeight = [Console]::WindowHeight
    
    # === CALCULAR NUEVO TAMAÑO SI SE SOLICITA ===
    if ($AutoSizeConsole) {
        $requiredHeight = $logoHeight + 5
        $requiredWidth = $logoWidth + 4
        
        $ratios = Get-AsciiScalingRatios `
            -OriginalWidth $logoWidth `
            -OriginalHeight $logoHeight `
            -ConsoleWidth $requiredWidth `
            -ConsoleHeight $requiredHeight
        
        if ($ratios.WidthRatio -gt 1 -or $ratios.HeightRatio -gt 1) {
            $requiredWidth = [Math]::Min($requiredWidth, $ratios.MaxWidth)
            $requiredHeight = $logoHeight / $ratios.HeightRatio + 5
        }
        
        $requiredWidth = [Math]::Max($requiredWidth, 80)
        $requiredHeight = [Math]::Max($requiredHeight, 30)
        
        Set-ConsoleSize -Width $requiredWidth -Height $requiredHeight | Out-Null
    }
    
    # === OBTENER NUEVO TAMAÑO ===
    $consoleWidth = [Console]::WindowWidth
    $consoleHeight = [Console]::WindowHeight
    
    $finalRatios = Get-AsciiScalingRatios `
        -OriginalWidth $logoWidth `
        -OriginalHeight $logoHeight `
        -ConsoleWidth $consoleWidth `
        -ConsoleHeight $consoleHeight
    
    # === PREPARAR CONSOLA ===
    $origVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false
    Clear-Host

    # === GUARDAR Y APLICAR COLORES DEL LOGO ===
    $originalFg = [Console]::ForegroundColor
    $originalBg = [Console]::BackgroundColor
    [Console]::ForegroundColor = $ForegroundColor
    [Console]::BackgroundColor = $BackgroundColor

    $startTime = Get-Date
    $barTop = $consoleHeight - 2
    
    # === CENTRAR VERTICALMENTE ===
    $verticalPadding = [Math]::Max(0, [Math]::Floor(($consoleHeight - $logoHeight - 2) / 2))
    
    # === DIBUJAR LOGO ===
    for ($i = 0; $i -lt $effectiveLines.Count; $i++) {
        $verticalPos = $verticalPadding + $i
        
        if ($verticalPos -ge ($consoleHeight - 3)) { break }
        
        $line = $effectiveLines[$i]
        
        # Aplicar escala horizontal si es necesario
        if ($finalRatios.WidthRatio -gt 1) {
            $newLine = ""
            for ($j = 0; $j -lt $line.Length; $j += $finalRatios.WidthRatio) {
                $newLine += $line[$j]
            }
            $line = $newLine
        }
        
        if ($line.Length -gt $consoleWidth) {
            $line = $line.Substring(0, $consoleWidth)
        }
        
        $horizontalPadding = [Math]::Max(0, [Math]::Floor(($consoleWidth - $line.Length) / 2))
        
        try { 
            [Console]::SetCursorPosition($horizontalPadding, $verticalPos) 
        } 
        catch { continue }

        # === ESCRIBIR LÍNEA ===
        Write-Host $line -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor -NoNewline
        
        # === REPRODUCIR SONIDO ESTILO DOS ===
        if ($PlaySound) {
            Invoke-DOSBeep -LineIndex $i -TotalLines $effectiveLines.Count
        }
        
        # === LLAMAR A LA FUNCIÓN DE BARRA DE PROGRESO ===
        if ($ShowProgress) {
            $percent = [int](($i + 1) / $effectiveLines.Count * 100)

            Write-LlevarProgressBar `
                -Percent $percent `
                -StartTime $startTime `
                -Label $Label `
                -Width ([Math]::Min(50, $consoleWidth - 4)) `
                -Top $barTop `
                -ShowEstimated:$false `
                -ShowRemaining:$false `
                -ShowElapsed:$false `
                -ShowPercent:$true `
                -ForegroundColor $BarForegroundColor `
                -BackgroundColor $BarBackgroundColor `
                -OverlayTextColor $OverlayTextColor `
                -OverlayBackgroundColor $OverlayBackgroundColor
        }

        if ($DelayMs -gt 0 -and $i -lt $effectiveLines.Count - 1) {
            Start-Sleep -Milliseconds $DelayMs
        }
    }

    # === Pausa final ===
    if ($FinalDelaySeconds -gt 0) {
        Start-Sleep -Seconds $FinalDelaySeconds
    }

    # === RESTAURAR TODO ===
    [Console]::ForegroundColor = $originalFg
    [Console]::BackgroundColor = $originalBg
    [Console]::CursorVisible = $origVisible
    [Console]::OutputEncoding = $originalOutputEncoding
    
    # Restaurar tamaño original de consola
    if ($AutoSizeConsole) {
        Start-Sleep -Seconds 1
        Set-ConsoleSize -Width $originalConsoleWidth -Height $originalConsoleHeight | Out-Null
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Show-Banner',
    'Show-WelcomeMessage',
    'Show-AsciiLogo'
)
