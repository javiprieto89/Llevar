# ========================================================================== #
#                       MÓDULO: TRANSFERENCIAS LOCALES                       #
# ========================================================================== #
# Propósito: Copia local con Robocopy, Copy-Item y Robocopy Mirror
# Funciones:
#   - Copy-LlevarLocalToLocal: Copia básica archivo por archivo
#   - Copy-LlevarLocalToLocalRobocopy: Copia con Robocopy avanzado
#   - Invoke-RobocopyMirror: Copia espejo (sincronización completa)
# ========================================================================== #

# Imports necesarios
$ModulesPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ModulesPath "Modules\UI\ProgressBar.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Core\Logging.psm1") -Force -Global

function Copy-LlevarLocalToLocal {
    <#
    .SYNOPSIS
        Copia local archivo por archivo con progreso detallado
    .DESCRIPTION
        Copia archivos individuales usando Copy-Item, calculando progreso byte a byte
    .PARAMETER SourcePath
        Ruta local del archivo o carpeta origen
    .PARAMETER DestinationPath
        Ruta local del destino
    .PARAMETER TotalBytes
        Total de bytes a copiar (para cálculo de progreso)
    .PARAMETER FileCount
        Número total de archivos a copiar
    .PARAMETER StartTime
        Tiempo de inicio para barra de progreso
    .PARAMETER ShowProgress
        Mostrar barra de progreso ($true por defecto)
    .PARAMETER ProgressTop
        Posición Y de la barra de progreso (-1 = actual)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        
        [long]$TotalBytes = 0,
        [int]$FileCount = 0,
        [datetime]$StartTime = (Get-Date),
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )
    
    Write-Log "Copia Local → Local: $SourcePath → $DestinationPath" "INFO"
    
    if (Test-Path $SourcePath -PathType Container) {
        # Es carpeta - copiar recursivamente
        $files = Get-ChildItem -Path $SourcePath -Recurse -File
        $copiedBytes = 0
        $fileIndex = 0
        
        foreach ($file in $files) {
            $fileIndex++
            $relativePath = $file.FullName.Substring($SourcePath.Length).TrimStart('\')
            $destFile = Join-Path $DestinationPath $relativePath
            $destDir = Split-Path $destFile -Parent
            
            # Crear directorio si no existe
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            
            # Copiar archivo
            Copy-Item -Path $file.FullName -Destination $destFile -Force
            $copiedBytes += $file.Length
            
            # Actualizar progreso
            if ($ShowProgress -and $TotalBytes -gt 0) {
                $percent = [Math]::Min(100, ($copiedBytes * 100.0 / $TotalBytes))
                $label = "Copiando $fileIndex/$FileCount - $($file.Name)"
                Write-LlevarProgressBar -Percent $percent -StartTime $StartTime -Label $label -Top $ProgressTop -Width 50
            }
        }
    }
    else {
        # Es archivo individual
        $destDir = Split-Path $DestinationPath -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 0 -StartTime $StartTime -Label "Copiando archivo..." -Top $ProgressTop -Width 50
        }
        
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
        
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 100 -StartTime $StartTime -Label "Copia completada" -Top $ProgressTop -Width 50
        }
    }
    
    Write-Log "Copia Local → Local completada" "INFO"
}

function Copy-LlevarLocalToLocalRobocopy {
    <#
    .SYNOPSIS
        Copia local usando Robocopy con opciones avanzadas
    .DESCRIPTION
        Usa Robocopy para copiar directorios completos con mayor eficiencia
    .PARAMETER SourcePath
        Ruta local del directorio origen
    .PARAMETER DestinationPath
        Ruta local del destino
    .PARAMETER UseMirror
        Si es $true, usa modo Mirror (/MIR) - sincroniza eliminando extras
    .PARAMETER StartTime
        Tiempo de inicio para barra de progreso
    .PARAMETER ShowProgress
        Mostrar barra de progreso ($true por defecto)
    .PARAMETER ProgressTop
        Posición Y de la barra de progreso (-1 = actual)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        
        [bool]$UseMirror = $false,
        [datetime]$StartTime = (Get-Date),
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )
    
    Write-Log "Copia Local → Local (Robocopy): $SourcePath → $DestinationPath (Mirror: $UseMirror)" "INFO"
    
    # Crear destino si no existe
    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }
    
    # Configurar argumentos de Robocopy
    $robocopyArgs = @(
        $SourcePath,
        $DestinationPath,
        '/E',           # Copiar subdirectorios, incluidos vacíos
        '/R:3',         # 3 reintentos en caso de error
        '/W:5',         # 5 segundos de espera entre reintentos
        '/NP',          # No mostrar progreso por archivo
        '/BYTES',       # Mostrar tamaños en bytes
        '/NFL',         # No mostrar lista de archivos
        '/NDL'          # No mostrar lista de directorios
    )
    
    # Si es modo Mirror, agregar /MIR
    if ($UseMirror) {
        $robocopyArgs += '/MIR'  # Mirror mode (incluye /PURGE)
        Write-Log "Modo Mirror activado - eliminará archivos extras en destino" "WARNING"
    }
    
    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 0 -StartTime $StartTime -Label "Copiando con Robocopy..." -Top $ProgressTop -Width 50
    }
    
    Write-Log "Ejecutando: robocopy $($robocopyArgs -join ' ')" "INFO"
    
    # Ejecutar Robocopy
    $process = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
    $exitCode = $process.ExitCode
    
    # Robocopy exit codes:
    # 0 = No changes (already synchronized)
    # 1 = Files copied successfully
    # 2 = Extra files found
    # 3 = Files copied and extras found
    # 4+ = Errors
    
    if ($exitCode -le 3) {
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 100 -StartTime $StartTime -Label "Copia Robocopy completada" -Top $ProgressTop -Width 50
        }
        
        $exitMessage = switch ($exitCode) {
            0 { "Sin cambios - origen y destino sincronizados" }
            1 { "Archivos copiados exitosamente" }
            2 { "Archivos extras encontrados en destino" }
            3 { "Archivos copiados y extras procesados" }
        }
        
        Write-Log "Robocopy completado: $exitMessage (código: $exitCode)" "INFO"
    }
    else {
        Write-Log "Robocopy finalizó con errores (código: $exitCode)" "ERROR"
        throw "Robocopy falló con código de salida: $exitCode"
    }
}

# Invoke-RobocopyMirror → Migrado a Modules/System/Robocopy.psm1

# Exportar funciones
Export-ModuleMember -Function @(
    'Copy-LlevarLocalToLocal',
    'Copy-LlevarLocalToLocalRobocopy'
)
