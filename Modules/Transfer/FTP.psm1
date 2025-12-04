# ========================================================================== #
#                           MÓDULO: OPERACIONES FTP                          #
# ========================================================================== #
# Propósito: Configuración, validación y operaciones con servidores FTP/FTPS
# Funciones:
#   - Get-FtpConfigFromUser: Solicita y valida configuración FTP interactiva
#   - Test-IsFtpPath: Detecta si una ruta es FTP/FTPS
#   - Mount-FtpPath: Monta conexión FTP como unidad virtual
#   - Copy-LlevarLocalToFtp: Copia de local a FTP con progreso
#   - Copy-LlevarFtpToLocal: Descarga de FTP a local con progreso
# ========================================================================== #

function Test-IsFtpPath {
    <#
    .SYNOPSIS
        Detecta si una ruta es FTP o FTPS
    .PARAMETER Path
        Ruta a verificar
    .OUTPUTS
        $true si es FTP/FTPS, $false si no
    #>
    param([string]$Path)
    return $Path -match '^ftp://|^ftps://'
}

function Get-FtpConfigFromUser {
    <#
    .SYNOPSIS
        Solicita configuración FTP al usuario con validación interactiva
    .DESCRIPTION
        Muestra menú para configurar servidor FTP, puerto, ruta y credenciales.
        Valida la conexión antes de retornar la configuración.
    .PARAMETER Purpose
        Propósito de la conexión (ej: "ORIGEN", "DESTINO")
    .OUTPUTS
        Hashtable con Path, Server, Port, Directory, User, Password
    #>
    param([string]$Purpose = "DESTINO")
    
    Show-Banner "CONFIGURACIÓN FTP - $Purpose" -BorderColor Cyan -TextColor Yellow
    
    Write-Host "Servidor FTP (ej: 192.168.1.100 o ftp.ejemplo.com): " -NoNewline -ForegroundColor Cyan
    $server = Read-Host
    
    # Si no tiene protocolo, agregarlo
    if ($server -notlike "ftp://*" -and $server -notlike "ftps://*") {
        $server = "ftp://$server"
    }
    
    Write-Host "Puerto (presione ENTER para usar 21 predeterminado): " -NoNewline -ForegroundColor Cyan
    $portInput = Read-Host
    $port = 21
    if (-not [string]::IsNullOrWhiteSpace($portInput)) {
        if ([int]::TryParse($portInput, [ref]$port)) {
            Write-Log "Puerto FTP configurado: $port" "INFO"
        }
        else {
            Write-Host "Puerto inválido, usando 21" -ForegroundColor Yellow
            Write-Log "Puerto FTP inválido ($portInput), usando 21" "WARNING"
        }
    }
    
    # Agregar puerto a la URL si no es el predeterminado
    if ($port -ne 21) {
        $serverUri = [uri]$server
        $server = "$($serverUri.Scheme)://$($serverUri.Host):$port"
    }
    
    Write-Host "Ruta en servidor (ej: /carpeta/subcarpeta o presione ENTER para raíz): " -NoNewline -ForegroundColor Cyan
    $path = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($path)) {
        $fullPath = $server
        $directory = "/"
    }
    else {
        # Asegurar que comienza con /
        if (-not $path.StartsWith('/')) {
            $path = "/$path"
        }
        $fullPath = "$server$path"
        $directory = $path
    }
    
    Write-Host ""
    Write-Host "Credenciales FTP:" -ForegroundColor Yellow
    $credentials = Get-Credential -Message "Ingrese usuario y contraseña para $server"
    
    if (-not $credentials) {
        Write-Log "Configuración FTP cancelada por el usuario" "WARNING"
        return $null
    }
    
    # Validar conexión
    Write-Host ""
    Write-Host "Validando conexión FTP..." -ForegroundColor Cyan
    Write-Log "Intentando conectar a: $server (Usuario: $($credentials.UserName))" "INFO"
    
    try {
        $testUri = [uri]$server
        $request = [System.Net.FtpWebRequest]::Create($testUri)
        $request.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
        $request.Credentials = $credentials.GetNetworkCredential()
        $request.Timeout = 15000
        $request.UsePassive = $true
        
        $response = $request.GetResponse()
        $statusDescription = $response.StatusDescription
        $response.Close()
        
        Write-Host "✓ Conexión FTP exitosa" -ForegroundColor Green
        Write-Host "  Estado: $statusDescription" -ForegroundColor Gray
        Write-Log "Conexión FTP exitosa: $server - $statusDescription" "INFO"
        
        Start-Sleep -Seconds 2
    }
    catch {
        $errorMsg = $_.Exception.Message
        Show-Banner "⚠ ERROR DE CONEXIÓN FTP" -BorderColor Red -TextColor Red
        Write-Host "Servidor: $server" -ForegroundColor White
        Write-Host "Puerto: $port" -ForegroundColor White
        Write-Host "Error: $errorMsg" -ForegroundColor Yellow
        Write-Host ""
        Write-Log "Error de conexión FTP a ${server}:${port} - $errorMsg" "ERROR" -ErrorRecord $_
        
        Write-Host "Posibles causas:" -ForegroundColor Yellow
        Write-Host "  • Servidor o puerto incorrectos" -ForegroundColor DarkGray
        Write-Host "  • Credenciales inválidas" -ForegroundColor DarkGray
        Write-Host "  • Firewall bloqueando conexión" -ForegroundColor DarkGray
        Write-Host "  • Servidor FTP no disponible" -ForegroundColor DarkGray
        Write-Host "  • Modo pasivo no soportado (intente modo activo)" -ForegroundColor DarkGray
        Write-Host ""
        
        Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        
        # Reintentar con popup
        $respuesta = Show-ConsolePopup -Title "⚠ ERROR FTP" `
            -Message "Error: $errorMsg`n`n¿Desea reintentar?" `
            -Options @("*Reintentar", "*Cancelar") -Beep
        
        if ($respuesta -eq 0) {
            # Reintentar recursivamente
            return Get-FtpConfigFromUser -Purpose $Purpose
        }
        else {
            Write-Log "Usuario canceló configuración FTP tras error" "INFO"
            return $null
        }
    }
    
    return @{
        Path      = $fullPath
        Server    = $server
        Port      = $port
        Directory = $directory
        User      = $credentials.UserName
        Password  = $credentials.GetNetworkCredential().Password
    }
}

function Mount-FtpPath {
    <#
    .SYNOPSIS
        Monta una conexión FTP como unidad virtual
    .DESCRIPTION
        Establece conexión FTP y la guarda en hashtable global para uso posterior
    .PARAMETER Path
        URL FTP completa (ftp://servidor/ruta o ftps://servidor/ruta)
    .PARAMETER Credential
        Credenciales para autenticación FTP
    .PARAMETER DriveName
        Nombre de la unidad virtual a crear
    .OUTPUTS
        String con identificador de conexión (FTP:NombreUnidad)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [pscredential]$Credential,
        
        [Parameter(Mandatory = $true)]
        [string]$DriveName
    )
    
    # Extraer componentes de la URL FTP
    if ($Path -match '^(ftps?://)(.*?)(/.*)?$') {
        $protocol = $Matches[1]
        $server = $Matches[2]
        $remotePath = if ($Matches[3]) { $Matches[3] } else { '/' }
    }
    else {
        throw "Formato de URL FTP inválido: $Path"
    }
    
    # Solicitar credenciales si no se proporcionaron
    if (-not $Credential) {
        Write-Host "Se requieren credenciales para: $protocol$server" -ForegroundColor Yellow
        $Credential = Get-Credential -Message "Credenciales FTP para $server"
        if (-not $Credential) {
            throw "Se requieren credenciales para acceder a $Path"
        }
    }
    
    # Crear información de conexión
    try {
        if (Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue) {
            Remove-PSDrive -Name $DriveName -ErrorAction SilentlyContinue
        }
        
        $ftpInfo = @{
            Url      = "$protocol$server$remotePath"
            Username = $Credential.UserName
            Password = $Credential.GetNetworkCredential().Password
            Protocol = $protocol
        }
        
        # Guardar globalmente para uso posterior
        if (-not $Global:FtpConnections) {
            $Global:FtpConnections = @{}
        }
        $Global:FtpConnections[$DriveName] = $ftpInfo
        
        Write-Host "✓ Conexión FTP establecida: $protocol$server" -ForegroundColor Green
        Write-Log "Conexión FTP montada: $DriveName = $protocol$server$remotePath" "INFO"
        
        return "FTP:$DriveName"
    }
    catch {
        Write-Log "Error al montar conexión FTP: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        throw "No se pudo montar la conexión FTP: $($_.Exception.Message)"
    }
}

function Copy-LlevarLocalToFtp {
    <#
    .SYNOPSIS
        Copia archivos locales a servidor FTP con progreso
    .DESCRIPTION
        Sube archivos/carpetas a FTP usando WebClient con barra de progreso
    .PARAMETER SourcePath
        Ruta local del archivo o carpeta origen
    .PARAMETER FtpConfig
        Hashtable con configuración FTP (Path, Server, User, Password)
    .PARAMETER TotalBytes
        Total de bytes a copiar (para progreso)
    .PARAMETER FileCount
        Número de archivos a copiar
    .PARAMETER StartTime
        Tiempo de inicio para barra de progreso
    .PARAMETER ShowProgress
        Mostrar barra de progreso
    .PARAMETER ProgressTop
        Posición Y de la barra de progreso
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$FtpConfig,
        
        [long]$TotalBytes = 0,
        [int]$FileCount = 0,
        [datetime]$StartTime = (Get-Date),
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )
    
    Write-Log "Copia Local → FTP: $SourcePath → $($FtpConfig.Server)" "INFO"
    
    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 0 -StartTime $StartTime -Label "Subiendo a FTP..." -Top $ProgressTop -Width 50
    }
    
    # TODO: Implementación completa de subida FTP con progreso byte por byte
    # Por ahora, lanzar excepción indicando que está en desarrollo
    Write-Log "Copia Local → FTP: Funcionalidad en desarrollo" "WARNING"
    throw "Copia Local → FTP no implementada completamente. Use FTP client externo por ahora."
}

function Copy-LlevarFtpToLocal {
    <#
    .SYNOPSIS
        Descarga archivos desde FTP a local con progreso
    .DESCRIPTION
        Descarga archivos/carpetas desde FTP usando WebClient con barra de progreso
    .PARAMETER FtpConfig
        Hashtable con configuración FTP (Path, Server, User, Password)
    .PARAMETER DestinationPath
        Ruta local de destino
    .PARAMETER StartTime
        Tiempo de inicio para barra de progreso
    .PARAMETER ShowProgress
        Mostrar barra de progreso
    .PARAMETER ProgressTop
        Posición Y de la barra de progreso
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$FtpConfig,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        
        [datetime]$StartTime = (Get-Date),
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )
    
    Write-Log "Copia FTP → Local: $($FtpConfig.Server) → $DestinationPath" "INFO"
    
    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 0 -StartTime $StartTime -Label "Descargando de FTP..." -Top $ProgressTop -Width 50
    }
    
    # TODO: Implementación completa de descarga FTP con progreso byte por byte
    Write-Log "Copia FTP → Local: Funcionalidad en desarrollo" "WARNING"
    throw "Copia FTP → Local no implementada completamente. Use FTP client externo por ahora."
}

function Connect-FtpServer {
    <#
    .SYNOPSIS
        Configura y valida conexión a servidor FTP
    
    .DESCRIPTION
        Solicita configuración de FTP (puerto, autenticación, credenciales) y valida la conexión.
        Retorna objeto con la configuración para uso posterior.
    
    .PARAMETER FtpUrl
        URL del servidor FTP (puede incluir puerto)
    
    .PARAMETER Tipo
        Tipo de conexión: "Origen" o "Destino"
    
    .EXAMPLE
        $ftpConfig = Connect-FtpServer -FtpUrl "ftp://servidor.com" -Tipo "Origen"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FtpUrl,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Tipo
    )
    
    Show-Banner "CONFIGURACIÓN FTP - $Tipo" -BorderColor Cyan -TextColor Yellow
    
    # Extraer componentes del servidor de la URL
    if ($FtpUrl -match '^(ftps?://)([^/:]+)(:(\d+))?(/.*)?$') {
        $protocol = $Matches[1]
        $server = $Matches[2]
        $portFromUrl = $Matches[4]
        $path = if ($Matches[5]) { $Matches[5] } else { "/" }
    }
    else {
        throw "URL FTP inválida: $FtpUrl"
    }
    
    Write-Host "Servidor: " -NoNewline
    Write-Host $server -ForegroundColor White
    Write-Host "Protocolo: " -NoNewline
    Write-Host $protocol.TrimEnd('://').ToUpper() -ForegroundColor White
    Write-Host ""
    
    # Solicitar puerto
    if ($portFromUrl) {
        $puerto = [int]$portFromUrl
        Write-Host "Puerto detectado en URL: $puerto" -ForegroundColor Green
    }
    else {
        Write-Host "Ingrese puerto FTP [21]: " -NoNewline -ForegroundColor Cyan
        $puertoInput = Read-Host
        $puerto = if ([string]::IsNullOrWhiteSpace($puertoInput)) { 21 } else { [int]$puertoInput }
    }
    
    Write-Host "Puerto configurado: " -NoNewline
    Write-Host $puerto -ForegroundColor White
    Write-Host ""
    
    # Solicitar tipo de autenticación
    $menuOptions = @(
        "*Anónima (sin credenciales)",
        "*Usuario y Contraseña (Básica)",
        "Usuario y Contraseña con *SSL/TLS (FTPS)"
    )
    
    $authOption = Show-DosMenu -Title "TIPO DE AUTENTICACIÓN" `
        -Items $menuOptions `
        -BorderColor Cyan `
        -TextColor Gray `
        -DefaultValue 2
    
    $useSsl = $false
    $credential = $null
    $authType = ""
    
    switch ($authOption) {
        1 {
            $authType = "Anónima"
            Write-Host "Usando autenticación anónima" -ForegroundColor Yellow
            # Crear credencial anónima
            $securePass = ConvertTo-SecureString "anonymous@" -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential("anonymous", $securePass)
        }
        2 {
            $authType = "Básica"
            Write-Host "Autenticación con usuario y contraseña (sin SSL)" -ForegroundColor Yellow
            $credential = Get-Credential -Message "Credenciales para FTP: $server"
            if (-not $credential) {
                throw "Se requieren credenciales para conectar al servidor FTP"
            }
        }
        3 {
            $authType = "SSL/TLS"
            $useSsl = $true
            Write-Host "Autenticación con usuario y contraseña (SSL/TLS habilitado)" -ForegroundColor Yellow
            $credential = Get-Credential -Message "Credenciales FTPS para: $server"
            if (-not $credential) {
                throw "Se requieren credenciales para conectar al servidor FTPS"
            }
            # Cambiar protocolo a FTPS si no lo es
            if ($protocol -notmatch '^ftps://') {
                $protocol = "ftps://"
            }
        }
        default {
            $authType = "Básica"
            Write-Host "Opción inválida, usando autenticación básica por defecto" -ForegroundColor Yellow
            $credential = Get-Credential -Message "Credenciales para FTP: $server"
            if (-not $credential) {
                throw "Se requieren credenciales para conectar al servidor FTP"
            }
        }
    }
    
    Write-Host ""
    Write-Host "Validando conexión a $server`:$puerto..." -ForegroundColor Cyan
    
    # Construir URL completa
    $fullUrl = "${protocol}${server}:${puerto}${path}"
    
    # Intentar conexión de prueba
    try {
        $testRequest = [System.Net.FtpWebRequest]::Create($fullUrl)
        $testRequest.Credentials = New-Object System.Net.NetworkCredential(
            $credential.UserName,
            $credential.GetNetworkCredential().Password
        )
        $testRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
        $testRequest.UseBinary = $true
        $testRequest.KeepAlive = $false
        $testRequest.EnableSsl = $useSsl
        $testRequest.Timeout = 10000  # 10 segundos
        
        # Ignorar errores de certificado SSL si es necesario
        if ($useSsl) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        }
        
        $response = $testRequest.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $listing = $reader.ReadToEnd()
        $reader.Close()
        $stream.Close()
        $response.Close()
        
        Write-Host "✓ Conexión exitosa a $server`:$puerto" -ForegroundColor Green
        Write-Host "✓ Autenticación verificada ($authType)" -ForegroundColor Green
        
        # Mostrar algunos archivos si los hay
        if ($listing) {
            $files = $listing.Split("`n") | Where-Object { $_.Trim() -ne "" } | Select-Object -First 5
            if ($files.Count -gt 0) {
                Write-Host "✓ Directorio accesible (archivos encontrados: $($files.Count))" -ForegroundColor Green
            }
        }
        
        Write-Host ""
        
        # Retornar configuración
        return [PSCustomObject]@{
            Url        = $fullUrl
            Server     = $server
            Port       = $puerto
            Protocol   = $protocol.TrimEnd('://')
            Path       = $path
            Credential = $credential
            UseSsl     = $useSsl
            AuthType   = $authType
            Validated  = $true
        }
    }
    catch {
        Write-Host "✗ Error al conectar a $server`:$puerto" -ForegroundColor Red
        Write-Host "  Mensaje: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        
        Write-Host "Posibles causas:" -ForegroundColor Yellow
        Write-Host "  • Puerto incorrecto (verifique que sea $puerto)" -ForegroundColor Gray
        Write-Host "  • Credenciales inválidas" -ForegroundColor Gray
        Write-Host "  • Servidor no accesible o firewall bloqueando" -ForegroundColor Gray
        Write-Host "  • SSL/TLS requerido pero no configurado" -ForegroundColor Gray
        Write-Host ""
        
        throw "No se pudo validar la conexión FTP al $Tipo"
    }
}

function Get-FtpConnection {
    <#
    .SYNOPSIS
        Obtiene información de conexión FTP previamente establecida
    .PARAMETER DriveName
        Nombre de la unidad/conexión FTP
    .OUTPUTS
        Hashtable con información de conexión o $null si no existe
    #>
    param([string]$DriveName)
    
    if ($Global:FtpConnections -and $Global:FtpConnections.ContainsKey($DriveName)) {
        return $Global:FtpConnections[$DriveName]
    }
    return $null
}

function Send-FtpFile {
    <#
    .SYNOPSIS
        Sube un archivo a servidor FTP
    .PARAMETER LocalPath
        Ruta local del archivo a subir
    .PARAMETER DriveName
        Nombre de la conexión FTP establecida
    .PARAMETER RemoteFileName
        Nombre del archivo en el servidor FTP
    .OUTPUTS
        $true si la subida fue exitosa, $false si falló
    #>
    param(
        [string]$LocalPath,
        [string]$DriveName,
        [string]$RemoteFileName
    )
    
    $ftpInfo = Get-FtpConnection -DriveName $DriveName
    if (-not $ftpInfo) {
        throw "Conexión FTP no encontrada: $DriveName"
    }
    
    $remoteUrl = "$($ftpInfo.Url.TrimEnd('/'))/$RemoteFileName"
    
    try {
        $webclient = New-Object System.Net.WebClient
        $webclient.Credentials = New-Object System.Net.NetworkCredential($ftpInfo.Username, $ftpInfo.Password)
        
        Write-Host "Subiendo $RemoteFileName a FTP..." -ForegroundColor Cyan
        $webclient.UploadFile($remoteUrl, $LocalPath)
        $webclient.Dispose()
        
        Write-Host "✓ Archivo subido: $RemoteFileName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error al subir archivo FTP: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Receive-FtpFile {
    <#
    .SYNOPSIS
        Descarga un archivo desde servidor FTP
    .PARAMETER RemoteFileName
        Nombre del archivo en el servidor FTP
    .PARAMETER DriveName
        Nombre de la conexión FTP establecida
    .PARAMETER LocalPath
        Ruta local donde guardar el archivo
    .OUTPUTS
        $true si la descarga fue exitosa, $false si falló
    #>
    param(
        [string]$RemoteFileName,
        [string]$DriveName,
        [string]$LocalPath
    )
    
    $ftpInfo = Get-FtpConnection -DriveName $DriveName
    if (-not $ftpInfo) {
        throw "Conexión FTP no encontrada: $DriveName"
    }
    
    $remoteUrl = "$($ftpInfo.Url.TrimEnd('/'))/$RemoteFileName"
    
    try {
        $webclient = New-Object System.Net.WebClient
        $webclient.Credentials = New-Object System.Net.NetworkCredential($ftpInfo.Username, $ftpInfo.Password)
        
        Write-Host "Descargando $RemoteFileName desde FTP..." -ForegroundColor Cyan
        $webclient.DownloadFile($remoteUrl, $LocalPath)
        $webclient.Dispose()
        
        Write-Host "✓ Archivo descargado: $RemoteFileName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error al descargar archivo FTP: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Test-IsFtpPath',
    'Get-FtpConfigFromUser',
    'Mount-FtpPath',
    'Copy-LlevarLocalToFtp',
    'Copy-LlevarFtpToLocal',
    'Connect-FtpServer',
    'Get-FtpConnection',
    'Send-FtpFile',
    'Receive-FtpFile'
)
