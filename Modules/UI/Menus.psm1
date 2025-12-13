# ========================================================================== #
#                         MÓDULO: MENÚS INTERACTIVOS                         #
# ========================================================================== #
# Propósito: Menús DOS y popups para interfaces interactivas
# Funciones:
#   - Show-DosMenu: Menú estilo DOS con navegación por teclado y hotkeys
#   - Show-ConsolePopup: Ventana popup con mensaje y opciones
# ========================================================================== #

function Show-DosMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $true)]
        [string[]]$Items,

        [int]$CancelValue = 0,
        [int]$DefaultValue = 0,

        # Colores
        [ConsoleColor]$BorderColor = "White",
        [ConsoleColor]$TextColor = "Gray",
        [ConsoleColor]$TextBackgroundColor = "Black",
        [ConsoleColor]$HighlightForegroundColor = "Black",
        [ConsoleColor]$HighlightBackgroundColor = "Yellow",
        [ConsoleColor]$HotkeyColor = "Cyan",
        [ConsoleColor]$AutoHotkeyColor = "DarkCyan",

        # Posicionamiento del menú
        [int]$X = 0,
        [int]$Y = 0
    )

    if (-not $Items -or $Items.Count -eq 0) {
        throw "Show-DosMenu: no hay elementos para mostrar."
    }

    # ----------------------------
    # 1) PROCESAR HOTKEYS
    # ----------------------------
    $meta = @()
    $usedHotkeys = @()

    for ($i = 0; $i -lt $Items.Count; $i++) {
        $raw = $Items[$i]
        $display = $raw
        $hotIndex = -1
        $hotChar = $null        

        # Hotkey explícita con *
        $star = $raw.IndexOf('*')
        if ($star -ge 0 -and $star -lt ($raw.Length - 1)) {
            $hotChar = $raw[$star + 1]
            $display = $raw.Remove($star, 1)
            $hotIndex = $star
        }

        $meta += [pscustomobject]@{
            Value        = ($i + 1)
            DisplayText  = $display
            HotkeyChar   = $hotChar
            HotkeyIndex  = $hotIndex
            IsAutoHotkey = $false
        }
    }

    # Evitar duplicados explícitos
    foreach ($m in $meta) {
        if ($m.HotkeyChar) {
            $key = ([string]$m.HotkeyChar).ToUpper()
            if ($usedHotkeys -contains $key) {
                $m.HotkeyChar = $null
                $m.HotkeyIndex = -1
            }
            else {
                $usedHotkeys += $key
            }
        }
    }

    # Asignar hotkeys automáticas
    foreach ($m in $meta) {
        if (-not $m.HotkeyChar) {
            $text = $m.DisplayText
            for ($i = 0; $i -lt $text.Length; $i++) {
                $ch = $text[$i]
                if ([char]::IsLetterOrDigit($ch)) {
                    $upper = ([string]$ch).ToUpper()
                    if (-not ($usedHotkeys -contains $upper)) {
                        $m.HotkeyChar = $ch
                        $m.HotkeyIndex = $i
                        $m.IsAutoHotkey = $true
                        $usedHotkeys += $upper
                        break
                    }
                }
            }
        }
    }

    # ----------------------------
    # 2) AGREGAR LA OPCIÓN CANCELAR
    # ----------------------------
    $optionMeta = @(
        [pscustomobject]@{
            Value        = $CancelValue
            DisplayText  = "Cancelar / Volver"
            HotkeyChar   = $null
            HotkeyIndex  = -1
            IsAutoHotkey = $false
        }
    ) + $meta

    # -----------------------------#
    # 3) CALCULAR TAMAÑOS         #
    # -----------------------------#

    $leftIndent = 2      # espacios después del borde izquierdo
    $rightMargin = 2      # margen a la derecha de la opción más larga

    # longitud máxima real de las opciones como se van a dibujar: "N: Texto"
    $maxOptionCore = 0
    foreach ($m in $optionMeta) {
        $lineCore = "{0}: {1}" -f $m.Value, $m.DisplayText
        if ($lineCore.Length -gt $maxOptionCore) {
            $maxOptionCore = $lineCore.Length
        }
    }

    # ancho interior (entre ║ y ║)
    $innerWidth = $leftIndent + $maxOptionCore + $rightMargin

    # el título puede requerir más ancho
    if ($Title.Length -gt $innerWidth) {
        $innerWidth = $Title.Length + 2   # un poco de aire para el título
    }

    $top = "╔" + ("═" * $innerWidth) + "╗"
    $div = "╠" + ("═" * $innerWidth) + "╣"
    $bottom = "╚" + ("═" * $innerWidth) + "╝"

    # Título centrado según innerWidth
    $leftPad = [Math]::Floor(($innerWidth - $Title.Length) / 2)
    $rightPad = $innerWidth - $Title.Length - $leftPad
    $titleLine = "║" + (" " * $leftPad) + $Title + (" " * $rightPad) + "║"

    # ----------------------------
    # 4) DIBUJO SIN PARPADEO
    # ----------------------------
    function Write-MenuLine {
        param($Ypos, $Text, $Fg, $Bg)

        [Console]::SetCursorPosition($menuX, $Ypos)
        Write-Host $Text -ForegroundColor $Fg -BackgroundColor $Bg
    }

    # Ubicación final del menú
    $menuX = $X
    $menuY = $Y

    $selected = 0
    # LIMPIAR UNA SOLA VEZ LA PANTALLA
    Clear-Host

    while ($true) {

        # DIBUJO ESTÁTICO (bordes y título)
        Write-MenuLine ($menuY + 0) $top $BorderColor $TextBackgroundColor
        Write-MenuLine ($menuY + 1) $titleLine $BorderColor $TextBackgroundColor
        Write-MenuLine ($menuY + 2) $div $BorderColor $TextBackgroundColor

        # Línea vacía debajo del título (aire)$result
        Write-MenuLine ($menuY + 3) ("║" + (" " * $innerWidth) + "║") $BorderColor $TextBackgroundColor

        # DIBUJO DINÁMICO DE OPCIONES
        for ($i = 0; $i -lt $optionMeta.Count; $i++) {
            $metaItem = $optionMeta[$i]
            $isSel = ($i -eq $selected)

            $fg = if ($isSel) { $HighlightForegroundColor } else { $TextColor }
            $bg = if ($isSel) { $HighlightBackgroundColor } else { $TextBackgroundColor }

            $coreText = "{0}: {1}" -f $metaItem.Value, $metaItem.DisplayText
            $coreLen = $coreText.Length

            $totalUsed = $leftIndent + $coreLen
            $paddingNeeded = $innerWidth - $totalUsed
            if ($paddingNeeded -lt 0) { $paddingNeeded = 0 }

            # Posicionar al inicio de la línea
            [Console]::SetCursorPosition($menuX, $menuY + 4 + $i)

            # Borde izquierdo
            Write-Host -NoNewline "║" -ForegroundColor $BorderColor -BackgroundColor $bg

            # Indent
            Write-Host -NoNewline (" " * $leftIndent) -ForegroundColor $fg -BackgroundColor $bg

            # Prefijo numérico "N: "
            $numPrefix = "{0}: " -f $metaItem.Value
            Write-Host -NoNewline $numPrefix -ForegroundColor $fg -BackgroundColor $bg

            # Texto con hotkey coloreada
            $disp = $metaItem.DisplayText
            if ($metaItem.HotkeyIndex -ge 0 -and $metaItem.HotkeyIndex -lt $disp.Length) {
                $left = $disp.Substring(0, $metaItem.HotkeyIndex)
                $keyCh = $disp.Substring($metaItem.HotkeyIndex, 1)
                $right = if ($metaItem.HotkeyIndex -lt ($disp.Length - 1)) {
                    $disp.Substring($metaItem.HotkeyIndex + 1)
                }
                else {
                    ""
                }

                if ($left.Length -gt 0) {
                    Write-Host -NoNewline $left -ForegroundColor $fg -BackgroundColor $bg
                }

                $keyFg = if ($metaItem.IsAutoHotkey) { $AutoHotkeyColor } else { $HotkeyColor }
                Write-Host -NoNewline $keyCh -ForegroundColor $keyFg -BackgroundColor $bg

                if ($right.Length -gt 0) {
                    Write-Host -NoNewline $right -ForegroundColor $fg -BackgroundColor $bg
                }
            }
            else {
                # sin hotkey marcada
                Write-Host -NoNewline $disp -ForegroundColor $fg -BackgroundColor $bg
            }

            # Relleno hasta el borde derecho
            Write-Host -NoNewline (" " * $paddingNeeded) -ForegroundColor $fg -BackgroundColor $bg

            # Borde derecho
            Write-Host "║" -ForegroundColor $BorderColor -BackgroundColor $bg
        }
        # Cerrar marco inferior
        Write-MenuLine ($menuY + 4 + $optionMeta.Count) $bottom $BorderColor $TextBackgroundColor

        # Indicaciones
        [Console]::SetCursorPosition($menuX, $menuY + 6 + $optionMeta.Count)
        Write-Host "Use flechas, ENTER, números o hotkeys." -ForegroundColor Gray

        # TECLAS
        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            'UpArrow' { $selected = ($selected - 1 + $optionMeta.Count) % $optionMeta.Count }
            'DownArrow' { $selected = ($selected + 1) % $optionMeta.Count }
            'Enter' { return $optionMeta[$selected].Value }

            Default {
                # Números directos
                if ($key.KeyChar -match '^\d$') {
                    $parsed = [int]$key.KeyChar
                    foreach ($m in $optionMeta) {
                        if ($m.Value -eq $parsed) {
                            return $parsed
                        }
                    }
                }

                # Hotkeys
                $pressed = ([string]$key.KeyChar).ToUpper()
                foreach ($m in $optionMeta) {
                    if ($m.HotkeyChar) {
                        if ($pressed -eq ([string]$m.HotkeyChar).ToUpper()) {
                            return $m.Value
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
        if ($m.HotkeyChar -and -not [string]::IsNullOrEmpty($m.HotkeyChar)) {
            $key = ([string]$m.HotkeyChar).ToUpper()
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
                    $upper = ([string]$ch).ToUpper()
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
            
            # Dibujar bottom al final del dibujado inicial
            [console]::SetCursorPosition($boxLeft, $boxTop + 5 + $msgLines.Count)
            Write-Host $bottomLine -ForegroundColor $BorderColor -BackgroundColor $BorderBackgroundColor
            
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
                    $upperCh = ([string]$ch).ToUpper()
                    for ($i = 0; $i -lt $meta.Count; $i++) {
                        $m = $meta[$i]
                        if ($m.HotkeyChar) {
                            $k = ([string]$m.HotkeyChar).ToUpper()
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
