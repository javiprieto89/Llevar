# ========================================================================== #
#                   MÓDULO: DESINSTALACIÓN DEL SISTEMA                       #
# ========================================================================== #
# Propósito: Desinstalar Llevar completamente del sistema
# Funciones:
#   - Uninstall-LlevarFromSystem: Desinstalación completa del sistema
# ========================================================================== #

function Uninstall-LlevarFromSystem {
    <#
    .SYNOPSIS
        Desinstala completamente Llevar del sistema
    .DESCRIPTION
        Elimina:
        - Entradas del registro (menú contextual)
        - Carpeta C:\Llevar completa
        - Acceso directo del escritorio
        - Entrada del PATH del sistema
        - Registro en Agregar o Quitar Programas
    .PARAMETER Silent
        Ejecutar en modo silencioso (sin confirmaciones)
    .PARAMETER Force
        Forzar desinstalación sin confirmación
    #>
    param(
        [switch]$Silent,
        [switch]$Force
    )
    
    $installPath = "C:\Llevar"
    
    # Importar módulo de UI para los popups
    $currentDir = Split-Path $PSCommandPath -Parent
    $rootDir = Split-Path $currentDir -Parent
    $menusModule = Join-Path $rootDir "UI\Menus.psm1"
    $bannersModule = Join-Path $rootDir "UI\Banners.psm1"
    
    if (Test-Path $menusModule) {
        Import-Module $menusModule -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $bannersModule) {
        Import-Module $bannersModule -Force -ErrorAction SilentlyContinue
    }
    
    # Mostrar banner
    if (Get-Command Show-Banner -ErrorAction SilentlyContinue) {
        Show-Banner -Message "DESINSTALACIÓN DE LLEVAR" -BorderColor Red -TextColor Yellow
    }
    else {
        Write-Host ""
        Write-Host "================================================================" -ForegroundColor Red
        Write-Host "  DESINSTALACIÓN DE LLEVAR DEL SISTEMA" -ForegroundColor Yellow
        Write-Host "================================================================" -ForegroundColor Red
        Write-Host ""
    }
    
    Write-Host "Esto eliminará:" -ForegroundColor White
    Write-Host "  • Menú contextual 'Llevar A...' del registro" -ForegroundColor Gray
    Write-Host "  • Carpeta C:\Llevar completa con todos sus archivos" -ForegroundColor Gray
    Write-Host "  • Acceso directo del escritorio" -ForegroundColor Gray
    Write-Host "  • Entrada del PATH del sistema" -ForegroundColor Gray
    Write-Host "  • Registro en 'Agregar o quitar programas'" -ForegroundColor Gray
    Write-Host ""
    
    # Confirmación del usuario usando Show-ConsolePopup si está disponible
    if (-not $Force -and -not $Silent) {
        if (Get-Command Show-ConsolePopup -ErrorAction SilentlyContinue) {
            $respuesta = Show-ConsolePopup -Title "⚠ CONFIRMAR DESINSTALACIÓN" `
                -Message "¿Está seguro de que desea desinstalar Llevar?`n`nSe eliminarán todos los archivos y configuraciones." `
                -Options @("*Sí, desinstalar", "*No, cancelar") `
                -DefaultIndex 1 `
                -BorderColor Red `
                -TitleColor Yellow `
                -TitleBackgroundColor DarkRed
            
            if ($respuesta -ne 0) {
                Write-Host ""
                Write-Host "Desinstalación cancelada por el usuario." -ForegroundColor Yellow
                Write-Host ""
                return 99  # Código de salida para cancelación
            }
        }
        else {
            # Fallback a confirmación simple
            Write-Host "¿Está seguro de que desea desinstalar Llevar? (S/N): " -ForegroundColor Yellow -NoNewline
            $confirm = Read-Host
            if ($confirm -ne "S" -and $confirm -ne "s") {
                Write-Host ""
                Write-Host "Desinstalación cancelada por el usuario." -ForegroundColor Yellow
                Write-Host ""
                return 99
            }
        }
    }
    
    Write-Host ""
    Write-Host "Iniciando desinstalación..." -ForegroundColor Cyan
    Write-Host ""
    
    $errores = 0
    
    # ============================================================
    # 1. ELIMINAR ENTRADAS DEL REGISTRO
    # ============================================================
    
    Write-Host "[*] Eliminando entradas del registro..." -ForegroundColor Cyan
    
    # Menú contextual de carpetas
    try {
        $keyPath = "Registry::HKEY_CLASSES_ROOT\Directory\shell\Llevar"
        if (Test-Path $keyPath) {
            Remove-Item -Path $keyPath -Recurse -Force -ErrorAction Stop
            Write-Host "  ✓ Menú contextual de carpetas eliminado" -ForegroundColor Green
        }
        else {
            Write-Host "  • Menú contextual de carpetas no encontrado" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  ✗ Error al eliminar menú contextual de carpetas: $_" -ForegroundColor Red
        $errores++
    }
    
    # Menú contextual de unidades
    try {
        $keyPath = "Registry::HKEY_CLASSES_ROOT\Drive\shell\Llevar"
        if (Test-Path $keyPath) {
            Remove-Item -Path $keyPath -Recurse -Force -ErrorAction Stop
            Write-Host "  ✓ Menú contextual de unidades eliminado" -ForegroundColor Green
        }
        else {
            Write-Host "  • Menú contextual de unidades no encontrado" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  ✗ Error al eliminar menú contextual de unidades: $_" -ForegroundColor Red
        $errores++
    }
    
    # Entrada de desinstalación en Panel de Control
    try {
        $keyPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Llevar"
        if (Test-Path $keyPath) {
            Remove-Item -Path $keyPath -Recurse -Force -ErrorAction Stop
            Write-Host "  ✓ Entrada del Panel de Control eliminada" -ForegroundColor Green
        }
        else {
            Write-Host "  • Entrada del Panel de Control no encontrada" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  ✗ Error al eliminar entrada del Panel de Control: $_" -ForegroundColor Red
        $errores++
    }
    
    # ============================================================
    # 2. ELIMINAR DEL PATH DEL SISTEMA
    # ============================================================
    
    Write-Host ""
    Write-Host "[*] Eliminando del PATH del sistema..." -ForegroundColor Cyan
    
    try {
        $currentPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        
        if ($currentPath -like "*$installPath*") {
            # Dividir el PATH en componentes
            $pathComponents = $currentPath -split ';' | Where-Object { $_ -ne $installPath -and $_ -ne "$installPath\" }
            $newPath = $pathComponents -join ';'
            
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'Machine')
            
            # También actualizar PATH de la sesión actual
            $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
            
            Write-Host "  ✓ C:\Llevar eliminado del PATH del sistema" -ForegroundColor Green
        }
        else {
            Write-Host "  • C:\Llevar no está en el PATH del sistema" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  ✗ Error al modificar PATH: $_" -ForegroundColor Red
        Write-Host "    Puede eliminarlo manualmente desde Variables de Entorno" -ForegroundColor Yellow
        $errores++
    }
    
    # ============================================================
    # 3. ELIMINAR ACCESO DIRECTO DEL ESCRITORIO
    # ============================================================
    
    Write-Host ""
    Write-Host "[*] Eliminando acceso directo del escritorio..." -ForegroundColor Cyan
    
    try {
        $escritorio = [Environment]::GetFolderPath("Desktop")
        $accesoDirecto = Join-Path $escritorio "Llevar.lnk"
        
        if (Test-Path $accesoDirecto) {
            Remove-Item -Path $accesoDirecto -Force -ErrorAction Stop
            Write-Host "  ✓ Acceso directo eliminado" -ForegroundColor Green
        }
        else {
            Write-Host "  • Acceso directo no encontrado" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  ✗ Error al eliminar acceso directo: $_" -ForegroundColor Red
        $errores++
    }
    
    # También verificar en el escritorio público
    try {
        $escritorioPublico = [Environment]::GetFolderPath("CommonDesktopDirectory")
        $accesoDirectoPublico = Join-Path $escritorioPublico "Llevar.lnk"
        
        if (Test-Path $accesoDirectoPublico) {
            Remove-Item -Path $accesoDirectoPublico -Force -ErrorAction Stop
            Write-Host "  ✓ Acceso directo público eliminado" -ForegroundColor Green
        }
    }
    catch {
        # Silencioso, no crítico
    }
    
    # ============================================================
    # 4. ELIMINAR CARPETA C:\Llevar
    # ============================================================
    
    Write-Host ""
    Write-Host "[*] Eliminando carpeta C:\Llevar..." -ForegroundColor Cyan
    
    if (Test-Path $installPath) {
        try {
            # Advertencia final si no es Silent
            if (-not $Silent -and (Get-Command Show-ConsolePopup -ErrorAction SilentlyContinue)) {
                $ultimaConfirmacion = Show-ConsolePopup -Title "⚠ ÚLTIMA CONFIRMACIÓN" `
                    -Message "Se eliminará permanentemente la carpeta:`n$installPath`n`n¿Continuar?" `
                    -Options @("*Eliminar", "*Cancelar") `
                    -DefaultIndex 1 `
                    -BorderColor Red
                
                if ($ultimaConfirmacion -ne 0) {
                    Write-Host ""
                    Write-Host "  • Eliminación de carpeta cancelada" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "La carpeta C:\Llevar no fue eliminada." -ForegroundColor Yellow
                    Write-Host "Puede eliminarla manualmente si lo desea." -ForegroundColor Gray
                    Write-Host ""
                    return 98  # Código de salida para eliminación parcial
                }
            }
            
            Write-Host "  Eliminando archivos..." -ForegroundColor Gray
            
            # Eliminar recursivamente
            Remove-Item -Path $installPath -Recurse -Force -ErrorAction Stop
            
            Write-Host "  ✓ Carpeta C:\Llevar eliminada completamente" -ForegroundColor Green
        }
        catch {
            Write-Host "  ✗ Error al eliminar carpeta C:\Llevar: $_" -ForegroundColor Red
            Write-Host "    La carpeta puede contener archivos en uso" -ForegroundColor Yellow
            Write-Host "    Puede eliminarla manualmente después de reiniciar" -ForegroundColor Yellow
            $errores++
        }
    }
    else {
        Write-Host "  • Carpeta C:\Llevar no existe" -ForegroundColor Gray
    }
    
    # ============================================================
    # 5. REFRESCAR EXPLORADOR DE ARCHIVOS
    # ============================================================
    
    Write-Host ""
    Write-Host "[*] Refrescando explorador de archivos..." -ForegroundColor Cyan
    
    try {
        $shell = New-Object -ComObject Shell.Application
        $shell.Windows() | ForEach-Object { $_.Refresh() }
        Write-Host "  ✓ Explorador refrescado" -ForegroundColor Green
    }
    catch {
        # Silencioso, no crítico
        Write-Host "  • No se pudo refrescar el explorador" -ForegroundColor Gray
    }
    
    # ============================================================
    # RESULTADO FINAL
    # ============================================================
    
    Write-Host ""
    
    if ($errores -eq 0) {
        if (Get-Command Show-Banner -ErrorAction SilentlyContinue) {
            Show-Banner "✓ DESINSTALACIÓN COMPLETADA" -BorderColor Green -TextColor Green
        }
        else {
            Write-Host "================================================================" -ForegroundColor Green
            Write-Host "  ✓ DESINSTALACIÓN COMPLETADA EXITOSAMENTE" -ForegroundColor Green
            Write-Host "================================================================" -ForegroundColor Green
        }
        Write-Host ""
        Write-Host "Llevar ha sido desinstalado completamente del sistema." -ForegroundColor White
        Write-Host ""
        Write-Host "Se recomienda reiniciar el sistema para asegurar que todos" -ForegroundColor Gray
        Write-Host "los cambios surtan efecto en el explorador de archivos." -ForegroundColor Gray
        Write-Host ""
        return 0
    }
    else {
        if (Get-Command Show-Banner -ErrorAction SilentlyContinue) {
            Show-Banner "⚠ DESINSTALACIÓN COMPLETADA CON ADVERTENCIAS" -BorderColor Yellow -TextColor Yellow
        }
        else {
            Write-Host "================================================================" -ForegroundColor Yellow
            Write-Host "  ⚠ DESINSTALACIÓN COMPLETADA CON ADVERTENCIAS" -ForegroundColor Yellow
            Write-Host "================================================================" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "La desinstalación se completó pero hubo $errores error(es)." -ForegroundColor Yellow
        Write-Host "Revise los mensajes anteriores para más detalles." -ForegroundColor Gray
        Write-Host ""
        Write-Host "Algunos elementos pueden requerir eliminación manual." -ForegroundColor Gray
        Write-Host ""
        return 1
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Uninstall-LlevarFromSystem'
)
