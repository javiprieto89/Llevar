<#
.SYNOPSIS
    Módulo para carga centralizada de todos los módulos de Llevar

.DESCRIPTION
    Proporciona una función unificada para importar todos los módulos necesarios,
    con validación, manejo de errores/advertencias y capacidad de importación selectiva
#>

function Import-LlevarModules {
    <#
    .SYNOPSIS
        Importa módulos de Llevar de forma centralizada con validación completa
    
    .PARAMETER ModulesPath
        Ruta base donde se encuentran los módulos
    
    .PARAMETER Categories
        Categorías de módulos a importar. Si no se especifica, importa todos.
        Valores válidos: Core, UI, Compression, Transfer, Installation, Utilities, System, Parameters
    
    .PARAMETER Global
        Si se especifica, importa los módulos en el scope global
    
    .OUTPUTS
        PSCustomObject con:
        - Success: bool indicando si la importación fue exitosa (true/false)
        - Warnings: array de advertencias
        - Errors: array de errores detallados
        - HasWarnings: bool indicando si hubo advertencias
        - HasErrors: bool indicando si hubo errores
        - LoadedModules: array de módulos importados exitosamente
        - FailedModules: array de módulos que fallaron
        - TotalModules: cantidad total de módulos procesados
        
    .NOTES
        Si Success = $false, el script que llama debe verificarlo y terminar la ejecución.
        El módulo NO termina automáticamente, solo retorna el estado.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModulesPath,
        
        [Parameter()]
        [ValidateSet('All', 'Core', 'UI', 'Compression', 'Transfer', 'Installation', 'Utilities', 'System', 'Parameters')]
        [string[]]$Categories = @('All'),
        
        [switch]$Global
    )
    
    $importWarnings = @()
    $importErrors = @()
    $loadedModules = @()
    $failedModules = @()
    
    # Definir módulos por categoría
    $modulesByCategory = @{
        Core         = @(
            'Core\TransferConfig.psm1'
            'Core\Validation.psm1'
            'Core\Logger.psm1'
        )
        UI           = @(
            'UI\Console.psm1'
            'UI\ProgressBar.psm1'
            'UI\Banners.psm1'
            'UI\Navigator.psm1'
            'UI\Menus.psm1'
            'UI\ConfigMenus.psm1'
        )
        Compression  = @(
            'Compression\SevenZip.psm1'
            'Compression\NativeZip.psm1'
            'Compression\BlockSplitter.psm1'
        )
        Transfer     = @(
            'Transfer\Local.psm1'
            'Transfer\FTP.psm1'
            'Transfer\UNC.psm1'
            'Transfer\OneDrive.psm1'
            'Transfer\Dropbox.psm1'
            'Transfer\Floppy.psm1'
            'Transfer\Unified.psm1'
        )
        Installation = @(
            'Installation\Uninstall.psm1'
            'Installation\Installer.psm1'
            'Installation\Installation.psm1'
            'Installation\Install.psm1'
            'Installation\InstallationCheck.psm1'
        )
        Utilities    = @(
            'Utilities\Examples.psm1'
            'Utilities\Help.psm1'
            'Utilities\PathSelectors.psm1'
            'Utilities\VolumeManagement.psm1'
        )
        System       = @(
            'System\Audio.psm1'
            'System\FileSystem.psm1'
            'System\Robocopy.psm1'
            'System\ISO.psm1'
        )
        Parameters   = @(
            'Parameters\Help.psm1'
            'Parameters\Example.psm1'
            'Parameters\Test.psm1'
            'Parameters\Robocopy.psm1'
            'Parameters\InteractiveMenu.psm1'
            'Parameters\NormalMode.psm1'
        )
    }
    
    # Determinar qué módulos importar
    $modulesToImport = @()
    if ($Categories -contains 'All') {
        foreach ($category in $modulesByCategory.Keys) {
            $modulesToImport += $modulesByCategory[$category]
        }
    }
    else {
        foreach ($category in $Categories) {
            if ($modulesByCategory.ContainsKey($category)) {
                $modulesToImport += $modulesByCategory[$category]
            }
        }
    }
    
    # Importar Logger.psm1 PRIMERO para tener funciones de logging disponibles
    $loggerPath = Join-Path $ModulesPath "Core\Logger.psm1"
    if (Test-Path $loggerPath) {
        try {
            if ($Global) {
                Import-Module $loggerPath -Force -Global -ErrorAction Stop -WarningAction SilentlyContinue
            }
            else {
                Import-Module $loggerPath -Force -ErrorAction Stop -WarningAction SilentlyContinue
            }
            
            # Verificar que Logger se cargó
            if (Get-Module -Name "Logger" -ErrorAction SilentlyContinue) {
                $loadedModules += "Logger"
            }
            
            # Remover Logger de la lista para no importarlo dos veces
            $modulesToImport = $modulesToImport | Where-Object { $_ -ne 'Core\Logger.psm1' }
        }
        catch {
            # Si Logger falla, agregar a errores y advertencias
            $errorDetail = [PSCustomObject]@{
                Module           = "Logger"
                Path             = "Core\Logger.psm1"
                FullPath         = $loggerPath
                ErrorType        = 'ImportException'
                Exception        = $_.Exception
                ErrorMessage     = $_.Exception.Message
                ScriptStackTrace = $_.ScriptStackTrace
            }
            $failedModules += "Logger"
            $importErrors += $errorDetail
            $importWarnings += "No se pudo cargar Logger.psm1: $($_.Exception.Message)"
            Write-Host "⚠ No se pudo cargar Logger.psm1: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # Importar y validar cada módulo
    foreach ($modulePath in $modulesToImport) {
        $fullPath = Join-Path $ModulesPath $modulePath
        $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($modulePath)
        
        # Verificar que el archivo existe
        if (-not (Test-Path $fullPath)) {
            $errorDetail = [PSCustomObject]@{
                Module    = $moduleName
                Path      = $modulePath
                FullPath  = $fullPath
                ErrorType = 'FileNotFound'
                Exception = [System.IO.FileNotFoundException]::new("Archivo de módulo no encontrado: $fullPath")
            }
            $failedModules += $moduleName
            $importErrors += $errorDetail
            $importWarnings += "Módulo no encontrado: $modulePath"
            continue
        }
        
        # Intentar importar el módulo
        try {
            $importParams = @{
                Name          = $fullPath
                Force         = $true
                ErrorAction   = 'Stop'
                WarningAction = 'SilentlyContinue'
            }
            
            if ($Global) {
                $importParams['Global'] = $true
            }
            
            Import-Module @importParams
            
            # Verificar que el módulo se importó correctamente
            $loadedModule = Get-Module -Name $moduleName -ErrorAction SilentlyContinue
            
            if ($loadedModule) {
                $loadedModules += $moduleName
            }
            else {
                # El Import-Module no lanzó error pero el módulo no está cargado
                $errorDetail = [PSCustomObject]@{
                    Module    = $moduleName
                    Path      = $modulePath
                    FullPath  = $fullPath
                    ErrorType = 'ValidationFailed'
                    Exception = [System.InvalidOperationException]::new("El módulo $moduleName no se encuentra en memoria después de Import-Module")
                }
                $failedModules += $moduleName
                $importErrors += $errorDetail
            }
        }
        catch {
            # Error durante Import-Module
            $errorDetail = [PSCustomObject]@{
                Module           = $moduleName
                Path             = $modulePath
                FullPath         = $fullPath
                ErrorType        = 'ImportException'
                Exception        = $_.Exception
                ErrorMessage     = $_.Exception.Message
                ScriptStackTrace = $_.ScriptStackTrace
            }
            $failedModules += $moduleName
            $importErrors += $errorDetail
        }
    }
    
    # Registrar en log si existe la función Write-Log
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        $logMessage = @"
[IMPORT-LLEVARMODULES]
Categorías solicitadas: $($Categories -join ', ')
Total módulos procesados: $($modulesToImport.Count)
Módulos cargados exitosamente: $($loadedModules.Count)
Módulos fallidos: $($failedModules.Count)
Advertencias: $($importWarnings.Count)
"@
        Write-Log $logMessage "INFO"
        
        if ($failedModules.Count -gt 0) {
            Write-Log "MÓDULOS FALLIDOS: $($failedModules -join ', ')" "ERROR"
            foreach ($err in $importErrors) {
                if ($err -is [PSCustomObject] -and $err.Module) {
                    Write-Log "  - $($err.Module): $($err.ErrorType) - $($err.Exception.Message)" "ERROR"
                }
            }
        }
        
        if ($importWarnings.Count -gt 0) {
            foreach ($warning in $importWarnings) {
                Write-Log "  ⚠ $warning" "WARNING"
            }
        }
    }
    
    # Determinar éxito general
    $success = ($importErrors.Count -eq 0)
    $hasErrors = ($importErrors.Count -gt 0)
    
    # Si hay errores críticos, mostrar información detallada
    if ($hasErrors) {
        # Construir log detallado
        $importErrorLog = @"
[ERROR CRÍTICO - IMPORTACIÓN DE MÓDULOS]
Se produjeron errores durante la importación de uno o más módulos.
La inicialización del sistema no puede continuar.

Total módulos procesados: $($modulesToImport.Count)
Módulos cargados exitosamente: $($loadedModules.Count)
Módulos fallidos: $($failedModules.Count)

MÓDULOS FALLIDOS:
  - $($failedModules -join "`n  - ")

DETALLES DE ERRORES ($($importErrors.Count)):
"@
        foreach ($err in $importErrors) {
            if ($err -is [PSCustomObject] -and $err.Module) {
                $importErrorLog += "`n  [$($err.Module)] $($err.ErrorType):`n    $($err.Exception.Message)"
            }
            else {
                $importErrorLog += "`n  - $($err.Exception.Message)"
            }
        }
        
        # Registrar en log usando función disponible
        if (Get-Command Write-InitLogSafe -ErrorAction SilentlyContinue) {
            Write-InitLogSafe $importErrorLog
        }
        elseif (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log $importErrorLog "ERROR"
        }
        
        # Mostrar error en consola
        Write-Host ""
        Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host "  ❌ ERROR CRÍTICO: Fallo en Importación de Módulos" -ForegroundColor Red
        Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host ""
        Write-Host "Módulos cargados: " -NoNewline -ForegroundColor Yellow
        Write-Host "$($loadedModules.Count)/$($modulesToImport.Count)" -ForegroundColor White
        Write-Host ""
        Write-Host "Módulos fallidos ($($failedModules.Count)):" -ForegroundColor Red
        foreach ($failedModule in $failedModules) {
            Write-Host "  ✗ $failedModule" -ForegroundColor Yellow
        }
        Write-Host ""
        if ($Global:LogFile) {
            Write-Host "Log detallado en: " -NoNewline -ForegroundColor Cyan
            Write-Host "$Global:LogFile" -ForegroundColor Gray
            Write-Host ""
        }
        Write-Host "ERROR: No se puede continuar sin los módulos requeridos." -ForegroundColor Red
        Write-Host ""
    }
    else {
        # Log de éxito solo si no hay errores
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log "✓ Módulos importados exitosamente: $($loadedModules.Count)/$($modulesToImport.Count)" "INFO"
        }
    }
    
    # Retornar resultado completo (el script que llama debe verificar Success)
    return [PSCustomObject]@{
        Success       = $success
        Warnings      = $importWarnings
        Errors        = $importErrors
        HasWarnings   = ($importWarnings.Count -gt 0)
        HasErrors     = $hasErrors
        LoadedModules = $loadedModules
        FailedModules = $failedModules
        TotalModules  = $modulesToImport.Count
    }
}

Export-ModuleMember -Function Import-LlevarModules
