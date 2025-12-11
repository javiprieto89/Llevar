# Importar clases de TransferConfig (using module debe estar al inicio)
using module "Q:\Utilidad\LLevar\Modules\Core\TransferConfig.psm1"

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

# Importar dependencias adicionales
$ModulesPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ModulesPath "Modules\Utilities\PathSelectors.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Transfer\Unified.psm1") -Force -Global

function Invoke-NormalMode {
    <#
    .SYNOPSIS
        Ejecuta el modo normal de LLEVAR con toda la lógica de transferencia.
    
    .PARAMETER TransferConfig
        Objeto de configuración unificado con toda la información de origen, destino y opciones.
        Debe ser creado con New-TransferConfig y configurado con Set-TransferConfigOrigen/Destino.
    
    .EXAMPLE
        $config = New-TransferConfig
        Set-TransferConfigOrigen -Config $config -Tipo "Local" -Parametros @{ Path = "C:\Data" }
        Set-TransferConfigDestino -Config $config -Tipo "USB" -Parametros @{ Path = "D:\USB" }
        Invoke-NormalMode -TransferConfig $config
    
    .EXAMPLE
        # Transferencia FTP a OneDrive
        $config = New-TransferConfig
        Set-TransferConfigOrigen -Config $config -Tipo "FTP" -Parametros @{ 
            Server = "ftp.example.com"; User = "user"; Password = "pass"; Directory = "/data" 
        }
        Set-TransferConfigDestino -Config $config -Tipo "OneDrive" -Parametros @{ Path = "/Backups" }
        Invoke-NormalMode -TransferConfig $config
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$TransferConfig
    )
    
    try {
        # Extraer valores del TransferConfig para uso local
        $BlockSizeMB = $TransferConfig.Opciones.BlockSizeMB
        $Clave = $TransferConfig.Opciones.Clave
        $UseNativeZip = $TransferConfig.Opciones.UseNativeZip
        
        # Determinar si el destino es ISO
        $esDestinoISO = ($TransferConfig.Destino.Tipo -eq "ISO")
        $IsoDestino = if ($esDestinoISO) { $TransferConfig.Destino.ISO.Size } else { "dvd" }
        
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

        # Validar origen si viene del menú contextual o parámetros legacy
        # Usar with para acceder directamente a las propiedades sin crear variables intermedias
        with ($TransferConfig.Origen) {
            switch ($PSItem.Tipo) {
                "Local" {
                    if ($PSItem.Local.Path -and (Test-Path $PSItem.Local.Path)) {
                        Show-Banner "ORIGEN PRESELECCIONADO DESDE MENÚ CONTEXTUAL" -BorderColor Cyan -TextColor Cyan
                        $item = Get-Item $PSItem.Local.Path
                        if ($item.PSIsContainer) {
                            Write-Host "Carpeta seleccionada: $($PSItem.Local.Path)" -ForegroundColor Green
                        }
                        else {
                            Write-Host "Archivo seleccionado: $($PSItem.Local.Path)" -ForegroundColor Green
                            Write-Host ""
                            Write-Host "NOTA: Se comprimirá el archivo individual." -ForegroundColor Yellow
                        }
                        Write-Host ""
                    }
                    elseif ($PSItem.Local.Path) {
                        Write-Host ""
                        Write-Host "El origen especificado no existe: $($PSItem.Local.Path)" -ForegroundColor Yellow
                        Write-Host ""
                    }
                    else {
                        $nuevoOrigen = Get-PathOrPrompt $null "ORIGEN"
                        Set-TransferConfigOrigen -Config $TransferConfig -Tipo "Local" -Parametros @{ Path = $nuevoOrigen }
                    }
                }
                "UNC" {
                    if ($PSItem.UNC.Path) {
                        Write-Host "Origen UNC configurado: $($PSItem.UNC.Path)" -ForegroundColor Green
                    }
                    else {
                        $nuevoOrigen = Get-PathOrPrompt $null "ORIGEN"
                        Set-TransferConfigOrigen -Config $TransferConfig -Tipo "Local" -Parametros @{ Path = $nuevoOrigen }
                    }
                }
                "FTP" {
                    if ($PSItem.FTP.Directory) {
                        Write-Host "Origen FTP configurado: $($PSItem.FTP.Directory)" -ForegroundColor Green
                    }
                    else {
                        $nuevoOrigen = Get-PathOrPrompt $null "ORIGEN"
                        Set-TransferConfigOrigen -Config $TransferConfig -Tipo "Local" -Parametros @{ Path = $nuevoOrigen }
                    }
                }
                "OneDrive" {
                    if ($PSItem.OneDrive.Path) {
                        Write-Host "Origen OneDrive configurado: $($PSItem.OneDrive.Path)" -ForegroundColor Green
                    }
                    else {
                        $nuevoOrigen = Get-PathOrPrompt $null "ORIGEN"
                        Set-TransferConfigOrigen -Config $TransferConfig -Tipo "Local" -Parametros @{ Path = $nuevoOrigen }
                    }
                }
                "Dropbox" {
                    if ($PSItem.Dropbox.Path) {
                        Write-Host "Origen Dropbox configurado: $($PSItem.Dropbox.Path)" -ForegroundColor Green
                    }
                    else {
                        $nuevoOrigen = Get-PathOrPrompt $null "ORIGEN"
                        Set-TransferConfigOrigen -Config $TransferConfig -Tipo "Local" -Parametros @{ Path = $nuevoOrigen }
                    }
                }
                default {
                    $nuevoOrigen = Get-PathOrPrompt $null "ORIGEN"
                    Set-TransferConfigOrigen -Config $TransferConfig -Tipo "Local" -Parametros @{ Path = $nuevoOrigen }
                }
            }
        }

        # Usar with para acceder directamente a las propiedades de destino sin crear variables intermedias
        with ($TransferConfig.Destino) {
            switch ($PSItem.Tipo) {
                "FTP" {
                    if (-not $PSItem.FTP.Directory) {
                        $nuevoDestino = Get-PathOrPrompt $null "DESTINO"
                        Set-TransferConfigDestino -Config $TransferConfig -Tipo "Local" -Parametros @{ Path = $nuevoDestino }
                    }
                }
                "Local" {
                    if (-not $PSItem.Local.Path) {
                        $nuevoDestino = Get-PathOrPrompt $null "DESTINO"
                        Set-TransferConfigDestino -Config $TransferConfig -Tipo "Local" -Parametros @{ Path = $nuevoDestino }
                    }
                }
                "USB" {
                    if (-not $PSItem.USB.Path) {
                        $nuevoDestino = Get-PathOrPrompt $null "DESTINO"
                        Set-TransferConfigDestino -Config $TransferConfig -Tipo "Local" -Parametros @{ Path = $nuevoDestino }
                    }
                }
                "UNC" {
                    if (-not $PSItem.UNC.Path) {
                        $nuevoDestino = Get-PathOrPrompt $null "DESTINO"
                        Set-TransferConfigDestino -Config $TransferConfig -Tipo "Local" -Parametros @{ Path = $nuevoDestino }
                    }
                }
                "OneDrive" {
                    if (-not $PSItem.OneDrive.Path) {
                        $nuevoDestino = Get-PathOrPrompt $null "DESTINO"
                        Set-TransferConfigDestino -Config $TransferConfig -Tipo "Local" -Parametros @{ Path = $nuevoDestino }
                    }
                }
                "Dropbox" {
                    if (-not $PSItem.Dropbox.Path) {
                        $nuevoDestino = Get-PathOrPrompt $null "DESTINO"
                        Set-TransferConfigDestino -Config $TransferConfig -Tipo "Local" -Parametros @{ Path = $nuevoDestino }
                    }
                }
                "ISO" {
                    if (-not $PSItem.ISO.OutputPath) {
                        $nuevoDestino = Get-PathOrPrompt $null "DESTINO"
                        Set-TransferConfigDestino -Config $TransferConfig -Tipo "Local" -Parametros @{ Path = $nuevoDestino }
                    }
                }
                "Diskette" {
                    if (-not $PSItem.Diskette.OutputPath) {
                        $nuevoDestino = Get-PathOrPrompt $null "DESTINO"
                        Set-TransferConfigDestino -Config $TransferConfig -Tipo "Local" -Parametros @{ Path = $nuevoDestino }
                    }
                }
                default {
                    $nuevoDestino = Get-PathOrPrompt $null "DESTINO"
                    Set-TransferConfigDestino -Config $TransferConfig -Tipo "Local" -Parametros @{ Path = $nuevoDestino }
                }
            }
        }

        # ========================================================================== #
        #              VALIDACIÓN DE ORIGEN Y DESTINO DESDE TRANSFERCONFIG           #
        # ========================================================================== #
        
        # Validar que tipo de origen esté definido
        if (-not $TransferConfig.Origen.Tipo) {
            Write-Host ""
            Write-Host "╔═══════════════════════════════════════╗" -ForegroundColor Red
            Write-Host "║  ⚠ FALTA DEFINIR ORIGEN               ║" -ForegroundColor Red
            Write-Host "╚═══════════════════════════════════════╝" -ForegroundColor Red
            Write-Host ""
            Write-Host "Debe configurar el origen antes de ejecutar la transferencia." -ForegroundColor Yellow
            Write-Host ""
            return
        }
        
        # Validar que tipo de destino esté definido
        if (-not $TransferConfig.Destino.Tipo) {
            Write-Host ""
            Write-Host "╔═══════════════════════════════════════╗" -ForegroundColor Red
            Write-Host "║  ⚠ FALTA DEFINIR DESTINO              ║" -ForegroundColor Red
            Write-Host "╚═══════════════════════════════════════╝" -ForegroundColor Red
            Write-Host ""
            Write-Host "Debe configurar el destino antes de ejecutar la transferencia." -ForegroundColor Yellow
            Write-Host ""
            return
        }
        
        # Determinar si se usa FTP, OneDrive o Dropbox accediendo directamente a TransferConfig
        $TransferMode = "Compress" # Por defecto comprimir
        with ($TransferConfig) {
            # Si alguno es FTP, OneDrive o Dropbox, preguntar modo de transferencia
            if (($PSItem.Origen.Tipo -eq "FTP" -or $PSItem.Destino.Tipo -eq "FTP") -or 
                ($PSItem.Origen.Tipo -eq "OneDrive" -or $PSItem.Destino.Tipo -eq "OneDrive") -or 
                ($PSItem.Origen.Tipo -eq "Dropbox" -or $PSItem.Destino.Tipo -eq "Dropbox")) {
                
                $tipoTransfer = "FTP"
                if ($PSItem.Origen.Tipo -eq "OneDrive" -or $PSItem.Destino.Tipo -eq "OneDrive") { $tipoTransfer = "OneDrive/FTP" }
                if ($PSItem.Origen.Tipo -eq "Dropbox" -or $PSItem.Destino.Tipo -eq "Dropbox") { $tipoTransfer = "Dropbox/OneDrive/FTP" }
                
                $mensaje = @"
¿Cómo desea realizar la transferencia?

• Transferir Directamente: Copia archivos sin comprimir
• Comprimir Primero: Comprime, divide en bloques y transfiere (genera INSTALAR.ps1)

Nota: Si elige comprimir, los archivos temporales se eliminarán automáticamente.
"@
                
                $opciones = @("*Transferir Directamente", "*Comprimir Primero")
                # DefaultIndex es base 0: 0=Directo, 1=Comprimir (dejamos Directo por defecto)
                $seleccion = Show-ConsolePopup -Title "Modo de Transferencia $tipoTransfer" -Message $mensaje -Options $opciones -DefaultIndex 0

                $TransferMode = if ($seleccion -eq 0) { "Direct" } else { "Compress" }
                Write-Host "Modo seleccionado: $TransferMode" -ForegroundColor Cyan
            }
            
            # Autenticar con OneDrive si es necesario
            if ($PSItem.Origen.Tipo -eq "OneDrive" -or $PSItem.Destino.Tipo -eq "OneDrive") {
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
            if ($PSItem.Origen.Tipo -eq "Dropbox" -or $PSItem.Destino.Tipo -eq "Dropbox") {
                Show-Banner "AUTENTICACIÓN DROPBOX" -BorderColor Cyan -TextColor Yellow
                
                if (-not (Connect-DropboxSession)) {
                    Write-Host "No se pudo autenticar con Dropbox. Cancelando." -ForegroundColor Red
                    return
                }
            }
        }

        # Procesar rutas especiales (UNC, OneDrive, Dropbox) usando solo TransferConfig
        $result = Initialize-TransferPaths -TransferConfig $TransferConfig
        
        if (-not $result) {
            # Acceder directamente a las propiedades con with para construir el mensaje de error
            $origenMsg = with ($TransferConfig.Origen) {
                switch ($PSItem.Tipo) {
                    "FTP" { $PSItem.FTP.Directory }
                    "Local" { $PSItem.Local.Path }
                    "UNC" { $PSItem.UNC.Path }
                    "OneDrive" { $PSItem.OneDrive.Path }
                    "Dropbox" { $PSItem.Dropbox.Path }
                    default { "No configurado" }
                }
            }
            $destinoMsg = with ($TransferConfig.Destino) {
                switch ($PSItem.Tipo) {
                    "FTP" { $PSItem.FTP.Directory }
                    "Local" { $PSItem.Local.Path }
                    "USB" { $PSItem.USB.Path }
                    "UNC" { $PSItem.UNC.Path }
                    "OneDrive" { $PSItem.OneDrive.Path }
                    "Dropbox" { $PSItem.Dropbox.Path }
                    "ISO" { $PSItem.ISO.OutputPath }
                    "Diskette" { $PSItem.Diskette.OutputPath }
                    default { "No configurado" }
                }
            }
            $msg = "Error inicializando rutas de transferencia.`nOrigen:  $origenMsg`nDestino: $destinoMsg`nRevise credenciales, conectividad o permisos de red."
            Show-ConsolePopup -Title "Error de Transferencia" -Message $msg -Options @("*OK") | Out-Null
            return
        }

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

        # Validar que el destino sea escribible (solo para rutas locales)
        with ($TransferConfig.Destino) {
            if ($PSItem.Tipo -notin @("FTP", "OneDrive", "Dropbox")) {
                if (-not (Test-PathWritable -Path $result.DestinoMontado)) {
                    Write-Host "Destino no es escribible. Cancelando." -ForegroundColor Red
                    Clear-TransferPaths -OrigenDrive $result.OrigenDrive -DestinoDrive $result.DestinoDrive
                    return
                }
            }
        }

        # El destino ISO ya está determinado en línea 82 desde TransferConfig
        # Modo ISO (solo si el destino es realmente ISO)
        with ($TransferConfig.Destino) {
            if ($PSItem.Tipo -eq "ISO") {
                New-LlevarIsoMain -Origen $result.OrigenMontado -Destino $result.DestinoMontado -Temp $Temp -SevenZ $SevenZ -BlockSizeMB $BlockSizeMB -Clave $Clave -IsoDestino $IsoDestino
                Clear-TransferPaths -OrigenDrive $result.OrigenDrive -DestinoDrive $result.DestinoDrive
                return
            }
        }

        # Ejecutar transferencia según el modo seleccionado
        if ($TransferMode -eq "Direct") {
            with ($TransferConfig) {
                Invoke-DirectTransfer -TransferConfig $TransferConfig -OrigenMontado $result.OrigenMontado -DestinoMontado $result.DestinoMontado `
                    -OrigenEsFtp ($PSItem.Origen.Tipo -eq "FTP") -DestinoEsFtp ($PSItem.Destino.Tipo -eq "FTP") `
                    -OrigenEsOneDrive ($PSItem.Origen.Tipo -eq "OneDrive") -DestinoEsOneDrive ($PSItem.Destino.Tipo -eq "OneDrive") `
                    -OrigenEsDropbox ($PSItem.Origen.Tipo -eq "Dropbox") -DestinoEsDropbox ($PSItem.Destino.Tipo -eq "Dropbox")
            }
            
            Clear-TransferPaths -OrigenDrive $result.OrigenDrive -DestinoDrive $result.DestinoDrive
            Write-Host "✓ Finalizado (Modo Directo)."
            return
        }

        # Modo Compresión y Transferencia
        Invoke-CompressedTransfer -TransferConfig $TransferConfig -OrigenMontado $result.OrigenMontado -DestinoMontado $result.DestinoMontado `
            -Temp $Temp -SevenZ $SevenZ -Clave $Clave -BlockSizeMB $BlockSizeMB
        
        Clear-TransferPaths -OrigenDrive $result.OrigenDrive -DestinoDrive $result.DestinoDrive -TempDir $Temp
        Write-Host "✓ Finalizado (Modo Comprimido)."
    }
    catch {
        Write-ErrorLog "Error en modo normal de ejecución." $_
        Write-Host "Ocurrió un error. Revise el log en: $Global:LogFile" -ForegroundColor Red
    }
}

# Función auxiliar para inicializar rutas de transferencia
function Initialize-TransferPaths {
    param(
        [TransferConfig]$TransferConfig
    )
    
    # Derivar rutas base directamente desde TransferConfig
    switch ($TransferConfig.Origen.Tipo) {
        "Local"   { $Origen = $TransferConfig.Origen.Local.Path }
        "UNC"     { $Origen = $TransferConfig.Origen.UNC.Path }
        "FTP"     { $Origen = $TransferConfig.Origen.FTP.Directory }
        "OneDrive"{ $Origen = $TransferConfig.Origen.OneDrive.Path }
        "Dropbox" { $Origen = $TransferConfig.Origen.Dropbox.Path }
        default   { $Origen = $null }
    }

    switch ($TransferConfig.Destino.Tipo) {
        "Local"   { $Destino = $TransferConfig.Destino.Local.Path }
        "USB"     { $Destino = $TransferConfig.Destino.USB.Path }
        "UNC"     { $Destino = $TransferConfig.Destino.UNC.Path }
        "FTP"     { $Destino = $TransferConfig.Destino.FTP.Directory }
        "OneDrive"{ $Destino = $TransferConfig.Destino.OneDrive.Path }
        "Dropbox" { $Destino = $TransferConfig.Destino.Dropbox.Path }
        "ISO"     { $Destino = $TransferConfig.Destino.ISO.OutputPath }
        "Diskette"{ $Destino = $TransferConfig.Destino.Diskette.OutputPath }
        default   { $Destino = $null }
    }

    $origenMontado = $Origen
    $destinoMontado = $Destino
    $origenDrive = $null
    $destinoDrive = $null

    # Manejar origen OneDrive
    if ($TransferConfig.Origen.Tipo -eq "OneDrive") {
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
    elseif ($TransferConfig.Origen.Tipo -eq "Dropbox") {
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
    elseif ($TransferConfig.Origen.Tipo -eq "UNC") {
        Write-Host "Montando ruta UNC de origen..." -ForegroundColor Cyan
        $origenDrive = "LLEVAR_ORIGEN"
        try {
            # Obtener credenciales desde TransferConfig
            $credOrigen = $null
            if ($TransferConfig.Origen.UNC.Credentials) {
                $credOrigen = $TransferConfig.Origen.UNC.Credentials
            }
            
            $origenMontado = Mount-LlevarNetworkPath -Path $Origen -Credential $credOrigen -DriveName $origenDrive
            Write-Host "✓ Origen montado: $origenMontado" -ForegroundColor Green
        }
        catch {
            Write-Host "Error al montar origen: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    }
    
    # Manejar destino OneDrive
    if ($TransferConfig.Destino.Tipo -eq "OneDrive") {
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
    elseif ($TransferConfig.Destino.Tipo -eq "Dropbox") {
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
    elseif ($TransferConfig.Origen.Tipo -eq "UNC") {
        Write-Host "Montando ruta UNC de destino..." -ForegroundColor Cyan
        $destinoDrive = "LLEVAR_DESTINO"
        try {
            # Obtener credenciales desde TransferConfig
            $credDestino = $null
            if ($TransferConfig.Destino.UNC.Credentials) {
                $credDestino = $TransferConfig.Destino.UNC.Credentials
            }
            
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
    param(
        [TransferConfig]$TransferConfig
    )
    
    Write-Host "Iniciando transferencia directa..." -ForegroundColor Cyan
    
    try {
        # Extraer configuración de origen y destino directamente de TransferConfig
        Write-Log "Usando TransferConfig para Copy-LlevarFiles" "INFO"
        
        # Ejecutar transferencia directa usando TransferConfig unificado
        $copyResult = Copy-LlevarFiles -TransferConfig $TransferConfig -ShowProgress $true -ProgressTop -1
        
        Show-Banner "TRANSFERENCIA COMPLETADA" -BorderColor Green -TextColor Green
        Write-Host "Archivos copiados: $($copyResult.FileCount)" -ForegroundColor White
        Write-Host "Bytes transferidos: $([Math]::Round($copyResult.BytesCopied/1MB, 2)) MB" -ForegroundColor White
        Write-Host "Tiempo transcurrido: $([Math]::Round($copyResult.ElapsedSeconds, 2)) segundos" -ForegroundColor White
        Write-Host ""
        
        Write-Host "Transferencia directa completada." -ForegroundColor Green
    }
    catch {
        Write-Host "Error durante transferencia directa: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog "Error en transferencia directa" $_
    }
}

# Función auxiliar para transferencia comprimida
function Invoke-CompressedTransfer {
    param(
        [TransferConfig]$TransferConfig,
        $OrigenMontado, $DestinoMontado, $Temp, $SevenZ, $Clave, $BlockSizeMB
    )    
    Write-Host "Iniciando compresión y transferencia..." -ForegroundColor Cyan
    
    # Si origen es OneDrive, Dropbox o FTP, descargar primero a temporal
    $origenParaComprimir = $OrigenMontado
    $tempOrigenCloud = $null
    
    if ($TransferConfig.Origen.Tipo -eq "OneDrive") {
        Write-Host "Descargando desde OneDrive a carpeta temporal..." -ForegroundColor Cyan
        $tempOrigenCloud = Join-Path $env:TEMP "LLEVAR_ONEDRIVE_ORIGEN"
        if (Test-Path $tempOrigenCloud) {
            Remove-Item $tempOrigenCloud -Recurse -Force
        }
        New-Item -Type Directory $tempOrigenCloud | Out-Null
        
        # CORREGIDO: Usar Copy-LlevarOneDriveToLocal con objeto config
        $oneDriveConfig = [PSCustomObject]@{
            Tipo            = "OneDrive"
            Path            = $OrigenMontado
            Token           = $TransferConfig.Origen.OneDrive.Token
            RefreshToken    = $TransferConfig.Origen.OneDrive.RefreshToken
            Email           = $TransferConfig.Origen.OneDrive.Email
            ApiUrl          = $TransferConfig.Origen.OneDrive.ApiUrl
            UseLocal        = $false
            DestinationPath = $tempOrigenCloud
        }
        Copy-LlevarOneDriveToLocal -OneDriveConfig $oneDriveConfig
        $origenParaComprimir = $tempOrigenCloud
    }
    elseif ($TransferConfig.Origen.Tipo -eq "Dropbox") {
        Write-Host "Descargando desde Dropbox a carpeta temporal..." -ForegroundColor Cyan
        $tempOrigenCloud = Join-Path $env:TEMP "LLEVAR_DROPBOX_ORIGEN"
        if (Test-Path $tempOrigenCloud) {
            Remove-Item $tempOrigenCloud -Recurse -Force
        }
        New-Item -Type Directory $tempOrigenCloud | Out-Null
        
        # CORREGIDO: Usar Copy-LlevarDropboxToLocal con objeto config
        $dropboxConfig = [PSCustomObject]@{
            Tipo            = "Dropbox"
            Path            = $OrigenMontado
            Token           = $TransferConfig.Origen.Dropbox.Token
            RefreshToken    = $TransferConfig.Origen.Dropbox.RefreshToken
            Email           = $TransferConfig.Origen.Dropbox.Email
            ApiUrl          = $TransferConfig.Origen.Dropbox.ApiUrl
            UseLocal        = $false
            DestinationPath = $tempOrigenCloud
        }
        Copy-LlevarDropboxToLocal -DropboxConfig $dropboxConfig
        $origenParaComprimir = $tempOrigenCloud
    }
    elseif ($TransferConfig.Origen.Tipo -eq "FTP") {
        Write-Host "Descargando desde FTP a carpeta temporal..." -ForegroundColor Cyan
        $tempOrigenCloud = Join-Path $env:TEMP "LLEVAR_FTP_ORIGEN"
        if (Test-Path $tempOrigenCloud) {
            Remove-Item $tempOrigenCloud -Recurse -Force
        }
        New-Item -Type Directory $tempOrigenCloud | Out-Null

        # Construir TransferConfig específico para FTP -> Local (descarga)
        $ftpToLocal = New-TransferConfig
        $ftpToLocal.Origen.Tipo = "FTP"
        foreach ($prop in $TransferConfig.Origen.FTP.PSObject.Properties) {
            $ftpToLocal.Origen.FTP.$($prop.Name) = $prop.Value
        }
        $ftpToLocal.Destino.Tipo = "Local"
        $ftpToLocal.Destino.Local.Path = $tempOrigenCloud

        # Usar dispatcher unificado
        $ftpDownloadResult = Copy-LlevarFiles -TransferConfig $ftpToLocal
        if (-not $ftpDownloadResult) {
            throw "No se pudo descargar datos desde FTP al origen temporal para compresión."
        }

        $origenParaComprimir = $tempOrigenCloud
    }

    $compressionResult = Compress-Folder $origenParaComprimir $Temp $SevenZ $Clave $BlockSizeMB $DestinoMontado
    $blocks = $compressionResult.Files
    $compressionType = $compressionResult.CompressionType

    # No pasar destino al instalador - dejarlo que use el directorio actual por defecto
    $installerScript = New-InstallerScript -Temp $Temp -CompressionType $compressionType

    # Si destino es OneDrive o Dropbox, subir bloques
    if ($TransferConfig.Destino.Tipo -eq "OneDrive") {
        Write-Host "Subiendo bloques a OneDrive..." -ForegroundColor Cyan

        $totalBlocks = $Blocks.Count
        $currentBlock = 0

        foreach ($block in $Blocks) {
            $currentBlock++
            $fileName = [System.IO.Path]::GetFileName($block)
            Write-Host "[$currentBlock/$totalBlocks] Subiendo: $fileName" -ForegroundColor Gray
            try {
                Send-LlevarOneDriveFile -Llevar $TransferConfig -LocalPath $block -RemotePath $DestinoMontado
            }
            catch {
                Write-Host "Error subiendo $fileName" -ForegroundColor Red
            }
        }

        if ($InstallerScript -and (Test-Path $InstallerScript)) {
            Write-Host "Subiendo INSTALAR.ps1..." -ForegroundColor Gray
            try {
                Send-LlevarOneDriveFile -Llevar $TransferConfig -LocalPath $InstallerScript -RemotePath $DestinoMontado
            }
            catch {
                Write-Host "Error subiendo INSTALAR.ps1" -ForegroundColor Red
            }
        }

        if ($SevenZ -and $CompressionType -ne "NATIVE_ZIP" -and (Test-Path $SevenZ)) {
            Write-Host "Subiendo 7z.exe..." -ForegroundColor Gray
            try {
                Send-LlevarOneDriveFile -Llevar $TransferConfig -LocalPath $SevenZ -RemotePath $DestinoMontado
            }
            catch {
                Write-Host "Error subiendo 7z.exe" -ForegroundColor Red
            }
        }

        Write-Host "Todos los archivos subidos a OneDrive" -ForegroundColor Green
    }
    elseif ($TransferConfig.Destino.Tipo -eq "Dropbox") {
        Write-Host "Subiendo bloques a Dropbox..." -ForegroundColor Cyan

        $totalBlocks = $Blocks.Count
        $currentBlock = 0

        foreach ($block in $Blocks) {
            $currentBlock++
            $fileName = [System.IO.Path]::GetFileName($block)
            Write-Host "[$currentBlock/$totalBlocks] Subiendo: $fileName" -ForegroundColor Gray
            try {
                Send-LlevarDropboxFile -Llevar $TransferConfig -LocalPath $block -RemotePath $DestinoMontado
            }
            catch {
                Write-Host "Error subiendo $fileName" -ForegroundColor Red
            }
        }

        if ($InstallerScript -and (Test-Path $InstallerScript)) {
            Write-Host "Subiendo INSTALAR.ps1..." -ForegroundColor Gray
            try {
                Send-LlevarDropboxFile -Llevar $TransferConfig -LocalPath $InstallerScript -RemotePath $DestinoMontado
            }
            catch {
                Write-Host "Error subiendo INSTALAR.ps1" -ForegroundColor Red
            }
        }

        if ($SevenZ -and $CompressionType -ne "NATIVE_ZIP" -and (Test-Path $SevenZ)) {
            Write-Host "Subiendo 7z.exe..." -ForegroundColor Gray
            try {
                Send-LlevarDropboxFile -Llevar $TransferConfig -LocalPath $SevenZ -RemotePath $DestinoMontado
            }
            catch {
                Write-Host "Error subiendo 7z.exe" -ForegroundColor Red
            }
        }

        Write-Host "Todos los archivos subidos a Dropbox" -ForegroundColor Green
    }
    elseif ($TransferConfig.Destino.Tipo -eq "Diskette") {
        $floppySuccess = Copy-ToFloppyDisks `
            -SourcePath $origenParaComprimir `
            -TempDir $Temp `
            -SevenZPath $SevenZ `
            -Password $Clave `
            -VerifyDisks
        
        if (-not $floppySuccess) {
            Write-Host "Error copiando a diskettes" -ForegroundColor Red
            return
        }
    }
    else {
        Copy-BlocksToUSB -Blocks $blocks -InstallerPath $installerScript -SevenZPath $SevenZ `
            -CompressionType $compressionType -DestinationPath $DestinoMontado -TransferConfig $TransferConfig
    }
    
    # Limpiar temporal de cloud origen si existe
    if ($tempOrigenCloud -and (Test-Path $tempOrigenCloud)) {
        Write-Host "Limpiando descarga temporal de cloud..." -ForegroundColor Cyan
        Remove-Item $tempOrigenCloud -Recurse -Force -ErrorAction SilentlyContinue
    }
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
        Write-Host "Limpiando archivos temporales..." -ForegroundColor Cyan
        try {
            if (Test-Path $TempDir) {
                Remove-Item -Path $TempDir -Recurse -Force -ErrorAction Stop
                Write-Host "Archivos temporales eliminados de: $TempDir" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "Advertencia: No se pudieron eliminar algunos archivos temporales: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-ErrorLog "Error al limpiar archivos temporales" $_
        }
    }
}

Export-ModuleMember -Function Invoke-NormalMode
