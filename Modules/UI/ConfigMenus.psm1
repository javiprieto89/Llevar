# ========================================================================== #
#                    MÓDULO: MENÚS DE CONFIGURACIÓN                          #
# ========================================================================== #
# Propósito: Menús de alto nivel para configuración de Llevar.ps1
# Funciones refactorizadas para usar TransferConfig como única fuente de verdad
# ========================================================================== #

# Cargar clase TransferConfig si no está disponible (GLOBAL SCOPE)
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
        # Dot-source en GLOBAL scope para que el tipo esté disponible en toda la sesión
        $global:__transferConfigScript = $transferConfigType
        Invoke-Expression ". `$global:__transferConfigScript"
    }
    else {
        throw "ERROR CRÍTICO: No se puede cargar TransferConfig.Type.ps1 desde $transferConfigType"
    }
}

# Todos los módulos necesarios ya fueron importados por Llevar.ps1
# Solo verificar que TransferConfig esté disponible
$ModulesPath = Split-Path $PSScriptRoot -Parent
if (-not (Get-Module -Name 'TransferConfig')) {
    Import-Module (Join-Path $ModulesPath "Core\TransferConfig.psm1") -Force -Global
}

# ========================================================================== #
#                          FUNCIÓN PRINCIPAL                                 #
# ========================================================================== #

function Show-MainMenu {
    <#
    .SYNOPSIS
        Menú principal interactivo de Llevar.ps1
    .DESCRIPTION
        Recibe TransferConfig por referencia y lo modifica directamente.
        
        ✅ Se pasa [TransferConfig]$TransferConfig desde el llamador
        ✅ Se modifica directamente cuando el usuario interactúa
        ✅ Origen y Destino son opciones INDEPENDIENTES del menú
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$TransferConfig
    )
    
    while ($true) {
        # Construir display del origen desde TransferConfig
        $origenDisplay = if ($TransferConfig.Origen.Tipo) {
            "$($TransferConfig.Origen.Tipo)"
        }
        else {
            "(No configurado)"
        }
        
        $origenPath = Get-TransferPath -Config $TransferConfig -Section "Origen"
        if ($origenPath) {
            $origenDisplay += " → $origenPath"
        }
        
        # Construir display del destino desde TransferConfig
        $destinoDisplay = if ($TransferConfig.Destino.Tipo) {
            "$($TransferConfig.Destino.Tipo)"
        }
        else {
            "(No configurado)"
        }
        
        $destinoPath = Get-TransferPath -Config $TransferConfig -Section "Destino"
        if ($destinoPath) {
            $destinoDisplay += " → $destinoPath"
        }
        
        $options = @(
            "*Origen: $origenDisplay",
            "*Destino: $destinoDisplay",
            "*Tamaño de Bloque: $($TransferConfig.Opciones.BlockSizeMB) MB",
            "Modo *Robocopy Mirror",
            "Generar *ISO (en lugar de USB)",
            "Usar ZIP *Nativo (sin 7-Zip)",
            "Configurar Con*traseña",
            "Modo *Ejemplo (Demo)",
            "*Ayuda",
            "*Ejecutar Transferencia"
        )
        
        $selection = Show-DosMenu -Title "LLEVAR - MENÚ PRINCIPAL" -Items $options -CancelValue 0
        
        switch ($selection) {
            0 { return $null }  # Salir
            1 { 
                Show-OrigenDestinoMenu -TransferConfig $TransferConfig -Cual "Origen" | Out-Null
            }
            2 { 
                Show-OrigenDestinoMenu -TransferConfig $TransferConfig -Cual "Destino" | Out-Null
            }
            3 { 
                Show-BlockSizeMenu -TransferConfig $TransferConfig | Out-Null
            }
            4 { 
                $currentValue = Get-TransferOption -Config $TransferConfig -Option "RobocopyMirror"
                Set-TransferOption -Config $TransferConfig -Option "RobocopyMirror" -Value (-not $currentValue)
                if (-not $currentValue) { 
                    Show-ConsolePopup -Title "Robocopy Mirror" -Message "Modo Robocopy Mirror activado`n`nSincronizará origen con destino (elimina extras)" -Options @("*OK") | Out-Null 
                }
            }
            5 { 
                Show-IsoMenu -TransferConfig $TransferConfig | Out-Null
            }
            6 { 
                $currentValue = Get-TransferOption -Config $TransferConfig -Option "UseNativeZip"
                Set-TransferOption -Config $TransferConfig -Option "UseNativeZip" -Value (-not $currentValue)
                Show-ConsolePopup -Title "ZIP Nativo" -Message "ZIP Nativo: $(if(-not $currentValue){'ACTIVADO'}else{'DESACTIVADO'})" -Options @("*OK") | Out-Null 
            }
            7 { 
                Show-PasswordMenu -TransferConfig $TransferConfig | Out-Null
            }
            8 { 
                $script:ExampleInfo = Initialize-ExampleTransfer -TransferConfig $TransferConfig
                return @{ Action = "Example" }
            }
            9 { return @{ Action = "Help" } }
            10 {
                # Validar configuración completa
                $errors = @()

                # VALIDAR ORIGEN
                if ($TransferConfig.Origen.Tipo) {
                    $origenPath = switch ($TransferConfig.Origen.Tipo) {
                        "FTP" { $TransferConfig.Origen.FTP.Directory }
                        "Local" { $TransferConfig.Origen.Local.Path }
                        "UNC" { $TransferConfig.Origen.UNC.Path }
                        "OneDrive" { $TransferConfig.Origen.OneDrive.Path }
                        "Dropbox" { $TransferConfig.Origen.Dropbox.Path }
                        default { $null }
                    }

                    if (-not $origenPath) {
                        $errors += "• Falta configurar la ruta de origen ($($TransferConfig.Origen.Tipo))"
                    }
                }
                else {
                    $errors += "• Falta configurar el tipo de origen"
                }
                
                # VALIDAR DESTINO
                $destinoPath = $null
                if ($TransferConfig.Destino.Tipo) {
                    $destinoPath = switch ($TransferConfig.Destino.Tipo) {
                        "FTP" { $TransferConfig.Destino.FTP.Directory }
                        "Local" { $TransferConfig.Destino.Local.Path }
                        "USB" { $TransferConfig.Destino.USB.Path }
                        "UNC" { $TransferConfig.Destino.UNC.Path }
                        "OneDrive" { $TransferConfig.Destino.OneDrive.Path }
                        "Dropbox" { $TransferConfig.Destino.Dropbox.Path }
                        "ISO" { $TransferConfig.Destino.ISO.OutputPath }
                        "Diskette" { $TransferConfig.Destino.Diskette.OutputPath }
                        default { $null }
                    }

                    if (-not $destinoPath) {
                        $errors += "• Falta configurar la ruta de destino ($($TransferConfig.Destino.Tipo))"
                    }
                }
                else {
                    $errors += "• Falta configurar el tipo de destino"
                }

                # MOSTRAR ERRORES / CONTINUAR

                if ($errors.Count -gt 0) {
                    $mensaje = "Faltan parámetros requeridos:`n`n" + ($errors -join "`n")
                    Show-ConsolePopup -Title "Configuración Incompleta" -Message $mensaje -Options @("*OK") | Out-Null 
                    continue
                }

                # ✅ RETORNAR ACCIÓN - TransferConfig ya está modificado
                return @{ Action = "Execute" }
            }
        }
    }
}

# ========================================================================== #
#                          SUBMENÚS DE CONFIGURACIÓN                         #
# ========================================================================== #

function Show-OrigenDestinoMenu {
    <#
    .SYNOPSIS
        Menú unificado de configuración de origen/destino usando TransferConfig
    .PARAMETER TransferConfig
        Referencia al objeto TransferConfig que se modificará directamente
    .PARAMETER Cual
        "Origen" o "Destino" para indicar qué se está configurando
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$TransferConfig,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Cual
    )
    
    if ($Cual -eq "Origen") {
        $options = @(
            "*Local (carpeta del sistema)",
            "*FTP (servidor FTP)",
            "*OneDrive (Microsoft OneDrive)",
            "*Dropbox",
            "*UNC (red compartida)"
        )
    }
    else {
        $options = @(
            "*Local (carpeta del sistema)",
            "*USB (copiar a dispositivos USB)",
            "*Diskettes (disquetes 1.44MB)",
            "*FTP (servidor FTP)",
            "*OneDrive (Microsoft OneDrive)",
            "*Dropbox",
            "U*NC (red compartida)"
        )
    }
    
    $selection = Show-DosMenu -Title "$Cual - Seleccione tipo" -Items $options -CancelValue 0
    
    if ($selection -eq 0) { return }
    
    if ($Cual -eq "Origen") {
        switch ($selection) {
            1 {
                $selected = Select-PathNavigator -Prompt "Seleccione carpeta de ORIGEN" -AllowFiles $false
                if ($selected) {
                    Set-TransferType -Config $TransferConfig -Section "Origen" -Type "Local"
                    Set-TransferPath -Config $TransferConfig -Section "Origen" -Value $selected
                    Set-TransferConfigValue -Config $TransferConfig -Path "OrigenIsSet" -Value $true
                }
            }
            2 {
                if (Get-FtpConfigFromUser -Llevar $TransferConfig -Cual "Origen") {
                    Set-TransferConfigValue -Config $TransferConfig -Path "OrigenIsSet" -Value $true
                }
            }
            3 {
                if (Get-OneDriveConfigFromUser -Llevar $TransferConfig -Cual "Origen") {
                    Set-TransferConfigValue -Config $TransferConfig -Path "OrigenIsSet" -Value $true
                }
            }
            4 {
                if (Get-DropboxConfigFromUser -Llevar $TransferConfig -Cual "Origen") {
                    Set-TransferConfigValue -Config $TransferConfig -Path "OrigenIsSet" -Value $true
                }
            }
            5 {
                if (Get-UncConfigFromUser -Llevar $TransferConfig -Cual "Origen") {
                    Set-TransferConfigValue -Config $TransferConfig -Path "OrigenIsSet" -Value $true
                }
            }
        }
    }
    else {
        switch ($selection) {
            1 {
                $selected = Select-PathNavigator -Prompt "Seleccione carpeta de DESTINO" -AllowFiles $false
                if ($selected) {
                    Set-TransferType -Config $TransferConfig -Section "Destino" -Type "Local"
                    Set-TransferPath -Config $TransferConfig -Section "Destino" -Value $selected
                    Set-TransferConfigValue -Config $TransferConfig -Path "DestinoIsSet" -Value $true
                }
            }
            2 {
                Show-ConsolePopup -Title "Modo USB" -Message "El programa solicitará USBs durante la transferencia" -Options @("*OK") | Out-Null
                Set-TransferType -Config $TransferConfig -Section "Destino" -Type "USB"
                Set-TransferPath -Config $TransferConfig -Section "Destino" -Value "USB"
                Set-TransferConfigValue -Config $TransferConfig -Path "DestinoIsSet" -Value $true
            }
            3 {
                if (-not (Test-FloppyDriveAvailable)) {
                    Show-ConsolePopup -Title "Error" -Message "No se detectó una unidad de diskette (A:)" -Options @("*OK") | Out-Null
                    return
                }
                
                $confirm = Show-ConsolePopup -Title "⚠ DISKETTES (LEGACY)" `
                    -Message "Los diskettes son medios obsoletos.`n`n¿Desea continuar?" `
                    -Options @("*Sí", "*No")
                
                if ($confirm -eq 0) {
                    Set-TransferType -Config $TransferConfig -Section "Destino" -Type "Diskette"
                    Set-TransferConfigValue -Config $TransferConfig -Path "Destino.Diskette.OutputPath" -Value $env:TEMP
                    Set-TransferConfigValue -Config $TransferConfig -Path "Destino.Diskette.MaxDisks" -Value 30
                    Set-TransferConfigValue -Config $TransferConfig -Path "DestinoIsSet" -Value $true
                }
            }
            4 {
                if (Get-FtpConfigFromUser -Llevar $TransferConfig -Cual "Destino") {
                    Set-TransferConfigValue -Config $TransferConfig -Path "DestinoIsSet" -Value $true
                }
            }
            5 {
                if (Get-OneDriveConfigFromUser -Llevar $TransferConfig -Cual "Destino") {
                    Set-TransferConfigValue -Config $TransferConfig -Path "DestinoIsSet" -Value $true
                }
            }
            6 {
                if (Get-DropboxConfigFromUser -Llevar $TransferConfig -Cual "Destino") {
                    Set-TransferConfigValue -Config $TransferConfig -Path "DestinoIsSet" -Value $true
                }
            }
            7 {
                if (Get-UncConfigFromUser -Llevar $TransferConfig -Cual "Destino") {
                    Set-TransferConfigValue -Config $TransferConfig -Path "DestinoIsSet" -Value $true
                }
            }
        }
    }
}

function Show-BlockSizeMenu {
    <#
    .SYNOPSIS
        Menú de configuración de tamaño de bloque
    .PARAMETER TransferConfig
        Referencia al objeto TransferConfig que se modificará directamente
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$TransferConfig
    )
    
    $options = @(
        "*1.44 MB (diskette)",
        "*10 MB (USBs pequeños)",
        "*50 MB (USBs medianos)",
        "*100 MB (USBs grandes)",
        "*500 MB (discos externos)",
        "*1000 MB / 1 GB (discos grandes)",
        "Tamaño *Manual"
    )
    
    $currentSize = $TransferConfig.Opciones.BlockSizeMB
    $selection = Show-DosMenu -Title "TAMAÑO DE BLOQUE (Actual: $currentSize MB)" -Items $options -CancelValue 0
    
    $newSize = switch ($selection) {
        0 { return }
        1 { 1.44 }
        2 { 10 }
        3 { 50 }
        4 { 100 }
        5 { 500 }
        6 { 1000 }
        7 {
            Write-Host ""
            Write-Host "Tamaño actual: $currentSize MB" -ForegroundColor Cyan
            Write-Host "Ingrese tamaño en MB (ENTER para cancelar): " -NoNewline -ForegroundColor Cyan
            $userInput = Read-Host
            
            if ([string]::IsNullOrWhiteSpace($userInput)) { return }
            
            $parsed = 0.0
            if ([double]::TryParse($userInput, [ref]$parsed) -and $parsed -gt 0 -and $parsed -le 2048) {
                $parsed
            }
            else {
                Show-ConsolePopup -Title "Error" -Message "Valor inválido. Debe estar entre 0 y 2048 MB" -Options @("*OK") | Out-Null
                return
            }
        }
        default { return }
    }
    
    if ($newSize) {
        Set-TransferOption -Config $TransferConfig -Option "BlockSizeMB" -Value $newSize
        Show-ConsolePopup -Title "Tamaño de Bloque" -Message "Configurado: $newSize MB" -Options @("*OK") | Out-Null
    }
}

function Show-PasswordMenu {
    <#
    .SYNOPSIS
        Menú de configuración de contraseña
    .PARAMETER TransferConfig
        Referencia al objeto TransferConfig que se modificará directamente
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$TransferConfig
    )
    
    if ($TransferConfig.Opciones.Clave) {
        $options = @("*Cambiar contraseña", "*Eliminar contraseña")
        $selection = Show-DosMenu -Title "CONTRASEÑA (Actual: ******)" -Items $options -CancelValue 0
        
        if ($selection -eq 0) { return }
        if ($selection -eq 2) {
            Set-TransferOption -Config $TransferConfig -Option "Clave" -Value $null
            Show-ConsolePopup -Title "Contraseña" -Message "Contraseña eliminada" -Options @("*OK") | Out-Null
            return
        }
    }
    
    Write-Host ""
    Write-Host "Ingrese contraseña (ENTER para cancelar): " -NoNewline -ForegroundColor Cyan
    $pass1 = Read-Host -AsSecureString
    
    if ($pass1.Length -eq 0) { return }
    
    Write-Host "Confirme contraseña: " -NoNewline -ForegroundColor Cyan
    $pass2 = Read-Host -AsSecureString
    
    $ptr1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass1)
    $ptr2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass2)
    $plainPass1 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr1)
    $plainPass2 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr2)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr1)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr2)
    
    if ($plainPass1 -eq $plainPass2) {
        Set-TransferOption -Config $TransferConfig -Option "Clave" -Value $plainPass1
        Show-ConsolePopup -Title "Contraseña" -Message "Contraseña configurada correctamente" -Options @("*OK") | Out-Null
    }
    else {
        Show-ConsolePopup -Title "Error" -Message "Las contraseñas no coinciden" -Options @("*OK") | Out-Null
    }
}

function Show-IsoMenu {
    <#
    .SYNOPSIS
        Menú de configuración ISO
    .PARAMETER TransferConfig
        Referencia al objeto TransferConfig que se modificará directamente
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$TransferConfig
    )
    
    $wasISO = ($TransferConfig.Destino.Tipo -eq "ISO")
    
    if (-not $wasISO) {
        $options = @("*CD (700 MB)", "*DVD (4.5 GB)", "*USB (4.5 GB)")
        $selection = Show-DosMenu -Title "TIPO DE ISO" -Items $options -CancelValue 0 -DefaultValue 2
        
        if ($selection -eq 0) { return }
        
        $isoSize = switch ($selection) {
            1 { "cd" }
            2 { "dvd" }
            3 { "usb" }
        }
        
        Set-TransferType -Config $TransferConfig -Section "Destino" -Type "ISO"
        Set-TransferConfigValue -Config $TransferConfig -Path "Destino.ISO.OutputPath" -Value $env:TEMP
        Set-TransferConfigValue -Config $TransferConfig -Path "Destino.ISO.Size" -Value $isoSize
        
        Show-ConsolePopup -Title "Modo ISO" -Message "Se generar\u00e1n im\u00e1genes ISO de tipo: $($isoSize.ToUpper())" -Options @("*OK") | Out-Null
    }
    else {
        Set-TransferType -Config $TransferConfig -Section "Destino" -Type "Local"
        Set-TransferPath -Config $TransferConfig -Section "Destino" -Value $null
        Show-ConsolePopup -Title "Modo ISO" -Message "Modo ISO desactivado" -Options @("*OK") | Out-Null
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Show-MainMenu',
    'Show-OrigenDestinoMenu',
    'Show-BlockSizeMenu',
    'Show-PasswordMenu',
    'Show-IsoMenu'
)
