# ========================================================================== #
#                           MÓDULO: OPERACIONES FTP                          #
# ========================================================================== #
# Propósito: Configuración, validación y operaciones con servidores FTP/FTPS
# Funciones refactorizadas para usar TransferConfig como única fuente de verdad
# ========================================================================== #

# Cargar clase TransferConfig si no está disponible
$transferConfigTypeLoaded = $false
try {
    $null = [TransferConfig] -as [type]
    $transferConfigTypeLoaded = $true
}
catch {
    $transferConfigTypeLoaded = $false
}

if (-not $transferConfigTypeLoaded) {
    $ModulesPath = Split-Path $PSScriptRoot -Parent
    $transferConfigType = Join-Path $ModulesPath "Core\TransferConfig.Type.ps1"
    
    if (Test-Path $transferConfigType) {
        . $transferConfigType
    }
    else {
        throw "ERROR CRÍTICO: No se puede cargar TransferConfig.Type.ps1 desde $transferConfigType"
    }
}

# Imports necesarios
$ModulesPath = Split-Path $PSScriptRoot -Parent
if (-not (Get-Module -Name 'TransferConfig')) {
    Import-Module (Join-Path $ModulesPath "Core\TransferConfig.psm1") -Force -Global
}
Import-Module (Join-Path $ModulesPath "UI\Banners.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "UI\ProgressBar.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "UI\Menus.psm1") -Force -Global

# ========================================================================== #
#                          FUNCIONES AUXILIARES                              #
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
        Solicita configuración FTP al usuario y la asigna directamente a $Llevar
    .DESCRIPTION
        Muestra menú para configurar servidor FTP, puerto, ruta y credenciales.
        Valida la conexión y asigna SOLO los valores FTP a:
        - $Llevar.Origen.Tipo = "FTP" + $Llevar.Origen.FTP.* si $Cual = "Origen"
        - $Llevar.Destino.Tipo = "FTP" + $Llevar.Destino.FTP.* si $Cual = "Destino"
        
        ✅ NO PISA otros valores del objeto $Llevar (Opciones, la otra sección, etc.)
    .PARAMETER Llevar
        Objeto TransferConfig donde se guardarán SOLO los valores FTP
    .PARAMETER Cual
        "Origen" o "Destino" - indica qué sección configurar
    .OUTPUTS
        $true si la configuración fue exitosa, $false si se canceló
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Llevar,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Cual
    )
    
    Show-Banner "CONFIGURACIÓN FTP - $Cual" -BorderColor Cyan -TextColor Yellow
    
    # Solicitar servidor
    Write-Host "Servidor FTP (ej: 192.168.1.100 o ftp.ejemplo.com): " -NoNewline -ForegroundColor Cyan
    $server = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($server)) {
        Write-Host "✗ Servidor FTP requerido" -ForegroundColor Red
        return $false
    }
    
    # Si no tiene protocolo, agregarlo
    if ($server -notlike "ftp://*" -and $server -notlike "ftps://*") {
        $server = "ftp://$server"
    }
    
    # Solicitar puerto
    Write-Host "Puerto (presione ENTER para usar 21 predeterminado): " -NoNewline -ForegroundColor Cyan
    $portInput = Read-Host
    
    # ✅ SI USUARIO DA ENTER, USA EL PUERTO POR DEFECTO DE TransferConfig
    if ([string]::IsNullOrWhiteSpace($portInput)) {
        # Obtener puerto por defecto de TransferConfig
        if ($Cual -eq "Origen") {
            $port = if ($Llevar.Origen.FTP.Port -gt 0) { $Llevar.Origen.FTP.Port } else { 21 }
        }
        else {
            $port = if ($Llevar.Destino.FTP.Port -gt 0) { $Llevar.Destino.FTP.Port } else { 21 }
        }
        Write-Log "Usuario aceptó puerto por defecto: $port" "INFO"
    }
    else {
        # ✅ SI USUARIO INGRESÓ VALOR, PARSEAR Y VALIDAR
        if (-not [int]::TryParse($portInput, [ref]$port)) {
            Write-Host "Puerto inválido, usando 21" -ForegroundColor Yellow
            $port = 21
            Write-Log "Puerto FTP inválido ($portInput), usando 21" "WARNING"
        }
        else {
            Write-Log "Puerto FTP configurado manualmente: $port" "INFO"
        }
    }
    
    # Agregar puerto a la URL si no es el predeterminado
    if ($port -ne 21) {
        $serverUri = [uri]$server
        $server = "$($serverUri.Scheme)://$($serverUri.Host):$port"
    }
    
    # Solicitar credenciales ANTES de pedir la ruta
    Write-Host ""
    Write-Host "Credenciales FTP:" -ForegroundColor Yellow
    $credentials = Get-Credential -Message "Ingrese usuario y contraseña para $server"
    
    if (-not $credentials) {
        Write-Log "Configuración FTP cancelada por el usuario" "WARNING"
        return $false
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
        
        Start-Sleep -Seconds 1
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
        Write-Host ""
        
        # Reintentar con popup
        $respuesta = Show-ConsolePopup -Title "⚠ ERROR FTP" `
            -Message "Error: $errorMsg`n`n¿Desea reintentar?" `
            -Options @("*Reintentar", "*Cancelar") -Beep
        
        if ($respuesta -eq 0) {
            # ✅ RECURSIÓN: VUELVE A LLAMAR PASANDO EL MISMO $Llevar
            return Get-FtpConfigFromUser -Llevar $Llevar -Cual $Cual
        }
        else {
            Write-Log "Usuario canceló configuración FTP tras error" "INFO"
            return $false
        }
    }
    
    # Navegación FTP para seleccionar carpeta (AHORA con credenciales ya validadas)
    Write-Host ""
    Write-Host "Selección de carpeta en el servidor FTP:" -ForegroundColor Cyan
    $respuesta = Show-ConsolePopup -Title "NAVEGACIÓN FTP" `
        -Message "¿Navegar por el servidor o ingresar ruta manualmente?" `
        -Options @("*Navegar", "Ingresar *Ruta", "Usar *Raíz (/)")
    
    $directory = "/"
    
    if ($respuesta -eq 0) {
        # NAVEGAR
        Write-Host "Abriendo navegador FTP..." -ForegroundColor Cyan
        
        try {
            $selectedPath = Select-FtpFolder `
                -Server $server `
                -Port $port `
                -Credential $credentials `
                -UseSsl ($server -match '^ftps://') `
                -Prompt "Seleccionar carpeta FTP en $server" `
                -InitialPath "/"
            
            if ($selectedPath) {
                $directory = $selectedPath
                Write-Host "✓ Carpeta seleccionada: $directory" -ForegroundColor Green
            }
            else {
                Write-Host "Navegación cancelada, usando raíz (/)" -ForegroundColor Yellow
                $directory = "/"
            }
        }
        catch {
            Write-Host "Error al navegar FTP: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "Error navegando FTP: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
            Write-Host "Usando raíz (/)" -ForegroundColor Yellow
            $directory = "/"
        }
    }
    elseif ($respuesta -eq 1) {
        # INGRESAR RUTA MANUAL
        Write-Host "Ruta en servidor (ej: /carpeta/subcarpeta): " -NoNewline -ForegroundColor Cyan
        $path = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($path)) {
            $directory = "/"
        }
        else {
            # Asegurar que comienza con /
            if (-not $path.StartsWith('/')) {
                $path = "/$path"
            }
            $directory = $path
        }
        Write-Host "✓ Ruta configurada: $directory" -ForegroundColor Green
    }
    else {
        # USAR RAÍZ
        $directory = "/"
        Write-Host "✓ Usando raíz (/)" -ForegroundColor Green
    }
    
    # ✅✅✅ ASIGNAR SOLO LA SECCIÓN FTP CORRESPONDIENTE
    if ($Cual -eq "Origen") {
        $Llevar.Origen.Tipo = "FTP"
        $Llevar.Origen.FTP.Server = $server
        $Llevar.Origen.FTP.Port = $port
        $Llevar.Origen.FTP.Credentials = $credentials
        $Llevar.Origen.FTP.User = $credentials.UserName
        $Llevar.Origen.FTP.Password = $credentials.GetNetworkCredential().Password
        $Llevar.Origen.FTP.UseSsl = ($server -match '^ftps://')
        $Llevar.Origen.FTP.Directory = $directory
        
        Write-Log "FTP Origen configurado: $server$directory (Usuario: $($credentials.UserName), Puerto: $port)" "INFO"
    }
    else {
        $Llevar.Destino.Tipo = "FTP"
        $Llevar.Destino.FTP.Server = $server
        $Llevar.Destino.FTP.Port = $port
        $Llevar.Destino.FTP.Credentials = $credentials
        $Llevar.Destino.FTP.User = $credentials.UserName
        $Llevar.Destino.FTP.Password = $credentials.GetNetworkCredential().Password
        $Llevar.Destino.FTP.UseSsl = ($server -match '^ftps://')
        $Llevar.Destino.FTP.Directory = $directory
        
        Write-Log "FTP Destino configurado: $server$directory (Usuario: $($credentials.UserName), Puerto: $port)" "INFO"
    }
    
    Write-Host ""
    Write-Host "✓ Configuración FTP guardada en \$Llevar.$Cual.FTP" -ForegroundColor Green
    Write-Host ""
    
    return $true
}

# ========================================================================== #
#                  FUNCIONES PRINCIPALES DE TRANSFERENCIA                    #
# ========================================================================== #

function Copy-LlevarLocalToFtp {
    <#
    .SYNOPSIS
        Copia archivos locales a servidor FTP con progreso
    .DESCRIPTION
        ✅ DELEGADO AL DISPATCHER UNIFICADO
        Esta función es ahora un wrapper que delega al dispatcher.
    .PARAMETER Llevar
        Objeto TransferConfig completo
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Llevar,
        
        [datetime]$StartTime = (Get-Date),
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )
    
    # ✅ DELEGAR AL DISPATCHER
    Write-Log "Copy-LlevarLocalToFtp: Delegando al dispatcher unificado" "INFO"
    
    # Importar dispatcher si no está cargado
    $dispatcherPath = Join-Path $ModulesPath "Transfer\Unified.psm1"
    if (-not (Get-Command Invoke-TransferDispatcher -ErrorAction SilentlyContinue)) {
        Import-Module $dispatcherPath -Force -Global
    }
    
    return Invoke-TransferDispatcher -Llevar $Llevar `
        -ShowProgress $ShowProgress -ProgressTop $ProgressTop
}

function Copy-LlevarFtpToLocal {
    <#
    .SYNOPSIS
        Descarga archivos desde FTP a local con progreso
    .DESCRIPTION
        ✅ DELEGADO AL DISPATCHER UNIFICADO
        Esta función es ahora un wrapper que delega al dispatcher.
    .PARAMETER Llevar
        Objeto TransferConfig completo
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Llevar,
        
        [datetime]$StartTime = (Get-Date),
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )
    
    # ✅ DELEGAR AL DISPATCHER
    Write-Log "Copy-LlevarFtpToLocal: Delegando al dispatcher unificado" "INFO"
    
    # Importar dispatcher si no está cargado
    $dispatcherPath = Join-Path $ModulesPath "Transfer\Unified.psm1"
    if (-not (Get-Command Invoke-TransferDispatcher -ErrorAction SilentlyContinue)) {
        Import-Module $dispatcherPath -Force -Global
    }
    
    return Invoke-TransferDispatcher -Llevar $Llevar `
        -ShowProgress $ShowProgress -ProgressTop $ProgressTop
}

# ========================================================================== #
#                         FUNCIONES LEGACY (OBSOLETAS)                       #
# ========================================================================== #

function Mount-FtpPath {
    <#
    .SYNOPSIS
        [LEGACY] Monta una conexión FTP como unidad virtual
    .DESCRIPTION
        Función legacy mantenida por compatibilidad.
        Se recomienda usar TransferConfig en su lugar.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [pscredential]$Credential,
        
        [Parameter(Mandatory = $true)]
        [string]$DriveName
    )
    
    if ($Path -match '^(ftps?://)(.*?)(/.*)?$') {
        $protocol = $Matches[1]
        $server = $Matches[2]
        $remotePath = if ($Matches[3]) { $Matches[3] } else { '/' }
    }
    else {
        throw "Formato de URL FTP inválido: $Path"
    }
    
    if (-not $Credential) {
        $Credential = Get-Credential -Message "Credenciales FTP para $server"
        if (-not $Credential) {
            throw "Se requieren credenciales para acceder a $Path"
        }
    }
    
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

function Get-FtpConnection {
    <#
    .SYNOPSIS
        [LEGACY] Obtiene información de conexión FTP previamente establecida
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
        [LEGACY] Sube un archivo a servidor FTP
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
        [LEGACY] Descarga un archivo desde servidor FTP
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

# ========================================================================== #
#                      FUNCIONES DE NAVEGACIÓN FTP                           #
# ========================================================================== #

function Get-FtpNavigatorItems {
    <#
    .SYNOPSIS
        Helper para Navigator genérico - Lista items de FTP
    .DESCRIPTION
        Esta función es llamada por el Navigator genérico cuando la fuente es FTP.
        Retorna items en formato compatible con el Navigator.
    .PARAMETER Server
        Servidor FTP (ej: ftp://192.168.1.100)
    .PARAMETER Port
        Puerto FTP
    .PARAMETER Username
        Usuario FTP
    .PARAMETER Credential
        Credenciales FTP (PSCredential)
    .PARAMETER CurrentPath
        Ruta actual en FTP
    .PARAMETER AllowFiles
        Si permite seleccionar archivos o solo carpetas
    .PARAMETER UseSsl
        Si usar FTPS
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Server,

        [int]$Port = 21,

        [PSCredential]$Credential,

        [string]$CurrentPath = "/",

        [bool]$AllowFiles = $false,

        [bool]$UseSsl = $false
    )

    # Normalizar ruta
    if ([string]::IsNullOrWhiteSpace($CurrentPath)) {
        $CurrentPath = "/"
    }
    if (-not $CurrentPath.StartsWith('/')) {
        $CurrentPath = "/$CurrentPath"
    }
    if ($CurrentPath -ne "/" -and $CurrentPath.EndsWith('/')) {
        $CurrentPath = $CurrentPath.TrimEnd('/')
    }

    # Construir URL FTP
    $serverClean = $Server -replace '^ftp(s)?://', ''
    $protocol = if ($UseSsl) { "ftps" } else { "ftp" }
    $ftpUrl = "${protocol}://${serverClean}:${Port}${CurrentPath}"

    Write-Log "Get-FtpNavigatorItems: Listando $ftpUrl" "DEBUG"

    $items = @()

    # Agregar item ".." si no estamos en raíz
    if ($CurrentPath -ne "/") {
        $parentPath = if ($CurrentPath.Contains('/')) {
            $CurrentPath.Substring(0, $CurrentPath.LastIndexOf('/'))
        }
        else {
            "/"
        }
        if ([string]::IsNullOrWhiteSpace($parentPath)) {
            $parentPath = "/"
        }

        $items += [PSCustomObject]@{
            Name            = ".."
            FullName        = $parentPath
            IsDirectory     = $true
            IsParent        = $true
            IsDriveSelector = $false
            Size            = ""
            Icon            = "↩"
        }
    }

    # Listar contenido del directorio FTP
    try {
        $request = [System.Net.FtpWebRequest]::Create($ftpUrl)
        $request.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
        
        if ($Credential) {
            $request.Credentials = $Credential.GetNetworkCredential()
        }
        
        if ($UseSsl) {
            $request.EnableSsl = $true
            # Aceptar cualquier certificado SSL (para servidores con certificados autofirmados)
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        }

        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        
        $listing = @()
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                $listing += $line
            }
        }

        $reader.Close()
        $stream.Close()
        $response.Close()

        # Parsear listado FTP (formato Unix-like)
        foreach ($line in $listing) {
            # Formato típico Unix: drwxr-xr-x 2 user group 4096 Dec 13 10:00 carpeta
            if ($line -match '^([d-])[rwx-]{9}\s+\d+\s+\S+\s+\S+\s+(\d+)\s+\S+\s+\S+\s+\S+\s+(.+)$') {
                $isDir = $matches[1] -eq 'd'
                $size = $matches[2]
                $name = $matches[3].Trim()

                # Ignorar . y ..
                if ($name -eq '.' -or $name -eq '..') {
                    continue
                }

                # Si no permitimos archivos y es archivo, saltar
                if (-not $AllowFiles -and -not $isDir) {
                    continue
                }

                $fullPath = if ($CurrentPath -eq "/") {
                    "/$name"
                }
                else {
                    "$CurrentPath/$name"
                }

                $items += [PSCustomObject]@{
                    Name            = $name
                    FullName        = $fullPath
                    IsDirectory     = $isDir
                    IsParent        = $false
                    IsDriveSelector = $false
                    Size            = if ($isDir) { "" } else { "$([int]($size/1KB)) KB" }
                    Icon            = if ($isDir) { "📁" } else { "📄" }
                }
            }
            # Formato Windows FTP: 12-13-25  12:40PM       <DIR>          Duke_3D
            # O formato Windows archivo: 12-13-25  12:40PM              1234 archivo.txt
            elseif ($line -match '^\d{2}-\d{2}-\d{2}\s+\d{1,2}:\d{2}[AP]M\s+(?:(<DIR>)|(\d+))\s+(.+)$') {
                $isDir = -not [string]::IsNullOrEmpty($matches[1])  # <DIR> capturado
                $size = if ($isDir) { 0 } else { [int]$matches[2] }
                $name = $matches[3].Trim()
                
                if ($name -eq '.' -or $name -eq '..') {
                    continue
                }

                if (-not $AllowFiles -and -not $isDir) {
                    continue
                }

                $fullPath = if ($CurrentPath -eq "/") {
                    "/$name"
                }
                else {
                    "$CurrentPath/$name"
                }

                $items += [PSCustomObject]@{
                    Name            = $name
                    FullName        = $fullPath
                    IsDirectory     = $isDir
                    IsParent        = $false
                    IsDriveSelector = $false
                    Size            = if ($isDir) { "" } else { "$([int]($size/1KB)) KB" }
                    Icon            = if ($isDir) { "📁" } else { "📄" }
                }
            }
            # Formato simple (solo nombre)
            elseif ($line -notmatch '^\s*$') {
                $name = $line.Trim()
                
                if ($name -eq '.' -or $name -eq '..') {
                    continue
                }

                $fullPath = if ($CurrentPath -eq "/") {
                    "/$name"
                }
                else {
                    "$CurrentPath/$name"
                }

                # En formato simple no podemos distinguir carpetas de archivos fácilmente
                # Asumimos que es carpeta si no tiene extensión
                $isDir = $name -notlike "*.*"

                if (-not $AllowFiles -and -not $isDir) {
                    continue
                }

                $items += [PSCustomObject]@{
                    Name            = $name
                    FullName        = $fullPath
                    IsDirectory     = $isDir
                    IsParent        = $false
                    IsDriveSelector = $false
                    Size            = ""
                    Icon            = if ($isDir) { "📁" } else { "📄" }
                }
            }
        }
    }
    catch {
        Write-Log "Error listando FTP: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        Write-Host "Error al listar directorio FTP: $($_.Exception.Message)" -ForegroundColor Red
    }

    return $items
}

function Select-FtpFolder {
    <#
    .SYNOPSIS
        Navegar y seleccionar carpeta FTP usando interfaz Navigator
    .PARAMETER Server
        Servidor FTP
    .PARAMETER Port
        Puerto FTP
    .PARAMETER Credential
        Credenciales FTP (PSCredential)
    .PARAMETER UseSsl
        Usar FTPS
    .PARAMETER Prompt
        Mensaje para el usuario
    .PARAMETER InitialPath
        Ruta inicial
    .OUTPUTS
        Ruta seleccionada o $null si se cancela
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Server,

        [int]$Port = 21,

        [PSCredential]$Credential,

        [bool]$UseSsl = $false,

        [string]$Prompt = "Seleccionar carpeta FTP",

        [string]$InitialPath = "/"
    )

    # Importar Navigator
    $navigatorPath = Join-Path (Split-Path $PSScriptRoot -Parent) "UI\Navigator.psm1"
    if (-not (Get-Module -Name Navigator)) {
        Import-Module $navigatorPath -Force -Global
    }

    # Callback para obtener items de FTP - debe aceptar parámetros que Navigator pasa
    # Usar GetNewClosure() para capturar variables del scope actual
    $getItemsCallback = {
        param(
            [string]$Path,           # Navigator pasa -Path
            [bool]$AllowFiles,       # Navigator pasa -AllowFiles
            [hashtable]$SizeCache    # Navigator pasa -SizeCache (no usado en FTP)
        )
        
        # Llamar a Get-FtpNavigatorItems con los parámetros correctos
        Get-FtpNavigatorItems -Server $Server -Port $Port -Credential $Credential `
            -CurrentPath $Path -AllowFiles $AllowFiles -UseSsl $UseSsl
    }.GetNewClosure()

    # Opciones del proveedor FTP (deshabilitar selectores locales)
    $ftpProviderOptions = @{
        AllowDriveSelector    = $false      # No mostrar F2:Unidad (es FTP, no local)
        AllowNetworkDiscovery = $false   # No mostrar F3:Red (es FTP, no UNC)
    }

    return Select-PathNavigator -Prompt $Prompt -AllowFiles:$false `
        -ItemProvider $getItemsCallback `
        -InitialPath $InitialPath `
        -ProviderOptions $ftpProviderOptions
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Test-IsFtpPath',
    'Get-FtpConfigFromUser',
    'Copy-LlevarLocalToFtp',
    'Copy-LlevarFtpToLocal',
    'Mount-FtpPath',
    'Get-FtpConnection',
    'Send-FtpFile',
    'Receive-FtpFile',
    'Get-FtpNavigatorItems',
    'Select-FtpFolder'
)
