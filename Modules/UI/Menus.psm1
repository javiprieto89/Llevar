# ========================================================================== #
#                         MÓDULO: MENÚS INTERACTIVOS                         #
# ========================================================================== #
# Propósito: Menús DOS y popups para interfaces interactivas
# Funciones:
#   - Show-DosMenu: Menú estilo DOS con navegación por teclado y hotkeys
#   - Show-ConsolePopup: Ventana popup con mensaje y opciones
# ========================================================================== #

function Show-DosMenu {
    <#
    .SYNOPSIS
        Menú interactivo estilo DOS con navegación por teclado
    .DESCRIPTION
        Muestra un menú con opciones que pueden navegarse con:
        - Flechas arriba/abajo
        - Enter para seleccionar
        - Números para selección directa
        - Hotkeys (marcadas con * en el texto)
        - Hotkeys automáticas (primera letra disponible)
    .PARAMETER Title
        Título del menú
    .PARAMETER Items
        Array de opciones del menú. Use * para marcar hotkey: "*Archivo"
    .PARAMETER CancelValue
        Valor devuelto al cancelar (default 0)
    .PARAMETER DefaultValue
        Valor seleccionado por defecto
    .PARAMETER X
        Posición X del menú (opcional, -1 para auto)
    .PARAMETER Y
        Posición Y del menú (opcional, -1 para auto)
    .OUTPUTS
        Int con el índice seleccionado (1-based)
    .EXAMPLE
        $sel = Show-DosMenu -Title "OPCIONES" -Items @("*Nuevo","*Abrir","*Guardar")
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [string[]]$Items,
        [int]$CancelValue = 0,

        [ConsoleColor]$BorderColor = [ConsoleColor]::White,
        [ConsoleColor]$TextColor = [ConsoleColor]::Gray,
        [ConsoleColor]$TextBackgroundColor = [ConsoleColor]::Black,
        [ConsoleColor]$HighlightForegroundColor = [ConsoleColor]::Black,
        [ConsoleColor]$HighlightBackgroundColor = [ConsoleColor]::Yellow,
        [ConsoleColor]$HotkeyColor = [ConsoleColor]::Cyan,
        [ConsoleColor]$AutoHotkeyColor = [ConsoleColor]::DarkCyan,
        [ConsoleColor]$HotkeyBackgroundColor = [ConsoleColor]::Black,
        [int]$DefaultValue = $CancelValue,
        
        [int]$X = -1,
        [int]$Y = -1
    )

    if (-not $Items -or $Items.Count -eq 0) {
        throw "Show-DosMenu: no hay elementos para mostrar."
    }

    $hasCancel = $true
    $cancelLabel = "Cancelar / Volver"

    # 1) Parsear items con posible *hotkey
    $meta = @()
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $num = $i + 1
        $raw = $Items[$i]
        $display = $raw
        $hotChar = $null
        $hotIndex = -1
        $isAuto = $false

        $starIndex = $raw.IndexOf('*')
        if ($starIndex -ge 0 -and $starIndex -lt ($raw.Length - 1)) {
            $hotChar = $raw[$starIndex + 1]
            $display = $raw.Remove($starIndex, 1)
            $hotIndex = $starIndex
        }

        $meta += [pscustomobject]@{
            Value        = $num
            DisplayText  = $display
            HotkeyChar   = $hotChar
            HotkeyIndex  = $hotIndex
            IsAutoHotkey = $isAuto
        }
    }

    # 2) Evitar teclas repetidas
    $usedHotkeys = @()
    foreach ($m in $meta) {
        if ($m.HotkeyChar -ne $null -and [string]::IsNullOrEmpty($m.HotkeyChar) -eq $false) {
            $key = [string]::ToUpper([string]$m.HotkeyChar)
            if ($usedHotkeys -contains $key) {
                $m.HotkeyChar = $null
                $m.HotkeyIndex = -1
            }
            else {
                $usedHotkeys += $key
            }
        }
    }

    # 3) Asignar teclas automaticas donde falten
    foreach ($m in $meta) {
        if (-not $m.HotkeyChar) {
            $text = $m.DisplayText
            for ($idx = 0; $idx -lt $text.Length; $idx++) {
                $ch = $text[$idx]
                if ([char]::IsLetterOrDigit($ch)) {
                    $upper = [string]::ToUpper([string]$ch)
                    if (-not ($usedHotkeys -contains $upper)) {
                        $m.HotkeyChar = $ch
                        $m.HotkeyIndex = $idx
                        $m.IsAutoHotkey = $true
                        $usedHotkeys += $upper
                        break
                    }
                }
            }
        }
    }

    # 4) Construir lista de opciones (incluye cancelar)
    $optionLines = @()
    $optionMeta = @()

    if ($hasCancel) {
        $cancelMeta = [pscustomobject]@{
            Value        = $CancelValue
            DisplayText  = $cancelLabel
            HotkeyChar   = $null
            HotkeyIndex  = -1
            IsAutoHotkey = $false
        }
        $optionMeta += $cancelMeta
        $optionLines += ("{0}: {1}" -f $CancelValue, $cancelLabel)
    }

    foreach ($m in $meta) {
        $optionMeta += $m
        $optionLines += ("{0}: {1}" -f $m.Value, $m.DisplayText)
    }

    $contentWidth = ($optionLines | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $titleWidth = $Title.Length
    if ($titleWidth -gt $contentWidth) { $contentWidth = $titleWidth }

    $padding = 2
    $innerWidth = $contentWidth + ($padding * 2)

    $top = "╔" + ("═" * $innerWidth) + "╗"
    $bottom = "╚" + ("═" * $innerWidth) + "╝"

    # Línea divisoria
    $divider = "╠" + ("═" * $innerWidth) + "╣"

    # Título centrado
    $leftPad = [int][Math]::Floor(($innerWidth - $Title.Length) / 2)
    $rightPad = $innerWidth - $Title.Length - $leftPad
    $titleLine = "║" + (" " * $leftPad) + $Title + (" " * $rightPad) + "║"

    # Seleccion inicial
    $selectedIndex = 0
    if ($optionMeta.Count -gt 0) {
        for ($i = 0; $i -lt $optionMeta.Count; $i++) {
            if ($optionMeta[$i].Value -eq $DefaultValue) {
                $selectedIndex = $i
                break
            }
        }
    }

    # Calcular posición si se especificó
    $menuX = -1
    $menuY = -1
    if ($X -ge 0 -and $Y -ge 0) {
        $winWidth = [Console]::WindowWidth
        $winHeight = [Console]::WindowHeight
        $menuX = [Math]::Max(0, [Math]::Min($X, $winWidth - $innerWidth - 2))
        $menuY = [Math]::Max(0, [Math]::Min($Y, $winHeight - ($optionLines.Count + 5)))
    }

    # Dibujar menú completo solo una vez
    $needsFullRedraw = $true
    $previousSelection = -1

    while ($true) {
        # Solo redibujar si es la primera vez
        if ($needsFullRedraw) {
            Clear-Host
            $needsFullRedraw = $false
        
            # Si se especificó posición, mover cursor a esa posición
            if ($menuX -ge 0 -and $menuY -ge 0) {
                try {
                    [Console]::SetCursorPosition($menuX, $menuY)
                }
                catch {
                    # Si falla, continuar con posición por defecto
                }
            }
        
            Write-Host $top       -ForegroundColor $BorderColor
        
            if ($menuX -ge 0 -and $menuY -ge 0) {
                [Console]::SetCursorPosition($menuX, $menuY + 1)
            }
            Write-Host $titleLine -ForegroundColor $BorderColor
        
            if ($menuX -ge 0 -and $menuY -ge 0) {
                [Console]::SetCursorPosition($menuX, $menuY + 2)
            }
            Write-Host $divider -ForegroundColor $BorderColor
        
            if ($menuX -ge 0 -and $menuY -ge 0) {
                [Console]::SetCursorPosition($menuX, $menuY + 3)
            }
            Write-Host ("║" + (" " * $innerWidth) + "║") -ForegroundColor $BorderColor
        }

        # Redibujar solo las líneas que cambiaron
        $linesToRedraw = @()
        if ($previousSelection -ge 0 -and $previousSelection -ne $selectedIndex) {
            $linesToRedraw += $previousSelection
        }
        if ($selectedIndex -ge 0) {
            $linesToRedraw += $selectedIndex
        }
        
        # Si es primera vez, dibujar todas
        if ($previousSelection -eq -1) {
            $linesToRedraw = 0..($optionLines.Count - 1)
        }

        foreach ($i in $linesToRedraw) {
            $line = $optionLines[$i]
            $metaItem = $optionMeta[$i]
            $padRight = $innerWidth - $line.Length
            if ($padRight -lt 0) { $padRight = 0 }

            $isSelected = ($i -eq $selectedIndex)

            $lineBg = $TextBackgroundColor
            $lineFg = $TextColor
            if ($isSelected) {
                $lineBg = $HighlightBackgroundColor
                $lineFg = $HighlightForegroundColor
            }

            $prefix = ("{0}: " -f $metaItem.Value)
            $display = $metaItem.DisplayText

            if ($menuX -ge 0 -and $menuY -ge 0) {
                [Console]::SetCursorPosition($menuX, $menuY + 4 + $i)
            }
            Write-Host -NoNewline "║ " -ForegroundColor $BorderColor -BackgroundColor $lineBg
            Write-Host -NoNewline $prefix -ForegroundColor $lineFg -BackgroundColor $lineBg

            if ($metaItem.HotkeyIndex -ge 0 -and $metaItem.HotkeyIndex -lt $display.Length) {
                $left = $display.Substring(0, $metaItem.HotkeyIndex)
                $keyChar = $display.Substring($metaItem.HotkeyIndex, 1)
                $right = ""
                if ($metaItem.HotkeyIndex -lt ($display.Length - 1)) {
                    $right = $display.Substring($metaItem.HotkeyIndex + 1)
                }

                if ($left.Length -gt 0) {
                    Write-Host -NoNewline $left -ForegroundColor $lineFg -BackgroundColor $lineBg
                }

                $keyFg = if ($metaItem.IsAutoHotkey) { $AutoHotkeyColor } else { $HotkeyColor }
                $keyBg = $HotkeyBackgroundColor
                if ($isSelected) {
                    $keyBg = $HighlightBackgroundColor
                }

                Write-Host -NoNewline $keyChar -ForegroundColor $keyFg -BackgroundColor $keyBg

                if ($right.Length -gt 0) {
                    Write-Host -NoNewline $right -ForegroundColor $lineFg -BackgroundColor $lineBg
                }
            }
            else {
                Write-Host -NoNewline $display -ForegroundColor $lineFg -BackgroundColor $lineBg
            }

            Write-Host -NoNewline (" " * ($padRight - 1)) -ForegroundColor $lineBg -BackgroundColor $lineBg
            Write-Host "║" -ForegroundColor $BorderColor -BackgroundColor $lineBg
        }

        # Dibujar bottom y ayuda solo la primera vez
        if ($previousSelection -eq -1) {
            if ($menuX -ge 0 -and $menuY -ge 0) {
                [Console]::SetCursorPosition($menuX, $menuY + 4 + $optionLines.Count)
            }
            Write-Host $bottom -ForegroundColor $BorderColor
            Write-Host ""
            Write-Host "Use flechas, ENTER, numero, o tecla resaltada."
        }
        
        # Actualizar selección previa
        $previousSelection = $selectedIndex

        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            'UpArrow' { $selectedIndex = ($selectedIndex - 1); if ($selectedIndex -lt 0) { $selectedIndex = $optionLines.Count - 1 } }
            'DownArrow' { $selectedIndex = ($selectedIndex + 1); if ($selectedIndex -ge $optionLines.Count) { $selectedIndex = 0 } }
            'Enter' {
                $lineSel = $optionLines[$selectedIndex]
                if ($lineSel -match '^\s*(\d+)\s*:') {
                    Clear-Host  # Limpiar solo al salir del menú
                    return [int]$matches[1]
                }
            }
            default {
                $ch = $key.KeyChar
                if ($ch -match '^\d$') {
                    $num = [int]::Parse($ch)
                    foreach ($m in $optionMeta) {
                        if ($m.Value -eq $num) {
                            Clear-Host  # Limpiar solo al salir del menú
                            return $num
                        }
                    }
                }
                elseif ($ch -match '^[A-Za-z0-9]$') {
                    $upperCh = [string]::ToUpper([string]$ch)
                    foreach ($m in $optionMeta) {
                        if ($m.HotkeyChar) {
                            $mKey = [string]::ToUpper([string]$m.HotkeyChar)
                            if ($mKey -eq $upperCh) {
                                Clear-Host  # Limpiar solo al salir del menú
                                return [int]$m.Value
                            }
                        }
                    }
                }
            }
        }
    }
}

function Show-ConsolePopup {
    <#
    .SYNOPSIS
        Ventana popup con mensaje y opciones
    .DESCRIPTION
        Muestra una ventana emergente centrada con:
        - Título personalizado
        - Mensaje multilínea
        - Opciones navegables con hotkeys
        - Bordes y colores configurables
        - Posicionamiento automático o manual
    .PARAMETER Title
        Título de la ventana
    .PARAMETER Message
        Mensaje a mostrar (soporta múltiples líneas con `n)
    .PARAMETER Options
        Array de opciones. Use * para marcar hotkey: @("*Sí","*No")
    .PARAMETER DefaultIndex
        Índice de la opción seleccionada por defecto
    .PARAMETER AllowEsc
        Si se permite cancelar con ESC (retorna -1)
    .PARAMETER Beep
        Reproduce beep al mostrar el popup
    .PARAMETER X
        Posición X (opcional, -1 para centrar)
    .PARAMETER Y
        Posición Y (opcional, -1 para centrar)
    .OUTPUTS
        Int con el índice de la opción seleccionada, o -1 si se cancela con ESC
    .EXAMPLE
        $result = Show-ConsolePopup -Title "Confirmar" -Message "¿Continuar?" -Options @("*Sí","*No")
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string[]]$Options = @("*Aceptar"),
        [int]$DefaultIndex = 0,

        [ConsoleColor]$BorderColor = [ConsoleColor]::White,
        [ConsoleColor]$BorderBackgroundColor = [ConsoleColor]::Black,
        [ConsoleColor]$TitleColor = [ConsoleColor]::Yellow,
        [ConsoleColor]$TitleBackgroundColor = [ConsoleColor]::DarkBlue,
        [ConsoleColor]$TextColor = [ConsoleColor]::Gray,
        [ConsoleColor]$TextBackgroundColor = [ConsoleColor]::Black,
        [ConsoleColor]$OptionColor = [ConsoleColor]::Gray,
        [ConsoleColor]$OptionBackgroundColor = [ConsoleColor]::Black,
        [ConsoleColor]$OptionHighlightColor = [ConsoleColor]::Black,
        [ConsoleColor]$OptionHighlightBackground = [ConsoleColor]::Yellow,
        [ConsoleColor]$HotkeyColor = [ConsoleColor]::Cyan,
        [ConsoleColor]$AutoHotkeyColor = [ConsoleColor]::DarkCyan,
        [ConsoleColor]$HotkeyBackgroundColor = [ConsoleColor]::Black,

        [switch]$AllowEsc,
        [switch]$Beep,
        
        [int]$X = -1,
        [int]$Y = -1
    )

    if (-not $Options -or $Options.Count -eq 0) {
        $Options = @("*Aceptar")
    }

    if ($Beep) {
        [console]::Beep()
    }

    $msgLines = $Message -split "`r?`n"

    # procesar opciones con * hotkeys
    $meta = @()
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $raw = $Options[$i]
        $display = $raw
        $hotChar = $null
        $hotIndex = -1
        $isAuto = $false

        $starIndex = $raw.IndexOf('*')
        if ($starIndex -ge 0 -and $starIndex -lt ($raw.Length - 1)) {
            $hotChar = $raw[$starIndex + 1]
            $display = $raw.Remove($starIndex, 1)
            $hotIndex = $starIndex
        }

        $meta += [pscustomobject]@{
            Index       = $i
            DisplayText = $display
            HotkeyChar  = $hotChar
            HotkeyIndex = $hotIndex
            IsAuto      = $isAuto
        }
    }

    $usedHotkeys = @()
    foreach ($m in $meta) {
        if ($m.HotkeyChar -ne $null -and [string]::IsNullOrEmpty($m.HotkeyChar) -eq $false) {
            $key = [string]::ToUpper([string]$m.HotkeyChar)
            if ($usedHotkeys -contains $key) {
                $m.HotkeyChar = $null
                $m.HotkeyIndex = -1
            }
            else {
                $usedHotkeys += $key
            }
        }
    }

    foreach ($m in $meta) {
        if (-not $m.HotkeyChar) {
            $text = $m.DisplayText
            for ($idx = 0; $idx -lt $text.Length; $idx++) {
                $ch = $text[$idx]
                if ([char]::IsLetterOrDigit($ch)) {
                    $upper = [string]::ToUpper([string]$ch)
                    if (-not ($usedHotkeys -contains $upper)) {
                        $m.HotkeyChar = $ch
                        $m.HotkeyIndex = $idx
                        $m.IsAuto = $true
                        $usedHotkeys += $upper
                        break
                    }
                }
            }
        }
    }

    $optionsText = ($meta | ForEach-Object { $_.DisplayText }) -join "   "
    $maxMsgWidth = ($msgLines | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    if ($null -eq $maxMsgWidth) { $maxMsgWidth = 0 }
    $contentWidth = [Math]::Max($maxMsgWidth, [Math]::Max($Title.Length, $optionsText.Length))
    $padding = 4
    $innerWidth = $contentWidth + $padding
    $boxWidth = $innerWidth + 2

    $topLine = "╔" + ("═" * $innerWidth) + "╗"
    $bottomLine = "╚" + ("═" * $innerWidth) + "╝"
    $dividerLine = "╠" + ("═" * $innerWidth) + "╣"

    $winWidth = [console]::WindowWidth
    $winHeight = [console]::WindowHeight

    # Usar posición especificada o calcular centrado
    if ($X -ge 0) {
        $boxLeft = [Math]::Max(0, [Math]::Min($X, $winWidth - $boxWidth))
    }
    else {
        $boxLeft = [Math]::Max(0, [int][Math]::Floor(($winWidth - $boxWidth) / 2))
    }
    
    if ($Y -ge 0) {
        $boxTop = [Math]::Max(0, [Math]::Min($Y, $winHeight - ($msgLines.Count + 6)))
    }
    else {
        $boxTop = [Math]::Max(0, [int][Math]::Floor(($winHeight - ($msgLines.Count + 6)) / 2))
    }

    $selected = if ($DefaultIndex -ge 0 -and $DefaultIndex -lt $meta.Count) { $DefaultIndex } else { 0 }
    $previousSelected = -1
    $needsFullRedraw = $true

    while ($true) {
        # Dibujar fondo solo la primera vez
        if ($needsFullRedraw) {
            for ($row = 0; $row -lt ($msgLines.Count + 6); $row++) {
                [console]::SetCursorPosition($boxLeft, $boxTop + $row)
                Write-Host (" " * $boxWidth) -NoNewline -BackgroundColor $BorderBackgroundColor
            }

            # borde superior
            [console]::SetCursorPosition($boxLeft, $boxTop)
            Write-Host $topLine -ForegroundColor $BorderColor -BackgroundColor $BorderBackgroundColor

            # titulo
            $titlePad = $innerWidth - $Title.Length
            $leftPad = [int][Math]::Floor($titlePad / 2)
            $rightPad = $innerWidth - $Title.Length - $leftPad
            $titleLine = "║" + (" " * $leftPad) + $Title + (" " * $rightPad) + "║"
            [console]::SetCursorPosition($boxLeft, $boxTop + 1)
            Write-Host $titleLine -ForegroundColor $TitleColor -BackgroundColor $TitleBackgroundColor

            # linea divisoria
            [console]::SetCursorPosition($boxLeft, $boxTop + 2)
            Write-Host $dividerLine -ForegroundColor $BorderColor -BackgroundColor $BorderBackgroundColor

            # mensaje (centrado)
            for ($i = 0; $i -lt $msgLines.Count; $i++) {
                $line = $msgLines[$i]
                $linePad = $innerWidth - $line.Length
                if ($linePad -lt 0) { $linePad = 0 }
            
                # Centrar el mensaje
                $lineLeftPad = [int][Math]::Floor($linePad / 2)
                $lineRightPad = $linePad - $lineLeftPad
            
                [console]::SetCursorPosition($boxLeft, $boxTop + 3 + $i)
                Write-Host -NoNewline "║" -ForegroundColor $BorderColor -BackgroundColor $TextBackgroundColor
                Write-Host -NoNewline (" " * $lineLeftPad) -ForegroundColor $TextColor -BackgroundColor $TextBackgroundColor
                Write-Host -NoNewline $line -ForegroundColor $TextColor -BackgroundColor $TextBackgroundColor
                Write-Host -NoNewline (" " * $lineRightPad) -ForegroundColor $TextColor -BackgroundColor $TextBackgroundColor
                Write-Host "║" -ForegroundColor $BorderColor -BackgroundColor $TextBackgroundColor
            }

            # linea separadora antes de opciones
            [console]::SetCursorPosition($boxLeft, $boxTop + 3 + $msgLines.Count)
            Write-Host $dividerLine -ForegroundColor $BorderColor -BackgroundColor $BorderBackgroundColor
            
            $needsFullRedraw = $false
        }

        # Redibujar línea de opciones solo si cambió la selección
        if ($previousSelected -ne $selected -or $needsFullRedraw) {
            # opciones (centradas)
            # Calcular ancho total de opciones con espacios entre ellas
            $optionsWidth = 0
            for ($i = 0; $i -lt $meta.Count; $i++) {
                $optionsWidth += $meta[$i].DisplayText.Length
                if ($i -gt 0) { $optionsWidth += 3 }  # espacios entre opciones
            }
        
            # Calcular padding para centrar
            $optionsPad = $innerWidth - $optionsWidth
            if ($optionsPad -lt 0) { $optionsPad = 0 }
            $optionsLeftPad = [int][Math]::Floor($optionsPad / 2)
            $optionsRightPad = $optionsPad - $optionsLeftPad
        
            [console]::SetCursorPosition($boxLeft, $boxTop + 4 + $msgLines.Count)
            Write-Host -NoNewline "║" -ForegroundColor $BorderColor -BackgroundColor $TextBackgroundColor
            Write-Host -NoNewline (" " * $optionsLeftPad) -BackgroundColor $TextBackgroundColor

            for ($i = 0; $i -lt $meta.Count; $i++) {
                $m = $meta[$i]
                $isSel = ($i -eq $selected)

                $fg = $OptionColor
                $bg = $OptionBackgroundColor
                if ($isSel) {
                    $fg = $OptionHighlightColor
                    $bg = $OptionHighlightBackground
                }

                $display = $m.DisplayText

                if ($i -gt 0) {
                    Write-Host "   " -NoNewline -ForegroundColor $fg -BackgroundColor $bg
                }

                if ($m.HotkeyIndex -ge 0 -and $m.HotkeyIndex -lt $display.Length) {
                    $left = $display.Substring(0, $m.HotkeyIndex)
                    $keyCh = $display.Substring($m.HotkeyIndex, 1)
                    $right = ""
                    if ($m.HotkeyIndex -lt ($display.Length - 1)) {
                        $right = $display.Substring($m.HotkeyIndex + 1)
                    }

                    if ($left.Length -gt 0) {
                        Write-Host $left -NoNewline -ForegroundColor $fg -BackgroundColor $bg
                    }

                    $kfg = if ($m.IsAuto) { $AutoHotkeyColor } else { $HotkeyColor }
                    $kbg = $HotkeyBackgroundColor
                    if ($isSel) { 
                        $kbg = $OptionHighlightBackground
                        $kfg = [ConsoleColor]::DarkBlue  # Color que se lee bien sobre amarillo
                    }

                    Write-Host $keyCh -NoNewline -ForegroundColor $kfg -BackgroundColor $kbg

                    if ($right.Length -gt 0) {
                        Write-Host $right -NoNewline -ForegroundColor $fg -BackgroundColor $bg
                    }
                }
                else {
                    Write-Host $display -NoNewline -ForegroundColor $fg -BackgroundColor $bg
                }
            }
        
            # Completar con espacios y cerrar borde derecho
            Write-Host -NoNewline (" " * $optionsRightPad) -BackgroundColor $TextBackgroundColor
            Write-Host "║" -ForegroundColor $BorderColor -BackgroundColor $TextBackgroundColor
            
            $previousSelected = $selected
        }

        # Dibujar bottom solo la primera vez
        if ($previousSelected -eq -1 -or ($previousSelected -ne $selected -and $previousSelected -eq -1)) {
            [console]::SetCursorPosition($boxLeft, $boxTop + 5 + $msgLines.Count)
            Write-Host $bottomLine -ForegroundColor $BorderColor -BackgroundColor $BorderBackgroundColor
        }

        # leer tecla
        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            'LeftArrow' { $selected = ($selected - 1); if ($selected -lt 0) { $selected = $meta.Count - 1 } }
            'RightArrow' { $selected = ($selected + 1); if ($selected -ge $meta.Count) { $selected = 0 } }
            'UpArrow' { $selected = ($selected - 1); if ($selected -lt 0) { $selected = $meta.Count - 1 } }
            'DownArrow' { $selected = ($selected + 1); if ($selected -ge $meta.Count) { $selected = 0 } }
            'Enter' { return $selected }
            'Escape' {
                if ($AllowEsc) {
                    return -1
                }
            }
            default {
                $ch = $key.KeyChar
                if ($ch -match '^[A-Za-z0-9]$') {
                    $upperCh = [string]::ToUpper([string]$ch)
                    for ($i = 0; $i -lt $meta.Count; $i++) {
                        $m = $meta[$i]
                        if ($m.HotkeyChar) {
                            $k = [string]::ToUpper([string]$m.HotkeyChar)
                            if ($k -eq $upperCh) {
                                return $i
                            }
                        }
                    }
                }
            }
        }
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Show-DosMenu',
    'Show-ConsolePopup'
)
