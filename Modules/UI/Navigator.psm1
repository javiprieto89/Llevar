# ========================================================================== #
#                     MÓDULO: NAVEGADOR NORTON COMMANDER                     #
# ========================================================================== #
# Propósito: Explorador de archivos/carpetas estilo Norton Commander
# Funciones:
#   - Select-PathNavigator: Navegador interactivo con teclado
# ========================================================================== #

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
        - Selección de archivos o carpetas
        - Scroll automático para listas grandes
    .PARAMETER Prompt
        Título del explorador
    .PARAMETER AllowFiles
        Si es $true, permite seleccionar archivos. Si es $false, solo carpetas.
    .OUTPUTS
        String con la ruta completa seleccionada, o $null si se cancela
    .EXAMPLE
        $folder = Select-PathNavigator -Prompt "Seleccione carpeta de origen"
    .EXAMPLE
        $file = Select-PathNavigator -Prompt "Seleccione archivo" -AllowFiles $true
    #>
    param(
        [string]$Prompt = "Seleccionar ubicación",
        [bool]$AllowFiles = $false
    )
    
    # Obtener todas las unidades disponibles (solo letras de unidad A-Z)
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -and $_.Name -match '^[A-Z]$' }
    $currentPath = $PWD.Path
    $selectedIndex = 0
    $scrollOffset = 0
    
    # Función auxiliar para buscar recursos compartidos en la red
    function Get-NetworkShares {
        $shares = @()
        
        try {
            Write-Host "`nBuscando recursos compartidos en la red..." -ForegroundColor Cyan
            Write-Host "Esto puede tardar unos segundos..." -ForegroundColor Gray
            
            # Obtener computadoras en la red local
            #$computers = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue | 
            Select-Object -ExpandProperty Name
            
            # Buscar en la red local usando net view
            $netView = net view /all 2>$null
            foreach ($line in $netView) {
                if ($line -match '\\\\(.+?)\s') {
                    $computerName = $matches[1]
                    $shares += [PSCustomObject]@{
                        Name            = "\\\\$computerName"
                        FullName        = "\\\\$computerName"
                        IsDirectory     = $true
                        IsParent        = $false
                        IsDriveSelector = $false
                        IsNetworkShare  = $true
                        Size            = "<RED>"
                        Icon            = "🌐"
                    }
                }
            }
        }
        catch {
            # Silenciar errores
        }
        
        if ($shares.Count -eq 0) {
            $shares += [PSCustomObject]@{
                Name            = "(No se encontraron recursos compartidos)"
                FullName        = ""
                IsDirectory     = $false
                IsParent        = $false
                IsDriveSelector = $false
                IsNetworkShare  = $false
                Size            = ""
                Icon            = "⚠"
            }
        }
        
        return $shares
    }
    
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
    
    # Función auxiliar para obtener items del directorio actual
    function Get-DirectoryItems {
        param([string]$Path)
        
        $items = @()
        
        try {
            # Detectar si estamos en la raíz de una unidad (C:\, D:\, etc.)
            $isRootDrive = $Path -match '^[A-Za-z]:\\$'
            
            if ($isRootDrive) {
                # En raíz: agregar "..." para ir al selector de unidades
                $items += [PSCustomObject]@{
                    Name            = "..."
                    FullName        = ""
                    IsDirectory     = $true
                    IsParent        = $false
                    IsDriveSelector = $true
                    Size            = ""
                    Icon            = "💾"
                }
            }
            elseif ($Path -ne "") {
                # No estamos en raíz: agregar ".." para subir
                $items += [PSCustomObject]@{
                    Name            = ".."
                    FullName        = Split-Path $Path -Parent
                    IsDirectory     = $true
                    IsParent        = $true
                    IsDriveSelector = $false
                    Size            = ""
                    Icon            = "▲"
                }
            }
            
            # Obtener directorios
            $dirs = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue | Sort-Object Name
            foreach ($dir in $dirs) {
                $items += [PSCustomObject]@{
                    Name            = $dir.Name
                    FullName        = $dir.FullName
                    IsDirectory     = $true
                    IsParent        = $false
                    IsDriveSelector = $false
                    Size            = "<DIR>"
                    Icon            = "📁"
                }
            }
            
            # Obtener archivos si está permitido
            if ($AllowFiles) {
                $files = Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue | Sort-Object Name
                foreach ($file in $files) {
                    $sizeKB = [math]::Round($file.Length / 1KB, 2)
                    $items += [PSCustomObject]@{
                        Name            = $file.Name
                        FullName        = $file.FullName
                        IsDirectory     = $false
                        IsParent        = $false
                        IsDriveSelector = $false
                        Size            = "$sizeKB KB"
                        Icon            = "📄"
                    }
                }
            }
        }
        catch {
            # Si hay error accediendo al directorio, volver atrás
        }
        
        return $items
    }
    
    # Función para dibujar la interfaz
    function Show-Interface {
        param(
            [string]$Path,
            [array]$Items,
            [int]$SelectedIndex,
            [int]$ScrollOffset
        )
        
        Clear-Host
        $width = [Math]::Min($host.UI.RawUI.WindowSize.Width - 2, 118)
        $height = [Math]::Min($host.UI.RawUI.WindowSize.Height - 12, 25)
        
        # Encabezado
        Write-Host ("╔" + ("═" * ($width)) + "╗") -ForegroundColor Cyan
        $titlePadding = [Math]::Max(0, ($width - $Prompt.Length) / 2)
        Write-Host ("║" + (" " * [Math]::Floor($titlePadding)) + $Prompt + (" " * [Math]::Ceiling($titlePadding)) + "║") -ForegroundColor Cyan
        Write-Host ("╠" + ("═" * ($width)) + "╣") -ForegroundColor Cyan
        
        # Ruta actual
        $pathDisplay = $Path
        if ($pathDisplay.Length -gt ($width - 4)) {
            $pathDisplay = "..." + $pathDisplay.Substring($pathDisplay.Length - ($width - 7))
        }
        Write-Host ("║ " + $pathDisplay.PadRight($width - 2) + " ║") -ForegroundColor Yellow
        Write-Host ("╠" + ("═" * ($width)) + "╣") -ForegroundColor Cyan
        
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
                
                # Truncar nombre si es muy largo
                $maxNameLength = $width - 20
                if ($name.Length -gt $maxNameLength) {
                    $name = $name.Substring(0, $maxNameLength - 3) + "..."
                }
                
                $line = " $icon $name".PadRight($width - 12) + $size.PadLeft(10)
                
                if ($isSelected) {
                    Write-Host ("║") -ForegroundColor Cyan -NoNewline
                    Write-Host $line.PadRight($width - 2) -BackgroundColor DarkCyan -ForegroundColor White -NoNewline
                    Write-Host ("║") -ForegroundColor Cyan
                }
                else {
                    $color = if ($item.IsDirectory) { "White" } else { "Gray" }
                    Write-Host ("║") -ForegroundColor Cyan -NoNewline
                    Write-Host $line.PadRight($width - 2) -ForegroundColor $color -NoNewline
                    Write-Host ("║") -ForegroundColor Cyan
                }
            }
            else {
                Write-Host ("║" + (" " * ($width - 2)) + "║") -ForegroundColor Cyan
            }
        }
        
        # Pie con instrucciones
        Write-Host ("╠" + ("═" * ($width)) + "╣") -ForegroundColor Cyan
        
        $instructions = "↑↓:Nav │ Enter:Entrar │ ←:Atrás │ F2:Unidades │ F3:Red │ F10:Seleccionar │ ESC:Salir"
        
        if ($instructions.Length -gt ($width - 4)) {
            $instructions = "↑↓ │ Enter │ ← │ F2:Unit │ F3:Red │ F10:Sel │ ESC"
        }
        
        $instrPadding = [Math]::Max(0, ($width - $instructions.Length) / 2)
        Write-Host ("║ " + (" " * [Math]::Floor($instrPadding)) + $instructions + (" " * [Math]::Ceiling($instrPadding - 1)) + "║") -ForegroundColor Green
        Write-Host ("╚" + ("═" * ($width)) + "╝") -ForegroundColor Cyan
        
        # Información adicional
        Write-Host ""
        $selectedItem = $Items[$SelectedIndex]
        if ($selectedItem) {
            $selectionType = if ($selectedItem.IsDirectory) { "Carpeta" } else { "Archivo" }
            Write-Host " Seleccionado: " -NoNewline -ForegroundColor DarkGray
            Write-Host "$selectionType - $($selectedItem.Name)" -ForegroundColor White
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
            $items = Show-DriveSelector
            $pathDisplay = "Seleccione una unidad"
        }
        else {
            $items = Get-DirectoryItems -Path $currentPath
            $pathDisplay = $currentPath
        }
        
        # Ajustar índice si está fuera de rango
        if ($selectedIndex -ge $items.Count) {
            $selectedIndex = [Math]::Max(0, $items.Count - 1)
        }
        
        Show-Interface -Path $pathDisplay -Items $items -SelectedIndex $selectedIndex -ScrollOffset $scrollOffset
        
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
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
                # F2 - Selector de unidades
                $currentPath = " UNIDADES "
                $selectedIndex = 0
                $scrollOffset = 0
            }
            114 {
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
