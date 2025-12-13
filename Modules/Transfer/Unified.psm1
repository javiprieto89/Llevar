# ========================================================================== #
#                    MÓDULO: DISPATCHER UNIFICADO DE TRANSFERENCIAS          #
# ========================================================================== #
# Propósito: Orquestador inteligente que detecta todas las combinaciones posibles
# Arquitectura: Funciones públicas legibles → Dispatcher genérico → Handlers específicos
# ========================================================================== #

# Todos los módulos necesarios ya fueron importados por Llevar.ps1
# Solo verificar que TransferConfig esté disponible
$ModulesPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "Modules"
if (-not (Get-Module -Name 'TransferConfig')) {
    Import-Module (Join-Path $ModulesPath "Core\TransferConfig.psm1") -Force -Global
}

# ========================================================================== #
#                  FUNCIONES PÚBLICAS (NOMBRES DESCRIPTIVOS)                 #
# ========================================================================== #

function Copy-LlevarFiles {
    <#
    .SYNOPSIS
        Función pública principal para copiar archivos (mantiene compatibilidad)
    .DESCRIPTION
        Punto de entrada unificado que delega al dispatcher.
        Soporta tanto el formato antiguo (SourceConfig/DestinationConfig)
        como el nuevo formato (TransferConfig).
    .PARAMETER TransferConfig
        Objeto TransferConfig completo (formato nuevo recomendado)
    .PARAMETER SourceConfig
        Configuración de origen (formato legacy)
    .PARAMETER DestinationConfig
        Configuración de destino (formato legacy)
    .PARAMETER SourcePath
        Ruta de origen (opcional)
    .PARAMETER ShowProgress
        Mostrar barra de progreso
    .PARAMETER ProgressTop
        Posición Y de la barra
    .PARAMETER UseRobocopy
        Usar Robocopy para Local→Local
    .PARAMETER RobocopyMirror
        Modo mirror de Robocopy
    #>
    param(
        [Parameter(Mandatory = $true)]
        $TransferConfig,
        
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )
    
    # Delegar al dispatcher
    return Invoke-TransferDispatcher -Llevar $TransferConfig -ShowProgress $ShowProgress -ProgressTop $ProgressTop
}

function Copy-LlevarLocalToFtp {
    param([Parameter(Mandatory = $true)][TransferConfig]$Llevar)
    Invoke-TransferDispatcher -Llevar $Llevar
}

function Copy-LlevarFtpToLocal {
    param([Parameter(Mandatory = $true)][TransferConfig]$Llevar)
    Invoke-TransferDispatcher -Llevar $Llevar
}

function Copy-LlevarLocalToOneDrive {
    param([Parameter(Mandatory = $true)][TransferConfig]$Llevar)
    Invoke-TransferDispatcher -Llevar $Llevar
}

function Copy-LlevarOneDriveToLocal {
    param([Parameter(Mandatory = $true)][TransferConfig]$Llevar)
    Invoke-TransferDispatcher -Llevar $Llevar
}

function Copy-LlevarLocalToDropbox {
    param([Parameter(Mandatory = $true)][TransferConfig]$Llevar)
    Invoke-TransferDispatcher -Llevar $Llevar
}

function Copy-LlevarDropboxToLocal {
    param([Parameter(Mandatory = $true)][TransferConfig]$Llevar)
    Invoke-TransferDispatcher -Llevar $Llevar
}

# ========================================================================== #
#                  DISPATCHER GENÉRICO (CORAZÓN DEL SISTEMA)                 #
# ========================================================================== #

function Invoke-TransferDispatcher {
    <#
    .SYNOPSIS
        Dispatcher inteligente que detecta automáticamente qué ruta tomar
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Llevar,
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )

    $startTime = Get-Date

    $origen = $Llevar.Origen
    $destino = $Llevar.Destino

    $tipoOrigen = $origen.Tipo
    $tipoDestino = $destino.Tipo
    $route = "$tipoOrigen→$tipoDestino"

    Write-Log "Dispatcher: Ruta detectada = $route" "INFO"

    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Analizando ruta: $route..." -Top $ProgressTop -Width 50
    }

    try {
        $result = switch ($tipoOrigen) {
            "Local" {
                switch ($tipoDestino) {
                    "Local" { Invoke-LocalToLocal    -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "FTP" { Invoke-LocalToFtp      -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "OneDrive" { Invoke-LocalToCloud    -Llevar $Llevar -CloudType "OneDrive" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "Dropbox" { Invoke-LocalToCloud    -Llevar $Llevar -CloudType "Dropbox"  -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "UNC" { Invoke-LocalToUNC      -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "USB" { Invoke-LocalToUSB      -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "ISO" { Invoke-LocalToISO      -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "Diskette" { Invoke-LocalToDiskette -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    default {
                        $msg = "Combinación no soportada: Local→$tipoDestino"
                        Write-Log $msg "ERROR"; throw $msg
                    }
                }
            }
            "FTP" {
                switch ($tipoDestino) {
                    "Local" { Invoke-FtpToLocal  -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "FTP" { Invoke-FtpToFtp    -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "OneDrive" { Invoke-FtpToCloud  -Llevar $Llevar -CloudType "OneDrive" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "Dropbox" { Invoke-FtpToCloud  -Llevar $Llevar -CloudType "Dropbox"  -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "UNC" { Invoke-FtpToUNC    -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "USB" { Invoke-FtpToUSB    -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "ISO" { Invoke-FtpToISO    -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "Diskette" { Invoke-FtpToDiskette -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    default {
                        $msg = "Combinación no soportada: FTP→$tipoDestino"
                        Write-Log $msg "ERROR"; throw $msg
                    }
                }
            }
            "OneDrive" {
                switch ($tipoDestino) {
                    "Local" { Invoke-CloudToLocal  -Llevar $Llevar -CloudType "OneDrive" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "FTP" { Invoke-CloudToFtp    -Llevar $Llevar -CloudType "OneDrive" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "OneDrive" { Invoke-CloudToCloud  -Llevar $Llevar -SourceCloud "OneDrive" -DestCloud "OneDrive" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "Dropbox" { Invoke-CloudToCloud  -Llevar $Llevar -SourceCloud "OneDrive" -DestCloud "Dropbox"  -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "UNC" { Invoke-CloudToUNC    -Llevar $Llevar -CloudType "OneDrive" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "USB" { Invoke-CloudToUSB    -Llevar $Llevar -CloudType "OneDrive" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "ISO" { Invoke-CloudToISO    -Llevar $Llevar -CloudType "OneDrive" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "Diskette" { Invoke-CloudToDiskette -Llevar $Llevar -CloudType "OneDrive" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    default {
                        $msg = "Combinación no soportada: OneDrive→$tipoDestino"
                        Write-Log $msg "ERROR"; throw $msg
                    }
                }
            }
            "Dropbox" {
                switch ($tipoDestino) {
                    "Local" { Invoke-CloudToLocal  -Llevar $Llevar -CloudType "Dropbox" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "FTP" { Invoke-CloudToFtp    -Llevar $Llevar -CloudType "Dropbox" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "OneDrive" { Invoke-CloudToCloud  -Llevar $Llevar -SourceCloud "Dropbox" -DestCloud "OneDrive" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "Dropbox" { Invoke-CloudToCloud  -Llevar $Llevar -SourceCloud "Dropbox" -DestCloud "Dropbox"  -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "UNC" { Invoke-CloudToUNC    -Llevar $Llevar -CloudType "Dropbox" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "USB" { Invoke-CloudToUSB    -Llevar $Llevar -CloudType "Dropbox" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "ISO" { Invoke-CloudToISO    -Llevar $Llevar -CloudType "Dropbox" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "Diskette" { Invoke-CloudToDiskette -Llevar $Llevar -CloudType "Dropbox" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    default {
                        $msg = "Combinación no soportada: Dropbox→$tipoDestino"
                        Write-Log $msg "ERROR"; throw $msg
                    }
                }
            }
            "UNC" {
                switch ($tipoDestino) {
                    "Local" { Invoke-UNCToLocal -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "FTP" { Invoke-UNCToFtp   -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "OneDrive" { Invoke-UNCToCloud -Llevar $Llevar -CloudType "OneDrive" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "Dropbox" { Invoke-UNCToCloud -Llevar $Llevar -CloudType "Dropbox"  -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "UNC" { Invoke-UNCToUNC   -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "USB" { Invoke-UNCToUSB   -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "ISO" { Invoke-UNCToISO   -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "Diskette" { Invoke-UNCToDiskette -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    default {
                        $msg = "Combinación no soportada: UNC→$tipoDestino"
                        Write-Log $msg "ERROR"; throw $msg
                    }
                }
            }
            "Diskette" {
                switch ($tipoDestino) {
                    "Diskette" { Invoke-DisketteToDiskette -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "Local" { Invoke-DisketteToLocal -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "FTP" { Invoke-DisketteToFtp -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "UNC" { Invoke-DisketteToUNC -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "Dropbox" { Invoke-DisketteToCloud -Llevar $Llevar -CloudType "Dropbox" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "OneDrive" { Invoke-DisketteToCloud -Llevar $Llevar -CloudType "OneDrive" -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    "ISO" { Invoke-DisketteToISO -Llevar $Llevar -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $startTime }
                    default {
                        $msg = "Combinación no soportada: Diskette→$tipoDestino"
                        Write-Log $msg "ERROR"; throw $msg
                    }
                }
            }
            default {
                $errorMsg = "Tipo de origen no soportado en dispatcher: $tipoOrigen"
                Write-Log $errorMsg "ERROR"
                throw $errorMsg
            }
        }

        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 100 -StartTime $startTime -Label "Transferencia completada" -Top $ProgressTop -Width 50
        }

        Write-Log "Dispatcher: Ruta $route completada en $([math]::Round(((Get-Date) - $startTime).TotalSeconds, 2))s" "INFO"
        return $result
    }
    catch {
        Write-Log "Dispatcher: Error en ruta $route - $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        throw
    }
}


# ========================================================================== #
#                  HANDLERS ESPECÍFICOS (FUNCIONES INTERNAS)                 #
# ========================================================================== #

function Invoke-LocalToLocal {
    param([TransferConfig]$Llevar, [bool]$ShowProgress, [int]$ProgressTop, [datetime]$StartTime)
    
    Write-Log "Handler: Local→Local" "INFO"
    
    $sourcePath = $Llevar.Origen.Local.Path
    $destPath = $Llevar.Destino.Local.Path
    $useMirror = $Llevar.Opciones.RobocopyMirror
    
    Copy-LlevarLocalToLocalRobocopy -SourcePath $sourcePath -DestinationPath $destPath `
        -UseMirror $useMirror -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $StartTime
    
    return @{ Success = $true; Route = "Local→Local" }
}

function Invoke-LocalToFtp {
    <#
    .SYNOPSIS
        Handler: Local→FTP (sube archivos locales a servidor FTP)
    #>
    param(
        [TransferConfig]$Llevar,
        [bool]$ShowProgress,
        [int]$ProgressTop,
        [datetime]$StartTime
    )
    
    Write-Log "Handler: Local→FTP" "INFO"
    
    # Obtener origen local
    $sourcePath = Get-TransferPath -Config $Llevar -Section "Origen"
    if ($Llevar.Origen.Tipo -ne "Local") {
        throw "Origen no es Local"
    }
    
    if (-not $sourcePath -or -not (Test-Path $sourcePath)) {
        throw "Local→FTP: Origen no válido o inexistente: '$sourcePath'"
    }
    
    # Obtener configuración FTP destino
    $ftpConfig = [PSCustomObject]@{
        Server    = $null
        Port      = 21
        User      = $null
        Password  = $null
        Directory = "/"
        UseSsl    = $false
    }

    $ftpConfig.Server = Get-TransferConfigValue -Config $Llevar -Path "Destino.FTP.Server"
    $ftpPort = Get-TransferConfigValue -Config $Llevar -Path "Destino.FTP.Port"
    $ftpConfig.Port = if ($ftpPort -gt 0) { $ftpPort } else { 21 }
    $ftpConfig.User = Get-TransferConfigValue -Config $Llevar -Path "Destino.FTP.User"
    $ftpConfig.Password = Get-TransferConfigValue -Config $Llevar -Path "Destino.FTP.Password"
    $ftpDirectory = Get-TransferConfigValue -Config $Llevar -Path "Destino.FTP.Directory"
    $ftpConfig.Directory = if ($ftpDirectory) { $ftpDirectory } else { "/" }
    $ftpConfig.UseSsl = Get-TransferConfigValue -Config $Llevar -Path "Destino.FTP.UseSsl"

    if (-not $ftpConfig.Server -or -not $ftpConfig.User) {
        throw "Local→FTP: Configuración FTP incompleta (falta Server o User)"
    }

    # Normalizar servidor (agregar protocolo si falta)
    if ($ftpConfig.Server -notlike "ftp://*" -and $ftpConfig.Server -notlike "ftps://*") {
        $ftpConfig.Server = if ($ftpConfig.UseSsl) { "ftps://$($ftpConfig.Server)" } else { "ftp://$($ftpConfig.Server)" }
    }

    # Normalizar directorio (asegurar que comienza con /)
    if (-not $ftpConfig.Directory.StartsWith('/')) {
        $ftpConfig.Directory = "/$($ftpConfig.Directory)"
    }

    if ($ftpConfig.Password -is [System.Security.SecureString]) {
        $ftpConfig.SecurePassword = $ftpConfig.Password
    }
    elseif ($ftpConfig.Password) {
        $ftpConfig.SecurePassword = ConvertTo-SecureString -String $ftpConfig.Password -AsPlainText -Force
    }
    else {
        $ftpConfig.SecurePassword = $null
    }
    
    Write-Log "Local→FTP: $sourcePath → $($ftpConfig.Server)$($ftpConfig.Directory)" "INFO"
    
    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 0 -StartTime $StartTime -Label "Subiendo a FTP..." -Top $ProgressTop -Width 50
    }
    
    # Función auxiliar para subir un archivo
    function Send-LlevarFtpFile {
        param(
            [Parameter(Mandatory = $true)]
            [string]$LocalPath,
            [Parameter(Mandatory = $true)]
            [string]$RemotePath,
            [Parameter(Mandatory = $true)]
            [pscustomobject]$Config
        )

        try {
            $uri = [uri]"$($Config.Server)$RemotePath"
            $request = [System.Net.FtpWebRequest]::Create($uri)
            $request.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
            $request.Credentials = New-Object System.Net.NetworkCredential($Config.User, $Config.SecurePassword)
            $request.UsePassive = $true
            $request.UseBinary = $true
            $request.KeepAlive = $false

            if ($Config.UseSsl) {
                $request.EnableSsl = $true
            }

            $fileContent = [System.IO.File]::ReadAllBytes($LocalPath)
            $request.ContentLength = $fileContent.Length

            $requestStream = $request.GetRequestStream()
            $requestStream.Write($fileContent, 0, $fileContent.Length)
            $requestStream.Close()

            $response = $request.GetResponse()
            $response.Close()

            return $true
        }
        catch {
            Write-Log "Error subiendo $LocalPath a FTP: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
            return $false
        }
    }

    # Función auxiliar para crear directorio en FTP
    function New-LlevarFtpDirectory {
        param(
            [Parameter(Mandatory = $true)]
            [string]$RemotePath,
            [Parameter(Mandatory = $true)]
            [pscustomobject]$Config
        )

        try {
            $uri = [uri]"$($Config.Server)$RemotePath"
            $request = [System.Net.FtpWebRequest]::Create($uri)
            $request.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
            $request.Credentials = New-Object System.Net.NetworkCredential($Config.User, $Config.SecurePassword)
            $request.UsePassive = $true

            if ($Config.UseSsl) {
                $request.EnableSsl = $true
            }

            $response = $request.GetResponse()
            $response.Close()
            return $true
        }
        catch {
            # Si el directorio ya existe, ignorar el error
            if ($_.Exception.Message -match "already exists|550") {
                return $true
            }
            return $false
        }
    }
    
    # Asegurar que el directorio destino existe
    New-LlevarFtpDirectory -RemotePath $ftpConfig.Directory -Config $ftpConfig | Out-Null
    
    # Obtener todos los archivos a subir
    $files = @()
    if (Test-Path $sourcePath -PathType Container) {
        $files = Get-ChildItem -Path $sourcePath -Recurse -File
    }
    else {
        $files = @(Get-Item $sourcePath)
    }
    
    $totalFiles = $files.Count
    $uploadedFiles = 0
    
    # Subir cada archivo
    foreach ($file in $files) {
        $relativePath = if (Test-Path $sourcePath -PathType Container) {
            $file.FullName.Substring($sourcePath.Length).TrimStart('\').Replace('\', '/')
        }
        else {
            $file.Name
        }
        
        $remotePath = "$($ftpConfig.Directory)/$relativePath".Replace('//', '/')
        
        # Crear directorios padre si es necesario
        $remoteDir = Split-Path $remotePath -Parent
        if ($remoteDir -and $remoteDir -ne $ftpConfig.Directory) {
            $dirParts = $remoteDir.Replace($ftpConfig.Directory, '').TrimStart('/').Split('/')
            $currentDir = $ftpConfig.Directory
            foreach ($dirPart in $dirParts) {
                if ($dirPart) {
                    $currentDir = "$currentDir/$dirPart".Replace('//', '/')
                    New-LlevarFtpDirectory -RemotePath $currentDir -Config $ftpConfig | Out-Null
                }
            }
        }
        
        if ($ShowProgress) {
            $percent = [Math]::Min(99, ($uploadedFiles * 100 / $totalFiles))
            Write-LlevarProgressBar -Percent $percent -StartTime $StartTime -Label "Subiendo: $($file.Name)..." -Top $ProgressTop -Width 50
        }
        
        $success = Send-LlevarFtpFile -LocalPath $file.FullName -RemotePath $remotePath `
            -Config $ftpConfig
        
        if (-not $success) {
            throw "Error al subir archivo: $($file.Name)"
        }
        
        $uploadedFiles++
        Write-Log "Archivo subido: $($file.Name) → $remotePath" "INFO"
    }
    
    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 100 -StartTime $StartTime -Label "Subida a FTP completada" -Top $ProgressTop -Width 50
    }
    
    Write-Log "Local→FTP: $uploadedFiles archivos subidos exitosamente" "INFO"
    
    return @{ Success = $true; Route = "Local→FTP"; FilesUploaded = $uploadedFiles }
}

function Invoke-LocalToCloud {
    <#
    .SYNOPSIS
        Handler: Local→OneDrive/Dropbox (sube archivos locales a servicio cloud)
    #>
    param(
        [TransferConfig]$Llevar,
        [string]$CloudType,
        [bool]$ShowProgress,
        [int]$ProgressTop,
        [datetime]$StartTime
    )
    
    Write-Log "Handler: Local→${CloudType}" "INFO"
    
    # Obtener origen local
    $sourcePath = Get-TransferPath -Config $Llevar -Section "Origen"
    if ($Llevar.Origen.Tipo -ne "Local") {
        throw "Origen no es Local"
    }
    
    if (-not $sourcePath -or -not (Test-Path $sourcePath)) {
        throw "Local→${CloudType}: Origen no válido o inexistente: '$sourcePath'"
    }
    
    # Obtener configuración cloud destino
    $cloudPath = $null
    if ($CloudType -eq "OneDrive") {
        $cloudPath = Get-TransferConfigValue -Config $Llevar -Path "Destino.OneDrive.Path"
        if (-not $cloudPath) {
            $cloudPath = "/"
        }
    }
    elseif ($CloudType -eq "Dropbox") {
        $cloudPath = Get-TransferConfigValue -Config $Llevar -Path "Destino.Dropbox.Path"
        if (-not $cloudPath) {
            $cloudPath = "/"
        }
    }
    else {
        throw "Local→${CloudType}: Tipo de cloud no soportado: ${CloudType}"
    }
    
    # Normalizar ruta cloud (asegurar que comienza con /)
    if (-not $cloudPath.StartsWith('/')) {
        $cloudPath = "/$cloudPath"
    }
    
    Write-Log "Local→${CloudType}: $sourcePath → $cloudPath" "INFO"
    
    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 0 -StartTime $StartTime -Label "Subiendo a ${CloudType}..." -Top $ProgressTop -Width 50
    }
    
    # Módulos OneDrive/Dropbox ya fueron importados por Llevar.ps1
    
    # Obtener todos los archivos a subir
    $files = @()
    if (Test-Path $sourcePath -PathType Container) {
        $files = Get-ChildItem -Path $sourcePath -Recurse -File
    }
    else {
        $files = @(Get-Item $sourcePath)
    }
    
    $totalFiles = $files.Count
    $uploadedFiles = 0
    
    # Subir cada archivo
    foreach ($file in $files) {
        $relativePath = if (Test-Path $sourcePath -PathType Container) {
            $file.FullName.Substring($sourcePath.Length).TrimStart('\').Replace('\', '/')
        }
        else {
            $file.Name
        }
        
        $remotePath = "$cloudPath/$relativePath".Replace('//', '/')
        
        if ($ShowProgress) {
            $percent = [Math]::Min(99, ($uploadedFiles * 100 / $totalFiles))
            Write-LlevarProgressBar -Percent $percent -StartTime $StartTime -Label "Subiendo: $($file.Name)..." -Top $ProgressTop -Width 50
        }
        
        try {
            if ($CloudType -eq "OneDrive") {
                Send-LlevarOneDriveFile -Llevar $Llevar -LocalPath $file.FullName -RemotePath $remotePath
            }
            elseif ($CloudType -eq "Dropbox") {
                Send-LlevarDropboxFile -Llevar $Llevar -LocalPath $file.FullName -RemotePath $remotePath
            }
            
            $uploadedFiles++
            Write-Log "Archivo subido: $($file.Name) → $remotePath" "INFO"
        }
        catch {
            Write-Log "Error subiendo $($file.Name) a ${CloudType}: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
            throw "Error al subir archivo: $($file.Name) - $($_.Exception.Message)"
        }
    }
    
    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 100 -StartTime $StartTime -Label "Subida a $CloudType completada" -Top $ProgressTop -Width 50
    }
    
    Write-Log "Local→${CloudType}: $uploadedFiles archivos subidos exitosamente" "INFO"
    
    return @{ Success = $true; Route = "Local→${CloudType}"; FilesUploaded = $uploadedFiles }
}

function Invoke-FtpToLocal {
    param([TransferConfig]$Llevar, [bool]$ShowProgress, [int]$ProgressTop, [datetime]$StartTime)
    
    Write-Log "Handler: FTP→Local (descarga recursiva)" "INFO"
    
    # Obtener configuración FTP
    $ftpServer = $Llevar.Origen.FTP.Server
    $ftpPort = $Llevar.Origen.FTP.Port
    $ftpDirectory = $Llevar.Origen.FTP.Directory
    $ftpCredentials = $Llevar.Origen.FTP.Credentials
    $ftpUseSsl = $Llevar.Origen.FTP.UseSsl
    
    # Obtener configuración destino local
    $localPath = $Llevar.Destino.Local.Path
    
    if (-not (Test-Path $localPath)) {
        New-Item -Type Directory -Path $localPath -Force | Out-Null
        Write-Log "Carpeta destino creada: $localPath" "INFO"
    }
    
    Write-Log "FTP→Local: Descargando de $ftpServer$ftpDirectory a $localPath" "INFO"
    
    # Helper para descargar un archivo FTP
    function Receive-SingleFtpFile {
        param(
            [string]$FtpUrl,
            [PSCredential]$Credentials,
            [string]$LocalFilePath,
            [bool]$UseSsl
        )
        
        $request = [System.Net.FtpWebRequest]::Create($FtpUrl)
        $request.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
        $request.Credentials = $Credentials.GetNetworkCredential()
        $request.UseBinary = $true
        $request.UsePassive = $true
        
        if ($UseSsl) {
            $request.EnableSsl = $true
        }
        
        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        
        $fileStream = [System.IO.File]::Create($LocalFilePath)
        $buffer = New-Object byte[] 8192
        
        do {
            $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
            $fileStream.Write($buffer, 0, $bytesRead)
        } while ($bytesRead -gt 0)
        
        $fileStream.Close()
        $stream.Close()
        $response.Close()
    }
    
    # Función recursiva para descargar carpetas FTP
    function Receive-FtpFolder {
        param(
            [string]$FtpPath,
            [string]$LocalDestination
        )
        
        # Obtener items del directorio FTP actual
        $items = Get-FtpNavigatorItems -Server $ftpServer -Port $ftpPort `
            -Credential $ftpCredentials -CurrentPath $FtpPath `
            -AllowFiles $true -UseSsl $ftpUseSsl
        
        foreach ($item in $items) {
            # Saltar item ".."
            if ($item.IsParent) {
                continue
            }
            
            $localItemPath = Join-Path $LocalDestination $item.Name
            
            if ($item.IsDirectory) {
                # Crear carpeta local
                if (-not (Test-Path $localItemPath)) {
                    New-Item -Type Directory -Path $localItemPath -Force | Out-Null
                }
                
                # Recursión para subcarpetas
                Receive-FtpFolder -FtpPath $item.FullName -LocalDestination $localItemPath
            }
            else {
                # Descargar archivo
                if ($ShowProgress) {
                    Write-LlevarProgressBar -Percent 50 -StartTime $StartTime `
                        -Label "Descargando: $($item.Name)..." -Top $ProgressTop -Width 50
                }
                
                try {
                    # Construir URL FTP completa
                    $ftpFileUrl = "$ftpServer$($item.FullName)"
                    
                    Receive-SingleFtpFile -FtpUrl $ftpFileUrl `
                        -Credentials $ftpCredentials `
                        -LocalFilePath $localItemPath `
                        -UseSsl $ftpUseSsl
                    
                    Write-Log "Archivo descargado: $($item.Name)" "INFO"
                }
                catch {
                    Write-Log "Error descargando $($item.Name): $($_.Exception.Message)" "ERROR" -ErrorRecord $_
                    throw
                }
            }
        }
    }
    
    # Iniciar descarga recursiva
    Receive-FtpFolder -FtpPath $ftpDirectory -LocalDestination $localPath
    
    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 100 -StartTime $StartTime `
            -Label "Descarga FTP completada" -Top $ProgressTop -Width 50
    }
    
    Write-Log "FTP→Local: Descarga completada exitosamente" "INFO"
    
    return @{ Success = $true; Route = "FTP→Local"; Downloaded = $true }
}

function Invoke-FtpToFtp {
    param([TransferConfig]$Llevar, [bool]$ShowProgress, [int]$ProgressTop, [datetime]$StartTime)
    
    Write-Log "Handler: FTP→FTP (vía temporal)" "INFO"
    
    $tempPath = Join-Path $env:TEMP "LLEVAR_FTP_BRIDGE_$(Get-Date -Format 'yyyyMMddHHmmss')"
    try {
        New-Item -Type Directory $tempPath | Out-Null
        
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 25 -StartTime $StartTime -Label "Descargando FTP origen..." -Top $ProgressTop -Width 50
        }
        
        # TODO: Descargar de FTP origen
        
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 75 -StartTime $StartTime -Label "Subiendo a FTP destino..." -Top $ProgressTop -Width 50
        }
        
        # TODO: Subir a FTP destino
        
        throw "FTP→FTP: Implementación pendiente"
    }
    finally {
        Remove-Item $tempPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-CloudToLocal {
    param([TransferConfig]$Llevar, [string]$CloudType, [bool]$ShowProgress, [int]$ProgressTop, [datetime]$StartTime)
    Write-Log "Handler: ${CloudType}→Local (en desarrollo)" "WARNING"
    throw "${CloudType}→Local: Implementación pendiente"
}

function Invoke-CloudToCloud {
    param([TransferConfig]$Llevar, [string]$SourceCloud, [string]$DestCloud, [bool]$ShowProgress, [int]$ProgressTop, [datetime]$StartTime)
    
    Write-Log "Handler: ${SourceCloud}→${DestCloud} (vía temporal)" "INFO"
    
    $tempPath = Join-Path $env:TEMP "LLEVAR_CLOUD_BRIDGE_$(Get-Date -Format 'yyyyMMddHHmmss')"
    try {
        New-Item -Type Directory $tempPath | Out-Null
        
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 33 -StartTime $StartTime -Label "Descargando de $SourceCloud..." -Top $ProgressTop -Width 50
        }
        
        # TODO: Descargar de origen
        
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 67 -StartTime $StartTime -Label "Subiendo a $DestCloud..." -Top $ProgressTop -Width 50
        }
        
        # TODO: Subir a destino
        
        throw "${SourceCloud}→${DestCloud}: Implementación pendiente"
    }
    finally {
        Remove-Item $tempPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-LocalToUNC {
    <#
    .SYNOPSIS
        Handler: Local→UNC (copia archivos locales a ruta UNC de red)
    #>
    param(
        [TransferConfig]$Llevar,
        [bool]$ShowProgress,
        [int]$ProgressTop,
        [datetime]$StartTime
    )
    
    Write-Log "Handler: Local→UNC" "INFO"
    
    # Obtener origen local
    $sourcePath = Get-TransferPath -Config $Llevar -Section "Origen"
    if ($Llevar.Origen.Tipo -ne "Local") {
        throw "Origen no es Local"
    }
    
    if (-not $sourcePath -or -not (Test-Path $sourcePath)) {
        throw "Local→UNC: Origen no válido o inexistente: '$sourcePath'"
    }
    
    # Obtener destino UNC
    $destPath = Get-TransferPath -Config $Llevar -Section "Destino"
    if ($Llevar.Destino.Tipo -ne "UNC") {
        throw "Destino no es UNC"
    }
    
    if (-not $destPath) {
        throw "Local→UNC: Ruta destino UNC no especificada"
    }
    
    Write-Log "Local→UNC: $sourcePath → $destPath" "INFO"
    
    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 0 -StartTime $StartTime -Label "Copiando a UNC..." -Top $ProgressTop -Width 50
    }
    
    # Montar UNC si es necesario
    $destDrive = "LLEVAR_LOCAL_UNC"
    $credDestino = $null
    if ($Llevar.Destino.UNC.Credentials) {
        $credDestino = $Llevar.Destino.UNC.Credentials
    }
    
    $destinoMontado = Mount-LlevarNetworkPath -Path $destPath -Credential $credDestino -DriveName $destDrive
    
    try {
        # Usar Robocopy para copiar (más eficiente para UNC)
        $useMirror = $Llevar.Opciones.RobocopyMirror
        
        # Módulo Local.psm1 ya fue importado por Llevar.ps1
        
        Copy-LlevarLocalToLocalRobocopy -SourcePath $sourcePath -DestinationPath $destinoMontado `
            -UseMirror $useMirror -ShowProgress $ShowProgress -ProgressTop $ProgressTop -StartTime $StartTime
        
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 100 -StartTime $StartTime -Label "Copia a UNC completada" -Top $ProgressTop -Width 50
        }
        
        Write-Log "Local→UNC: Copia completada exitosamente" "INFO"
        
        return @{ Success = $true; Route = "Local→UNC" }
    }
    finally {
        # Desmontar UNC
        if ($destDrive -and (Get-PSDrive -Name $destDrive -ErrorAction SilentlyContinue)) {
            Remove-PSDrive -Name $destDrive -Force -ErrorAction SilentlyContinue
        }
    }
}
function Invoke-LocalToUSB { param($Llevar, $ShowProgress, $ProgressTop, $StartTime); throw "Local→USB: En desarrollo" }
function Invoke-LocalToISO {
    <#
    .SYNOPSIS
        Handler: Local→ISO (crea imagen ISO desde archivos locales)
    #>
    param(
        [TransferConfig]$Llevar,
        [bool]$ShowProgress,
        [int]$ProgressTop,
        [datetime]$StartTime
    )
    
    Write-Log "Handler: Local→ISO" "INFO"
    
    # Obtener origen local
    $sourcePath = Get-TransferPath -Config $Llevar -Section "Origen"
    if ($Llevar.Origen.Tipo -ne "Local") {
        throw "Origen no es Local"
    }
    
    if (-not $sourcePath -or -not (Test-Path $sourcePath)) {
        throw "Local→ISO: Origen no válido o inexistente: '$sourcePath'"
    }
    
    # Obtener configuración ISO destino
    $isoOutputPath = Get-TransferConfigValue -Config $Llevar -Path "Destino.ISO.OutputPath"
    $isoSizeValue = Get-TransferConfigValue -Config $Llevar -Path "Destino.ISO.Size"
    $isoSize = if ($isoSizeValue) { $isoSizeValue } else { "dvd" }
    
    if (-not $isoOutputPath) {
        # Si no hay ruta de salida, usar el directorio del origen
        $isoOutputPath = Split-Path $sourcePath -Parent
        if (-not $isoOutputPath) {
            $isoOutputPath = $PSScriptRoot
        }
    }
    
    # Asegurar que el directorio de salida existe
    if (-not (Test-Path $isoOutputPath -PathType Container)) {
        New-Item -ItemType Directory -Path $isoOutputPath -Force | Out-Null
    }
    
    Write-Log "Local→ISO: $sourcePath → $isoOutputPath" "INFO"
    
    if ($ShowProgress) {
        Write-LlevarProgressBar -Percent 0 -StartTime $StartTime -Label "Generando ISO..." -Top $ProgressTop -Width 50
    }
    
    # Módulos ISO y SevenZip ya fueron importados por Llevar.ps1
    
    # Obtener 7-Zip
    $sevenZ = Get-SevenZipLlevar
    if (-not $sevenZ -or $sevenZ -eq "NATIVE_ZIP") {
        $sevenZ = "NATIVE_ZIP"
    }
    
    # Obtener contraseña si existe
    $password = $Llevar.Opciones.Clave
    if ([string]::IsNullOrWhiteSpace($password)) {
        $password = $null
    }
    
    # Obtener tamaño de bloque si existe
    $blockSizeMB = $Llevar.Opciones.BlockSizeMB
    if ($blockSizeMB -le 0) {
        $blockSizeMB = 0  # Usar valor por defecto
    }
    
    # Determinar tipo de ISO según tamaño
    $isoDestino = switch ($isoSize.ToLower()) {
        "cd" { "cd" }
        "dvd" { "dvd" }
        "usb" { "usb" }
        default { "dvd" }
    }
    
    # Crear directorio temporal
    $tempDir = Join-Path $env:TEMP "LLEVAR_ISO_TEMP_$(Get-Date -Format 'yyyyMMddHHmmss')"
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    try {
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 25 -StartTime $StartTime -Label "Comprimiendo archivos..." -Top $ProgressTop -Width 50
        }
        
        # Llamar a New-LlevarIsoMain que maneja compresión y creación de ISO
        New-LlevarIsoMain -Origen $sourcePath -Destino $isoOutputPath -Temp $tempDir `
            -SevenZ $sevenZ -BlockSizeMB $blockSizeMB -Clave $password -IsoDestino $isoDestino
        
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 100 -StartTime $StartTime -Label "ISO generado exitosamente" -Top $ProgressTop -Width 50
        }
        
        Write-Log "Local→ISO: Imagen ISO generada exitosamente en $isoOutputPath" "INFO"
        
        return @{ Success = $true; Route = "Local→ISO"; OutputPath = $isoOutputPath }
    }
    catch {
        Write-Log "Error generando ISO: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        throw "Error al generar imagen ISO: $($_.Exception.Message)"
    }
    finally {
        # Limpiar directorio temporal
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
function Invoke-LocalToDiskette {
    param(
        [TransferConfig]$Llevar,
        [bool]$ShowProgress,
        [int]$ProgressTop,
        [datetime]$StartTime
    )

    Write-Log "Handler: Local→Diskette (via Copy-ToFloppyDisks)" "INFO"

    # Origen local desde TransferConfig
    $sourcePath = $Llevar.Origen.Local.Path

    if (-not $sourcePath -or -not (Test-Path $sourcePath)) {
        throw "Local→Diskette: Origen no válido o inexistente: '$sourcePath'"
    }

    $tempDir = $Llevar.Destino.Diskette.OutputPath
    if (-not $tempDir) {
        $tempDir = Join-Path $env:TEMP "LLEVAR_FLOPPY"
    }

    $password = $Llevar.Opciones.Clave

    $ok = Copy-ToFloppyDisks -SourcePath $sourcePath -TempDir $tempDir -SevenZPath $null -Password $password -VerifyDisks

    if (-not $ok) {
        throw "Local→Diskette: error durante la copia a diskettes"
    }

    return @{
        Success = $true
        Route   = "Local→Diskette"
    }
}

function Invoke-FtpToCloud { param($Llevar, $CloudType, $ShowProgress, $ProgressTop, $StartTime); throw "FTP→${CloudType}: En desarrollo" }
function Invoke-FtpToUNC { param($Llevar, $ShowProgress, $ProgressTop, $StartTime); throw "FTP→UNC: En desarrollo" }
function Invoke-FtpToUSB { param($Llevar, $ShowProgress, $ProgressTop, $StartTime); throw "FTP→USB: En desarrollo" }
function Invoke-FtpToISO { param($Llevar, $ShowProgress, $ProgressTop, $StartTime); throw "FTP→ISO: En desarrollo" }
function Invoke-FtpToDiskette { param($Llevar, $ShowProgress, $ProgressTop, $StartTime); throw "FTP→Diskette: En desarrollo" }
function Invoke-CloudToFtp { param($Llevar, $CloudType, $ShowProgress, $ProgressTop, $StartTime); throw "${CloudType}→FTP: En desarrollo" }
function Invoke-CloudToUNC { param($Llevar, $CloudType, $ShowProgress, $ProgressTop, $StartTime); throw "${CloudType}→UNC: En desarrollo" }
function Invoke-CloudToUSB { param($Llevar, $CloudType, $ShowProgress, $ProgressTop, $StartTime); throw "${CloudType}→USB: En desarrollo" }
function Invoke-CloudToISO { param($Llevar, $CloudType, $ShowProgress, $ProgressTop, $StartTime); throw "${CloudType}→ISO: En desarrollo" }
function Invoke-CloudToDiskette { param($Llevar, $CloudType, $ShowProgress, $ProgressTop, $StartTime); throw "${CloudType}→Diskette: En desarrollo" }
function Invoke-UNCToLocal { param($Llevar, $ShowProgress, $ProgressTop, $StartTime); throw "UNC→Local: En desarrollo" }
function Invoke-UNCToFtp { param($Llevar, $ShowProgress, $ProgressTop, $StartTime); throw "UNC→FTP: En desarrollo" }
function Invoke-UNCToCloud { param($Llevar, $CloudType, $ShowProgress, $ProgressTop, $StartTime); throw "UNC→${CloudType}: En desarrollo" }
function Invoke-UNCToUNC { param($Llevar, $ShowProgress, $ProgressTop, $StartTime); throw "UNC→UNC: En desarrollo" }
function Invoke-UNCToUSB { param($Llevar, $ShowProgress, $ProgressTop, $StartTime); throw "UNC→USB: En desarrollo" }
function Invoke-UNCToISO { param($Llevar, $ShowProgress, $ProgressTop, $StartTime); throw "UNC→ISO: En desarrollo" }
function Invoke-UNCToDiskette { param($Llevar, $ShowProgress, $ProgressTop, $StartTime); throw "UNC→Diskette: En desarrollo" }

# ========================================================================== #
#                  HANDLERS DISKETTE→* (ORIGEN DISKETTE)                      #
# ========================================================================== #

function Invoke-DisketteToDiskette {
    <#
    .SYNOPSIS
        Handler: Diskette→Diskette (copia directa entre diskettes)
    #>
    param(
        [TransferConfig]$Llevar,
        [bool]$ShowProgress,
        [int]$ProgressTop,
        [datetime]$StartTime
    )
    
    $msg = "Origen Diskette no soportado: para restaurar desde diskettes use INSTALAR.BAT desde el diskette 1 (restauración legacy fuera del dispatcher)."
    Write-Log $msg "WARNING"
    throw $msg
}

function Invoke-DisketteToLocal {
    <#
    .SYNOPSIS
        Handler: Diskette→Local
    #>
    param(
        [TransferConfig]$Llevar,
        [bool]$ShowProgress,
        [int]$ProgressTop,
        [datetime]$StartTime
    )
    
    $msg = "Origen Diskette no soportado: para restaurar desde diskettes use INSTALAR.BAT desde el diskette 1 (restauración legacy fuera del dispatcher)."
    Write-Log $msg "WARNING"
    throw $msg
}

function Invoke-DisketteToFtp {
    <#
    .SYNOPSIS
        Handler: Diskette→FTP
    #>
    param(
        [TransferConfig]$Llevar,
        [bool]$ShowProgress,
        [int]$ProgressTop,
        [datetime]$StartTime
    )
    
    $msg = "Origen Diskette no soportado: para restaurar desde diskettes use INSTALAR.BAT desde el diskette 1 (restauración legacy fuera del dispatcher)."
    Write-Log $msg "WARNING"
    throw $msg
}

function Invoke-DisketteToUNC {
    <#
    .SYNOPSIS
        Handler: Diskette→UNC
    #>
    param(
        [TransferConfig]$Llevar,
        [bool]$ShowProgress,
        [int]$ProgressTop,
        [datetime]$StartTime
    )
    
    $msg = "Origen Diskette no soportado: para restaurar desde diskettes use INSTALAR.BAT desde el diskette 1 (restauración legacy fuera del dispatcher)."
    Write-Log $msg "WARNING"
    throw $msg
}

function Invoke-DisketteToCloud {
    <#
    .SYNOPSIS
        Handler: Diskette→OneDrive/Dropbox
    #>
    param(
        [TransferConfig]$Llevar,
        [string]$CloudType,
        [bool]$ShowProgress,
        [int]$ProgressTop,
        [datetime]$StartTime
    )
    
    $msg = "Origen Diskette no soportado: para restaurar desde diskettes use INSTALAR.BAT desde el diskette 1 (restauración legacy fuera del dispatcher)."
    Write-Log $msg "WARNING"
    throw $msg
}

function Invoke-DisketteToISO {
    <#
    .SYNOPSIS
        Handler: Diskette→ISO
    #>
    param(
        [TransferConfig]$Llevar,
        [bool]$ShowProgress,
        [int]$ProgressTop,
        [datetime]$StartTime
    )
    
    $msg = "Origen Diskette no soportado: para restaurar desde diskettes use INSTALAR.BAT desde el diskette 1 (restauración legacy fuera del dispatcher)."
    Write-Log $msg "WARNING"
    throw $msg
}

# Exportar funciones PÚBLICAS solamente
Export-ModuleMember -Function Copy-LlevarFiles, Copy-LlevarLocalToFtp, Copy-LlevarFtpToLocal, Copy-LlevarLocalToOneDrive, Copy-LlevarOneDriveToLocal, Copy-LlevarLocalToDropbox, Copy-LlevarDropboxToLocal
