<#
.SYNOPSIS
    Maneja el modo normal de ejecución cuando no se usa ningún parámetro especial.

.DESCRIPTION
    Este módulo contiene toda la lógica del flujo principal de LLEVAR:
    - Validación de origen/destino
    - Montaje de rutas FTP/UNC/Cloud
    - Autenticación OneDrive/Dropbox
    - Selección de modo transferencia (Directo/Comprimido)
    - Compresión y división en bloques
    - Copia a USB/ISO/Cloud
    - Limpieza de temporales
#>

# Importar dependencias
$ModulesPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ModulesPath "Modules\Utilities\PathSelectors.psm1") -Force -Global

function Invoke-NormalMode {
    <#
    .SYNOPSIS
        Ejecuta el modo normal de LLEVAR con toda la lógica de transferencia.
    
    .PARAMETER Origen
        Ruta de origen (puede ser local, UNC, FTP, OneDrive, Dropbox).
    
    .PARAMETER Destino
        Ruta de destino (puede ser local, UNC, FTP, OneDrive, Dropbox, USB).
    
    .PARAMETER BlockSizeMB
        Tamaño de cada bloque en MB (default: 10).
    
    .PARAMETER Clave
        Contraseña para proteger el archivo comprimido (solo 7-Zip).
    
    .PARAMETER UseNativeZip
        Forzar el uso de compresión ZIP nativa de Windows.
    
    .PARAMETER Iso
        Generar imágenes ISO en lugar de copiar a USB.
    
    .PARAMETER IsoDestino
        Tipo de ISO: usb, cd, dvd (default: dvd).
    
    .PARAMETER MenuConfig
        Configuración desde el menú interactivo (si viene del menú).
    
    .PARAMETER SourceCredentials
        Credenciales para FTP origen.
    
    .PARAMETER DestinationCredentials
        Credenciales para FTP destino.
    
    .PARAMETER OnedriveOrigen
        Indica que el origen es OneDrive.
    
    .PARAMETER OnedriveDestino
        Indica que el destino es OneDrive.
    
    .PARAMETER DropboxOrigen
        Indica que el origen es Dropbox.
    
    .PARAMETER DropboxDestino
        Indica que el destino es Dropbox.
    
    .PARAMETER RobocopyMirror
        Usar Robocopy en modo mirror.
    
    .EXAMPLE
        Invoke-NormalMode -Origen "C:\Data" -Destino "D:\USB"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Origen,
        
        [Parameter(Mandatory = $false)]
        [string]$Destino,
        
        [Parameter(Mandatory = $false)]
        [int]$BlockSizeMB = 10,
        
        [Parameter(Mandatory = $false)]
        [string]$Clave,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseNativeZip,
        
        [Parameter(Mandatory = $false)]
        [switch]$Iso,
        
        [Parameter(Mandatory = $false)]
        [string]$IsoDestino = "dvd",
        
        [Parameter(Mandatory = $false)]
        [hashtable]$MenuConfig,
        
        [Parameter(Mandatory = $false)]
        [pscredential]$SourceCredentials,
        
        [Parameter(Mandatory = $false)]
        [pscredential]$DestinationCredentials,
        
        [Parameter(Mandatory = $false)]
        [switch]$OnedriveOrigen,
        
        [Parameter(Mandatory = $false)]
        [switch]$OnedriveDestino,
        
        [Parameter(Mandatory = $false)]
        [switch]$DropboxOrigen,
        
        [Parameter(Mandatory = $false)]
        [switch]$DropboxDestino,
        
        [Parameter(Mandatory = $false)]
        [switch]$RobocopyMirror
    )
    
    try {
        # Validar si se forzó ZIP nativo
        if ($UseNativeZip) {
            if (-not (Test-Windows10OrLater)) {
                Write-Host ""
                Write-Host "ERROR: La compresión ZIP nativa requiere Windows 10 o superior." -ForegroundColor Red
                Write-Host ""
                Write-Host "Su versión de Windows: $([System.Environment]::OSVersion.Version)" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Opciones:" -ForegroundColor Cyan
                Write-Host "  1. Actualice a Windows 10 o superior" -ForegroundColor Gray
                Write-Host "  2. Quite el parámetro -UseNativeZip para usar 7-Zip automáticamente" -ForegroundColor Gray
                Write-Host "  3. Instale 7-Zip manualmente desde: https://www.7-zip.org/" -ForegroundColor Gray
                Write-Host ""
                return
            }
            Write-Host ""
            Write-Host "Usando compresión ZIP nativa de Windows (forzado por parámetro)" -ForegroundColor Cyan
            Write-Host "NOTA: ZIP nativo NO soporta contraseñas. El parámetro -Clave será ignorado." -ForegroundColor Yellow
            Write-Host ""
        }

        # Validar origen si viene del menú contextual
        if ($Origen) {
            if (Test-Path $Origen) {
                Show-Banner "ORIGEN PRESELECCIONADO DESDE MENÚ CONTEXTUAL" -BorderColor Cyan -TextColor Cyan
                
                $item = Get-Item $Origen
                if ($item.PSIsContainer) {
                    Write-Host "Carpeta seleccionada: $Origen" -ForegroundColor Green
                }
                else {
                    Write-Host "Archivo seleccionado: $Origen" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "NOTA: Se comprimirá el archivo individual." -ForegroundColor Yellow
                }
                Write-Host ""
            }
            else {
                Write-Host ""
                Write-Host "⚠ El origen especificado no existe: $Origen" -ForegroundColor Yellow
                Write-Host ""
                $Origen = $null
            }
        }
        
        # Si no hay origen o era inválido, pedirlo
        if (-not $Origen) {
            $Origen = Get-PathOrPrompt $Origen "ORIGEN"
        }
        
        # Pedir destino solo si no está configurado o es una ruta local que no existe
        if (-not $Destino) {
            $Destino = Get-PathOrPrompt $Destino "DESTINO"
        }
        elseif (-not ($Destino -match '^ftp://|^onedrive://|^dropbox://|^\\\\')) {
            if (-not (Test-Path $Destino)) {
                Write-Host ""
                Write-Host "⚠ El destino especificado no existe: $Destino" -ForegroundColor Yellow
                Write-Host ""
                $Destino = Get-PathOrPrompt $Destino "DESTINO"
            }
        }

        # Determinar si origen o destino son FTP, OneDrive o Dropbox
        $origenEsFtp = Test-IsFtpPath -Path $Origen
        $destinoEsFtp = Test-IsFtpPath -Path $Destino
        $origenEsOneDrive = $OnedriveOrigen -or (Test-IsOneDrivePath -Path $Origen)
        $destinoEsOneDrive = $OnedriveDestino -or (Test-IsOneDrivePath -Path $Destino)
        $origenEsDropbox = $DropboxOrigen -or (Test-IsDropboxPath -Path $Origen)
        $destinoEsDropbox = $DropboxDestino -or (Test-IsDropboxPath -Path $Destino)
        
        # Si alguno es FTP, OneDrive o Dropbox, preguntar modo de transferencia
        $TransferMode = "Compress" # Por defecto comprimir
        if ($origenEsFtp -or $destinoEsFtp -or $origenEsOneDrive -or $destinoEsOneDrive -or $origenEsDropbox -or $destinoEsDropbox) {
            $tipoTransfer = "FTP"
            if ($origenEsOneDrive -or $destinoEsOneDrive) { $tipoTransfer = "OneDrive/FTP" }
            if ($origenEsDropbox -or $destinoEsDropbox) { $tipoTransfer = "Dropbox/OneDrive/FTP" }
            
            $mensaje = @"
¿Cómo desea realizar la transferencia?

• Transferir Directamente: Copia archivos sin comprimir
• Comprimir Primero: Comprime, divide en bloques y transfiere (genera INSTALAR.ps1)

Nota: Si elige comprimir, los archivos temporales se eliminarán automáticamente.
"@
            
            $opciones = @("*Transferir Directamente", "*Comprimir Primero")
            $seleccion = Show-ConsolePopup -Title "Modo de Transferencia $tipoTransfer" -Message $mensaje -Options $opciones -DefaultValue 2
            
            $TransferMode = if ($seleccion -eq 1) { "Direct" } else { "Compress" }
            Write-Host "Modo seleccionado: $TransferMode" -ForegroundColor Cyan
        }
        
        # Autenticar con OneDrive si es necesario
        if ($origenEsOneDrive -or $destinoEsOneDrive) {
            if (-not (Test-MicrosoftGraphModule)) {
                Write-Host ""
                Write-Host "✗ No se pueden usar funciones de OneDrive sin los módulos Microsoft.Graph" -ForegroundColor Red
                Write-Host ""
                return
            }
            
            Show-Banner "AUTENTICACIÓN ONEDRIVE" -BorderColor Cyan -TextColor Yellow
            
            if (-not (Connect-GraphSession)) {
                Write-Host "No se pudo autenticar con OneDrive. Cancelando." -ForegroundColor Red
                return
            }
        }
        
        # Autenticar con Dropbox si es necesario
        if ($origenEsDropbox -or $destinoEsDropbox) {
            Show-Banner "AUTENTICACIÓN DROPBOX" -BorderColor Cyan -TextColor Yellow
            
            if (-not (Connect-DropboxSession)) {
                Write-Host "No se pudo autenticar con Dropbox. Cancelando." -ForegroundColor Red
                return
            }
        }

        # Procesar rutas especiales (UNC, FTP, OneDrive, Dropbox)
        $result = Initialize-TransferPaths -Origen $Origen -Destino $Destino `
            -OrigenEsOneDrive $origenEsOneDrive -DestinoEsOneDrive $destinoEsOneDrive `
            -OrigenEsDropbox $origenEsDropbox -DestinoEsDropbox $destinoEsDropbox `
            -OrigenEsFtp $origenEsFtp -DestinoEsFtp $destinoEsFtp `
            -SourceCredentials $SourceCredentials -DestinationCredentials $DestinationCredentials
        
        if (-not $result) {
            Write-Host "Error inicializando rutas de transferencia." -ForegroundColor Red
            return
        }
        
        $origenMontado = $result.OrigenMontado
        $destinoMontado = $result.DestinoMontado
        $origenDrive = $result.OrigenDrive
        $destinoDrive = $result.DestinoDrive

        # Determinar método de compresión
        if ($UseNativeZip) {
            $SevenZ = "NATIVE_ZIP"
        }
        else {
            $SevenZ = Get-SevenZipLlevar
        }

        $Temp = Join-Path $env:TEMP "LLEVAR_TEMP"
        if (-not (Test-Path $Temp)) { 
            New-Item -Type Directory $Temp | Out-Null 
        }

        # Validar que el destino sea escribible
        if (-not (Test-PathWritable -Path $destinoMontado)) {
            Write-Host "Destino no es escribible. Cancelando." -ForegroundColor Red
            Clear-TransferPaths -OrigenDrive $origenDrive -DestinoDrive $destinoDrive
            return
        }

        # Modo ISO
        if ($Iso) {
            New-LlevarIsoMain -Origen $origenMontado -Destino $destinoMontado -Temp $Temp -SevenZ $SevenZ -BlockSizeMB $BlockSizeMB -Clave $Clave
            Clear-TransferPaths -OrigenDrive $origenDrive -DestinoDrive $destinoDrive
            return
        }

        # Ejecutar transferencia según el modo seleccionado
        if ($TransferMode -eq "Direct") {
            Invoke-DirectTransfer -OrigenMontado $origenMontado -DestinoMontado $destinoMontado `
                -MenuConfig $MenuConfig -RobocopyMirror $RobocopyMirror `
                -OrigenEsFtp $origenEsFtp -DestinoEsFtp $destinoEsFtp `
                -OrigenEsOneDrive $origenEsOneDrive -DestinoEsOneDrive $destinoEsOneDrive `
                -OrigenEsDropbox $origenEsDropbox -DestinoEsDropbox $destinoEsDropbox
            
            Clear-TransferPaths -OrigenDrive $origenDrive -DestinoDrive $destinoDrive
            Write-Host "`n✓ Finalizado (Modo Directo)."
            return
        }

        # Modo Compresión y Transferencia
        Invoke-CompressedTransfer -OrigenMontado $origenMontado -DestinoMontado $destinoMontado `
            -Temp $Temp -SevenZ $SevenZ -Clave $Clave -BlockSizeMB $BlockSizeMB `
            -OrigenEsOneDrive $origenEsOneDrive -DestinoEsOneDrive $destinoEsOneDrive `
            -OrigenEsDropbox $origenEsDropbox -DestinoEsDropbox $destinoEsDropbox `
            -DestinoEsFtp $destinoEsFtp -MenuConfig $MenuConfig
        
        Clear-TransferPaths -OrigenDrive $origenDrive -DestinoDrive $destinoDrive -TempDir $Temp
        Write-Host "`n✓ Finalizado (Modo Comprimido)."
    }
    catch {
        Write-ErrorLog "Error en modo normal de ejecución." $_
        Write-Host "Ocurrió un error. Revise el log en: $Global:LogFile" -ForegroundColor Red
    }
}

# Función auxiliar para inicializar rutas de transferencia
function Initialize-TransferPaths {
    param(
        $Origen, $Destino,
        $OrigenEsOneDrive, $DestinoEsOneDrive,
        $OrigenEsDropbox, $DestinoEsDropbox,
        $OrigenEsFtp, $DestinoEsFtp,
        $SourceCredentials, $DestinationCredentials
    )
    
    $origenMontado = $Origen
    $destinoMontado = $Destino
    $origenDrive = $null
    $destinoDrive = $null
    
    # Manejar origen OneDrive
    if ($OrigenEsOneDrive) {
        Write-Host "Configurando origen OneDrive..." -ForegroundColor Cyan
        if ($Origen -match '^onedrive://(.+)$' -or $Origen -match '^ONEDRIVE:(.+)$') {
            $origenMontado = $Matches[1]
        }
        else {
            Write-Host "Ingrese la ruta en OneDrive (ejemplo: /Documentos/MiCarpeta): " -NoNewline
            $origenMontado = Read-Host
        }
        Write-Host "✓ Origen OneDrive configurado: $origenMontado" -ForegroundColor Green
    }
    # Manejar origen Dropbox
    elseif ($OrigenEsDropbox) {
        Write-Host "Configurando origen Dropbox..." -ForegroundColor Cyan
        if ($Origen -match '^dropbox://(.+)$' -or $Origen -match '^DROPBOX:(.+)$') {
            $origenMontado = $Matches[1]
        }
        else {
            Write-Host "Ingrese la ruta en Dropbox (ejemplo: /Documentos/MiCarpeta): " -NoNewline
            $origenMontado = Read-Host
        }
        Write-Host "✓ Origen Dropbox configurado: $origenMontado" -ForegroundColor Green
    }
    elseif ($Origen -match '^\\\\' -or $OrigenEsFtp) {
        $tipoOrigen = if ($OrigenEsFtp) { "FTP" } else { "UNC" }
        Write-Host "Montando ruta $tipoOrigen de origen..." -ForegroundColor Cyan
        $origenDrive = "LLEVAR_ORIGEN"
        try {
            $credOrigen = if ($OrigenEsFtp) { $SourceCredentials } else { $null }
            $origenMontado = Mount-LlevarNetworkPath -Path $Origen -Credential $credOrigen -DriveName $origenDrive
            Write-Host "✓ Origen montado: $origenMontado" -ForegroundColor Green
        }
        catch {
            Write-Host "Error al montar origen: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    }
    
    # Manejar destino OneDrive
    if ($DestinoEsOneDrive) {
        Write-Host "Configurando destino OneDrive..." -ForegroundColor Cyan
        if ($Destino -match '^onedrive://(.+)$' -or $Destino -match '^ONEDRIVE:(.+)$') {
            $destinoMontado = $Matches[1]
        }
        else {
            Write-Host "Ingrese la ruta en OneDrive (ejemplo: /Documentos/Destino): " -NoNewline
            $destinoMontado = Read-Host
        }
        Write-Host "✓ Destino OneDrive configurado: $destinoMontado" -ForegroundColor Green
    }
    # Manejar destino Dropbox
    elseif ($DestinoEsDropbox) {
        Write-Host "Configurando destino Dropbox..." -ForegroundColor Cyan
        if ($Destino -match '^dropbox://(.+)$' -or $Destino -match '^DROPBOX:(.+)$') {
            $destinoMontado = $Matches[1]
        }
        else {
            Write-Host "Ingrese la ruta en Dropbox (ejemplo: /Documentos/Destino): " -NoNewline
            $destinoMontado = Read-Host
        }
        Write-Host "✓ Destino Dropbox configurado: $destinoMontado" -ForegroundColor Green
    }
    elseif ($Destino -match '^\\\\' -or $DestinoEsFtp) {
        $tipoDestino = if ($DestinoEsFtp) { "FTP" } else { "UNC" }
        Write-Host "Montando ruta $tipoDestino de destino..." -ForegroundColor Cyan
        $destinoDrive = "LLEVAR_DESTINO"
        try {
            $credDestino = if ($DestinoEsFtp) { $DestinationCredentials } else { $null }
            $destinoMontado = Mount-LlevarNetworkPath -Path $Destino -Credential $credDestino -DriveName $destinoDrive
            Write-Host "✓ Destino montado: $destinoMontado" -ForegroundColor Green
        }
        catch {
            Write-Host "Error al montar destino: $($_.Exception.Message)" -ForegroundColor Red
            if ($origenDrive -and (Get-PSDrive -Name $origenDrive -ErrorAction SilentlyContinue)) {
                Remove-PSDrive -Name $origenDrive -Force -ErrorAction SilentlyContinue
            }
            return $null
        }
    }
    
    return @{
        OrigenMontado  = $origenMontado
        DestinoMontado = $destinoMontado
        OrigenDrive    = $origenDrive
        DestinoDrive   = $destinoDrive
    }
}

# Función auxiliar para transferencia directa
function Invoke-DirectTransfer {
    param($OrigenMontado, $DestinoMontado, $MenuConfig, $RobocopyMirror,
        $OrigenEsFtp, $DestinoEsFtp, $OrigenEsOneDrive, $DestinoEsOneDrive,
        $OrigenEsDropbox, $DestinoEsDropbox)
    
    Write-Host "`nIniciando transferencia directa..." -ForegroundColor Cyan
    
    try {
        if ($MenuConfig -and $MenuConfig.Origen -and $MenuConfig.Destino) {
            Write-Log "Usando configuración del menú para Copy-LlevarFiles" "INFO"
            
            $useRobocopy = $false
            if ($MenuConfig.Origen.Tipo -eq "Local" -and $MenuConfig.Destino.Tipo -in @("Local", "UNC")) {
                $useRobocopy = $MenuConfig.RobocopyMirror -or $false
            }
            
            $copyResult = Copy-LlevarFiles -SourceConfig $MenuConfig.Origen -DestinationConfig $MenuConfig.Destino `
                -SourcePath $OrigenMontado -ShowProgress $true -ProgressTop -1 `
                -UseRobocopy $useRobocopy -RobocopyMirror $MenuConfig.RobocopyMirror
        }
        else {
            Write-Log "Construyendo configuración desde parámetros de línea de comandos" "INFO"
            
            $sourceConfig = Build-TransferConfig -Path $OrigenMontado -IsFtp $OrigenEsFtp `
                -IsOneDrive $OrigenEsOneDrive -IsDropbox $OrigenEsDropbox
            
            $destConfig = Build-TransferConfig -Path $DestinoMontado -IsFtp $DestinoEsFtp `
                -IsOneDrive $DestinoEsOneDrive -IsDropbox $DestinoEsDropbox
            
            $useRobocopy = $false
            if ($sourceConfig.Tipo -eq "Local" -and $destConfig.Tipo -in @("Local", "UNC") -and $RobocopyMirror) {
                $useRobocopy = $true
            }
            
            $copyResult = Copy-LlevarFiles -SourceConfig $sourceConfig -DestinationConfig $destConfig `
                -SourcePath $OrigenMontado -ShowProgress $true -ProgressTop -1 `
                -UseRobocopy $useRobocopy -RobocopyMirror $RobocopyMirror
        }
        
        Show-Banner "✓ TRANSFERENCIA COMPLETADA" -BorderColor Green -TextColor Green
        Write-Host "Archivos copiados: $($copyResult.FileCount)" -ForegroundColor White
        Write-Host "Bytes transferidos: $([Math]::Round($copyResult.BytesCopied/1MB, 2)) MB" -ForegroundColor White
        Write-Host "Tiempo transcurrido: $([Math]::Round($copyResult.ElapsedSeconds, 2)) segundos" -ForegroundColor White
        Write-Host ""
        
        Write-Host "✓ Transferencia directa completada." -ForegroundColor Green
    }
    catch {
        Write-Host "Error durante transferencia directa: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog "Error en transferencia directa" $_
    }
}

# Función auxiliar para transferencia comprimida
function Invoke-CompressedTransfer {
    param($OrigenMontado, $DestinoMontado, $Temp, $SevenZ, $Clave, $BlockSizeMB,
        $OrigenEsOneDrive, $DestinoEsOneDrive, $OrigenEsDropbox, $DestinoEsDropbox,
        $DestinoEsFtp, $MenuConfig)
    
    Write-Host "`nIniciando compresión y transferencia..." -ForegroundColor Cyan
    
    # Si origen es OneDrive o Dropbox, descargar primero a temporal
    $origenParaComprimir = $OrigenMontado
    $tempOrigenCloud = $null
    
    if ($OrigenEsOneDrive) {
        Write-Host "Descargando desde OneDrive a carpeta temporal..." -ForegroundColor Cyan
        $tempOrigenCloud = Join-Path $env:TEMP "LLEVAR_ONEDRIVE_ORIGEN"
        if (Test-Path $tempOrigenCloud) {
            Remove-Item $tempOrigenCloud -Recurse -Force
        }
        New-Item -Type Directory $tempOrigenCloud | Out-Null
        
        Receive-OneDriveFolder -OneDrivePath "root:${OrigenMontado}:" -LocalFolder $tempOrigenCloud
        $origenParaComprimir = $tempOrigenCloud
    }
    elseif ($OrigenEsDropbox) {
        Write-Host "Descargando desde Dropbox a carpeta temporal..." -ForegroundColor Cyan
        $tempOrigenCloud = Join-Path $env:TEMP "LLEVAR_DROPBOX_ORIGEN"
        if (Test-Path $tempOrigenCloud) {
            Remove-Item $tempOrigenCloud -Recurse -Force
        }
        New-Item -Type Directory $tempOrigenCloud | Out-Null
        
        Receive-DropboxFolder -RemotePath $OrigenMontado -LocalFolder $tempOrigenCloud -Token $Global:DropboxToken
        $origenParaComprimir = $tempOrigenCloud
    }
    
    $compressionResult = Compress-Folder $origenParaComprimir $Temp $SevenZ $Clave $BlockSizeMB $DestinoMontado
    $blocks = $compressionResult.Files
    $compressionType = $compressionResult.CompressionType

    # No pasar destino al instalador - dejarlo que use el directorio actual por defecto
    $installerScript = New-InstallerScript -Temp $Temp -CompressionType $compressionType

    # Si destino es OneDrive o Dropbox, subir bloques
    if ($DestinoEsOneDrive) {
        Send-ToOneDrive -Blocks $blocks -InstallerScript $installerScript -SevenZ $SevenZ `
            -CompressionType $compressionType -DestinoMontado $DestinoMontado
    }
    elseif ($DestinoEsDropbox) {
        Send-ToDropbox -Blocks $blocks -InstallerScript $installerScript -SevenZ $SevenZ `
            -CompressionType $compressionType -DestinoMontado $DestinoMontado
    }
    elseif ($MenuConfig -and $MenuConfig.Destino -and $MenuConfig.Destino.Tipo -eq "Floppy") {
        $floppySuccess = Copy-ToFloppyDisks `
            -SourcePath $origenParaComprimir `
            -TempDir $Temp `
            -SevenZPath $SevenZ `
            -Password $Clave `
            -VerifyDisks
        
        if (-not $floppySuccess) {
            Write-Host "✗ Error copiando a diskettes" -ForegroundColor Red
            return
        }
    }
    else {
        Copy-BlocksToUSB -Blocks $blocks -InstallerPath $installerScript -SevenZPath $SevenZ `
            -CompressionType $compressionType -DestinationPath $DestinoMontado -IsFtp $DestinoEsFtp
    }
    
    # Limpiar temporal de cloud origen si existe
    if ($tempOrigenCloud -and (Test-Path $tempOrigenCloud)) {
        Write-Host "`nLimpiando descarga temporal de cloud..." -ForegroundColor Cyan
        Remove-Item $tempOrigenCloud -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Función auxiliar para construir configuración de transferencia
function Build-TransferConfig {
    param($Path, $IsFtp, $IsOneDrive, $IsDropbox)
    
    $config = @{
        Tipo      = "Local"
        Path      = $Path
        LocalPath = $Path
    }
    
    if ($IsFtp) {
        $config.Tipo = "FTP"
        $config.FtpServer = $script:FtpSourceServer
        $config.FtpPort = $script:FtpSourcePort
        $config.FtpUser = $script:FtpSourceUser
        $config.FtpPassword = $script:FtpSourcePassword
    }
    elseif ($IsOneDrive) {
        $config.Tipo = "OneDrive"
    }
    elseif ($IsDropbox) {
        $config.Tipo = "Dropbox"
    }
    
    return $config
}

# Función auxiliar para subir a OneDrive
function Send-ToOneDrive {
    param($Blocks, $InstallerScript, $SevenZ, $CompressionType, $DestinoMontado)
    
    Write-Host "`nSubiendo bloques a OneDrive..." -ForegroundColor Cyan
    
    $totalBlocks = $Blocks.Count
    $currentBlock = 0
    
    foreach ($block in $Blocks) {
        $currentBlock++
        $fileName = [System.IO.Path]::GetFileName($block)
        Write-Host "[$currentBlock/$totalBlocks] Subiendo: $fileName" -ForegroundColor Gray
        Send-OneDriveFile -LocalPath $block -RemotePath $DestinoMontado
    }
    
    if ($InstallerScript -and (Test-Path $InstallerScript)) {
        Write-Host "Subiendo INSTALAR.ps1..." -ForegroundColor Gray
        Send-OneDriveFile -LocalPath $InstallerScript -RemotePath $DestinoMontado
    }
    
    if ($SevenZ -and $CompressionType -ne "NATIVE_ZIP" -and (Test-Path $SevenZ)) {
        Write-Host "Subiendo 7z.exe..." -ForegroundColor Gray
        Send-OneDriveFile -LocalPath $SevenZ -RemotePath $DestinoMontado
    }
    
    Write-Host "`n✓ Todos los archivos subidos a OneDrive" -ForegroundColor Green
}

# Función auxiliar para subir a Dropbox
function Send-ToDropbox {
    param($Blocks, $InstallerScript, $SevenZ, $CompressionType, $DestinoMontado)
    
    Write-Host "`nSubiendo bloques a Dropbox..." -ForegroundColor Cyan
    
    $totalBlocks = $Blocks.Count
    $currentBlock = 0
    
    foreach ($block in $Blocks) {
        $currentBlock++
        $fileName = [System.IO.Path]::GetFileName($block)
        $remotePath = "$DestinoMontado/$fileName".Replace('//', '/')
        Write-Host "[$currentBlock/$totalBlocks] Subiendo: $fileName" -ForegroundColor Gray
        Send-DropboxFile -LocalPath $block -RemotePath $remotePath -Token $Global:DropboxToken
    }
    
    if ($InstallerScript -and (Test-Path $InstallerScript)) {
        Write-Host "Subiendo INSTALAR.ps1..." -ForegroundColor Gray
        $installerName = [System.IO.Path]::GetFileName($InstallerScript)
        $remotePath = "$DestinoMontado/$installerName".Replace('//', '/')
        Send-DropboxFile -LocalPath $InstallerScript -RemotePath $remotePath -Token $Global:DropboxToken
    }
    
    if ($SevenZ -and $CompressionType -ne "NATIVE_ZIP" -and (Test-Path $SevenZ)) {
        Write-Host "Subiendo 7z.exe..." -ForegroundColor Gray
        $remotePath = "$DestinoMontado/7z.exe".Replace('//', '/')
        Send-DropboxFile -LocalPath $SevenZ -RemotePath $remotePath -Token $Global:DropboxToken
    }
    
    Write-Host "`n✓ Todos los archivos subidos a Dropbox" -ForegroundColor Green
}

# Función auxiliar para limpiar rutas y temporales
function Clear-TransferPaths {
    param($OrigenDrive, $DestinoDrive, $TempDir)
    
    if ($OrigenDrive -and (Get-PSDrive -Name $OrigenDrive -ErrorAction SilentlyContinue)) {
        Remove-PSDrive -Name $OrigenDrive -Force -ErrorAction SilentlyContinue
    }
    if ($DestinoDrive -and (Get-PSDrive -Name $DestinoDrive -ErrorAction SilentlyContinue)) {
        Remove-PSDrive -Name $DestinoDrive -Force -ErrorAction SilentlyContinue
    }
    
    if ($TempDir) {
        Write-Host "`nLimpiando archivos temporales..." -ForegroundColor Cyan
        try {
            if (Test-Path $TempDir) {
                Remove-Item -Path $TempDir -Recurse -Force -ErrorAction Stop
                Write-Host "✓ Archivos temporales eliminados de: $TempDir" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "Advertencia: No se pudieron eliminar algunos archivos temporales: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-ErrorLog "Error al limpiar archivos temporales" $_
        }
    }
}

Export-ModuleMember -Function Invoke-NormalMode
