# ========================================================================== #
#                     MÓDULO: NAVEGADOR NORTON COMMANDER                     #
# ========================================================================== #
# Propósito: Explorador de archivos/carpetas estilo Norton Commander
# Funciones:
#   - Select-PathNavigator: Navegador interactivo con teclado
# ========================================================================== #

# Todos los módulos necesarios ya fueron importados por Llevar.ps1
# Solo importar si se usan de forma independiente
if (-not (Get-Command Get-DirectoryItems -ErrorAction SilentlyContinue)) {
    Import-Module "$PSScriptRoot\..\System\FileSystem.psm1" -Force -Global
}
if (-not (Get-Command Write-LlevarProgressBar -ErrorAction SilentlyContinue)) {
    Import-Module "$PSScriptRoot\..\UI\ProgressBar.psm1" -Force -Global
}
if (-not (Get-Command Select-NetworkPath -ErrorAction SilentlyContinue)) {
    Import-Module "$PSScriptRoot\..\Transfer\UNC.psm1" -Force -Global
}

# Variable global para almacenar tamaños calculados de directorios
$script:DirectorySizeCache = @{}

function Select-PathNavigator {
    <#
    .SYNOPSIS
        Explorador de archivos/carpetas estilo Norton Commander con navegación por teclado
    .DESCRIPTION
        Proporciona una interfaz de usuario estilo Norton Commander para navegar
        por el sistema de archivos con soporte para:
        - Navegación por teclado (flechas, Enter, ESC)
        - Selector de unidades (F2)
        - Discovery de recursos de red UNC (F3)
        - Buscador con filtrado (F4)
        - Cálculo de tamaño de carpetas (ESPACIO)
        - Selección de archivos o carpetas
        - Scroll automático para listas grandes
    .PARAMETER Prompt
        Título del explorador
    .PARAMETER AllowFiles
        Si es $true, permite seleccionar archivos. Si es $false, solo carpetas.
    .PARAMETER ProviderOptions
        Hashtable usado para personalizar comportamientos del navegador (permite deshabilitar F2/F3 y definir el
        proveedor de tamaños). Claves: AllowDriveSelector, AllowNetworkDiscovery, SizeCalculator, Token, DriveId, ModulePath.
    .OUTPUTS
        String con la ruta completa seleccionada, o $null si se cancela
    .EXAMPLE
        $folder = Select-PathNavigator -Prompt "Seleccione carpeta de origen"
    .EXAMPLE
        $file = Select-PathNavigator -Prompt "Seleccione archivo" -AllowFiles $true
    #>
    param(
        [string]$Prompt = "Seleccionar ubicación",
        [bool]$AllowFiles = $false,
        [scriptblock]$ItemProvider,
        [string]$InitialPath,
        [hashtable]$ProviderOptions
    )
    
    # Obtener todas las unidades disponibles (solo letras de unidad A-Z)
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -and $_.Name -match '^[A-Z]$' }
    $currentPath = if ($InitialPath) { $InitialPath } else { $PWD.Path }
    $selectedIndex = 0
    $scrollOffset = 0
    $searchMode = $false
    $searchPattern = ""
    $allItems = @()
    $filteredItems = @()
    
    if (-not $ProviderOptions) {
        $ProviderOptions = @{}
    }
    
    $allowDriveSelector = if ($ProviderOptions.ContainsKey('AllowDriveSelector')) { [bool]$ProviderOptions.AllowDriveSelector } else { $true }
    $allowNetworkDiscovery = if ($ProviderOptions.ContainsKey('AllowNetworkDiscovery')) { [bool]$ProviderOptions.AllowNetworkDiscovery } else { $true }
    $providerToken = $ProviderOptions.Token
    $providerDriveId = $ProviderOptions.DriveId
    $modulePath = $ProviderOptions.ModulePath
    $useRemoteSizeCalculator = if ($ProviderOptions.ContainsKey('UseRemoteSizeCalculator')) { [bool]$ProviderOptions.UseRemoteSizeCalculator } else { $false }
    
    # Función auxiliar para mostrar selector de unidades
    function Show-DriveSelector {
        $driveItems = @()
        foreach ($drive in $drives) {
            $driveItems += [PSCustomObject]@{
                Name            = "$($drive.Root) - $($drive.Description)"
                FullName        = $drive.Root
                IsDirectory     = $true
                IsParent        = $false
                IsDriveSelector = $false
                Size            = ""
                Icon            = "💾"
            }
        }
        return $driveItems
    }
    
    # Función para dibujar la interfaz
    function Show-Interface {
        param(
            [string]$Path,
            [array]$Items,
            [int]$SelectedIndex,
            [int]$ScrollOffset,
            [bool]$SearchMode = $false,
            [string]$SearchPattern = ""
        )
        
        # Evitar parpadeo usando SetCursorPosition en lugar de Clear-Host
        try {
            if (System.Management.Automation.Internal.Host.InternalHost.Name -and (System.Management.Automation.Internal.Host.InternalHost.Name -ilike '*consolehost*' -or System.Management.Automation.Internal.Host.InternalHost.Name -ilike '*visual studio code host*')) { try { [Console]::SetCursorPosition(0, 0) } catch { Clear-Host } } else { Clear-Host }
        }
        catch {
            Clear-Host
        }
        $width = [Math]::Min($host.UI.RawUI.WindowSize.Width - 2, 118)
        $height = [Math]::Min($host.UI.RawUI.WindowSize.Height - 12, 25)
        
        # Encabezado
        $borderLine = "═" * $width
        Write-Host "╔${borderLine}╗" -ForegroundColor Cyan
        
        # Título centrado
        $titlePadding = [Math]::Max(0, ($width - $Prompt.Length) / 2)
        $leftPad = [Math]::Floor($titlePadding)
        $rightPad = $width - $Prompt.Length - $leftPad
        $titleLine = (" " * $leftPad) + $Prompt + (" " * $rightPad)
        Write-Host "║${titleLine}║" -ForegroundColor Cyan
        
        Write-Host "╠${borderLine}╣" -ForegroundColor Cyan
        
        # Ruta actual o modo búsqueda
        if ($SearchMode) {
            $searchDisplay = "🔍 BÚSQUEDA: $SearchPattern"
            if ($searchDisplay.Length -gt ($width - 2)) {
                $searchDisplay = $searchDisplay.Substring(0, $width - 5) + "..."
            }
            $searchLine = " " + $searchDisplay
            $searchLine = $searchLine.PadRight($width)
            
            Write-Host "║" -ForegroundColor Cyan -NoNewline
            Write-Host $searchLine -ForegroundColor Green -NoNewline
            Write-Host "║" -ForegroundColor Cyan
        }
        else {
            $pathDisplay = $Path
            if ($pathDisplay.Length -gt ($width - 2)) {
                $pathDisplay = "..." + $pathDisplay.Substring($pathDisplay.Length - ($width - 5))
            }
            $pathLine = " " + $pathDisplay
            $pathLine = $pathLine.PadRight($width)
            
            Write-Host "║" -ForegroundColor Cyan -NoNewline
            Write-Host $pathLine -ForegroundColor Yellow -NoNewline
            Write-Host "║" -ForegroundColor Cyan
        }
        
        Write-Host "╠${borderLine}╣" -ForegroundColor Cyan
        
        # Lista de items
        $visibleItems = $height
        for ($i = 0; $i -lt $visibleItems; $i++) {
            $itemIndex = $i + $ScrollOffset
            
            if ($itemIndex -lt $Items.Count) {
                $item = $Items[$itemIndex]
                $isSelected = ($itemIndex -eq $SelectedIndex)
                
                # Preparar el texto del item
                $icon = $item.Icon
                $name = $item.Name
                $size = $item.Size
                
                # Ancho disponible para el contenido (sin los bordes ║ ║)
                $contentWidth = $width
                $sizeWidth = 16  # Ancho fijo para la columna de tamaño (aumentado para "XX.XX MB <DIR>")
                
                # Calcular espacio para nombre considerando: " " + icon + " " + nombre + padding + tamaño
                # Los emojis ocupan ~2 caracteres de ancho visual
                $iconSpace = 3  # espacio + emoji (cuenta como 2) + espacio
                $maxNameLength = $contentWidth - $iconSpace - $sizeWidth - 1
                
                if ($name.Length -gt $maxNameLength) {
                    $name = $name.Substring(0, $maxNameLength - 3) + "..."
                }
                
                # Construir la línea: " icon nombre       tamaño"
                $namePart = " $icon $name"
                $namePartLength = 1 + 2 + 1 + $name.Length  # espacio + emoji(2) + espacio + nombre
                $paddingNeeded = $contentWidth - $namePartLength - $sizeWidth
                $line = $namePart + (" " * $paddingNeeded) + $size.PadLeft($sizeWidth)
                
                # Ajustar longitud exacta por si hay diferencias
                if ($line.Length -gt $contentWidth) {
                    $line = $line.Substring(0, $contentWidth)
                }
                elseif ($line.Length -lt $contentWidth) {
                    $line = $line.PadRight($contentWidth)
                }
                
                # Mostrar la línea
                if ($isSelected) {
                    Write-Host "║" -ForegroundColor Cyan -NoNewline
                    Write-Host $line -BackgroundColor DarkCyan -ForegroundColor White -NoNewline
                    Write-Host "║" -ForegroundColor Cyan
                }
                else {
                    $color = if ($item.IsDirectory) { "White" } else { "Gray" }
                    Write-Host "║" -ForegroundColor Cyan -NoNewline
                    Write-Host $line -ForegroundColor $color -NoNewline
                    Write-Host "║" -ForegroundColor Cyan
                }
            }
            else {
                # Línea vacía
                Write-Host "║" -ForegroundColor Cyan -NoNewline
                Write-Host (" " * $width) -NoNewline
                Write-Host "║" -ForegroundColor Cyan
            }
        }
        
        # Pie con instrucciones
        $borderLine = "═" * $width
        Write-Host "╠${borderLine}╣" -ForegroundColor Cyan
        
        if ($SearchMode) {
            $instructions = "Escriba para buscar │ ESC:Salir búsqueda │ Enter:Aplicar"
        }
        else {
            $tokens = @(
                "↑↓:Nav",
                "Enter",
                "←:Atrás",
                "ESPACIO:Tamaño",
                "F4:Buscar",
                "F10:Sel",
                "ESC"
            )
            if ($allowDriveSelector) {
                $tokens += "F2:Unidad"
            }
            if ($allowNetworkDiscovery) {
                $tokens += "F3:Red"
            }
            $instructions = ($tokens -join " │ ")
        }
        
        if ($instructions.Length -gt $width) {
            $tokens = @("↑↓", "Enter", "ESPACIO:Tamaño", "F4", "F10", "ESC")
            if ($allowDriveSelector) {
                $tokens += "F2"
            }
            if ($allowNetworkDiscovery) {
                $tokens += "F3"
            }
            $instructions = ($tokens -join " │ ")
        }
        
        # Centrar las instrucciones
        $instrPadding = [Math]::Max(0, ($width - $instructions.Length) / 2)
        $leftPad = [Math]::Floor($instrPadding)
        $rightPad = $width - $instructions.Length - $leftPad
        $instrLine = (" " * $leftPad) + $instructions + (" " * $rightPad)
        
        Write-Host "║" -ForegroundColor Cyan -NoNewline
        Write-Host $instrLine -ForegroundColor Green -NoNewline
        Write-Host "║" -ForegroundColor Cyan
        
        Write-Host "╚${borderLine}╝" -ForegroundColor Cyan
        
        # Información adicional
        Write-Host ""
        $selectedItem = $Items[$SelectedIndex]
        if ($selectedItem) {
            $selectionType = if ($selectedItem.IsDirectory) { "Carpeta" } else { "Archivo" }
            $itemInfo = "$selectionType - $($selectedItem.Name)"
            if ($SearchMode) {
                $itemInfo += " │ Total: $($Items.Count) items"
            }
            Write-Host " Seleccionado: " -NoNewline -ForegroundColor DarkGray
            Write-Host $itemInfo -ForegroundColor White
        }
    }
    
    # Si la ruta actual está vacía, mostrar selector de unidades al iniciar
    if ([string]::IsNullOrEmpty($currentPath) -or $currentPath -eq "") {
        $currentPath = " UNIDADES "  # Marcador especial para mostrar selector
    }
    
    # Navegación principal
    while ($true) {
        # Verificar si debemos mostrar selector de unidades
        if ($currentPath -eq " UNIDADES ") {
            $allItems = Show-DriveSelector
            $pathDisplay = "Seleccione una unidad"
        }
        else {
            if ($ItemProvider) {
                $allItems = & $ItemProvider -Path $currentPath -AllowFiles $AllowFiles -SizeCache $script:DirectorySizeCache
            }
            else {
                $allItems = Get-DirectoryItems -Path $currentPath -AllowFiles $AllowFiles -SizeCache $script:DirectorySizeCache
            }
            $pathDisplay = $currentPath
        }
        
        # Aplicar filtro si está en modo búsqueda
        if ($searchMode -and $searchPattern) {
            try {
                $filteredItems = @($allItems | Where-Object { 
                        $_.Name -match $searchPattern 
                    })
                if ($filteredItems.Count -eq 0) {
                    $filteredItems = @([PSCustomObject]@{
                            Name            = "(No se encontraron coincidencias)"
                            FullName        = ""
                            IsDirectory     = $false
                            IsParent        = $false
                            IsDriveSelector = $false
                            Size            = ""
                            Icon            = "⚠"
                        })
                }
            }
            catch {
                # Si la regex es inválida, mostrar todos los items
                $filteredItems = $allItems
            }
            $items = $filteredItems
        }
        else {
            $items = $allItems
        }
        
        # Ajustar índice si está fuera de rango
        if ($selectedIndex -ge $items.Count) {
            $selectedIndex = [Math]::Max(0, $items.Count - 1)
        }
        
        Show-Interface -Path $pathDisplay -Items $items -SelectedIndex $selectedIndex -ScrollOffset $scrollOffset -SearchMode $searchMode -SearchPattern $searchPattern
        
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Si estamos en modo búsqueda, capturar teclas de texto
        if ($searchMode) {
            switch ($key.VirtualKeyCode) {
                27 {
                    # ESC - Salir del modo búsqueda
                    $searchMode = $false
                    $searchPattern = ""
                    $selectedIndex = 0
                    $scrollOffset = 0
                    continue
                }
                13 {
                    # Enter - Mantener búsqueda y salir del modo edición
                    $searchMode = $false
                    $selectedIndex = 0
                    $scrollOffset = 0
                    continue
                }
                8 {
                    # Backspace
                    if ($searchPattern.Length -gt 0) {
                        $searchPattern = $searchPattern.Substring(0, $searchPattern.Length - 1)
                    }
                    continue
                }
                38 {
                    # Flecha arriba
                    if ($selectedIndex -gt 0) {
                        $selectedIndex--
                        if ($selectedIndex -lt $scrollOffset) {
                            $scrollOffset = $selectedIndex
                        }
                    }
                    continue
                }
                40 {
                    # Flecha abajo
                    if ($selectedIndex -lt ($items.Count - 1)) {
                        $selectedIndex++
                        $visibleHeight = [Math]::Min($host.UI.RawUI.WindowSize.Height - 12, 25)
                        if ($selectedIndex -ge ($scrollOffset + $visibleHeight)) {
                            $scrollOffset = $selectedIndex - $visibleHeight + 1
                        }
                    }
                    continue
                }
                default {
                    # Agregar caracter si es imprimible
                    if ($key.Character -match '[a-zA-Z0-9\.\*\+\?\[\]\(\)\{\}\|\\\^\$\-_ ]') {
                        $searchPattern += $key.Character
                        $selectedIndex = 0
                        $scrollOffset = 0
                    }
                    continue
                }
            }
        }
        
        # Modo navegación normal
        switch ($key.VirtualKeyCode) {
            38 {
                # Flecha arriba
                if ($selectedIndex -gt 0) {
                    $selectedIndex--
                    if ($selectedIndex -lt $scrollOffset) {
                        $scrollOffset = $selectedIndex
                    }
                }
            }
            40 {
                # Flecha abajo
                if ($selectedIndex -lt ($items.Count - 1)) {
                    $selectedIndex++
                    $visibleHeight = [Math]::Min($host.UI.RawUI.WindowSize.Height - 12, 25)
                    if ($selectedIndex -ge ($scrollOffset + $visibleHeight)) {
                        $scrollOffset = $selectedIndex - $visibleHeight + 1
                    }
                }
            }
            32 {
                # ESPACIO - Calcular tamaño de carpeta
                $selectedItem = $items[$selectedIndex]
                if ($selectedItem.IsDirectory -and -not $selectedItem.IsParent -and -not $selectedItem.IsDriveSelector) {
                    $dirPath = $selectedItem.FullName
                    
                    # Variables para cálculo
                    $calculating = $true
                    $cancelled = $false
                    $totalSize = 0
                    $fileCount = 0
                    $dirCount = 0
                    $spinnerChars = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
                    $spinnerIndex = 0
                    
                    # Iniciar cálculo en background
                    $job = Start-Job -ScriptBlock {
                        param($Path, $SelectedItem, $Token, $DriveId, $ModulePath, $UseRemote)

                        if ($ModulePath) {
                            try {
                                Import-Module -LiteralPath $ModulePath -Force -ErrorAction Stop | Out-Null
                            }
                            catch {
                            }
                        }

                        if ($UseRemote -and $SelectedItem) {
                            $folderSizeCmd = Get-Command Get-OneDriveFolderSize -ErrorAction SilentlyContinue
                            if ($folderSizeCmd) {
                                return Get-OneDriveFolderSize -Token $Token -DriveId $DriveId -ItemId $SelectedItem.ItemId
                            }
                            
                            function Get-OneDriveFolderSizeInline {
                                param(
                                    [string]$Token,
                                    [string]$DriveId,
                                    [string]$ItemId
                                )
                                if (-not $Token -or -not $DriveId -or -not $ItemId) {
                                    return @{ Size = 0; Files = 0; Dirs = 0 }
                                }

                                $headers = @{ "Authorization" = "Bearer $Token" }
                                $queue = @($ItemId)
                                $totalSize = 0
                                $fileCount = 0
                                $dirCount = 0

                                while ($queue.Count -gt 0) {
                                    $currentId = $queue[0]
                                    $queue = if ($queue.Count -gt 1) { $queue[1..($queue.Count - 1)] } else { @() }
                                    $url = "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$currentId/children?`$select=id,size,folder"
                                    do {
                                        try {
                                            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
                                        }
                                        catch {
                                            return @{ Size = $totalSize; Files = $fileCount; Dirs = $dirCount }
                                        }

                                        foreach ($child in $response.value) {
                                            if ($child.folder) {
                                                $dirCount++
                                                $queue += $child.id
                                            }
                                            elseif ($child.size) {
                                                $totalSize += [int64]$child.size
                                                $fileCount++
                                            }
                                        }

                                        $url = $response.'@odata.nextLink'
                                    } while ($url)
                                }

                                return @{ Size = $totalSize; Files = $fileCount; Dirs = $dirCount }
                            }

                            return Get-OneDriveFolderSizeInline -Token $Token -DriveId $DriveId -ItemId $SelectedItem.ItemId
                        }

                        function Get-DirSizeRecursive {
                            param($Path)

                            $size = 0
                            $files = 0
                            $dirs = 0

                            try {
                                $items = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue
                                foreach ($item in $items) {
                                    if ($item.PSIsContainer) {
                                        $dirs++
                                        $subResult = Get-DirSizeRecursive -Path $item.FullName
                                        $size += $subResult.Size
                                        $files += $subResult.Files
                                        $dirs += $subResult.Dirs
                                    }
                                    else {
                                        $size += $item.Length
                                        $files++
                                    }
                                }
                            }
                            catch {}

                            return @{ Size = $size; Files = $files; Dirs = $dirs }
                        }

                        return Get-DirSizeRecursive -Path $Path
                    } -ArgumentList $dirPath, $selectedItem, $providerToken, $providerDriveId, $modulePath, $useRemoteSizeCalculator
                    
                    # Mostrar interfaz con spinner mientras calcula
                    while ($calculating) {
                        if ($job.State -eq 'Completed') {
                            $result = Receive-Job -Job $job
                            $totalSize = $result.Size
                            $fileCount = $result.Files
                            $dirCount = $result.Dirs
                            $calculating = $false
                        }
                        elseif ($job.State -eq 'Failed') {
                            $calculating = $false
                            $cancelled = $true
                        }
                        else {
                            # Redibujar la interfaz con spinner (sin parpadeo)
                            try {
                                if (System.Management.Automation.Internal.Host.InternalHost.Name -and (System.Management.Automation.Internal.Host.InternalHost.Name -ilike '*consolehost*' -or System.Management.Automation.Internal.Host.InternalHost.Name -ilike '*visual studio code host*')) { try { [Console]::SetCursorPosition(0, 0) } catch { Clear-Host } } else { Clear-Host }
                            }
                            catch {
                                Clear-Host
                            }
                            $width = [Math]::Min($host.UI.RawUI.WindowSize.Width - 2, 118)
                            $height = [Math]::Min($host.UI.RawUI.WindowSize.Height - 12, 25)
                            
                            # Encabezado
                            $borderLine = "═" * $width
                            Write-Host "╔${borderLine}╗" -ForegroundColor Cyan
                            
                            # Título centrado
                            $titlePadding = [Math]::Max(0, ($width - $Prompt.Length) / 2)
                            $leftPad = [Math]::Floor($titlePadding)
                            $rightPad = $width - $Prompt.Length - $leftPad
                            $titleLine = (" " * $leftPad) + $Prompt + (" " * $rightPad)
                            Write-Host "║${titleLine}║" -ForegroundColor Cyan
                            
                            Write-Host "╠${borderLine}╣" -ForegroundColor Cyan
                            
                            # Ruta actual
                            $pathDisplay = if ($currentPath -eq " UNIDADES ") { "Seleccione una unidad" } else { $currentPath }
                            if ($pathDisplay.Length -gt ($width - 2)) {
                                $pathDisplay = "..." + $pathDisplay.Substring($pathDisplay.Length - ($width - 5))
                            }
                            $pathLine = " " + $pathDisplay
                            $pathLine = $pathLine.PadRight($width)
                            
                            Write-Host "║" -ForegroundColor Cyan -NoNewline
                            Write-Host $pathLine -ForegroundColor Yellow -NoNewline
                            Write-Host "║" -ForegroundColor Cyan
                            
                            Write-Host "╠${borderLine}╣" -ForegroundColor Cyan
                            
                            # Mostrar items con el seleccionado destacado y spinner
                            $visibleItems = $height
                            for ($i = 0; $i -lt $visibleItems; $i++) {
                                $itemIndex = $i + $scrollOffset
                                
                                if ($itemIndex -lt $items.Count) {
                                    $item = $items[$itemIndex]
                                    $isSelected = ($itemIndex -eq $selectedIndex)
                                    
                                    # Preparar el texto del item
                                    $icon = $item.Icon
                                    $name = $item.Name
                                    $size = $item.Size
                                    
                                    # Si es el item seleccionado y estamos calculando, mostrar spinner
                                    if ($isSelected -and $item.FullName -eq $dirPath) {
                                        $spinnerChar = $spinnerChars[$spinnerIndex]
                                        
                                        # Formatear tamaño actual
                                        if ($totalSize -ge 1TB) {
                                            $sizeStr = "{0:N2} TB" -f ($totalSize / 1TB)
                                        }
                                        elseif ($totalSize -ge 1GB) {
                                            $sizeStr = "{0:N2} GB" -f ($totalSize / 1GB)
                                        }
                                        elseif ($totalSize -ge 1MB) {
                                            $sizeStr = "{0:N2} MB" -f ($totalSize / 1MB)
                                        }
                                        elseif ($totalSize -ge 1KB) {
                                            $sizeStr = "{0:N2} KB" -f ($totalSize / 1KB)
                                        }
                                        else {
                                            $sizeStr = "$totalSize B"
                                        }
                                        
                                        $size = "$spinnerChar $sizeStr"
                                    }
                                    
                                    # Ancho disponible para el contenido
                                    $contentWidth = $width
                                    $sizeWidth = 20  # Más ancho para spinner + tamaño + <DIR>
                                    $iconSpace = 3
                                    $maxNameLength = $contentWidth - $iconSpace - $sizeWidth - 1
                                    
                                    if ($name.Length -gt $maxNameLength) {
                                        $name = $name.Substring(0, $maxNameLength - 3) + "..."
                                    }
                                    
                                    # Construir la línea
                                    $namePart = " $icon $name"
                                    $namePartLength = 1 + 2 + 1 + $name.Length
                                    $paddingNeeded = $contentWidth - $namePartLength - $sizeWidth
                                    $line = $namePart + (" " * $paddingNeeded) + $size.PadLeft($sizeWidth)
                                    
                                    # Ajustar longitud exacta
                                    if ($line.Length -gt $contentWidth) {
                                        $line = $line.Substring(0, $contentWidth)
                                    }
                                    elseif ($line.Length -lt $contentWidth) {
                                        $line = $line.PadRight($contentWidth)
                                    }
                                    
                                    # Mostrar la línea
                                    if ($isSelected) {
                                        Write-Host "║" -ForegroundColor Cyan -NoNewline
                                        Write-Host $line -BackgroundColor DarkCyan -ForegroundColor White -NoNewline
                                        Write-Host "║" -ForegroundColor Cyan
                                    }
                                    else {
                                        $color = if ($item.IsDirectory) { "White" } else { "Gray" }
                                        Write-Host "║" -ForegroundColor Cyan -NoNewline
                                        Write-Host $line -ForegroundColor $color -NoNewline
                                        Write-Host "║" -ForegroundColor Cyan
                                    }
                                }
                                else {
                                    # Línea vacía
                                    Write-Host "║" -ForegroundColor Cyan -NoNewline
                                    Write-Host (" " * $width) -NoNewline
                                    Write-Host "║" -ForegroundColor Cyan
                                }
                            }
                            
                            # Pie con instrucciones especiales
                            Write-Host "╠${borderLine}╣" -ForegroundColor Cyan
                            
                            $instructions = "Calculando... │ ESC:Cancelar"
                            $instrPadding = [Math]::Max(0, ($width - $instructions.Length) / 2)
                            $leftPad = [Math]::Floor($instrPadding)
                            $rightPad = $width - $instructions.Length - $leftPad
                            $instrLine = (" " * $leftPad) + $instructions + (" " * $rightPad)
                            
                            Write-Host "║" -ForegroundColor Cyan -NoNewline
                            Write-Host $instrLine -ForegroundColor Yellow -NoNewline
                            Write-Host "║" -ForegroundColor Cyan
                            
                            Write-Host "╚${borderLine}╝" -ForegroundColor Cyan
                            
                            # Información adicional
                            Write-Host ""
                            Write-Host " Calculando: " -NoNewline -ForegroundColor DarkGray
                            Write-Host "$fileCount archivos - $dirCount carpetas" -ForegroundColor White
                            
                            # Avanzar spinner
                            $spinnerIndex = ($spinnerIndex + 1) % $spinnerChars.Count
                            
                            # Verificar si se presionó ESC
                            if ([Console]::KeyAvailable) {
                                $checkKey = [Console]::ReadKey($true)
                                if ($checkKey.Key -eq 'Escape') {
                                    $cancelled = $true
                                    Stop-Job -Job $job
                                    $calculating = $false
                                }
                            }
                            
                            Start-Sleep -Milliseconds 100
                        }
                    }
                    
                    Remove-Job -Job $job -Force
                    
                    # Guardar resultado en caché y actualizar item si se completó
                    if (-not $cancelled -and $totalSize -gt 0) {
                        $script:DirectorySizeCache[$dirPath] = $totalSize
                        
                        # Actualizar el item en la lista con el tamaño calculado + <DIR>
                        $itemToUpdate = $items | Where-Object { $_.FullName -eq $dirPath } | Select-Object -First 1
                        if ($itemToUpdate) {
                            if ($totalSize -ge 1TB) {
                                $itemToUpdate.Size = "{0:N2} TB <DIR>" -f ($totalSize / 1TB)
                            }
                            elseif ($totalSize -ge 1GB) {
                                $itemToUpdate.Size = "{0:N2} GB <DIR>" -f ($totalSize / 1GB)
                            }
                            elseif ($totalSize -ge 1MB) {
                                $itemToUpdate.Size = "{0:N2} MB <DIR>" -f ($totalSize / 1MB)
                            }
                            elseif ($totalSize -ge 1KB) {
                                $itemToUpdate.Size = "{0:N2} KB <DIR>" -f ($totalSize / 1KB)
                            }
                            else {
                                $itemToUpdate.Size = "$totalSize B <DIR>"
                            }
                        }
                    }
                }
            }
            115 {
                # F4 - Activar modo búsqueda
                $searchMode = $true
                $searchPattern = ""
                $selectedIndex = 0
                $scrollOffset = 0
            }
            13 {
                # Enter
                $selectedItem = $items[$selectedIndex]
                
                # Si estamos en selector de unidades, cambiar a esa unidad
                if ($currentPath -eq " UNIDADES ") {
                    $currentPath = $selectedItem.FullName
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
                # Si es "..." ir al selector de unidades
                elseif ($selectedItem.IsDriveSelector) {
                    $currentPath = " UNIDADES "
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
                elseif ($selectedItem.IsDirectory) {
                    if ($selectedItem.IsParent) {
                        $parentPath = Split-Path $currentPath -Parent
                        if ($parentPath) {
                            $currentPath = $parentPath
                        }
                        else {
                            # Si no hay parent, ir al selector de unidades
                            $currentPath = " UNIDADES "
                        }
                    }
                    else {
                        $currentPath = $selectedItem.FullName
                    }
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
            }
            39 {
                # Flecha derecha
                $selectedItem = $items[$selectedIndex]
                
                # Si estamos en selector de unidades, entrar a esa unidad
                if ($currentPath -eq " UNIDADES ") {
                    $currentPath = $selectedItem.FullName
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
                # Si es "..." ir al selector de unidades
                elseif ($selectedItem.IsDriveSelector) {
                    $currentPath = " UNIDADES "
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
                elseif ($selectedItem.IsDirectory -and -not $selectedItem.IsParent) {
                    $currentPath = $selectedItem.FullName
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
            }
            37 {
                # Flecha izquierda
                if ($currentPath -eq " UNIDADES ") {
                    # Ya estamos en selector, no hacer nada
                }
                else {
                    $parentPath = Split-Path $currentPath -Parent
                    if ($parentPath) {
                        $currentPath = $parentPath
                    }
                    else {
                        # Si no hay parent, ir al selector de unidades
                        $currentPath = " UNIDADES "
                    }
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
            }
            8 {
                # Backspace
                if ($currentPath -eq " UNIDADES ") {
                    # Ya estamos en selector, no hacer nada
                }
                else {
                    $parentPath = Split-Path $currentPath -Parent
                    if ($parentPath) {
                        $currentPath = $parentPath
                    }
                    else {
                        # Si no hay parent, ir al selector de unidades
                        $currentPath = " UNIDADES "
                    }
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
            }
            113 {
                if ($allowDriveSelector) {
                    # F2 - Selector de unidades
                    $currentPath = " UNIDADES "
                    $selectedIndex = 0
                    $scrollOffset = 0
                }
            }
            114 {
                if ($allowNetworkDiscovery) {
                    # F3 - Discovery de recursos UNC con credenciales
                    Write-Log "Usuario activó F3 para descubrir recursos de red" "INFO"
                    
                    # Guardar contexto actual
                    #$savedPath = $currentPath
                    
                    # Llamar a la función de discovery UNC
                    $uncResult = Select-NetworkPath -Purpose "NAVEGADOR"
                    
                    if ($uncResult -and $uncResult.Path) {
                        # Si se seleccionó un recurso UNC, intentar acceder
                        try {
                            if (Test-Path $uncResult.Path) {
                                $currentPath = $uncResult.Path
                                $selectedIndex = 0
                                $scrollOffset = 0
                                Write-Log "Accedido exitosamente a: $($uncResult.Path)" "INFO"
                            }
                            else {
                                Show-ConsolePopup -Title "Error de Acceso" -Message "No se puede acceder a:`n$($uncResult.Path)`n`nVerifique permisos o credenciales" -Options @("*OK") | Out-Null
                                Write-Log "No se pudo acceder a: $($uncResult.Path)" "WARNING"
                            }
                        }
                        catch {
                            Show-ConsolePopup -Title "Error" -Message "Error al acceder al recurso:`n$($_.Exception.Message)" -Options @("*OK") | Out-Null
                            Write-Log "Error al acceder a recurso UNC: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
                        }
                    }
                    # Si se canceló, mantener ruta actual
                }
            }
            121 {
                # F10
                $selectedItem = $items[$selectedIndex]
                if ($AllowFiles) {
                    # Permitir seleccionar archivo o carpeta
                    return $selectedItem.FullName
                }
                else {
                    # Solo permitir carpetas
                    if ($selectedItem.IsDirectory -and -not $selectedItem.IsParent -and -not $selectedItem.IsDriveSelector) {
                        return $selectedItem.FullName
                    }
                    elseif ($selectedItem.IsParent) {
                        return $currentPath
                    }
                    else {
                        # Si seleccionó carpeta actual sin tener item específico
                        return $currentPath
                    }
                }
            }
            27 {
                # ESC
                return $null
            }
        }
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Select-PathNavigator'
)
