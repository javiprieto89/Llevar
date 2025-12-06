# ========================================================================== #
#                    MÓDULO: ORQUESTADOR DE TRANSFERENCIAS                   #
# ========================================================================== #
# Propósito: Función unificada Copy-LlevarFiles que orquesta todas las transferencias
# Soporta: Local, FTP, OneDrive, Dropbox, UNC en todas las combinaciones
# ========================================================================== #

function Copy-LlevarFiles {
    <#
    .SYNOPSIS
        Función unificada para copiar archivos entre cualquier tipo de origen y destino
    .DESCRIPTION
        Soporta todas las combinaciones: Local, FTP, OneDrive, Dropbox, UNC
        Incluye barra de progreso automática con Write-LlevarProgressBar
    .PARAMETER SourceConfig
        Hashtable con configuración de origen (Tipo, Path, credenciales según tipo)
    .PARAMETER DestinationConfig
        Hashtable con configuración de destino (Tipo, Path, credenciales según tipo)
    .PARAMETER SourcePath
        Ruta local del archivo/carpeta a copiar (si origen es Local/UNC)
    .PARAMETER ShowProgress
        Si se debe mostrar barra de progreso (por defecto: $true)
    .PARAMETER ProgressTop
        Posición Y de la barra de progreso (-1 = posición actual)
    .PARAMETER UseRobocopy
        Usar Robocopy para copias locales (más rápido para carpetas grandes)
    .PARAMETER RobocopyMirror
        Modo espejo con Robocopy (elimina archivos extras en destino)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$SourceConfig,
        
        [Parameter(Mandatory = $true)]
        [psobject]$DestinationConfig,
        
        [Parameter(Mandatory = $false)]
        [string]$SourcePath,
        
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1,
        [bool]$UseRobocopy = $false,
        [bool]$RobocopyMirror = $false
    )
    
    $startTime = Get-Date
    Write-Log "Iniciando copia unificada: $($SourceConfig.Tipo) → $($DestinationConfig.Tipo)" "INFO"
    
    # Validar tipos
    $validTypes = @("Local", "FTP", "OneDrive", "Dropbox", "UNC", "USB")
    if ($SourceConfig.Tipo -notin $validTypes) {
        Write-Log "Tipo de origen inválido: $($SourceConfig.Tipo)" "ERROR"
        throw "Tipo de origen inválido: $($SourceConfig.Tipo)"
    }
    if ($DestinationConfig.Tipo -notin $validTypes) {
        Write-Log "Tipo de destino inválido: $($DestinationConfig.Tipo)" "ERROR"
        throw "Tipo de destino inválido: $($DestinationConfig.Tipo)"
    }
    
    # Determinar ruta de origen
    $sourceLocation = $SourcePath
    if (-not $sourceLocation) {
        if ($SourceConfig.LocalPath) { 
            $sourceLocation = $SourceConfig.LocalPath
        }
        elseif ($SourceConfig.Path) {
            $sourceLocation = $SourceConfig.Path
        }
        else {
            throw "No se pudo determinar la ubicación de origen"
        }
    }
    
    # Verificar que el origen existe (solo para Local/UNC)
    if ($SourceConfig.Tipo -in @("Local", "UNC")) {
        if (-not (Test-Path $sourceLocation)) {
            Write-Log "Origen no existe: $sourceLocation" "ERROR"
            throw "El origen no existe: $sourceLocation"
        }
    }
    
    # Obtener información del archivo/carpeta origen
    $isFolder = $false
    $totalBytes = 0
    $fileCount = 0
    
    if ($SourceConfig.Tipo -in @("Local", "UNC")) {
        $item = Get-Item $sourceLocation
        $isFolder = $item.PSIsContainer
        
        if ($isFolder) {
            $files = Get-ChildItem -Path $sourceLocation -Recurse -File
            $fileCount = $files.Count
            $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
        }
        else {
            $fileCount = 1
            $totalBytes = $item.Length
        }
    }
    
    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Preparando copia..." -Top $ProgressTop -Width 50
    }
    
    Write-Log "Origen: $($SourceConfig.Tipo) - $sourceLocation" "INFO"
    Write-Log "Destino: $($DestinationConfig.Tipo) - $($DestinationConfig.Path)" "INFO"
    Write-Log "Archivos: $fileCount | Tamaño: $([Math]::Round($totalBytes/1MB, 2)) MB" "INFO"
    
    # ====== MATRIZ DE DECISIÓN: ORIGEN → DESTINO ======
    
    try {
        # LOCAL → LOCAL/UNC
        if ($SourceConfig.Tipo -eq "Local" -and $DestinationConfig.Tipo -in @("Local", "UNC")) {
            if ($UseRobocopy) {
                Copy-LlevarLocalToLocalRobocopy -SourcePath $sourceLocation -DestinationPath $DestinationConfig.Path `
                    -UseMirror $RobocopyMirror -StartTime $startTime -ShowProgress $ShowProgress -ProgressTop $ProgressTop
            }
            else {
                Copy-LlevarLocalToLocal -SourcePath $sourceLocation -DestinationPath $DestinationConfig.Path `
                    -TotalBytes $totalBytes -FileCount $fileCount -StartTime $startTime `
                    -ShowProgress $ShowProgress -ProgressTop $ProgressTop
            }
        }
        
        # LOCAL → FTP
        elseif ($SourceConfig.Tipo -eq "Local" -and $DestinationConfig.Tipo -eq "FTP") {
            Copy-LlevarLocalToFtp -SourcePath $sourceLocation -FtpConfig $DestinationConfig `
                -TotalBytes $totalBytes -FileCount $fileCount -StartTime $startTime `
                -ShowProgress $ShowProgress -ProgressTop $ProgressTop
        }
        
        # LOCAL → ONEDRIVE
        elseif ($SourceConfig.Tipo -eq "Local" -and $DestinationConfig.Tipo -eq "OneDrive") {
            Copy-LlevarLocalToOneDrive -SourcePath $sourceLocation -OneDriveConfig $DestinationConfig `
                -TotalBytes $totalBytes -FileCount $fileCount -StartTime $startTime `
                -ShowProgress $ShowProgress -ProgressTop $ProgressTop
        }
        
        # LOCAL → DROPBOX
        elseif ($SourceConfig.Tipo -eq "Local" -and $DestinationConfig.Tipo -eq "Dropbox") {
            Copy-LlevarLocalToDropbox -SourcePath $sourceLocation -DropboxConfig $DestinationConfig `
                -TotalBytes $totalBytes -FileCount $fileCount -StartTime $startTime `
                -ShowProgress $ShowProgress -ProgressTop $ProgressTop
        }
        
        # FTP → LOCAL
        elseif ($SourceConfig.Tipo -eq "FTP" -and $DestinationConfig.Tipo -in @("Local", "UNC")) {
            Copy-LlevarFtpToLocal -FtpConfig $SourceConfig -DestinationPath $DestinationConfig.Path `
                -StartTime $startTime -ShowProgress $ShowProgress -ProgressTop $ProgressTop
        }

        # FTP → FTP (vía carpeta temporal local)
        elseif ($SourceConfig.Tipo -eq "FTP" -and $DestinationConfig.Tipo -eq "FTP") {
            $tempPath = Join-Path $env:TEMP "LlevarFtpBridge_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
            try {
                if ($ShowProgress) {
                    Write-LlevarProgressBar -Percent 10 -StartTime $startTime -Label "Descargando FTP origen..." -Top $ProgressTop -Width 50
                }
                Copy-LlevarFtpToLocal -FtpConfig $SourceConfig -DestinationPath $tempPath `
                    -StartTime $startTime -ShowProgress $false -ProgressTop $ProgressTop
                $files = Get-ChildItem -Path $tempPath -Recurse -File
                $fileCount = $files.Count
                $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
                if ($ShowProgress) {
                    Write-LlevarProgressBar -Percent 60 -StartTime $startTime -Label "Subiendo a FTP destino..." -Top $ProgressTop -Width 50
                }
                Copy-LlevarLocalToFtp -SourcePath $tempPath -FtpConfig $DestinationConfig `
                    -TotalBytes $totalBytes -FileCount $fileCount -StartTime $startTime `
                    -ShowProgress $ShowProgress -ProgressTop $ProgressTop
            }
            finally {
                Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        # ONEDRIVE → LOCAL
        elseif ($SourceConfig.Tipo -eq "OneDrive" -and $DestinationConfig.Tipo -in @("Local", "UNC")) {
            Copy-LlevarOneDriveToLocal -OneDriveConfig $SourceConfig -DestinationPath $DestinationConfig.Path `
                -StartTime $startTime -ShowProgress $ShowProgress -ProgressTop $ProgressTop
        }
        
        # DROPBOX → LOCAL
        elseif ($SourceConfig.Tipo -eq "Dropbox" -and $DestinationConfig.Tipo -in @("Local", "UNC")) {
            Copy-LlevarDropboxToLocal -DropboxConfig $SourceConfig -DestinationPath $DestinationConfig.Path `
                -StartTime $startTime -ShowProgress $ShowProgress -ProgressTop $ProgressTop
        }
        
        # ONEDRIVE → DROPBOX (vía local temporal)
        elseif ($SourceConfig.Tipo -eq "OneDrive" -and $DestinationConfig.Tipo -eq "Dropbox") {
            $tempPath = Join-Path $env:TEMP "LlevarTransfer_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
            
            try {
                if ($ShowProgress) {
                    Write-LlevarProgressBar -Percent 25 -StartTime $startTime -Label "Descargando de OneDrive..." -Top $ProgressTop -Width 50
                }
                Copy-LlevarOneDriveToLocal -OneDriveConfig $SourceConfig -DestinationPath $tempPath `
                    -StartTime $startTime -ShowProgress $false -ProgressTop $ProgressTop
                
                if ($ShowProgress) {
                    Write-LlevarProgressBar -Percent 75 -StartTime $startTime -Label "Subiendo a Dropbox..." -Top $ProgressTop -Width 50
                }
                Copy-LlevarLocalToDropbox -SourcePath $tempPath -DropboxConfig $DestinationConfig `
                    -TotalBytes $totalBytes -FileCount $fileCount -StartTime $startTime `
                    -ShowProgress $false -ProgressTop $ProgressTop
            }
            finally {
                Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        # DROPBOX → ONEDRIVE (vía local temporal)
        elseif ($SourceConfig.Tipo -eq "Dropbox" -and $DestinationConfig.Tipo -eq "OneDrive") {
            $tempPath = Join-Path $env:TEMP "LlevarTransfer_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
            
            try {
                if ($ShowProgress) {
                    Write-LlevarProgressBar -Percent 25 -StartTime $startTime -Label "Descargando de Dropbox..." -Top $ProgressTop -Width 50
                }
                Copy-LlevarDropboxToLocal -DropboxConfig $SourceConfig -DestinationPath $tempPath `
                    -StartTime $startTime -ShowProgress $false -ProgressTop $ProgressTop
                
                if ($ShowProgress) {
                    Write-LlevarProgressBar -Percent 75 -StartTime $startTime -Label "Subiendo a OneDrive..." -Top $ProgressTop -Width 50
                }
                Copy-LlevarLocalToOneDrive -SourcePath $tempPath -OneDriveConfig $DestinationConfig `
                    -TotalBytes $totalBytes -FileCount $fileCount -StartTime $startTime `
                    -ShowProgress $false -ProgressTop $ProgressTop
            }
            finally {
                Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Combinaciones no implementadas
        else {
            throw "Combinación no soportada: $($SourceConfig.Tipo) → $($DestinationConfig.Tipo)"
        }
        
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 100 -StartTime $startTime -Label "Copia completada" -Top $ProgressTop -Width 50
        }
        
        $elapsed = (Get-Date) - $startTime
        Write-Log "Copia completada en $($elapsed.TotalSeconds) segundos" "INFO"
        
        return @{
            Success        = $true
            BytesCopied    = $totalBytes
            FileCount      = $fileCount
            ElapsedSeconds = $elapsed.TotalSeconds
        }
    }
    catch {
        Write-Log "Error en copia unificada: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Error en copia" -Top $ProgressTop -Width 50
        }
        
        throw
    }
}

# Exportar función
Export-ModuleMember -Function @(
    'Copy-LlevarFiles'
)
