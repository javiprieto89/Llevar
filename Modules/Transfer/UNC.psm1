# ========================================================================== #
#                        MÓDULO: OPERACIONES DE RED UNC                      #
# ========================================================================== #
# Propósito: Descubrimiento, montaje y acceso a rutas UNC de red
# Funciones:
#   - Get-NetworkComputers: Descubre equipos en la red local
#   - Test-UncPathAccess: Verifica acceso a ruta UNC con/sin credenciales
#   - Get-ComputerShares: Lista recursos compartidos de un equipo
#   - Select-NetworkPath: Menú interactivo para seleccionar ruta UNC
#   - Split-UncRootAndPath: Divide ruta UNC en raíz y subdirectorio
#   - Mount-LlevarNetworkPath: Monta ruta UNC como PSDrive
# ========================================================================== #

function Get-NetworkComputers {
    <#
    .SYNOPSIS
        Descubre equipos en la red local LAN
    .DESCRIPTION
        Escanea la red usando NetBIOS y WMI para encontrar equipos disponibles
    .OUTPUTS
        Array de objetos con Name y Path (\\equipo)
    #>
    
    Write-Host "`nBuscando equipos en la red local..." -ForegroundColor Cyan
    Write-Host "Esto puede tardar unos segundos..." -ForegroundColor Gray
    Write-Host ""
    
    $computers = @()
    
    try {
        # Método 1: Usar net view (rápido pero puede fallar en algunas redes)
        $netViewOutput = net view 2>$null
        if ($LASTEXITCODE -eq 0) {
            $netViewOutput | ForEach-Object {
                if ($_ -match '^\\\\[\w-]+') {
                    $computerName = $_.Trim().Split()[0].TrimStart('\')
                    if ($computerName -and $computerName -ne '') {
                        $computers += [PSCustomObject]@{
                            Name = $computerName
                            Path = "\\$computerName"
                        }
                    }
                }
            }
        }
    }
    catch {
        # Ignorar errores de net view
    }
    
    # Método 2: Intentar con Get-ADComputer (si está en dominio)
    try {
        if (Get-Command Get-ADComputer -ErrorAction SilentlyContinue) {
            $adComputers = Get-ADComputer -Filter * -Properties Name 2>$null | Select-Object -First 50
            foreach ($comp in $adComputers) {
                if ($comp.Name -and ($computers.Name -notcontains $comp.Name)) {
                    $computers += [PSCustomObject]@{
                        Name = $comp.Name
                        Path = "\\$($comp.Name)"
                    }
                }
            }
        }
    }
    catch {
        # AD no disponible o no está en dominio
    }
    
    if ($computers.Count -eq 0) {
        Write-Host "No se encontraron equipos en la red." -ForegroundColor Yellow
        Write-Host "Esto puede deberse a:" -ForegroundColor Gray
        Write-Host "  • No estar en una red local" -ForegroundColor DarkGray
        Write-Host "  • Firewall bloqueando descubrimiento" -ForegroundColor DarkGray
        Write-Host "  • Red configurada sin NetBIOS" -ForegroundColor DarkGray
    }
    
    return $computers
}

function Test-UncPathAccess {
    <#
    .SYNOPSIS
        Verifica si se puede acceder a una ruta UNC
    .DESCRIPTION
        Intenta acceder a ruta UNC con o sin credenciales usando net use
    .PARAMETER UncPath
        Ruta UNC a verificar (\\servidor\recurso)
    .PARAMETER Credential
        Credenciales opcionales para acceso
    .OUTPUTS
        Hashtable con Success ($true/$false) y Message (descripción)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$UncPath,
        
        [PSCredential]$Credential = $null
    )
    
    try {
        # Si hay credenciales, intentar montar con net use
        if ($Credential) {
            $username = $Credential.UserName
            $password = $Credential.GetNetworkCredential().Password
            
            # Intentar montar con credenciales
            $netUseCmd = "net use `"$UncPath`" /user:$username $password 2>&1"
            $result = Invoke-Expression $netUseCmd
            
            if ($LASTEXITCODE -eq 0) {
                # Verificar acceso real
                if (Test-Path $UncPath) {
                    return @{
                        Success = $true
                        Message = "Acceso exitoso con credenciales"
                    }
                }
                else {
                    return @{
                        Success = $false
                        Message = "Credenciales aceptadas pero ruta no accesible"
                    }
                }
            }
            else {
                return @{
                    Success = $false
                    Message = "Credenciales incorrectas o acceso denegado"
                }
            }
        }
        else {
            # Sin credenciales, intentar acceso directo
            if (Test-Path $UncPath) {
                return @{
                    Success = $true
                    Message = "Acceso exitoso sin credenciales"
                }
            }
            else {
                return @{
                    Success = $false
                    Message = "No se puede acceder (puede requerir credenciales)"
                }
            }
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Error: $($_.Exception.Message)"
        }
    }
}

function Get-ComputerShares {
    <#
    .SYNOPSIS
        Lista los recursos compartidos de un equipo
    .DESCRIPTION
        Obtiene lista de carpetas compartidas usando net view
    .PARAMETER ComputerName
        Nombre del equipo (sin \\)
    .PARAMETER Credential
        Credenciales opcionales (no usado actualmente)
    .OUTPUTS
        Array de objetos con Name y Path (\\equipo\recurso)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        
        [PSCredential]$Credential = $null
    )
    
    $shares = @()
    
    try {
        # Usar net view para listar shares
        $netViewOutput = net view "\\$ComputerName" 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            $inShareList = $false
            
            foreach ($line in $netViewOutput) {
                # Detectar inicio de lista de shares (línea con guiones)
                if ($line -match '^\-{3,}') {
                    $inShareList = $true
                    continue
                }
                
                # Extraer shares
                if ($inShareList -and $line.Trim() -ne '') {
                    # Primera columna es el nombre del share
                    $parts = $line -split '\s{2,}'
                    if ($parts.Count -gt 0) {
                        $shareName = $parts[0].Trim()
                        if ($shareName -and $shareName -ne '') {
                            $shares += [PSCustomObject]@{
                                Name = $shareName
                                Path = "\\$ComputerName\$shareName"
                            }
                        }
                    }
                }
            }
        }
    }
    catch {
        # Ignorar errores
        Write-Log "Error al listar shares de $ComputerName`: $($_.Exception.Message)" "WARNING"
    }
    
    return $shares
}

function Select-NetworkPath {
    <#
    .SYNOPSIS
        Menú interactivo para seleccionar ruta UNC
    .DESCRIPTION
        Permite descubrir equipos en red o ingresar ruta manual
    .PARAMETER Purpose
        Propósito de la selección (ej: "ORIGEN", "DESTINO")
    .OUTPUTS
        String con ruta UNC seleccionada o $null si canceló
    #>
    param(
        [string]$Purpose = "DESTINO"
    )
    
    $options = @(
        "*Descubrir equipos en la red (automático)",
        "Ingresar ruta *Manual (\\servidor\carpeta)"
    )
    
    $selection = Show-DosMenu -Title "RED UNC - $Purpose" -Items $options -CancelValue 0
    
    if ($selection -eq 0) {
        return $null  # Cancelado
    }
    
    if ($selection -eq 1) {
        # Descubrimiento automático
        $computers = Get-NetworkComputers
        
        if ($computers.Count -eq 0) {
            Write-Host ""
            Write-Host "No se encontraron equipos. Ingrese ruta manualmente." -ForegroundColor Yellow
            $selection = 2  # Forzar entrada manual
        }
        else {
            # Mostrar menú con equipos encontrados
            $computerNames = $computers | ForEach-Object { $_.Name }
            $compSelection = Show-DosMenu -Title "EQUIPOS ENCONTRADOS" -Items $computerNames -CancelValue 0
            
            if ($compSelection -eq 0) {
                return $null  # Cancelado
            }
            
            $selectedComputer = $computers[$compSelection - 1]
            
            # Listar shares del equipo seleccionado
            Write-Host ""
            Write-Host "Buscando recursos compartidos en $($selectedComputer.Name)..." -ForegroundColor Cyan
            $shares = Get-ComputerShares -ComputerName $selectedComputer.Name
            
            if ($shares.Count -eq 0) {
                Write-Host "No se encontraron recursos compartidos." -ForegroundColor Yellow
                Write-Host "Ingrese la ruta manualmente." -ForegroundColor Gray
                $selection = 2
            }
            else {
                $shareNames = $shares | ForEach-Object { $_.Name }
                $shareSelection = Show-DosMenu -Title "RECURSOS COMPARTIDOS" -Items $shareNames -CancelValue 0
                
                if ($shareSelection -eq 0) {
                    return $null  # Cancelado
                }
                
                return $shares[$shareSelection - 1].Path
            }
        }
    }
    
    if ($selection -eq 2) {
        # Entrada manual
        Write-Host ""
        Write-Host "Ingrese ruta UNC (ej: \\servidor\carpeta): " -NoNewline -ForegroundColor Cyan
        $manualPath = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($manualPath)) {
            return $null
        }
        
        # Validar formato básico
        if ($manualPath -notlike "\\*") {
            $manualPath = "\\$manualPath"
        }
        
        return $manualPath
    }
    
    return $null
}

function Split-UncRootAndPath {
    <#
    .SYNOPSIS
        Divide ruta UNC en raíz (\\servidor\recurso) y subdirectorio
    .DESCRIPTION
        Separa la ruta UNC en componente de montaje y ruta relativa
    .PARAMETER Path
        Ruta UNC completa (ej: \\servidor\recurso\carpeta\archivo.txt)
    .OUTPUTS
        Array con [raíz, subdirectorio]
    #>
    param([string]$Path)
    
    if ($Path -notlike "\\*") {
        return @($null, $null)
    }
    
    # Remover \\ inicial
    $cleanPath = $Path.TrimStart('\')
    
    # Dividir en componentes
    $parts = $cleanPath -split '\\'
    
    if ($parts.Count -lt 2) {
        return @($Path, $null)
    }
    
    # Raíz = \\servidor\recurso
    $root = "\\$($parts[0])\$($parts[1])"
    
    # Resto = subdirectorio
    if ($parts.Count -gt 2) {
        $rest = '\' + ($parts[2..($parts.Count - 1)] -join '\')
    }
    else {
        $rest = $null
    }
    
    return @($root, $rest)
}

function Mount-LlevarNetworkPath {
    <#
    .SYNOPSIS
        Monta ruta UNC o FTP como PSDrive
    .DESCRIPTION
        Crea PSDrive para acceso a red, manejando credenciales y reintentos
    .PARAMETER Path
        Ruta UNC (\\servidor\recurso) o FTP (ftp://servidor)
    .PARAMETER Credential
        Credenciales para autenticación
    .PARAMETER DriveName
        Nombre de la unidad a crear
    .OUTPUTS
        String con ruta mapeada (X:\ o FTP:nombre)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [pscredential]$Credential = $null,
        
        [Parameter(Mandatory = $true)]
        [string]$DriveName
    )
    
    # Verificar si es FTP (delegar a módulo FTP)
    if (Test-IsFtpPath -Path $Path) {
        return Mount-FtpPath -Path $Path -Credential $Credential -DriveName $DriveName
    }
    
    # Continuar con lógica UNC
    if (-not $Path -or $Path -notlike "\\*") {
        return $Path  # No es UNC, retornar tal cual
    }
    
    # Dividir en raíz y subdirectorio
    $parts = Split-UncRootAndPath -Path $Path
    $root = $parts[0]
    $rest = $parts[1]
    
    if (-not $root) { 
        return $Path 
    }
    
    # Intentar montar con reintentos
    while ($true) {
        # Remover PSDrive existente si lo hay
        if (Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue) {
            Remove-PSDrive -Name $DriveName -ErrorAction SilentlyContinue
        }
        
        try {
            if ($Credential) {
                New-PSDrive -Name $DriveName -PSProvider FileSystem -Root $root -Credential $Credential -ErrorAction Stop | Out-Null
            }
            else {
                # Intento sin credenciales
                New-PSDrive -Name $DriveName -PSProvider FileSystem -Root $root -ErrorAction Stop | Out-Null
            }
            
            Write-Log "PSDrive montado: $DriveName = $root" "INFO"
            break  # Éxito
        }
        catch {
            # Solo interactuar si no se pasaron credenciales
            if (-not $Credential) {
                Write-Host ""
                Write-Host "Error al acceder a $root" -ForegroundColor Red
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host ""
                
                $choice = Show-DosMenu -Title "Error de Red" `
                    -Items @("*Ingresar credenciales", "*Cancelar") `
                    -CancelValue 1
                
                if ($choice -eq 1) {
                    # Ingresar credenciales
                    $Credential = Get-Credential -Message "Credenciales para $root"
                    if (-not $Credential) {
                        throw "Se requieren credenciales para acceder a $root"
                    }
                    continue  # Reintentar con credenciales
                }
                else {
                    throw "No se pudo acceder a $root"
                }
            }
            else {
                # Ya se tenían credenciales y falló
                throw "No se pudo acceder a $root con las credenciales proporcionadas"
            }
        }
    }
    
    # Construir ruta final
    $driveRoot = "${DriveName}:\"
    
    if ($rest) {
        $sub = $rest.TrimStart('\')
        return (Join-Path $driveRoot $sub)
    }
    else {
        return $driveRoot
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Get-NetworkComputers',
    'Test-UncPathAccess',
    'Get-ComputerShares',
    'Select-NetworkPath',
    'Split-UncRootAndPath',
    'Mount-LlevarNetworkPath'
)
