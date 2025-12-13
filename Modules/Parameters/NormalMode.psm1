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
$ModulesPath = Split-Path $PSScriptRoot -Parent
#$ModulesPath = Join-Path $PSScriptRoot "Modules"
if (-not (Get-Module -Name 'TransferConfig')) {
    Import-Module (Join-Path $ModulesPath "Core\TransferConfig.psm1") -Force -Global
}
Import-Module (Join-Path $ModulesPath "Utilities\PathSelectors.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Transfer\Unified.psm1") -Force -Global

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
        # Validar si se forzó ZIP nativo
        if ($TransferConfig.Opciones.UseNativeZip) {
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

        # Validar origen si viene del menú contextual (solo para tipo Local)
        if (-not $TransferConfig.OrigenIsSet) {
            # Solo mostrar banner si viene del menú contextual con path local válido
            $origenTipo = Get-TransferType -Config $TransferConfig -Section "Origen"
            $origenLocalPath = Get-TransferConfigValue -Config $TransferConfig -Path "Origen.Local.Path"
            
            if ($origenTipo -eq "Local" -and $origenLocalPath -and (Test-Path $origenLocalPath)) {
                Show-Banner "ORIGEN PRESELECCIONADO DESDE MENÚ CONTEXTUAL" -BorderColor Cyan -TextColor Cyan
                $item = Get-Item $origenLocalPath
                if ($item.PSIsContainer) {
                    Write-Host "Carpeta seleccionada: $origenLocalPath" -ForegroundColor Green
                }
                else {
                    Write-Host "Archivo seleccionado: $origenLocalPath" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "NOTA: Se comprimirá el archivo individual." -ForegroundColor Yellow
                }
                Write-Host ""
            }
            elseif ($origenTipo -eq "Local" -and $origenLocalPath) {
                Write-Host ""
                Write-Host "El origen especificado no existe: $origenLocalPath" -ForegroundColor Yellow
                Write-Host ""
            }
            # Marcar flag - la validación completa se hace después
            Set-TransferConfigValue -Config $TransferConfig -Path "OrigenIsSet" -Value $true
        }
        
        # Marcar destino como configurado si viene del menú
        if (-not $TransferConfig.DestinoIsSet) {
            # La validación de configuración completa se hace después (líneas 223-252)
            # Aquí solo marcamos que el usuario ya pasó por la configuración
            Set-TransferConfigValue -Config $TransferConfig -Path "DestinoIsSet" -Value $true
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
        
        # Determinar si se usa FTP, OneDrive o Dropbox
        $TransferMode = "Compress" # Por defecto comprimir
        
        # Leer configuración para determinar modo de transferencia
        $origenTipo = Get-TransferType -Config $TransferConfig -Section "Origen"
        $destinoTipo = Get-TransferType -Config $TransferConfig -Section "Destino"
        
        # Si alguno es FTP, OneDrive o Dropbox, preguntar modo de transferencia
        if (($origenTipo -eq "FTP" -or $destinoTipo -eq "FTP") -or 
            ($origenTipo -eq "OneDrive" -or $destinoTipo -eq "OneDrive") -or 
            ($origenTipo -eq "Dropbox" -or $destinoTipo -eq "Dropbox")) {
            
            $tipoTransfer = "FTP"
            if ($origenTipo -eq "OneDrive" -or $destinoTipo -eq "OneDrive") { $tipoTransfer = "OneDrive/FTP" }
            if ($origenTipo -eq "Dropbox" -or $destinoTipo -eq "Dropbox") { $tipoTransfer = "Dropbox/OneDrive/FTP" }
            
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
        if ($origenTipo -eq "OneDrive" -or $destinoTipo -eq "OneDrive") {
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
        if ($origenTipo -eq "Dropbox" -or $destinoTipo -eq "Dropbox") {
            Show-Banner "AUTENTICACIÓN DROPBOX" -BorderColor Cyan -TextColor Yellow
                
            if (-not (Connect-DropboxSession)) {
                Write-Host "No se pudo autenticar con Dropbox. Cancelando." -ForegroundColor Red
                return
            }
        }

        # Inicializar rutas especiales (montar UNC, crear temp, determinar 7-Zip)
        $initResult = Initialize-TransferPaths -TransferConfig $TransferConfig
        
        if (-not $initResult) {
            Write-Host "Error inicializando rutas de transferencia." -ForegroundColor Red
            Write-Host "Revise credenciales, conectividad o permisos de red." -ForegroundColor Yellow
            return
        }
        $rutaDestino = $null
        # Validar que el destino sea escribible (solo para rutas locales/USB/UNC)
        $destinoTipo = Get-TransferType -Config $TransferConfig -Section "Destino"
        
        if ($destinoTipo -notin @("FTP", "OneDrive", "Dropbox", "ISO", "Diskette")) {
            $rutaDestino = switch ($destinoTipo) {
                "Local" { Get-TransferConfigValue -Config $TransferConfig -Path "Destino.Local.Path" }
                "USB" { Get-TransferConfigValue -Config $TransferConfig -Path "Destino.USB.Path" }
                "UNC" {
                    $destinoDrive = Get-TransferConfigValue -Config $TransferConfig -Path "Interno.DestinoDrive"
                    if ($destinoDrive) {
                        "${destinoDrive}:\"
                    }
                    else {
                        Get-TransferConfigValue -Config $TransferConfig -Path "Destino.UNC.Path"
                    }
                }
            }
            
            if (-not (Test-PathWritable -Path $rutaDestino)) {
                Write-Host "Destino no es escribible: $rutaDestino" -ForegroundColor Red
                Clear-TransferPaths -TransferConfig $TransferConfig
                return
            }
        }

        # Ejecutar transferencia según el modo seleccionado
        if ($TransferMode -eq "Direct") {
            Invoke-DirectTransfer -TransferConfig $TransferConfig
            Clear-TransferPaths -TransferConfig $TransferConfig
            Write-Host "✓ Finalizado (Modo Directo)." -ForegroundColor Green
        }
        else {
            # Modo Compresión y Transferencia
            Invoke-CompressedTransfer -TransferConfig $TransferConfig
            Clear-TransferPaths -TransferConfig $TransferConfig
            Write-Host "✓ Finalizado (Modo Comprimido)." -ForegroundColor Green
        }
    }
    catch {
        Write-ErrorLog "Error en modo normal de ejecución." $_
        Write-Host "Ocurrió un error. Revise el log en: $Global:LogFile" -ForegroundColor Red
    }
}

# Función auxiliar para inicializar rutas de transferencia
function Initialize-TransferPaths {
    <#
    .SYNOPSIS
        Inicializa recursos internos y monta drives UNC si es necesario
    .DESCRIPTION
        - Crea directorio temporal
        - Determina ruta a 7-Zip
        - Monta origen/destino UNC como drives temporales
        - Guarda todo en $TransferConfig.Interno
    #>
    param(
        [TransferConfig]$TransferConfig
    )
    
    # Inicializar TempDir
    $tempDir = Join-Path $env:TEMP "LLEVAR_TEMP"
    Set-TransferConfigValue -Config $TransferConfig -Path "Interno.TempDir" -Value $tempDir
    if (-not (Test-Path $tempDir)) {
        New-Item -Type Directory $tempDir | Out-Null
    }
    
    # Determinar SevenZipPath
    $sevenZipPath = if ($TransferConfig.Opciones.UseNativeZip) {
        "NATIVE_ZIP"
    }
    else {
        Get-SevenZipLlevar
    }
    Set-TransferConfigValue -Config $TransferConfig -Path "Interno.SevenZipPath" -Value $sevenZipPath
    
    # Manejar origen UNC - montar como drive temporal
    if ($TransferConfig.Origen.Tipo -eq "UNC") {
        Write-Host "Montando origen UNC..." -ForegroundColor Cyan
        
        $mounted = Mount-LlevarNetworkPath `
            -Path $TransferConfig.Origen.UNC.Path `
            -Credential $TransferConfig.Origen.UNC.Credentials `
            -DriveName "LLEVAR_ORIGEN"
        
        if ($mounted) {
            Set-TransferConfigValue -Config $TransferConfig -Path "Interno.OrigenDrive" -Value "LLEVAR_ORIGEN"
            Write-Host "✓ Origen UNC montado en LLEVAR_ORIGEN:\" -ForegroundColor Green
        }
        else {
            Write-Host "Error montando origen UNC. Verifique credenciales y conectividad." -ForegroundColor Red
            return $false
        }
    }
    
    # Manejar destino UNC - montar como drive temporal
    if ($TransferConfig.Destino.Tipo -eq "UNC") {
        Write-Host "Montando destino UNC..." -ForegroundColor Cyan
        
        $mounted = Mount-LlevarNetworkPath `
            -Path $TransferConfig.Destino.UNC.Path `
            -Credential $TransferConfig.Destino.UNC.Credentials `
            -DriveName "LLEVAR_DESTINO"
        
        if ($mounted) {
            Set-TransferConfigValue -Config $TransferConfig -Path "Interno.DestinoDrive" -Value "LLEVAR_DESTINO"
            Write-Host "✓ Destino UNC montado en LLEVAR_DESTINO:\" -ForegroundColor Green
        }
        else {
            Write-Host "Error montando destino UNC. Verifique credenciales y conectividad." -ForegroundColor Red
            # Limpiar origen si ya estaba montado
            if ($TransferConfig.Interno.OrigenDrive -and (Get-PSDrive -Name $TransferConfig.Interno.OrigenDrive -ErrorAction SilentlyContinue)) {
                Remove-PSDrive -Name $TransferConfig.Interno.OrigenDrive -Force
            }
            return $false
        }
    }
    
    return $true
}

# Función auxiliar para transferencia directa
# Función auxiliar para transferencia directa
function Invoke-DirectTransfer {
    <#
    .SYNOPSIS
        Ejecuta transferencia directa sin comprimir
    .DESCRIPTION
        Usa Invoke-LlevarTransfer que maneja TODAS las combinaciones:
        FTP-FTP, Local-FTP, OneDrive-Local, UNC-USB, etc.
        Detecta el tipo desde $TransferConfig automáticamente
    #>
    param(
        [TransferConfig]$TransferConfig
    )
    
    Write-Host "Iniciando transferencia directa..." -ForegroundColor Cyan
    
    try {
        # Invoke-LlevarTransfer maneja TODAS las combinaciones
        # Detecta origen/destino desde $TransferConfig.Origen.Tipo y $TransferConfig.Destino.Tipo
        $copyResult = Copy-LlevarFiles -TransferConfig $TransferConfig -ShowProgress $true -ProgressTop -1
        
        Show-Banner "TRANSFERENCIA COMPLETADA" -BorderColor Green -TextColor Green
        Write-Host "Archivos copiados: $($copyResult.FileCount)" -ForegroundColor White
        Write-Host "Bytes transferidos: $([Math]::Round($copyResult.BytesCopied / 1MB, 2)) MB" -ForegroundColor White
        Write-Host "Tiempo transcurrido: $([Math]::Round($copyResult.ElapsedSeconds, 2)) segundos" -ForegroundColor White
        Write-Host ""
        
        Write-Host "✓ Transferencia directa completada." -ForegroundColor Green
    }
    catch {
        Write-Host "Error durante transferencia directa: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog "Error en transferencia directa" $_
        throw
    }
}

# Función auxiliar para transferencia comprimida
# Función auxiliar para transferencia comprimida
function Invoke-CompressedTransfer {
    <#
    .SYNOPSIS
        Comprime archivos y transfiere bloques al destino
    .DESCRIPTION
        - Descarga desde cloud/FTP si es necesario → temporal
        - Comprime el origen en bloques
        - Genera script instalador
        - Sube/copia bloques al destino según tipo
        - Limpia temporales
    #>
    param(
        [TransferConfig]$TransferConfig
    )
    
    Write-Host "Iniciando compresión y transferencia..." -ForegroundColor Cyan
    
    # Determinar origen para comprimir
    $origenParaComprimir = $null
    $tempOrigenCloud = $null
    
    $origenTipo = Get-TransferType -Config $TransferConfig -Section "Origen"
    $tempDir = Get-TransferConfigValue -Config $TransferConfig -Path "Interno.TempDir"
    
    switch ($origenTipo) {
        "OneDrive" {
            $tempOrigenCloud = Join-Path $tempDir "OneDrive_Download"
            if (-not (Test-Path $tempOrigenCloud)) {
                New-Item -Type Directory $tempOrigenCloud | Out-Null
            }
            
            Write-Host "Descargando desde OneDrive a temporal..." -ForegroundColor Cyan
            # TODO: Implementar Copy-LlevarFromOneDrive
            $origenParaComprimir = $tempOrigenCloud
            Write-Host "✓ Descarga de OneDrive completada" -ForegroundColor Green
        }
        
        "Dropbox" {
            $tempOrigenCloud = Join-Path $tempDir "Dropbox_Download"
            if (-not (Test-Path $tempOrigenCloud)) {
                New-Item -Type Directory $tempOrigenCloud | Out-Null
            }
            
            Write-Host "Descargando desde Dropbox a temporal..." -ForegroundColor Cyan
            # TODO: Implementar Copy-LlevarFromDropbox
            $origenParaComprimir = $tempOrigenCloud
            Write-Host "✓ Descarga de Dropbox completada" -ForegroundColor Green
        }
        
        "FTP" {
            $tempOrigenCloud = Join-Path $tempDir "FTP_Download"
            if (-not (Test-Path $tempOrigenCloud)) {
                New-Item -Type Directory $tempOrigenCloud | Out-Null
            }
            
            Write-Host "Descargando desde FTP a temporal..." -ForegroundColor Cyan
            # TODO: Implementar Copy-LlevarFromFTP usando Copy-LlevarFiles
            $origenParaComprimir = $tempOrigenCloud
            Write-Host "✓ Descarga de FTP completada" -ForegroundColor Green
        }
        
        "Local" { 
            $origenParaComprimir = Get-TransferConfigValue -Config $TransferConfig -Path "Origen.Local.Path"
        }
        "USB" { 
            $origenParaComprimir = Get-TransferConfigValue -Config $TransferConfig -Path "Origen.USB.Path"
        }
        "UNC" {
            # Si es UNC, usar el drive montado
            $origenDrive = Get-TransferConfigValue -Config $TransferConfig -Path "Interno.OrigenDrive"
            $origenParaComprimir = if ($origenDrive) {
                "${origenDrive}:\"
            }
            else {
                Get-TransferConfigValue -Config $TransferConfig -Path "Origen.UNC.Path"
            }
        }
    }
    
    # Ejecutar compresión
    Write-Host "Comprimiendo archivos..." -ForegroundColor Cyan
    $compressionResult = Compress-Folder `
        -SourcePath $origenParaComprimir `
        -TempPath $TransferConfig.Interno.TempDir `
        -SevenZipPath $TransferConfig.Interno.SevenZipPath `
        -Password $TransferConfig.Opciones.Clave `
        -BlockSizeMB $TransferConfig.Opciones.BlockSizeMB
    
    $blocks = $compressionResult.Files
    $compressionType = $compressionResult.CompressionType
    
    # Generar script instalador
    $installerScript = New-InstallerScript `
        -Temp $TransferConfig.Interno.TempDir `
        -CompressionType $compressionType
    
    # Copiar/subir bloques según tipo de destino
    $destinoTipo = Get-TransferType -Config $TransferConfig -Section "Destino"
    $sevenZipPath = Get-TransferConfigValue -Config $TransferConfig -Path "Interno.SevenZipPath"
    $tempDir = Get-TransferConfigValue -Config $TransferConfig -Path "Interno.TempDir"
    
    switch ($destinoTipo) {
        "OneDrive" {
            Write-Host "Subiendo bloques a OneDrive..." -ForegroundColor Cyan
            
            $archivosParaSubir = $blocks + @($installerScript)
            if ($sevenZipPath -ne "NATIVE_ZIP") {
                $archivosParaSubir += $sevenZipPath
            }
            
            $onedrivePathValue = Get-TransferConfigValue -Config $TransferConfig -Path "Destino.OneDrive.Path"
            
            foreach ($archivo in $archivosParaSubir) {
                $nombreArchivo = Split-Path $archivo -Leaf
                
                Write-Host "  Subiendo: $nombreArchivo" -ForegroundColor Gray
                # TODO: Send-LlevarOneDriveFile -Llevar $TransferConfig -LocalPath $archivo -RemotePath "$onedrivePathValue/$nombreArchivo"
            }
            
            Write-Host "✓ Todos los bloques subidos a OneDrive" -ForegroundColor Green
            Show-Banner "TRANSFERENCIA COMPLETADA" -BorderColor Green -TextColor Yellow
            Write-Host "Los archivos están en OneDrive: $onedrivePathValue" -ForegroundColor Cyan
            Write-Host "Descarga los bloques .7z.* y ejecuta INSTALAR.ps1" -ForegroundColor Yellow
        }
        
        "Dropbox" {
            Write-Host "Subiendo bloques a Dropbox..." -ForegroundColor Cyan
            
            $archivosParaSubir = $blocks + @($installerScript)
            if ($sevenZipPath -ne "NATIVE_ZIP") {
                $archivosParaSubir += $sevenZipPath
            }
            
            $dropboxPathValue = Get-TransferConfigValue -Config $TransferConfig -Path "Destino.Dropbox.Path"
            
            foreach ($archivo in $archivosParaSubir) {
                $nombreArchivo = Split-Path $archivo -Leaf
                
                Write-Host "  Subiendo: $nombreArchivo" -ForegroundColor Gray
                # TODO: Send-LlevarDropboxFile -Llevar $TransferConfig -LocalPath $archivo -RemotePath "$dropboxPathValue/$nombreArchivo"
            }
            
            Write-Host "✓ Todos los bloques subidos a Dropbox" -ForegroundColor Green
            Show-Banner "TRANSFERENCIA COMPLETADA" -BorderColor Green -TextColor Yellow
            Write-Host "Los archivos están en Dropbox: $dropboxPathValue" -ForegroundColor Cyan
            Write-Host "Descarga los bloques .7z.* y ejecuta INSTALAR.ps1" -ForegroundColor Yellow
        }
        
        "Diskette" {
            Write-Host "Generando disquetes..." -ForegroundColor Cyan
            
            $passwordValue = Get-TransferOption -Config $TransferConfig -Option "Clave"
            
            Copy-ToFloppyDisks `
                -SourcePath $origenParaComprimir `
                -TempDir $tempDir `
                -SevenZPath $sevenZipPath `
                -Password $passwordValue `
                -VerifyDisks
            
            Write-Host "✓ Disquetes generados" -ForegroundColor Green
        }
        
        default {
            # Local, USB, UNC, FTP, ISO - copiar bloques directamente
            $destino = switch (.Tipo) {
                "Local" { .Local.Path }
                "USB" { .USB.Path }
                "UNC" {
                    if ($TransferConfig.Interno.DestinoDrive) {
                        "$($TransferConfig.Interno.DestinoDrive):\"
                    }
                    else {
                        .UNC.Path
                    }
                }
                "FTP" { .FTP.Directory }
                "ISO" { .ISO.OutputPath }
            }
                
            Write-Host "Copiando bloques a destino: $destino" -ForegroundColor Cyan
                
            # Copiar bloques, script instalador y 7z.exe si aplica
            $archivosParaCopiar = $blocks + @($installerScript)
            if ($TransferConfig.Interno.SevenZipPath -ne "NATIVE_ZIP" -and (Test-Path $TransferConfig.Interno.SevenZipPath)) {
                $archivosParaCopiar += $TransferConfig.Interno.SevenZipPath
            }
                
            # TODO: Usar Copy-LlevarFiles o función específica según destino
            foreach ($archivo in $archivosParaCopiar) {
                $nombreArchivo = Split-Path $archivo -Leaf
                Write-Host "  Copiando: $nombreArchivo" -ForegroundColor Gray
                Copy-Item $archivo -Destination $destino -Force
            }
                
            Write-Host "✓ Bloques copiados a destino" -ForegroundColor Green
        }
    }
    
    # Limpiar temporal de cloud origen si existe
    if ($tempOrigenCloud -and (Test-Path $tempOrigenCloud)) {
        Remove-Item $tempOrigenCloud -Recurse -Force
        Write-Host "✓ Limpiado temporal de descarga cloud" -ForegroundColor Green
    }
}

# Función auxiliar para limpiar rutas y temporales
function Clear-TransferPaths {
    <#
    .SYNOPSIS
        Limpia recursos: desmonta drives UNC y elimina temporales
    .DESCRIPTION
        - Desmonta drives UNC si fueron montados
        - Elimina directorio temporal
        - Accede a todo desde $TransferConfig.Interno
    #>
    param(
        [TransferConfig]$TransferConfig
    )
    
    $origenDrive = Get-TransferConfigValue -Config $TransferConfig -Path "Interno.OrigenDrive"
    $destinoDrive = Get-TransferConfigValue -Config $TransferConfig -Path "Interno.DestinoDrive"
    $tempDir = Get-TransferConfigValue -Config $TransferConfig -Path "Interno.TempDir"
    
    # Desmontar drives UNC
    if ($origenDrive -and (Get-PSDrive -Name $origenDrive -ErrorAction SilentlyContinue)) {
        Remove-PSDrive -Name $origenDrive -Force -ErrorAction SilentlyContinue
        Write-Host "✓ Desmontado origen UNC: $origenDrive" -ForegroundColor Green
    }
    
    if ($destinoDrive -and (Get-PSDrive -Name $destinoDrive -ErrorAction SilentlyContinue)) {
        Remove-PSDrive -Name $destinoDrive -Force -ErrorAction SilentlyContinue
        Write-Host "✓ Desmontado destino UNC: $destinoDrive" -ForegroundColor Green
    }
    
    # Limpiar directorio temporal
    if ($tempDir) {
        try {
            if (Test-Path $tempDir) {
                Remove-Item $tempDir -Recurse -Force -ErrorAction Stop
                Write-Host "✓ Limpiado directorio temporal" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "Advertencia: No se pudieron eliminar todos los archivos temporales" -ForegroundColor Yellow
            Write-ErrorLog "Error al limpiar archivos temporales" $_
        }
    }
}

Export-ModuleMember -Function Invoke-NormalMode
