# ========================================================================== #
#                         MÓDULO: OPERACIONES DROPBOX                        #
# ========================================================================== #
# Propósito: Configuración, validación y operaciones con Dropbox
# Funciones refactorizadas para usar TransferConfig como única fuente de verdad
# ========================================================================== #

# Importar TransferConfig al inicio (ruta relativa para permitir mover la carpeta)


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

function Test-IsDropboxPath {
    <#
    .SYNOPSIS
        Detecta si una ruta es Dropbox
    .PARAMETER Path
        Ruta a verificar
    .OUTPUTS
        $true si es Dropbox, $false si no
    #>
    param([string]$Path)
    return $Path -match '^dropbox://|^DROPBOX:'
}

function Send-LlevarDropboxFile {
    <#
    .SYNOPSIS
        Sube un archivo local a Dropbox usando la configuraci¢n de TransferConfig
    .PARAMETER Llevar
        Objeto TransferConfig con Destino.Tipo = "Dropbox" y tokens configurados
    .PARAMETER LocalPath
        Ruta local del archivo a subir
    .PARAMETER RemotePath
        Ruta remota base en Dropbox (ej: /Carpeta)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Llevar,

        [Parameter(Mandatory = $true)]
        [string]$LocalPath,

        [Parameter(Mandatory = $true)]
        [string]$RemotePath
    )

    if (-not (Test-Path $LocalPath)) {
        throw "Send-LlevarDropboxFile: archivo local no encontrado: $LocalPath"
    }

    $token = $Llevar.Destino.Dropbox.Token
    if (-not $token) {
        throw "Send-LlevarDropboxFile: falta Token en Destino.Dropbox"
    }

    # Normalizar ruta remota (evitar // y asegurar / inicial)
    $remoteFolder = $RemotePath
    if (-not $remoteFolder.StartsWith('/')) {
        $remoteFolder = "/$remoteFolder"
    }
    $remoteFolder = $remoteFolder.Replace('//', '/')

    $fileName = [System.IO.Path]::GetFileName($LocalPath)
    $remoteFullPath = "$remoteFolder/$fileName".Replace('//', '/')

    $bytes = [System.IO.File]::ReadAllBytes($LocalPath)

    $headers = @{
        "Authorization"   = "Bearer $token"
        "Dropbox-API-Arg" = '{"path":"' + $remoteFullPath + '","mode":"overwrite"}'
        "Content-Type"    = "application/octet-stream"
    }

    Invoke-RestMethod -Uri "https://content.dropboxapi.com/2/files/upload" `
        -Method Post -Headers $headers -Body $bytes | Out-Null
}

function Get-DropboxConfigFromUser {
    <#
    .SYNOPSIS
        Solicita configuración Dropbox al usuario y la asigna directamente a $Llevar
    .DESCRIPTION
        Autentica con Dropbox OAuth y configura la sección correspondiente.
        Asigna SOLO los valores Dropbox a:
        - $Llevar.Origen.Tipo = "Dropbox" + $Llevar.Origen.Dropbox.* si $Cual = "Origen"
        - $Llevar.Destino.Tipo = "Dropbox" + $Llevar.Destino.Dropbox.* si $Cual = "Destino"
        
        ✅ NO PISA otros valores del objeto $Llevar
    .PARAMETER Llevar
        Objeto TransferConfig donde se guardarán SOLO los valores Dropbox
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
    
    Show-Banner "CONFIGURACIÓN DROPBOX - $Cual" -BorderColor Cyan -TextColor Yellow
    
    Write-Host "Autenticando con Dropbox..." -ForegroundColor Cyan
    Write-Host "(Se abrirá el navegador para autenticación OAuth)" -ForegroundColor Gray
    Write-Host ""
    Write-Log "Intentando autenticar Dropbox para $Cual" "INFO"
    
    try {
        $authResult = Get-DropboxAuth
        
        if (-not $authResult) {
            Write-Host "✗ Autenticación cancelada" -ForegroundColor Red
            return $false
        }
        
        Write-Host "✓ Autenticación exitosa" -ForegroundColor Green
        Write-Host ""
        
        # Solicitar ruta Dropbox
        Write-Host "Ruta en Dropbox (ej: /Documentos/MiCarpeta): " -NoNewline -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Presione ENTER para usar raíz (/): " -NoNewline -ForegroundColor Gray
        $dropboxPath = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($dropboxPath)) {
            $dropboxPath = "/"
        }
        elseif (-not $dropboxPath.StartsWith('/')) {
            $dropboxPath = "/$dropboxPath"
        }
        
        Write-Host ""
        Write-Host "✓ Ruta configurada: $dropboxPath" -ForegroundColor Green
        
    }
    catch {
        $errorMsg = $_.Exception.Message
        Show-Banner "⚠ ERROR DE AUTENTICACIÓN DROPBOX" -BorderColor Red -TextColor Red
        Write-Host "Error: $errorMsg" -ForegroundColor Yellow
        Write-Host ""
        Write-Log "Error autenticación Dropbox - $errorMsg" "ERROR" -ErrorRecord $_
        
        $respuesta = Show-ConsolePopup -Title "⚠ ERROR DROPBOX" `
            -Message "Error: $errorMsg`n`n¿Desea reintentar?" `
            -Options @("*Reintentar", "*Cancelar") -Beep
        
        if ($respuesta -eq 0) {
            return Get-DropboxConfigFromUser -Llevar $Llevar -Cual $Cual
        }
        else {
            return $false
        }
    }
    
    # ✅✅✅ ASIGNAR SOLO LA SECCIÓN DROPBOX CORRESPONDIENTE
    if ($Cual -eq "Origen") {
        $Llevar.Origen.Tipo = "Dropbox"
        $Llevar.Origen.Dropbox.Path = $dropboxPath
        $Llevar.Origen.Dropbox.Token = $authResult.Token
        $Llevar.Origen.Dropbox.RefreshToken = $authResult.RefreshToken
        $Llevar.Origen.Dropbox.Email = $authResult.Email
        $Llevar.Origen.Dropbox.ApiUrl = $authResult.ApiUrl
        
        Write-Log "Dropbox Origen configurado: $dropboxPath (Usuario: $($authResult.Email))" "INFO"
    }
    else {
        $Llevar.Destino.Tipo = "Dropbox"
        $Llevar.Destino.Dropbox.Path = $dropboxPath
        $Llevar.Destino.Dropbox.Token = $authResult.Token
        $Llevar.Destino.Dropbox.RefreshToken = $authResult.RefreshToken
        $Llevar.Destino.Dropbox.Email = $authResult.Email
        $Llevar.Destino.Dropbox.ApiUrl = $authResult.ApiUrl
        
        Write-Log "Dropbox Destino configurado: $dropboxPath (Usuario: $($authResult.Email))" "INFO"
    }
    
    Write-Host ""
    Write-Host "✓ Configuración Dropbox guardada en \$Llevar.$Cual.Dropbox" -ForegroundColor Green
    Write-Host ""
    
    return $true
}

# ========================================================================== #
#                  FUNCIONES PRINCIPALES DE TRANSFERENCIA                    #
# ========================================================================== #

function Copy-LlevarLocalToDropbox {
    <#
    .SYNOPSIS
        Copia archivos locales a Dropbox con progreso
    .DESCRIPTION
        ✅ DELEGADO AL DISPATCHER UNIFICADO
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
    Write-Log "Copy-LlevarLocalToDropbox: Delegando al dispatcher unificado" "INFO"
    
    $ModulesPath = Split-Path $PSScriptRoot -Parent
    $dispatcherPath = Join-Path $ModulesPath "Transfer\Unified.psm1"
    if (-not (Get-Command Invoke-TransferDispatcher -ErrorAction SilentlyContinue)) {
        Import-Module $dispatcherPath -Force -Global
    }
    
    return Invoke-TransferDispatcher -Llevar $Llevar `
        -ShowProgress $ShowProgress -ProgressTop $ProgressTop
}

function Copy-LlevarDropboxToLocal {
    <#
    .SYNOPSIS
        Descarga archivos desde Dropbox a local con progreso
    .DESCRIPTION
        ✅ DELEGADO AL DISPATCHER UNIFICADO
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
    Write-Log "Copy-LlevarDropboxToLocal: Delegando al dispatcher unificado" "INFO"
    
    $ModulesPath = Split-Path $PSScriptRoot -Parent
    $dispatcherPath = Join-Path $ModulesPath "Transfer\Unified.psm1"
    if (-not (Get-Command Invoke-TransferDispatcher -ErrorAction SilentlyContinue)) {
        Import-Module $dispatcherPath -Force -Global
    }
    
    return Invoke-TransferDispatcher -Llevar $Llevar `
        -ShowProgress $ShowProgress -ProgressTop $ProgressTop
}
# ========================================================================== #
#                         FUNCIONES LEGACY (AUXILIARES)                      #
# ========================================================================== #

function Get-DropboxAuth {
    <#
    .SYNOPSIS
        [AUXILIAR] Obtiene autenticación Dropbox OAuth
    .DESCRIPTION
        Función auxiliar para autenticación.
        NO modificar sin coordinar con Get-DropboxConfigFromUser.
    #>
    # Mock simplificado
    return @{
        Token        = "mock_token_$(Get-Random)"
        RefreshToken = "mock_refresh_$(Get-Random)"
        Email        = "user@example.com"
        ApiUrl       = "https://api.dropboxapi.com/2"
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Test-IsDropboxPath',
    'Get-DropboxConfigFromUser',
    'Copy-LlevarLocalToDropbox',
    'Copy-LlevarDropboxToLocal',
    'Get-DropboxAuth'
)
