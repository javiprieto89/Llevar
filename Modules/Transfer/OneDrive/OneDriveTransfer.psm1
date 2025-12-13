# ========================================================================== #
#                    MÓDULO: TRANSFERENCIA ONEDRIVE                          #
# ========================================================================== #
# Propósito: Operaciones de transferencia y helpers para navegación         #
# Funciones principales:                                                     #
#   - Send-OneDriveFile / Receive-OneDriveFile: Subir/Descargar archivos    #
#   - Get-OneDriveNavigatorItems: Helper para Navigator genérico            #
#   - Get-OneDriveFolderSize: Cálculo recursivo de tamaño de carpetas       #
#   - Copy-LlevarLocalToOneDrive / Copy-LlevarOneDriveToLocal               #
# ========================================================================== #

# Imports necesarios
$ModulesPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ModulesPath "UI\Banners.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "UI\Navigator.psm1") -Force -Global
if (-not (Get-Module -Name 'TransferConfig')) {
    Import-Module (Join-Path $ModulesPath "Core\TransferConfig.psm1") -Force -Global
}
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "System\FileSystem.psm1") -Force -Global

# Importar módulo de autenticación
$authModulePath = Join-Path $PSScriptRoot "OneDriveAuth.psm1"
Import-Module $authModulePath -Force -Global

# ========================================================================== #
# FUNCIONES AUXILIARES
# ========================================================================== #

function Test-IsOneDrivePath {
    <#
    .SYNOPSIS
        Detecta si una ruta es OneDrive
    #>
    param([string]$Path)
    return $Path -match '^onedrive://|^ONEDRIVE:'
}

function Invoke-OneDriveApiCall {
    <#
    .SYNOPSIS
        Ejecuta una llamada a Microsoft Graph API con manejo automático de token expirado
    .PARAMETER Uri
        URL de la API a llamar
    .PARAMETER Token
        Token de acceso actual
    .PARAMETER RefreshToken
        Token para refrescar si es necesario
    .PARAMETER Method
        Método HTTP (Get, Post, Put, Delete, etc.)
    .PARAMETER Body
        Cuerpo de la solicitud (opcional)
    .PARAMETER Headers
        Headers adicionales (además de Authorization)
    .OUTPUTS
        Respuesta de la API o $null si falla
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [string]$RefreshToken,
        [string]$Method = "Get",
        [object]$Body,
        [hashtable]$Headers = @{}
    )

    $maxRetries = 2
    $attempt = 0

    while ($attempt -lt $maxRetries) {
        $attempt++
        
        try {
            $requestHeaders = @{
                "Authorization" = "Bearer $Token"
                "Content-Type"  = "application/json"
            }

            foreach ($key in $Headers.Keys) {
                if ($key -ne "Authorization" -and $key -ne "Content-Type") {
                    $requestHeaders[$key] = $Headers[$key]
                }
            }

            $params = @{
                Uri         = $Uri
                Headers     = $requestHeaders
                Method      = $Method
                ErrorAction = "Stop"
            }

            if ($Body) {
                $params.Body = $Body
            }

            Write-Log "Llamada API OneDrive: $Method $Uri (intento $attempt/$maxRetries)" "DEBUG"
            $response = Invoke-RestMethod @params
            return $response
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.Value

            if ($statusCode -eq 401 -and $RefreshToken -and $attempt -lt $maxRetries) {
                Write-Log "Token expirado (401), intentando actualizar..." "WARNING"
                
                $newTokenData = Update-OneDriveToken -RefreshToken $RefreshToken
                
                if ($newTokenData -and $newTokenData.access_token) {
                    Write-Log "Token actualizado, reintentando llamada..." "INFO"
                    $Token = $newTokenData.access_token
                    continue
                }
                else {
                    Write-Log "No se pudo actualizar el token" "ERROR"
                    return $null
                }
            }

            Write-Log "Error en Invoke-OneDriveApiCall: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
            return $null
        }
    }

    return $null
}

# ========================================================================== #
# FUNCIONES DE API GRAPH
# ========================================================================== #

function Get-OneDriveFiles {
    <#
    .SYNOPSIS
        Lista archivos y carpetas del root de OneDrive con manejo de token expirado
    .PARAMETER Token
        Token de acceso de OneDrive
    .PARAMETER RefreshToken
        Refresh token (opcional, para auto-refresh)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token,
        
        [string]$RefreshToken
    )
    
    try {
        $url = "https://graph.microsoft.com/v1.0/me/drive/root/children"
        
        $response = Invoke-OneDriveApiCall -Uri $url `
            -Token $Token `
            -RefreshToken $RefreshToken `
            -Method Get

        return $response.value
    }
    catch {
        Write-Log "Error listando archivos: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        Write-Host "✗ Error listando archivos: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Send-OneDriveFile {
    <#
    .SYNOPSIS
        Sube un archivo a OneDrive con manejo automático de token expirado
    .PARAMETER Token
        Token de acceso
    .PARAMETER RefreshToken
        Refresh token (opcional, para auto-refresh)
    .PARAMETER LocalPath
        Ruta local del archivo
    .PARAMETER RemoteFileName
        Nombre del archivo en OneDrive
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token,

        [string]$RefreshToken,
        
        [Parameter(Mandatory = $true)]
        [string]$LocalPath,

        [Parameter(Mandatory = $true)]
        [string]$RemoteFileName
    )
    
    try {
        if (-not (Test-Path $LocalPath)) {
            throw "Archivo no existe: $LocalPath"
        }
        
        $fileContent = [System.IO.File]::ReadAllBytes($LocalPath)
        
        $url = "https://graph.microsoft.com/v1.0/me/drive/root:/${RemoteFileName}:/content"
        $headers = @{
            "Content-Type" = "application/octet-stream"
        }

        $response = Invoke-OneDriveApiCall -Uri $url `
            -Token $Token `
            -RefreshToken $RefreshToken `
            -Method Put `
            -Body $fileContent `
            -Headers $headers

        return $response
    }
    catch {
        Write-Log "Error subiendo archivo: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        Write-Host "✗ Error subiendo archivo: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Receive-OneDriveFile {
    <#
    .SYNOPSIS
        Descarga un archivo desde OneDrive con manejo automático de token expirado
    .PARAMETER Token
        Token de acceso
    .PARAMETER RefreshToken
        Refresh token (opcional, para auto-refresh)
    .PARAMETER RemoteFileName
        Nombre del archivo en OneDrive
    .PARAMETER LocalPath
        Ruta local donde guardar
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token,

        [string]$RefreshToken,
        
        [Parameter(Mandatory = $true)]
        [string]$RemoteFileName,

        [Parameter(Mandatory = $true)]
        [string]$LocalPath
    )
    
    try {
        $url = "https://graph.microsoft.com/v1.0/me/drive/root:/${RemoteFileName}"
        
        $fileInfo = Invoke-OneDriveApiCall -Uri $url `
            -Token $Token `
            -RefreshToken $RefreshToken `
            -Method Get

        if (-not $fileInfo.'@microsoft.graph.downloadUrl') {
            throw "No se pudo obtener URL de descarga"
        }
        
        $downloadUrl = $fileInfo.'@microsoft.graph.downloadUrl'
        Invoke-WebRequest -Uri $downloadUrl -OutFile $LocalPath -ErrorAction Stop
        
        return $true
    }
    catch {
        Write-Log "Error descargando archivo: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        Write-Host "✗ Error descargando archivo: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-OneDriveConnection {
    <#
    .SYNOPSIS
        Prueba completa de conexión y operaciones con OneDrive
    .PARAMETER OneDriveConfig
        Configuración de OneDrive con Token
    .PARAMETER CleanupTestFiles
        Si es $true, elimina los archivos de prueba después
    .OUTPUTS
        $true si todas las pruebas pasaron, $false si falló
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$OneDriveConfig,
        
        [bool]$CleanupTestFiles = $true
    )

    try {
        Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║  PRUEBA DE CONEXIÓN Y OPERACIONES    ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""

        $token = $OneDriveConfig.Token
        
        if ([string]::IsNullOrWhiteSpace($token)) {
            Write-Host "✗ Token no configurado" -ForegroundColor Red
            return $false
        }

        if (-not (Test-OneDriveToken -Token $token)) {
            Write-Host "✗ Token inválido o expirado" -ForegroundColor Red
            return $false
        }

        Write-Host "[1/4] Listando archivos en OneDrive raíz..." -ForegroundColor Yellow
        
        try {
            $files = Get-OneDriveFiles -Token $token
            
            if ($files) {
                Write-Host "✓ Archivos encontrados: $($files.Count)" -ForegroundColor Green
                foreach ($file in $files | Select-Object -First 10) {
                    $icon = if ($file.folder) { "📁" } else { "📄" }
                    $size = if ($file.size) { " ($([Math]::Round($file.size/1KB, 2)) KB)" } else { "" }
                    Write-Host "  $icon $($file.name)$size" -ForegroundColor Gray
                }
                if ($files.Count -gt 10) {
                    Write-Host "  ... y $($files.Count - 10) más" -ForegroundColor DarkGray
                }
            }
            else {
                Write-Host "⚠ Sin archivos en root" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "✗ Error listando archivos: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "Test-OneDriveConnection error en listar: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
            return $false
        }

        Write-Host "[2/4] Creando y subiendo archivo de prueba..." -ForegroundColor Yellow
        
        $testFileName = "LLEVAR_Test_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $tempFile = Join-Path $env:TEMP $testFileName
        
        try {
            $testContent = @"
╔════════════════════════════════════════╗
║     ARCHIVO DE PRUEBA - LLEVAR         ║
╚════════════════════════════════════════╝

Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Usuario: $($OneDriveConfig.Email)
Sistema: $env:COMPUTERNAME

Este archivo fue creado automáticamente
para probar la conexión con OneDrive.

✓ Subida exitosa
"@
            
            [System.IO.File]::WriteAllText($tempFile, $testContent, [System.Text.Encoding]::UTF8)
            Write-Host "  Archivo temporal creado: $testFileName" -ForegroundColor Gray
            
            $uploadResult = Send-OneDriveFile -Token $token -LocalPath $tempFile -RemoteFileName $testFileName
            
            if ($uploadResult) {
                Write-Host "✓ Archivo subido a OneDrive: $testFileName" -ForegroundColor Green
            }
            else {
                Write-Host "✗ Error subiendo archivo" -ForegroundColor Red
                return $false
            }
        }
        catch {
            Write-Host "✗ Error en prueba de carga: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "Test-OneDriveConnection error en upload: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
            return $false
        }
        finally {
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }

        Write-Host "[3/4] Descargando archivo desde OneDrive..." -ForegroundColor Yellow
        
        $downloadPath = "C:\Temp"
        $downloadFile = Join-Path $downloadPath $testFileName
        
        try {
            if (-not (Test-Path $downloadPath)) {
                New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
            }
            
            $downloadResult = Receive-OneDriveFile -Token $token -RemoteFileName $testFileName -LocalPath $downloadFile
            
            if ($downloadResult -and (Test-Path $downloadFile)) {
                Write-Host "✓ Archivo descargado correctamente" -ForegroundColor Green
                Write-Host "  Ubicación: $downloadFile" -ForegroundColor Gray
                
                Write-Host "  Contenido:" -ForegroundColor Cyan
                Get-Content $downloadFile | ForEach-Object {
                    Write-Host "    $_" -ForegroundColor White
                }
            }
            else {
                Write-Host "✗ Error descargando archivo" -ForegroundColor Red
                return $false
            }
        }
        catch {
            Write-Host "✗ Error en prueba de descarga: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "Test-OneDriveConnection error en download: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
            return $false
        }

        Write-Host "[4/4] Limpiando archivos de prueba..." -ForegroundColor Yellow
        
        try {
            if ($CleanupTestFiles) {
                $deleteResult = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/drive/root:/$testFileName" `
                    -Headers @{ "Authorization" = "Bearer $token" } `
                    -Method Delete `
                    -ErrorAction SilentlyContinue

                if ($deleteResult -or -not $?) {
                    Write-Host "✓ Archivo de prueba eliminado de OneDrive" -ForegroundColor Green
                }
                else {
                    Write-Host "⚠ No se pudo eliminar archivo de OneDrive (pero continuando)" -ForegroundColor Yellow
                }
            }
            
            if (Test-Path $downloadFile) {
                Remove-Item $downloadFile -Force -ErrorAction SilentlyContinue
                Write-Host "✓ Archivo local de prueba eliminado" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "⚠ Error en limpieza: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "✓ ¡Todas las operaciones completadas exitosamente!" -ForegroundColor Green
        Write-Log "Prueba de conexión OneDrive completada exitosamente" "INFO"
        return $true
    }
    catch {
        Write-Host "✗ Error general en prueba: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Test-OneDriveConnection error general: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        return $false
    }
}

function Send-LlevarOneDriveFile {
    <#
    .SYNOPSIS
        Sube un archivo local a OneDrive usando la configuración de TransferConfig
    .PARAMETER Llevar
        Objeto TransferConfig con Destino.Tipo = "OneDrive" y tokens configurados
    .PARAMETER LocalPath
        Ruta local del archivo a subir
    .PARAMETER RemotePath
        Ruta remota base en OneDrive (ej: /Carpeta)
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Llevar,

        [Parameter(Mandatory = $true)]
        [string]$LocalPath,

        [Parameter(Mandatory = $true)]
        [string]$RemotePath
    )

    if (-not (Test-Path $LocalPath)) {
        throw "Send-LlevarOneDriveFile: archivo local no encontrado: $LocalPath"
    }

    $oneDriveConfig = $Llevar.Destino.OneDrive
    $token = $oneDriveConfig.Token
    $useLocal = $oneDriveConfig.UseLocal
    $localRoot = $oneDriveConfig.LocalPath

    if ($useLocal -and $localRoot) {
        $remoteFolder = if ([string]::IsNullOrWhiteSpace($RemotePath)) { "/" } else { $RemotePath }
        if (-not $remoteFolder.StartsWith('/')) {
            $remoteFolder = "/$remoteFolder"
        }
        $remoteFolder = $remoteFolder.Replace('//', '/')

        $targetFolder = if ($remoteFolder -eq "/") { $localRoot } else { Join-Path $localRoot $remoteFolder.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar) }
        if (-not (Test-Path $targetFolder)) {
            New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
        }

        $fileName = [System.IO.Path]::GetFileName($LocalPath)
        $targetPath = Join-Path $targetFolder $fileName
        Copy-Item -Path $LocalPath -Destination $targetPath -Force
        Write-Log "Archivo copiado a OneDrive local: $targetPath" "INFO"
        return $true
    }

    if (-not $token) {
        throw "Send-LlevarOneDriveFile: falta Token en Destino.OneDrive"
    }

    $remoteFolder = $RemotePath
    if (-not $remoteFolder.StartsWith('/')) {
        $remoteFolder = "/$remoteFolder"
    }
    $remoteFolder = $remoteFolder.Replace('//', '/')
    if (($remoteFolder -ne "/") -and $remoteFolder.EndsWith('/')) {
        $remoteFolder = $remoteFolder.TrimEnd('/')
    }

    # Crear la carpeta si no existe
    if ($remoteFolder -ne "/") {
        $folderCreated = New-OneDriveFolder -Token $token -FolderPath $remoteFolder
        if (-not $folderCreated) {
            Write-Warning "No se pudo verificar/crear la carpeta: $remoteFolder. Continuando..."
        }
    }

    $fileName = [System.IO.Path]::GetFileName($LocalPath)
    if ($remoteFolder -eq "/") {
        $uploadUrl = "https://graph.microsoft.com/v1.0/me/drive/root:" + "/" + $fileName + ":/content"
    }
    else {
        $uploadUrl = "https://graph.microsoft.com/v1.0/me/drive/root:" + $remoteFolder + "/" + $fileName + ":/content"
    }
    $uploadHeaders = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/octet-stream"
    }

    $fileContent = [System.IO.File]::ReadAllBytes($LocalPath)

    Invoke-RestMethod -Uri $uploadUrl -Headers $uploadHeaders -Method Put -Body $fileContent | Out-Null
    return $true
}

# ========================================================================== #
# FUNCIONES DE RUTAS
# ========================================================================== #

function New-OneDriveFolder {
    <#
    .SYNOPSIS
        Crea una carpeta en OneDrive si no existe
    .PARAMETER Token
        Token de autenticación de OneDrive
    .PARAMETER FolderPath
        Ruta de la carpeta a crear (ej: /Apps/TestLlevar)
    .OUTPUTS
        $true si la carpeta existe o se creó exitosamente, $false si falla
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token,
        
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )
    
    $folderPath = Resolve-OneDrivePath -Path $FolderPath
    
    # Si es raíz, no hay nada que crear
    if ($folderPath -eq "/") {
        return $true
    }
    
    # Verificar si la carpeta ya existe
    try {
        $checkUrl = "https://graph.microsoft.com/v1.0/me/drive/root:${folderPath}"
        $headers = @{
            "Authorization" = "Bearer $Token"
        }
        
        Invoke-RestMethod -Uri $checkUrl -Headers $headers -Method Get -ErrorAction Stop | Out-Null
        Write-Log "Carpeta OneDrive ya existe: $folderPath" "DEBUG"
        return $true
    }
    catch {
        # Si no existe, intentar crearla
        Write-Log "Carpeta no existe, creando: $folderPath" "DEBUG"
    }
    
    # Crear carpetas recursivamente si es necesario
    $parts = $folderPath.TrimStart('/').Split('/')
    $currentPath = ""
    
    foreach ($part in $parts) {
        if ([string]::IsNullOrWhiteSpace($part)) { continue }
        
        $parentPath = $currentPath
        $currentPath = if ($currentPath) { "$currentPath/$part" } else { "/$part" }
        
        try {
            # Verificar si existe
            $checkUrl = "https://graph.microsoft.com/v1.0/me/drive/root:${currentPath}"
            $headers = @{
                "Authorization" = "Bearer $Token"
            }
            
            Invoke-RestMethod -Uri $checkUrl -Headers $headers -Method Get -ErrorAction Stop | Out-Null
            Write-Log "Carpeta existe: $currentPath" "DEBUG"
        }
        catch {
            # Crear la carpeta
            try {
                $createUrl = if ($parentPath) {
                    "https://graph.microsoft.com/v1.0/me/drive/root:${parentPath}:/children"
                }
                else {
                    "https://graph.microsoft.com/v1.0/me/drive/root/children"
                }
                
                $body = @{
                    name                                = $part
                    folder                              = @{}
                    "@microsoft.graph.conflictBehavior" = "fail"
                } | ConvertTo-Json
                
                $headers = @{
                    "Authorization" = "Bearer $Token"
                    "Content-Type"  = "application/json"
                }
                
                Invoke-RestMethod -Uri $createUrl -Headers $headers -Method Post -Body $body -ErrorAction Stop | Out-Null
                Write-Log "Carpeta creada: $currentPath" "INFO"
            }
            catch {
                if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*nameAlreadyExists*") {
                    Write-Log "Carpeta ya existe (conflicto): $currentPath" "DEBUG"
                }
                else {
                    Write-Log "Error creando carpeta $currentPath : $($_.Exception.Message)" "ERROR"
                    return $false
                }
            }
        }
    }
    
    return $true
}

function Resolve-OneDrivePath {
    param([string]$Path)
    
    $clean = if ($Path) { $Path.Trim() } else { "" }
    $clean = $clean -replace '\\', '/'
    if (-not $clean.StartsWith('/')) {
        $clean = "/$clean"
    }
    if (($clean -ne "/") -and $clean.EndsWith('/')) {
        $clean = $clean.TrimEnd('/')
    }
    if (-not $clean) {
        return "/"
    }
    return $clean
}

function Get-OneDriveParentPath {
    param([string]$Path)

    $normalized = Resolve-OneDrivePath -Path $Path
    if ($normalized -eq "/") {
        return "/"
    }

    $segments = $normalized.TrimStart('/').Split('/') | Where-Object { $_ -ne '' }
    if ($segments.Count -le 1) {
        return "/"
    }

    $parentSegments = $segments[0..($segments.Count - 2)]
    return "/" + ($parentSegments -join '/')
}

function Convert-GraphItemToNavigatorEntry {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Item,

        [string]$ParentPath,
        [string]$DriveId
    )

    $isFolder = $null -ne $Item.folder
    $normalizedParent = Resolve-OneDrivePath -Path $ParentPath
    $name = $Item.name
    $fullName = if ($normalizedParent -eq "/") { "/$name" } else { "$normalizedParent/$name" }
    $sizeText = if ($Item.size) {
        # Graph expone size (bytes) también para carpetas; mostrarlo formateado
        Format-FileSize -Size $Item.size
    }
    elseif ($isFolder) {
        "<DIR>"
    }
    else {
        ""
    }

    return [PSCustomObject]@{
        Name            = $name
        FullName        = $fullName
        IsDirectory     = $isFolder
        IsParent        = $false
        IsDriveSelector = $false
        Size            = $sizeText
        Icon            = if ($isFolder) { "📁" } else { "📄" }
        RawItem         = $Item
        ItemId          = $Item.id
        DriveId         = if ($DriveId) { $DriveId } else { $Item.parentReference.driveId }
    }
}

# ========================================================================== #
# FUNCIONES HELPER PARA NAVIGATOR GENÉRICO
# ========================================================================== #

function Get-OneDriveNavigatorItems {
    <#
    .SYNOPSIS
        Helper para Navigator genérico - Lista items de OneDrive
    .DESCRIPTION
        Esta función es llamada por el Navigator genérico cuando la fuente es OneDrive.
        Retorna items en formato compatible con el Navigator.
    .PARAMETER Token
        Token de acceso OneDrive
    .PARAMETER CurrentPath
        Ruta actual en OneDrive
    .PARAMETER AllowFiles
        Si permite seleccionar archivos o solo carpetas
    .PARAMETER DriveId
        ID del drive (opcional)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token,

        [string]$CurrentPath = "/",
        [bool]$AllowFiles = $false,
        [string]$DriveId
    )

    if ([string]::IsNullOrWhiteSpace($Token)) {
        Write-Log "Get-OneDriveNavigatorItems: Token vacío" "ERROR"
        return @()
    }

    if (-not (Test-OneDriveToken -Token $Token)) {
        Write-Log "Get-OneDriveNavigatorItems: Token inválido o expirado" "WARNING"
        return @()
    }

    $normalizedPath = Resolve-OneDrivePath -Path $CurrentPath
    $relativePath = $normalizedPath.TrimStart('/')

    $endpoint = if ([string]::IsNullOrEmpty($relativePath)) {
        "https://graph.microsoft.com/v1.0/me/drive/root/children"
    }
    else {
        try {
            $escaped = [System.Uri]::EscapeDataString($relativePath)
            "https://graph.microsoft.com/v1.0/me/drive/root:/" + $escaped + ":/children"
        }
        catch {
            Write-Log "Error escapando ruta: $relativePath" "ERROR" -ErrorRecord $_
            return @()
        }
    }

    $headers = @{
        "Authorization" = "Bearer $Token"
    }

    try {
        $response = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Get -ErrorAction Stop
    }
    catch {
        Write-Log "Get-OneDriveNavigatorItems error en API: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        return @()
    }

    $items = @()

    if ($normalizedPath -ne "/") {
        $parentPath = Get-OneDriveParentPath -Path $normalizedPath
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

    if ($response.value) {
        foreach ($entry in $response.value) {
            if (-not $AllowFiles -and $entry.file) {
                continue
            }

            $items += Convert-GraphItemToNavigatorEntry -Item $entry -ParentPath $normalizedPath -DriveId $DriveId
        }
    }

    return $items
}

function Get-OneDriveFolderSize {
    <#
    .SYNOPSIS
        Calcula el tamaño total de una carpeta OneDrive recursivamente
    .DESCRIPTION
        Usa Graph API para recorrer recursivamente todos los archivos y subcarpetas.
        Suma el tamaño total y cuenta archivos/directorios.
    .PARAMETER Token
        Token de acceso OneDrive
    .PARAMETER DriveId
        ID del drive
    .PARAMETER ItemId
        ID del item (carpeta) a calcular
    .OUTPUTS
        Hashtable con Size (bytes), Files (cantidad), Dirs (cantidad)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [string]$DriveId,

        [Parameter(Mandatory = $true)]
        [string]$ItemId
    )

    if (-not $Token -or -not $DriveId -or -not $ItemId) {
        return @{ Size = 0; Files = 0; Dirs = 0 }
    }

    $headers = @{
        "Authorization" = "Bearer $Token"
    }

    $queue = @($ItemId)
    $totalSize = 0
    $fileCount = 0
    $dirCount = 0

    while ($queue.Count -gt 0) {
        $currentId = $queue[0]
        $queue = if ($queue.Count -gt 1) { $queue[1..($queue.Count - 1)] } else { @() }
        $url = "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$currentId/children?`$select=id,size,folder"

        do {
            try {
                $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
            }
            catch {
                return @{ Size = $totalSize; Files = $fileCount; Dirs = $dirCount }
            }

            foreach ($child in $response.value) {
                if ($child.folder) {
                    $dirCount++
                    $queue += $child.id
                }
                elseif ($child.size) {
                    $totalSize += [int64]$child.size
                    $fileCount++
                }
            }

            $url = $response.'@odata.nextLink'
        } while ($url)
    }

    return @{
        Size  = $totalSize
        Files = $fileCount
        Dirs  = $dirCount
    }
}

function Select-OneDrivePath {
    <#
    .SYNOPSIS
        Navega OneDrive usando el Navigator genérico
    .DESCRIPTION
        Proporciona un provider compatible con Select-PathNavigator
    #>
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$OneDriveConfig,

        [bool]$AllowFiles = $false,
        [string]$Prompt = "Navegar OneDrive",
        [string]$InitialPath = "/"
    )

    if (-not $OneDriveConfig) {
        Write-Log "Select-OneDrivePath: Falta configuración de OneDrive" "ERROR"
        throw "Select-OneDrivePath: falta configuración de OneDrive"
    }

    $useLocal = [bool]$OneDriveConfig.UseLocal
    $localRoot = $OneDriveConfig.LocalPath
    $token = $OneDriveConfig.Token
    $driveId = $OneDriveConfig.DriveId

    if (-not $useLocal -and -not $token) {
        Write-Log "Select-OneDrivePath: No hay token para navegación remota" "ERROR"
        throw "Select-OneDrivePath: no hay token disponible para navegación remota"
    }

    if ($useLocal -and -not $localRoot) {
        Write-Log "Select-OneDrivePath: Falta ruta local de OneDrive" "ERROR"
        throw "Select-OneDrivePath: falta ruta local de OneDrive"
    }

    if ($useLocal -and -not (Test-Path $localRoot)) {
        Write-Log "Select-OneDrivePath: Ruta local no existe: $localRoot" "ERROR"
        throw "Select-OneDrivePath: ruta local no existe: $localRoot"
    }

    $currentPath = Resolve-OneDrivePath -Path $InitialPath

    $provider = {
        param($Path, $AllowFiles, $SizeCache)

        $requestedPath = Resolve-OneDrivePath -Path $Path

        if ($useLocal -and $localRoot) {
            try {
                $relative = if ($requestedPath -eq "/") { "" } else { $requestedPath.TrimStart('/') }
                $localPath = if ($relative) {
                    Join-Path $localRoot ($relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
                }
                else {
                    $localRoot
                }

                if (-not (Test-Path $localPath)) {
                    Write-Log "Ruta local no encontrada: $localPath" "WARNING"
                    return @()
                }

                if (Get-Command Get-DirectoryItems -ErrorAction SilentlyContinue) {
                    return Get-DirectoryItems -Path $localPath -AllowFiles $AllowFiles -SizeCache $SizeCache
                }
                else {
                    Write-Log "Get-DirectoryItems no disponible" "WARNING"
                    return @()
                }
            }
            catch {
                Write-Log "Error en navegación local: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
                return @()
            }
        }

        return Get-OneDriveNavigatorItems -Token $token -CurrentPath $requestedPath -AllowFiles $AllowFiles -DriveId $driveId
    }

    $modulePathResolved = $MyInvocation.MyCommand.Path
    try {
        if ($modulePathResolved) {
            $modulePathResolved = (Resolve-Path -LiteralPath $modulePathResolved).Path
        }
    }
    catch {}

    $providerOptions = @{
        AllowDriveSelector      = $useLocal
        AllowNetworkDiscovery   = $useLocal
        Token                   = $token
        DriveId                 = $driveId
        ModulePath              = $modulePathResolved
        UseRemoteSizeCalculator = (-not $useLocal)
    }

    try {
        return Select-PathNavigator -Prompt $Prompt -AllowFiles:$AllowFiles `
            -ItemProvider $provider -InitialPath $currentPath `
            -ProviderOptions $providerOptions
    }
    catch {
        Write-Log "Error en Select-OneDrivePath: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        throw
    }
}

function Select-OneDriveFolder {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$OneDriveConfig,

        [string]$Prompt = "Seleccionar carpeta OneDrive",
        [string]$InitialPath = "/"
    )

    return Select-OneDrivePath -OneDriveConfig $OneDriveConfig -AllowFiles:$false -Prompt $Prompt -InitialPath $InitialPath
}

# ========================================================================== #
# FUNCIONES DE TRANSFERENCIA COMPLETA
# ========================================================================== #

function Copy-LlevarLocalToOneDrive {
    <#
    .SYNOPSIS
        Copia archivos locales a OneDrive con progreso
    .DESCRIPTION
        DELEGADO AL DISPATCHER UNIFICADO
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Llevar,
        
        [datetime]$StartTime = (Get-Date),
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )
    
    Write-Log "Copy-LlevarLocalToOneDrive: Delegando al dispatcher unificado" "INFO"
    
    
    $dispatcherPath = Join-Path $ModulesPath "Transfer\Unified.psm1"
    if (-not (Get-Command Invoke-TransferDispatcher -ErrorAction SilentlyContinue)) {
        Import-Module $dispatcherPath -Force -Global
    }
    
    return Invoke-TransferDispatcher -Llevar $Llevar `
        -ShowProgress $ShowProgress -ProgressTop $ProgressTop
}

function Copy-LlevarOneDriveToLocal {
    <#
    .SYNOPSIS
        Descarga archivos desde OneDrive a local con progreso
    .DESCRIPTION
        DELEGADO AL DISPATCHER UNIFICADO
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Llevar,
        
        [datetime]$StartTime = (Get-Date),
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )
    
    Write-Log "Copy-LlevarOneDriveToLocal: Delegando al dispatcher unificado" "INFO"
    
    
    $dispatcherPath = Join-Path $ModulesPath "Transfer\Unified.psm1"
    if (-not (Get-Command Invoke-TransferDispatcher -ErrorAction SilentlyContinue)) {
        Import-Module $dispatcherPath -Force -Global
    }
    
    return Invoke-TransferDispatcher -Llevar $Llevar `
        -ShowProgress $ShowProgress -ProgressTop $ProgressTop
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Test-IsOneDrivePath',
    'Invoke-OneDriveApiCall',
    'Get-OneDriveFiles',
    'Send-OneDriveFile',
    'Receive-OneDriveFile',
    'Test-OneDriveConnection',
    'Send-LlevarOneDriveFile',
    'New-OneDriveFolder',
    'Resolve-OneDrivePath',
    'Get-OneDriveParentPath',
    'Convert-GraphItemToNavigatorEntry',
    'Get-OneDriveNavigatorItems',
    'Get-OneDriveFolderSize',
    'Select-OneDrivePath',
    'Select-OneDriveFolder',
    'Copy-LlevarLocalToOneDrive',
    'Copy-LlevarOneDriveToLocal'
)
