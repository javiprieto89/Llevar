# ========================================================================== #
#                    MÓDULO: MENÚS DE CONFIGURACIÓN                          #
# ========================================================================== #
# Propósito: Menús de alto nivel para configuración de Llevar.ps1
# Funciones:
#   - Show-MainMenu: Menú principal de la aplicación
#   - Show-OrigenMenu: Configuración de origen
#   - Show-DestinoMenu: Configuración de destino  
#   - Show-BlockSizeMenu: Configuración de tamaño de bloque
#   - Show-PasswordMenu: Configuración de contraseña
#   - Show-IsoMenu: Configuración de generación ISO
# ========================================================================== #

function Show-MainMenu {
    <#
    .SYNOPSIS
        Menú principal interactivo de Llevar.ps1
    #>
    
    $config = @{
        # Configuración de Origen
        Origen         = @{
            Tipo           = "Local"  # Local, FTP, OneDrive, Dropbox, UNC, USB
            Path           = $null
            # Solo para FTP
            FtpServer      = $null
            FtpPort        = 21
            FtpDirectory   = "/"
            FtpUser        = $null
            FtpPassword    = $null
            # Solo para UNC/Red
            UncPath        = $null
            UncUser        = $null
            UncPassword    = $null
            UncDomain      = $null
            # Solo para Local/USB
            LocalPath      = $null
            DriveLetter    = $null
            # Solo para OneDrive
            OneDriveEmail  = $null
            OneDriveToken  = $null
            OneDriveApiUrl = "https://graph.microsoft.com/v1.0/me/drive"
            # Solo para Dropbox
            DropboxToken   = $null
            DropboxApiUrl  = "https://api.dropboxapi.com/2"
        }
        
        # Configuración de Destino
        Destino        = @{
            Tipo           = "Local"  # Local, FTP, OneDrive, Dropbox, UNC, USB
            Path           = $null
            # Solo para FTP
            FtpServer      = $null
            FtpPort        = 21
            FtpDirectory   = "/"
            FtpUser        = $null
            FtpPassword    = $null
            # Solo para UNC/Red
            UncPath        = $null
            UncUser        = $null
            UncPassword    = $null
            UncDomain      = $null
            # Solo para Local/USB
            LocalPath      = $null
            DriveLetter    = $null
            # Solo para OneDrive
            OneDriveEmail  = $null
            OneDriveToken  = $null
            OneDriveApiUrl = "https://graph.microsoft.com/v1.0/me/drive"
            # Solo para Dropbox
            DropboxToken   = $null
            DropboxApiUrl  = "https://api.dropboxapi.com/2"
        }
        
        # Configuración general
        BlockSizeMB    = 10
        Clave          = $null
        UseNativeZip   = $false
        Iso            = $false
        IsoDestino     = "dvd"
        RobocopyMirror = $false
    }
    
    while ($true) {
        # Construir display del origen
        $origenDisplay = $config.Origen.Tipo
        if ($config.Origen.Path) {
            $origenDisplay += " → $($config.Origen.Path)"
        }
        elseif ($config.Origen.FtpServer) {
            $origenDisplay += " → $($config.Origen.FtpServer):$($config.Origen.FtpPort)$($config.Origen.FtpDirectory)"
        }
        elseif ($config.Origen.UncPath) {
            $origenDisplay += " → $($config.Origen.UncPath)"
        }
        
        # Construir display del destino
        $destinoDisplay = $config.Destino.Tipo
        if ($config.Destino.Path) {
            $destinoDisplay += " → $($config.Destino.Path)"
        }
        elseif ($config.Destino.FtpServer) {
            $destinoDisplay += " → $($config.Destino.FtpServer):$($config.Destino.FtpPort)$($config.Destino.FtpDirectory)"
        }
        elseif ($config.Destino.UncPath) {
            $destinoDisplay += " → $($config.Destino.UncPath)"
        }
        
        $options = @(
            "*Origen: $origenDisplay",
            "*Destino: $destinoDisplay",
            "*Tamaño de Bloque: $($config.BlockSizeMB) MB",
            "Modo *Robocopy Mirror",
            "Generar *ISO (en lugar de USB)",
            "Usar ZIP *Nativo (sin 7-Zip)",
            "Configurar Con*traseña",
            "Modo *Ejemplo (Demo)",
            "*Ayuda",
            "*Ejecutar Transferencia....LLEVAR =)"
        )
        
        $selection = Show-DosMenu -Title "LLEVAR - MENÚ PRINCIPAL" -Items $options -CancelValue 0
        
        switch ($selection) {
            0 { return $null }  # Salir
            1 { $config = Show-OrigenMenu -Config $config }
            2 { $config = Show-DestinoMenu -Config $config }
            3 { $config = Show-BlockSizeMenu -Config $config }
            4 { $config.RobocopyMirror = -not $config.RobocopyMirror; if ($config.RobocopyMirror) { Show-ConsolePopup -Title "Robocopy Mirror" -Message "Modo Robocopy Mirror activado`n`nSincronizará origen con destino (elimina extras)" -Options @("*OK") | Out-Null } }
            5 { $config = Show-IsoMenu -Config $config }
            6 { $config.UseNativeZip = -not $config.UseNativeZip; Show-ConsolePopup -Title "ZIP Nativo" -Message "ZIP Nativo: $(if($config.UseNativeZip){'ACTIVADO'}else{'DESACTIVADO'})" -Options @("*OK") | Out-Null }
            7 { $config = Show-PasswordMenu -Config $config }
            8 { return @{ Action = "Example" } }
            9 { return @{ Action = "Help" } }
            10 { 
                # Validar configuración completa antes de ejecutar
                $errores = @()
                
                # Validación específica por tipo para evitar falsos negativos (FTP/UNC vs Local)
                $validateEndpoint = {
                    param($endpoint, $label)
                    switch ($endpoint.Tipo) {
                        'FTP' {
                            if (-not $endpoint.FtpServer) { $errores += "• $label FTP sin servidor configurado" }
                        }
                        'UNC' {
                            if (-not $endpoint.UncPath) { $errores += "• $label UNC sin ruta configurada" }
                        }
                        default {
                            if (-not $endpoint.Path) { $errores += "• $label no configurado" }
                        }
                    }
                }

                & $validateEndpoint $config.Origen  "Origen"
                & $validateEndpoint $config.Destino "Destino"
                
                if ($errores.Count -gt 0) {
                    $mensaje = "Faltan parámetros requeridos:`n`n" + ($errores -join "`n")
                    Show-ConsolePopup -Title "Configuración Incompleta" -Message $mensaje -Options @("*OK") | Out-Null
                    continue
                }
                
                $config.Action = "Execute"
                return $config
            }
        }
    }
}

function Show-OrigenMenu {
    <#
    .SYNOPSIS
        Menú de configuración de origen
    #>
    param($Config)
    
    $options = @(
        "*Local (carpeta del sistema)",
        "*FTP (servidor FTP)",
        "*OneDrive (Microsoft OneDrive)",
        "*Dropbox",
        "*UNC (red compartida)"
    )
    
    $selection = Show-DosMenu -Title "ORIGEN - Seleccione tipo" -Items $options -CancelValue 0
    
    switch ($selection) {
        0 { return $Config }
        1 {
            $Config.Origen.Tipo = "Local"
            $selected = Select-LlevarFolder "Seleccione carpeta de ORIGEN"
            if ($selected) {
                $Config.Origen.Path = $selected
                $Config.Origen.LocalPath = $selected
                # Limpiar campos FTP/UNC
                $Config.Origen.FtpServer = $null
                $Config.Origen.UncPath = $null
            }
        }
        2 {
            $Config.Origen.Tipo = "FTP"
            $ftpConfig = Get-FtpConfigFromUser -Purpose "ORIGEN"
            if ($ftpConfig) {
                $Config.Origen.Path = $ftpConfig.Path
                $Config.Origen.FtpServer = $ftpConfig.Server
                $Config.Origen.FtpPort = $ftpConfig.Port
                $Config.Origen.FtpDirectory = $ftpConfig.Directory
                $Config.Origen.FtpUser = $ftpConfig.User
                $Config.Origen.FtpPassword = $ftpConfig.Password
                # Limpiar campos Local/UNC
                $Config.Origen.LocalPath = $null
                $Config.Origen.UncPath = $null
            }
        }
        3 {
            $Config.Origen.Tipo = "OneDrive"
            $authResult = Get-OneDriveAuth
            if ($authResult) {
                if ($authResult.UseLocal) {
                    # Uso local
                    $Config.Origen.Path = $authResult.LocalPath
                    $Config.Origen.LocalPath = $authResult.LocalPath
                    $Config.Origen.OneDriveEmail = $authResult.Email
                    $Config.Origen.OneDriveToken = $null
                    $Config.Origen.OneDriveApiUrl = $null
                }
                else {
                    # Uso API
                    Write-Host "`nIngrese la ruta en OneDrive (ej: /Documentos/MiCarpeta):" -ForegroundColor Cyan
                    Write-Host "Presione ENTER para ruta raíz (/)" -ForegroundColor Gray
                    $path = Read-Host "Ruta"
                    if ([string]::IsNullOrWhiteSpace($path)) { $path = "/" }
                    
                    $Config.Origen.Path = "onedrive://$path"
                    $Config.Origen.OneDriveEmail = $authResult.Email
                    $Config.Origen.OneDriveToken = $authResult.Token
                    $Config.Origen.OneDriveApiUrl = $authResult.ApiUrl
                    $Config.Origen.LocalPath = $null
                }
                # Limpiar campos FTP/UNC
                $Config.Origen.FtpServer = $null
                $Config.Origen.UncPath = $null
            }
        }
        4 {
            $Config.Origen.Tipo = "Dropbox"
            $authResult = Get-DropboxAuth
            if ($authResult) {
                if ($authResult.UseLocal) {
                    # Uso local
                    $Config.Origen.Path = $authResult.LocalPath
                    $Config.Origen.LocalPath = $authResult.LocalPath
                    $Config.Origen.DropboxToken = $null
                    $Config.Origen.DropboxApiUrl = $null
                }
                else {
                    # Uso API
                    Write-Host "`nIngrese la ruta en Dropbox (ej: /Documentos/MiCarpeta):" -ForegroundColor Cyan
                    Write-Host "Presione ENTER para ruta raíz (/)" -ForegroundColor Gray
                    $path = Read-Host "Ruta"
                    if ([string]::IsNullOrWhiteSpace($path)) { $path = "/" }
                    
                    $Config.Origen.Path = "dropbox://$path"
                    $Config.Origen.DropboxToken = $authResult.Token
                    $Config.Origen.DropboxApiUrl = $authResult.ApiUrl
                    $Config.Origen.LocalPath = $null
                }
                # Limpiar campos FTP/UNC
                $Config.Origen.FtpServer = $null
                $Config.Origen.UncPath = $null
            }
        }
        5 {
            $Config.Origen.Tipo = "UNC"
            $uncResult = Select-NetworkPath -Purpose "ORIGEN"
            
            if ($uncResult) {
                $Config.Origen.Path = $uncResult.Path
                $Config.Origen.UncPath = $uncResult.Path
                if ($uncResult.Credentials) {
                    $Config.Origen.UncUser = $uncResult.Credentials.UserName
                    $Config.Origen.UncPassword = $uncResult.Credentials.GetNetworkCredential().Password
                    $Config.Origen.UncDomain = $uncResult.Credentials.GetNetworkCredential().Domain
                }
                # Limpiar campos FTP/Local
                $Config.Origen.FtpServer = $null
                $Config.Origen.LocalPath = $null
            }
        }
    }
    
    return $Config
}

function Show-DestinoMenu {
    <#
    .SYNOPSIS
        Menú de configuración de destino
    #>
    param($Config)
    
    $options = @(
        "*Local (carpeta del sistema)",
        "*USB (copiar a dispositivos USB)",
        "*Diskettes (disquetes 1.44MB)",
        "*FTP (servidor FTP)",
        "*OneDrive (Microsoft OneDrive)",
        "*Dropbox",
        "U*NC (red compartida)"
    )
    
    $selection = Show-DosMenu -Title "DESTINO - Seleccione tipo" -Items $options -CancelValue 0
    
    switch ($selection) {
        0 { return $Config }
        1 {
            $Config.Destino.Tipo = "Local"
            $selected = Select-LlevarFolder "Seleccione carpeta de DESTINO"
            if ($selected) {
                $Config.Destino.Path = $selected
                $Config.Destino.LocalPath = $selected
                # Limpiar campos FTP/UNC
                $Config.Destino.FtpServer = $null
                $Config.Destino.UncPath = $null
            }
        }
        2 {
            $Config.Destino.Tipo = "USB"
            Show-ConsolePopup -Title "Modo USB" -Message "El programa solicitará USBs durante la transferencia" -Options @("*OK") | Out-Null
            $Config.Destino.Path = "USB"
            # Limpiar campos FTP/UNC/Local
            $Config.Destino.FtpServer = $null
            $Config.Destino.UncPath = $null
            $Config.Destino.LocalPath = $null
        }
        3 {
            $Config.Destino.Tipo = "Floppy"
            
            # Verificar si hay unidad de diskette
            if (-not (Test-FloppyDriveAvailable)) {
                Show-ConsolePopup -Title "Error" -Message "No se detectó una unidad de diskette (A:) en el sistema.`n`nLos diskettes son tecnología obsoleta. Se recomienda usar USB o ISO." -Options @("*OK") | Out-Null
                return $Config
            }
            
            $mensaje = @"
⚠ MODO DISKETTES (LEGACY)

Los diskettes de 1.44MB son medios obsoletos y poco confiables.
Este modo existe solo por compatibilidad histórica.

Características:
• Capacidad: 1.44 MB por diskette
• Máximo: 30 diskettes
• Formateo automático
• Verificación de integridad

¿Desea continuar con diskettes?
"@
            
            $confirmOptions = @("*Sí, usar diskettes", "*No, elegir otro destino")
            $confirm = Show-ConsolePopup -Title "Confirmación" -Message $mensaje -Options $confirmOptions
            
            if ($confirm -eq 1) {
                $Config.Destino.Path = "FLOPPY"
                Show-ConsolePopup -Title "Modo Diskette" -Message "El programa solicitará diskettes durante la transferencia.`nAsegúrese de tener suficientes diskettes vacíos." -Options @("*OK") | Out-Null
                # Limpiar otros campos
                $Config.Destino.FtpServer = $null
                $Config.Destino.UncPath = $null
                $Config.Destino.LocalPath = $null
            }
        }
        4 {
            $Config.Destino.Tipo = "FTP"
            $ftpConfig = Get-FtpConfigFromUser -Purpose "DESTINO"
            if ($ftpConfig) {
                $Config.Destino.Path = $ftpConfig.Path
                $Config.Destino.FtpServer = $ftpConfig.Server
                $Config.Destino.FtpPort = $ftpConfig.Port
                $Config.Destino.FtpDirectory = $ftpConfig.Directory
                $Config.Destino.FtpUser = $ftpConfig.User
                $Config.Destino.FtpPassword = $ftpConfig.Password
                # Limpiar campos Local/UNC
                $Config.Destino.LocalPath = $null
                $Config.Destino.UncPath = $null
            }
        }
        5 {
            $Config.Destino.Tipo = "OneDrive"
            $authResult = Get-OneDriveAuth
            if ($authResult) {
                if ($authResult.UseLocal) {
                    # Uso local
                    $Config.Destino.Path = $authResult.LocalPath
                    $Config.Destino.LocalPath = $authResult.LocalPath
                    $Config.Destino.OneDriveEmail = $authResult.Email
                    $Config.Destino.OneDriveToken = $null
                    $Config.Destino.OneDriveApiUrl = $null
                }
                else {
                    # Uso API
                    Write-Host "`nIngrese la ruta en OneDrive (ej: /Backups/MiCarpeta):" -ForegroundColor Cyan
                    Write-Host "Presione ENTER para ruta raíz (/)" -ForegroundColor Gray
                    $path = Read-Host "Ruta"
                    if ([string]::IsNullOrWhiteSpace($path)) { $path = "/" }
                    
                    $Config.Destino.Path = "onedrive://$path"
                    $Config.Destino.OneDriveEmail = $authResult.Email
                    $Config.Destino.OneDriveToken = $authResult.Token
                    $Config.Destino.OneDriveApiUrl = $authResult.ApiUrl
                    $Config.Destino.LocalPath = $null
                }
                # Limpiar campos FTP/UNC
                $Config.Destino.FtpServer = $null
                $Config.Destino.UncPath = $null
            }
        }
        6 {
            $Config.Destino.Tipo = "Dropbox"
            $authResult = Get-DropboxAuth
            if ($authResult) {
                if ($authResult.UseLocal) {
                    # Uso local
                    $Config.Destino.Path = $authResult.LocalPath
                    $Config.Destino.LocalPath = $authResult.LocalPath
                    $Config.Destino.DropboxToken = $null
                    $Config.Destino.DropboxApiUrl = $null
                }
                else {
                    # Uso API
                    Write-Host "`nIngrese la ruta en Dropbox (ej: /Backups/MiCarpeta):" -ForegroundColor Cyan
                    Write-Host "Presione ENTER para ruta raíz (/)" -ForegroundColor Gray
                    $path = Read-Host "Ruta"
                    if ([string]::IsNullOrWhiteSpace($path)) { $path = "/" }
                    
                    $Config.Destino.Path = "dropbox://$path"
                    $Config.Destino.DropboxToken = $authResult.Token
                    $Config.Destino.DropboxApiUrl = $authResult.ApiUrl
                    $Config.Destino.LocalPath = $null
                }
                # Limpiar campos FTP/UNC
                $Config.Destino.FtpServer = $null
                $Config.Destino.UncPath = $null
            }
        }
        7 {
            $Config.Destino.Tipo = "UNC"
            $uncResult = Select-NetworkPath -Purpose "DESTINO"
            
            if ($uncResult) {
                $Config.Destino.Path = $uncResult.Path
                $Config.Destino.UncPath = $uncResult.Path
                if ($uncResult.Credentials) {
                    $Config.Destino.UncUser = $uncResult.Credentials.UserName
                    $Config.Destino.UncPassword = $uncResult.Credentials.GetNetworkCredential().Password
                    $Config.Destino.UncDomain = $uncResult.Credentials.GetNetworkCredential().Domain
                }
                # Limpiar campos FTP/Local
                $Config.Destino.FtpServer = $null
                $Config.Destino.LocalPath = $null
            }
        }
    }
    
    return $Config
}

function Show-BlockSizeMenu {
    <#
    .SYNOPSIS
        Menú de configuración de tamaño de bloque
    #>
    param($Config)
    
    $options = @(
        "*1.44 MB (diskette)",
        "*10 MB (USBs pequeños)",
        "*50 MB (USBs medianos)",
        "*100 MB (USBs grandes)",
        "*500 MB (discos externos)",
        "*1000 MB / 1 GB (discos grandes)",
        "Tamaño *Manual (ingresar valor)"
    )
    
    $currentSize = $Config.BlockSizeMB
    $selection = Show-DosMenu -Title "TAMAÑO DE BLOQUE (Actual: $currentSize MB)" -Items $options -CancelValue 0
    
    switch ($selection) {
        0 { return $Config }  # Cancelar
        1 { 
            # Diskette 1.44MB
            $Config.BlockSizeMB = 1.44
            Show-ConsolePopup -Title "Tamaño de Bloque" -Message "Configurado: 1.44 MB (diskette)`n`n⚠ Solo compatible con 7-Zip`n(ZIP nativo no soporta tamaños menores a 2 MB)" -Options @("*OK") | Out-Null
        }
        2 { 
            # 10 MB
            $Config.BlockSizeMB = 10
            Show-ConsolePopup -Title "Tamaño de Bloque" -Message "Configurado: 10 MB" -Options @("*OK") | Out-Null
        }
        3 { 
            # 50 MB
            $Config.BlockSizeMB = 50
            Show-ConsolePopup -Title "Tamaño de Bloque" -Message "Configurado: 50 MB" -Options @("*OK") | Out-Null
        }
        4 { 
            # 100 MB
            $Config.BlockSizeMB = 100
            Show-ConsolePopup -Title "Tamaño de Bloque" -Message "Configurado: 100 MB" -Options @("*OK") | Out-Null
        }
        5 { 
            # 500 MB
            $Config.BlockSizeMB = 500
            Show-ConsolePopup -Title "Tamaño de Bloque" -Message "Configurado: 500 MB" -Options @("*OK") | Out-Null
        }
        6 { 
            # 1 GB
            $Config.BlockSizeMB = 1000
            Show-ConsolePopup -Title "Tamaño de Bloque" -Message "Configurado: 1000 MB (1 GB)" -Options @("*OK") | Out-Null
        }
        7 {
            # Manual
            Show-Banner "TAMAÑO MANUAL" -BorderColor Cyan -TextColor Yellow
            Write-Host ""
            Write-Host "Tamaño actual: $($Config.BlockSizeMB) MB" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Límites según compresor:" -ForegroundColor Gray
            Write-Host "  • 7-Zip:      0.001 MB - 2048 MB (2 GB)" -ForegroundColor DarkGray
            Write-Host "  • ZIP Nativo: 2 MB - 2048 MB (2 GB)" -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "Ingrese tamaño en MB (ENTER para cancelar): " -NoNewline -ForegroundColor Cyan
            $userInput = Read-Host
            
            if (-not [string]::IsNullOrWhiteSpace($userInput)) {
                $newSize = 0.0
                if ([double]::TryParse($userInput, [ref]$newSize)) {
                    # Validar límites
                    if ($newSize -le 0) {
                        Show-ConsolePopup -Title "Error" -Message "El tamaño debe ser mayor a 0 MB" -Options @("*OK") | Out-Null
                    }
                    elseif ($newSize -gt 2048) {
                        Show-ConsolePopup -Title "Error" -Message "El tamaño máximo es 2048 MB (2 GB)" -Options @("*OK") | Out-Null
                    }
                    elseif ($newSize -lt 2 -and $Config.UseNativeZip) {
                        Show-ConsolePopup -Title "Error" -Message "ZIP nativo requiere mínimo 2 MB`n`nUse 7-Zip para tamaños menores o aumente el tamaño." -Options @("*OK") | Out-Null
                    }
                    else {
                        $Config.BlockSizeMB = $newSize
                        
                        $mensaje = "Tamaño configurado: $newSize MB"
                        if ($newSize -lt 2) {
                            $mensaje += "`n`n⚠ Requiere 7-Zip (ZIP nativo no soporta tamaños menores a 2 MB)"
                        }
                        
                        Show-ConsolePopup -Title "Tamaño de Bloque" -Message $mensaje -Options @("*OK") | Out-Null
                    }
                }
                else {
                    Show-ConsolePopup -Title "Error" -Message "Valor inválido. Ingrese un número decimal válido.`n`nEjemplo: 1.44 o 10.5" -Options @("*OK") | Out-Null
                }
            }
        }
    }
    
    return $Config
}

function Show-PasswordMenu {
    <#
    .SYNOPSIS
        Menú de configuración de contraseña
    #>
    param($Config)
    
    if ($Config.Clave) {
        $options = @(
            "*Cambiar contraseña",
            "*Eliminar contraseña"
        )
        $selection = Show-DosMenu -Title "CONTRASEÑA (Actual: ******)" -Items $options -CancelValue 0
        
        if ($selection -eq 0) { return $Config }
        if ($selection -eq 2) {
            $Config.Clave = $null
            Show-ConsolePopup -Title "Contraseña" -Message "Contraseña eliminada" -Options @("*OK") | Out-Null
            return $Config
        }
    }
    
    Show-Banner "CONFIGURAR CONTRASEÑA" -BorderColor Cyan -TextColor Yellow
    Write-Host "⚠ NOTA: Solo funciona con 7-Zip (no con ZIP nativo)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Ingrese contraseña (ENTER para cancelar): " -NoNewline -ForegroundColor Cyan
    $pass1 = Read-Host -AsSecureString
    
    if ($pass1.Length -eq 0) {
        return $Config
    }
    
    Write-Host "Confirme contraseña: " -NoNewline -ForegroundColor Cyan
    $pass2 = Read-Host -AsSecureString
    
    $ptr1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass1)
    $ptr2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass2)
    $plainPass1 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr1)
    $plainPass2 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr2)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr1)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr2)
    
    if ($plainPass1 -eq $plainPass2) {
        $Config.Clave = $plainPass1
        Show-ConsolePopup -Title "Contraseña" -Message "Contraseña configurada correctamente" -Options @("*OK") | Out-Null
    }
    else {
        Show-ConsolePopup -Title "Error" -Message "Las contraseñas no coinciden" -Options @("*OK") | Out-Null
    }
    
    return $Config
}

function Show-IsoMenu {
    <#
    .SYNOPSIS
        Menú de configuración ISO
    #>
    param($Config)
    
    $config.Iso = -not $config.Iso
    
    if ($config.Iso) {
        $options = @(
            "*CD (700 MB)",
            "*DVD (4.5 GB)",
            "*USB (4.5 GB)"
        )
        
        $selection = Show-DosMenu -Title "TIPO DE ISO" -Items $options -CancelValue 0 -DefaultValue 2
        
        switch ($selection) {
            0 { 
                $config.Iso = $false
                return $Config 
            }
            1 { $config.IsoDestino = "cd" }
            2 { $config.IsoDestino = "dvd" }
            3 { $config.IsoDestino = "usb" }
        }
        
        Show-ConsolePopup -Title "Modo ISO" -Message "Se generarán imágenes ISO de tipo: $($config.IsoDestino.ToUpper())" -Options @("*OK") | Out-Null
    }
    else {
        Show-ConsolePopup -Title "Modo ISO" -Message "Modo ISO desactivado" -Options @("*OK") | Out-Null
    }
    
    return $Config
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Show-MainMenu',
    'Show-OrigenMenu',
    'Show-DestinoMenu',
    'Show-BlockSizeMenu',
    'Show-PasswordMenu',
    'Show-IsoMenu'
)
