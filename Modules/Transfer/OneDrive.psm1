# ========================================================================== #
#                      MÓDULO: OPERACIONES ONEDRIVE                          #
# ========================================================================== #
# Propósito: Autenticación y operaciones con OneDrive (local y API)
# Funciones:
#   - Get-OneDriveAuth: Configuración con detección local o API OAuth
#   - Test-MicrosoftGraphModule: Verifica/instala módulos Microsoft.Graph
#   - Test-IsOneDrivePath: Detecta rutas OneDrive
#   - Connect-GraphSession: Asegura sesión autenticada con Microsoft Graph
#   - Send-OneDriveFile: Sube archivo a OneDrive
#   - Receive-OneDriveFile: Descarga archivo desde OneDrive
#   - Send-OneDriveFolder: Sube carpeta completa
#   - Receive-OneDriveFolder: Descarga carpeta completa
#   - Copy-LlevarLocalToOneDrive: Copia con progreso
#   - Copy-LlevarOneDriveToLocal: Descarga con progreso
# ========================================================================== #

function Test-IsOneDrivePath {
    <#
    .SYNOPSIS
        Detecta si una ruta es OneDrive
    #>
    param([string]$Path)
    return $Path -match '^onedrive://|^ONEDRIVE:'
}

function Test-MicrosoftGraphModule {
    <#
    .SYNOPSIS
        Verifica e instala módulos Microsoft.Graph si es necesario
    .OUTPUTS
        $true si módulos disponibles, $false si faltan
    #>
    
    Show-Banner "VERIFICACIÓN DE MÓDULOS MICROSOFT.GRAPH" -BorderColor Cyan -TextColor Yellow
    
    $requiredModules = @(
        'Microsoft.Graph.Authentication',
        'Microsoft.Graph.Files'
    )
    
    $missingModules = @()
    
    foreach ($moduleName in $requiredModules) {
        Write-Host "Verificando $moduleName..." -NoNewline -ForegroundColor Gray
        
        $module = Get-Module -ListAvailable -Name $moduleName | Select-Object -First 1
        
        if ($module) {
            Write-Host " ✓ v$($module.Version)" -ForegroundColor Green
        }
        else {
            Write-Host " ✗ No encontrado" -ForegroundColor Yellow
            $missingModules += $moduleName
        }
    }
    
    if ($missingModules.Count -eq 0) {
        Write-Host "`n✓ Todos los módulos requeridos están instalados" -ForegroundColor Green
        
        foreach ($moduleName in $requiredModules) {
            if (-not (Get-Module -Name $moduleName)) {
                Import-Module $moduleName -ErrorAction Stop
            }
        }
        return $true
    }
    
    # Intentar instalar
    Show-Banner "MÓDULOS REQUERIDOS" -BorderColor Yellow -TextColor Yellow
    
    Write-Host "Se requieren los siguientes módulos:" -ForegroundColor Cyan
    $missingModules | ForEach-Object { Write-Host "  • $_" -ForegroundColor White }
    Write-Host ""
    
    $response = Read-Host "¿Desea instalar ahora? (S/N)"
    
    if ($response -notmatch '^[SsYy]') {
        Write-Host "`n✗ Instalación cancelada" -ForegroundColor Red
        return $false
    }
    
    try {
        Write-Host "`nInstalando Microsoft.Graph..." -ForegroundColor Cyan
        Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        
        Write-Host "✓ Instalación completada" -ForegroundColor Green
        
        foreach ($moduleName in $requiredModules) {
            Import-Module $moduleName -ErrorAction Stop
        }
        
        return $true
    }
    catch {
        Write-Host "✗ Error en instalación: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Get-OneDriveAuth {
    <#
    .SYNOPSIS
        Configura autenticación OneDrive con OAuth o ruta local
    .OUTPUTS
        Hashtable con Email, Token, ApiUrl, LocalPath, UseLocal
    #>
    param([switch]$ForceApi)
    
    Write-Log "Iniciando configuración OneDrive" "INFO"
    Clear-Host
    Show-Banner -Message "CONFIGURACIÓN ONEDRIVE" -BorderColor "Cyan"
    
    # Buscar instalación local
    $oneDriveLocal = $null
    if (-not $ForceApi) {
        $possiblePaths = @(
            "$env:USERPROFILE\OneDrive",
            "$env:LOCALAPPDATA\Microsoft\OneDrive",
            "$env:OneDrive"
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $oneDriveLocal = $path
                Write-Log "OneDrive detectado: $path" "INFO"
                break
            }
        }
    }
    
    if ($oneDriveLocal) {
        Write-Host "`nOneDrive detectado en:" -ForegroundColor Green
        Write-Host "  $oneDriveLocal" -ForegroundColor White
        Write-Host ""
        
        $opcion = Show-ConsolePopup -Title "OneDrive Local" `
            -Message "¿Usar instalación local o API?" `
            -Options @("*Usar Local", "Usar *API", "*Cancelar")
        
        if ($opcion -eq 0) {
            Write-Log "Usuario eligió OneDrive local" "INFO"
            return @{
                Email     = $env:USERNAME + "@onedrive.com"
                Token     = $null
                ApiUrl    = $null
                LocalPath = $oneDriveLocal
                UseLocal  = $true
            }
        }
        elseif ($opcion -eq 2) {
            return $null
        }
    }
    
    # Configuración API
    Show-Banner "AUTENTICACIÓN ONEDRIVE API" -BorderColor Cyan -TextColor White
    Write-Host "`nPara usar OneDrive API necesita:" -ForegroundColor Yellow
    Write-Host "  1. Cuenta Microsoft" -ForegroundColor White
    Write-Host "  2. Token OAuth 2.0" -ForegroundColor White
    Write-Host ""
    
    $email = Read-Host "Email de Microsoft"
    if ([string]::IsNullOrWhiteSpace($email)) { return $null }
    
    $tokenSecure = Read-Host "Token OAuth 2.0" -AsSecureString
    $token = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenSecure)
    )
    
    if ([string]::IsNullOrWhiteSpace($token)) { return $null }
    
    # Validar token
    try {
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type"  = "application/json"
        }
        
        $apiUrl = "https://graph.microsoft.com/v1.0/me/drive"
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -TimeoutSec 10
        
        Write-Host "`n✓ Autenticación exitosa" -ForegroundColor Green
        Write-Host "  Usuario: $($response.owner.user.displayName)" -ForegroundColor White
        Write-Log "OneDrive API autenticado: $email" "INFO"
        
        return @{
            Email     = $email
            Token     = $token
            ApiUrl    = $apiUrl
            LocalPath = $null
            UseLocal  = $false
        }
    }
    catch {
        Write-Host "`n✗ Error de autenticación: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Error OneDrive: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        return $null
    }
}

function Connect-GraphSession {
    <#
    .SYNOPSIS
        Asegura conexión con Microsoft Graph
    #>
    try {
        $ctx = Get-MgContext -ErrorAction Stop
        if ($ctx.Account) {
            Write-Host "[+] Autenticado como $($ctx.Account)" -ForegroundColor Green
            return $true
        }
    }
    catch {}
    
    Write-Host "[*] Iniciando login con MFA..." -ForegroundColor Yellow
    
    try {
        Connect-MgGraph -Scopes "Files.ReadWrite.All" | Out-Null
        Write-Host "[+] Autenticación correcta" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[X] Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Send-OneDriveFile {
    <#
    .SYNOPSIS
        Sube archivo a OneDrive
    #>
    param([string]$LocalPath, [string]$RemotePath)
    
    if (-not (Test-Path $LocalPath)) {
        throw "Archivo no existe: $LocalPath"
    }
    
    $bytes = [System.IO.File]::ReadAllBytes($LocalPath)
    $fileName = Split-Path $LocalPath -Leaf
    $remote = "root:/$RemotePath/${fileName}:"
    
    Write-Host "[*] Subiendo $fileName a OneDrive..." -ForegroundColor Cyan
    
    try {
        $fileSize = (Get-Item $LocalPath).Length
        
        if ($fileSize -gt 4MB) {
            # Upload con sesión para archivos grandes
            $uploadUrl = "https://graph.microsoft.com/v1.0/me/drive/$remote/createUploadSession"
            $uploadSession = Invoke-MgGraphRequest -Method POST -Uri $uploadUrl
            
            $chunkSize = 320KB * 10
            $stream = [System.IO.File]::OpenRead($LocalPath)
            $buffer = New-Object byte[] $chunkSize
            $bytesUploaded = 0
            
            while ($bytesUploaded -lt $fileSize) {
                $bytesRead = $stream.Read($buffer, 0, $chunkSize)
                $rangeStart = $bytesUploaded
                $rangeEnd = $bytesUploaded + $bytesRead - 1
                
                $headers = @{
                    "Content-Length" = $bytesRead
                    "Content-Range"  = "bytes $rangeStart-$rangeEnd/$fileSize"
                }
                
                $dataToSend = $buffer[0..($bytesRead - 1)]
                Invoke-RestMethod -Method PUT -Uri $uploadSession.uploadUrl -Body $dataToSend -Headers $headers | Out-Null
                
                $bytesUploaded += $bytesRead
                $percent = [int](($bytesUploaded * 100) / $fileSize)
                Write-Host "`r  Progreso: $percent%" -NoNewline -ForegroundColor Gray
            }
            
            $stream.Close()
            Write-Host ""
        }
        else {
            # Upload simple
            New-MgDriveItemContent -DriveId "me" -DriveItemId $remote -BodyParameter $bytes | Out-Null
        }
        
        Write-Host "[✓] Subida completada" -ForegroundColor Green
    }
    catch {
        Write-Host "[X] Error: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Receive-OneDriveFile {
    <#
    .SYNOPSIS
        Descarga archivo desde OneDrive
    #>
    param([string]$OneDrivePath, [string]$LocalPath)
    
    Write-Host "[*] Descargando desde OneDrive..." -ForegroundColor Cyan
    
    try {
        $content = Get-MgDriveItemContent -DriveId "me" -DriveItemId $OneDrivePath
        
        $folder = Split-Path $LocalPath
        if (-not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder | Out-Null
        }
        
        [System.IO.File]::WriteAllBytes($LocalPath, $content)
        Write-Host "[✓] Descargado → $LocalPath" -ForegroundColor Green
    }
    catch {
        Write-Host "[X] Error: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Send-OneDriveFolder {
    <#
    .SYNOPSIS
        Sube carpeta completa a OneDrive
    #>
    param([string]$LocalFolder, [string]$RemotePath)
    
    if (-not (Test-Path $LocalFolder)) {
        throw "Carpeta no existe: $LocalFolder"
    }
    
    Write-Host "[*] Subiendo carpeta: $LocalFolder → $RemotePath" -ForegroundColor Cyan
    
    $files = Get-ChildItem -Path $LocalFolder -File -Recurse
    $total = $files.Count
    $current = 0
    
    foreach ($file in $files) {
        $current++
        $relativePath = $file.FullName.Substring($LocalFolder.Length).TrimStart('\\', '/')
        $targetPath = "$RemotePath/$relativePath".Replace('\\', '/')
        $targetFolder = Split-Path $targetPath -Parent
        
        Write-Host "[$current/$total] $relativePath" -ForegroundColor Gray
        
        try {
            Send-OneDriveFile -LocalPath $file.FullName -RemotePath $targetFolder
        }
        catch {
            Write-Host "  [X] Error: $relativePath" -ForegroundColor Red
        }
    }
    
    Write-Host "[✓] Carpeta subida" -ForegroundColor Green
}

function Receive-OneDriveFolder {
    <#
    .SYNOPSIS
        Descarga carpeta completa desde OneDrive
    #>
    param([string]$OneDrivePath, [string]$LocalFolder)
    
    Write-Host "[*] Descargando carpeta: $OneDrivePath → $LocalFolder" -ForegroundColor Cyan
    
    try {
        $items = Get-MgDriveItem -DriveId "me" -DriveItemId $OneDrivePath -ExpandProperty "children"
        
        if (-not (Test-Path $LocalFolder)) {
            New-Item -ItemType Directory -Path $LocalFolder | Out-Null
        }
        
        foreach ($item in $items.Children) {
            $localPath = Join-Path $LocalFolder $item.Name
            
            if ($item.Folder) {
                $subPath = "$OneDrivePath/$($item.Name)"
                Receive-OneDriveFolder -OneDrivePath $subPath -LocalFolder $localPath
            }
            else {
                Write-Host "  $($item.Name)" -ForegroundColor Gray
                $itemPath = "root:/$($item.ParentReference.Path)/$($item.Name):"
                Receive-OneDriveFile -OneDrivePath $itemPath -LocalPath $localPath
            }
        }
        
        Write-Host "[✓] Carpeta descargada" -ForegroundColor Green
    }
    catch {
        Write-Host "[X] Error: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Copy-LlevarLocalToOneDrive {
    <#
    .SYNOPSIS
        Copia de local a OneDrive con progreso
    #>
    param(
        [string]$SourcePath,
        [hashtable]$OneDriveConfig,
        [long]$TotalBytes = 0,
        [int]$FileCount = 0,
        [datetime]$StartTime = (Get-Date),
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )
    
    Write-Log "Copia Local → OneDrive: $SourcePath" "INFO"
    
    if ($OneDriveConfig.UseLocal -and $OneDriveConfig.LocalPath) {
        # Usar copia local
        Copy-LlevarLocalToLocal -SourcePath $SourcePath -DestinationPath $OneDriveConfig.LocalPath `
            -TotalBytes $TotalBytes -FileCount $FileCount -StartTime $StartTime `
            -ShowProgress $ShowProgress -ProgressTop $ProgressTop
    }
    else {
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 50 -StartTime $StartTime -Label "Subiendo a OneDrive API..." -Top $ProgressTop -Width 50
        }
        
        # TODO: Usar Send-OneDriveFile con progreso
        throw "OneDrive API no completamente implementado"
    }
}

function Copy-LlevarOneDriveToLocal {
    <#
    .SYNOPSIS
        Copia de OneDrive a local con progreso
    #>
    param(
        [hashtable]$OneDriveConfig,
        [string]$DestinationPath,
        [datetime]$StartTime = (Get-Date),
        [bool]$ShowProgress = $true,
        [int]$ProgressTop = -1
    )
    
    Write-Log "Copia OneDrive → Local: $DestinationPath" "INFO"
    
    if ($OneDriveConfig.UseLocal -and $OneDriveConfig.LocalPath) {
        $totalBytes = 0
        $fileCount = 0
        
        if (Test-Path $OneDriveConfig.LocalPath -PathType Container) {
            $files = Get-ChildItem -Path $OneDriveConfig.LocalPath -Recurse -File
            $fileCount = $files.Count
            $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
        }
        
        Copy-LlevarLocalToLocal -SourcePath $OneDriveConfig.LocalPath -DestinationPath $DestinationPath `
            -TotalBytes $totalBytes -FileCount $fileCount -StartTime $StartTime `
            -ShowProgress $ShowProgress -ProgressTop $ProgressTop
    }
    else {
        if ($ShowProgress) {
            Write-LlevarProgressBar -Percent 50 -StartTime $StartTime -Label "Descargando de OneDrive API..." -Top $ProgressTop -Width 50
        }
        
        # TODO: Usar Receive-OneDriveFile con progreso
        throw "OneDrive API no completamente implementado"
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Test-IsOneDrivePath',
    'Test-MicrosoftGraphModule',
    'Get-OneDriveAuth',
    'Connect-GraphSession',
    'Send-OneDriveFile',
    'Receive-OneDriveFile',
    'Send-OneDriveFolder',
    'Receive-OneDriveFolder',
    'Copy-LlevarLocalToOneDrive',
    'Copy-LlevarOneDriveToLocal'
)
