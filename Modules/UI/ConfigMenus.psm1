# Importar TransferConfig al inicio del módulo
using module "Q:\Utilidad\LLevar\Modules\Core\TransferConfig.psm1"

# ========================================================================== #
#                    MÓDULO: MENÚS DE CONFIGURACIÓN                          #
# ========================================================================== #
# Propósito: Menús de alto nivel para configuración de Llevar.ps1
# Funciones refactorizadas para usar TransferConfig como única fuente de verdad
# ========================================================================== #

# Importar módulos necesarios
$ModulesPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ModulesPath "Modules\UI\Menus.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\UI\Banners.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\UI\Navigator.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Transfer\FTP.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Transfer\OneDrive.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Transfer\Dropbox.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Transfer\UNC.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Transfer\Floppy.psm1") -Force -Global

# ========================================================================== #
#                          FUNCIÓN PRINCIPAL                                 #
# ========================================================================== #

function Show-MainMenu {
    <#
    .SYNOPSIS
        Menú principal interactivo de Llevar.ps1
    .DESCRIPTION
        Crea y mantiene una instancia única de TransferConfig que se modifica
        directamente por las funciones del menú.
        
        ✅ $llevar se inicializa UNA SOLA VEZ al inicio
        ✅ Se modifica directamente cuando el usuario interactúa
        ✅ Origen y Destino son opciones INDEPENDIENTES del menú
    #>
    
    # ✅ CREAR INSTANCIA ÚNICA DE TRANSFERCONFIG
    $llevar = [TransferConfig]::new()
    
    while ($true) {
        # Construir display del origen desde TransferConfig
        $origenDisplay = if ($llevar.Origen.Tipo) {
            "$($llevar.Origen.Tipo)"
        }
        else {
            "(No configurado)"
        }
        
        $origenPath = switch ($llevar.Origen.Tipo) {
            "Local"   { $llevar.Origen.Local.Path }
            "UNC"     { $llevar.Origen.UNC.Path }
            "FTP"     { $llevar.Origen.FTP.Directory }
            "OneDrive"{ $llevar.Origen.OneDrive.Path }
            "Dropbox" { $llevar.Origen.Dropbox.Path }
            default   { $null }
        }
        if ($origenPath) {
            $origenDisplay += " → $origenPath"
        }
        
        # Construir display del destino desde TransferConfig
        $destinoDisplay = if ($llevar.Destino.Tipo) {
            "$($llevar.Destino.Tipo)"
        }
        else {
            "(No configurado)"
        }
        
        $destinoPath = switch ($llevar.Destino.Tipo) {
            "Local"    { $llevar.Destino.Local.Path }
            "USB"      { $llevar.Destino.USB.Path }
            "UNC"      { $llevar.Destino.UNC.Path }
            "FTP"      { $llevar.Destino.FTP.Directory }
            "OneDrive" { $llevar.Destino.OneDrive.Path }
            "Dropbox"  { $llevar.Destino.Dropbox.Path }
            "ISO"      { $llevar.Destino.ISO.OutputPath }
            "Diskette" { $llevar.Destino.Diskette.OutputPath }
            default    { $null }
        }
        if ($destinoPath) {
            $destinoDisplay += " → $destinoPath"
        }
        
        $options = @(
            "*Origen: $origenDisplay",
            "*Destino: $destinoDisplay",
            "*Tamaño de Bloque: $($llevar.Opciones.BlockSizeMB) MB",
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
                # ✅ PASAR $llevar A SHOW-ORIGENMENU
                Show-OrigenMenu -Llevar $llevar | Out-Null
            }
            2 { 
                # ✅ PASAR $llevar A SHOW-DESTINOMENU
                Show-DestinoMenu -Llevar $llevar | Out-Null
            }
            3 { 
                # ✅ PASAR $llevar A SHOW-BLOCKSIZEMENU
                Show-BlockSizeMenu -Llevar $llevar | Out-Null
            }
            4 { 
                $llevar.Opciones.RobocopyMirror = -not $llevar.Opciones.RobocopyMirror
                if ($llevar.Opciones.RobocopyMirror) { 
                    Show-ConsolePopup -Title "Robocopy Mirror" -Message "Modo Robocopy Mirror activado`n`nSincronizará origen con destino (elimina extras)" -Options @("*OK") | Out-Null 
                }
            }
            5 { 
                # ✅ PASAR $llevar A SHOW-ISOMENU
                Show-IsoMenu -Llevar $llevar | Out-Null
            }
            6 { 
                $llevar.Opciones.UseNativeZip = -not $llevar.Opciones.UseNativeZip
                Show-ConsolePopup -Title "ZIP Nativo" -Message "ZIP Nativo: $(if($llevar.Opciones.UseNativeZip){'ACTIVADO'}else{'DESACTIVADO'})" -Options @("*OK") | Out-Null 
            }
            7 { 
                # ✅ PASAR $llevar A SHOW-PASSWORDMENU
                Show-PasswordMenu -Llevar $llevar | Out-Null
            }
            8 { return @{ Action = "Example" } }
            9 { return @{ Action = "Help" } }
            10 { 
                # Validar configuración completa usando with y switch
                $errors = @()

                # Validar origen
                if (-not $llevar.Origen.Tipo) {
                    $errors += "• Falta configurar el tipo de origen"
                }
                else {
                    $origenPath = switch ($llevar.Origen.Tipo) {
                        "FTP" {
                            with $llevar.Origen.FTP { .Directory }
                        }
                        "Local" {
                            with $llevar.Origen.Local { .Path }
                        }
                        "UNC" {
                            with $llevar.Origen.UNC { .Path }
                        }
                        "OneDrive" {
                            with $llevar.Origen.OneDrive { .Path }
                        }
                        "Dropbox" {
                            with $llevar.Origen.Dropbox { .Path }
                        }
                        default { $null }
                    }
                    if (-not $origenPath) {
                        $errors += "• Falta configurar la ruta de origen ($($llevar.Origen.Tipo))"
                    }
                }

                # Validar destino
                if (-not $llevar.Destino.Tipo) {
                    $errors += "• Falta configurar el tipo de destino"
                }
                else {
                    $destinoPath = switch ($llevar.Destino.Tipo) {
                        "FTP" {
                            with $llevar.Destino.FTP { .Directory }
                        }
                        "Local" {
                            with $llevar.Destino.Local { .Path }
                        }
                        "USB" {
                            with $llevar.Destino.USB { .Path }
                        }
                        "UNC" {
                            with $llevar.Destino.UNC { .Path }
                        }
                        "OneDrive" {
                            with $llevar.Destino.OneDrive { .Path }
                        }
                        "Dropbox" {
                            with $llevar.Destino.Dropbox { .Path }
                        }
                        "ISO" {
                            with $llevar.Destino.ISO { .OutputPath }
                        }
                        "Diskette" {
                            with $llevar.Destino.Diskette { .OutputPath }
                        }
                        default { $null }
                    }
                    if (-not $destinoPath) {
                        $errors += "• Falta configurar la ruta de destino ($($llevar.Destino.Tipo))"
                    }
                }

                if ($errors.Count -gt 0) {
                    $mensaje = "Faltan parámetros requeridos:`n`n" + ($errors -join "`n")
                    Show-ConsolePopup -Title "Configuración Incompleta" -Message $mensaje -Options @("*OK") | Out-Null
                    continue
                }
                
                # ✅ RETORNAR $llevar CONFIGURADO
                return @{ 
                    Action         = "Execute"
                    TransferConfig = $llevar
                }
            }
        }
    }
}

# ========================================================================== #
#                          SUBMENÚS DE CONFIGURACIÓN                         #
# ========================================================================== #

function Show-OrigenMenu {
    <#
    .SYNOPSIS
        Menú de configuración de origen usando TransferConfig
    .PARAMETER Llevar
        Objeto TransferConfig que se modificará directamente
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Llevar
    )
    
    $options = @(
        "*Local (carpeta del sistema)",
        "*FTP (servidor FTP)",
        "*OneDrive (Microsoft OneDrive)",
        "*Dropbox",
        "*UNC (red compartida)"
    )
    
    $selection = Show-DosMenu -Title "ORIGEN - Seleccione tipo" -Items $options -CancelValue 0
    
    switch ($selection) {
        0 { return }
        1 {
            $selected = Select-PathNavigator -Prompt "Seleccione carpeta de ORIGEN" -AllowFiles $false
            if ($selected) {
                $Llevar.Origen.Tipo = "Local"
                $Llevar.Origen.Local.Path = $selected
            }
        }
        2 {
            # ✅ LLAMADA CORRECTA: PASA $Llevar y "Origen"
            $success = Get-FtpConfigFromUser -Llevar $Llevar -Cual "Origen"
            # ✅ $Llevar.Origen.FTP.* YA ESTÁ CONFIGURADO
        }
        3 {
            # ✅ LLAMADA CORRECTA: PASA $Llevar y "Origen"
            $success = Get-OneDriveConfigFromUser -Llevar $Llevar -Cual "Origen"
            # ✅ $Llevar.Origen.OneDrive.* YA ESTÁ CONFIGURADO
        }
        4 {
            # ✅ LLAMADA CORRECTA: PASA $Llevar y "Origen"
            $success = Get-DropboxConfigFromUser -Llevar $Llevar -Cual "Origen"
            # ✅ $Llevar.Origen.Dropbox.* YA ESTÁ CONFIGURADO
        }
        5 {
            $uncPath = Select-NetworkPath -Purpose "ORIGEN"
            if ($uncPath) {
                $Llevar.Origen.Tipo = "UNC"
                $Llevar.Origen.UNC.Path = $uncPath
            }
        }
    }
}

function Show-DestinoMenu {
    <#
    .SYNOPSIS
        Menú de configuración de destino usando TransferConfig
    .PARAMETER Llevar
        Objeto TransferConfig que se modificará directamente
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Llevar
    )
    
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
        0 { return }
        1 {
            $selected = Select-PathNavigator -Prompt "Seleccione carpeta de DESTINO" -AllowFiles $false
            if ($selected) {
                $Llevar.Destino.Tipo = "Local"
                $Llevar.Destino.Local.Path = $selected
            }
        }
        2 {
            Show-ConsolePopup -Title "Modo USB" -Message "El programa solicitará USBs durante la transferencia" -Options @("*OK") | Out-Null
            $Llevar.Destino.Tipo = "USB"
            $Llevar.Destino.USB.Path = "USB"
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
                $Llevar.Destino.Tipo = "Diskette"
                $Llevar.Destino.Diskette.OutputPath = $env:TEMP
                $Llevar.Destino.Diskette.MaxDisks = 30
            }
        }
        4 {
            # ✅ LLAMADA CORRECTA: PASA $Llevar y "Destino"
            $success = Get-FtpConfigFromUser -Llevar $Llevar -Cual "Destino"
            # ✅ $Llevar.Destino.FTP.* YA ESTÁ CONFIGURADO
        }
        5 {
            # ✅ LLAMADA CORRECTA: PASA $Llevar y "Destino"
            $success = Get-OneDriveConfigFromUser -Llevar $Llevar -Cual "Destino"
            # ✅ $Llevar.Destino.OneDrive.* YA ESTÁ CONFIGURADO
        }
        6 {
            # ✅ LLAMADA CORRECTA: PASA $Llevar y "Destino"
            $success = Get-DropboxConfigFromUser -Llevar $Llevar -Cual "Destino"
            # ✅ $Llevar.Destino.Dropbox.* YA ESTÁ CONFIGURADO
        }
        7 {
            $uncPath = Select-NetworkPath -Purpose "DESTINO"
            if ($uncPath) {
                $Llevar.Destino.Tipo = "UNC"
                $Llevar.Destino.UNC.Path = $uncPath
            }
        }
    }
}

function Show-BlockSizeMenu {
    <#
    .SYNOPSIS
        Menú de configuración de tamaño de bloque
    .PARAMETER Llevar
        Objeto TransferConfig que se modificará directamente
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Llevar
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
    
    $currentSize = $Llevar.Opciones.BlockSizeMB
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
        $Llevar.Opciones.BlockSizeMB = $newSize
        Show-ConsolePopup -Title "Tamaño de Bloque" -Message "Configurado: $newSize MB" -Options @("*OK") | Out-Null
    }
}

function Show-PasswordMenu {
    <#
    .SYNOPSIS
        Menú de configuración de contraseña
    .PARAMETER Llevar
        Objeto TransferConfig que se modificará directamente
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Llevar
    )
    
    if ($Llevar.Opciones.Clave) {
        $options = @("*Cambiar contraseña", "*Eliminar contraseña")
        $selection = Show-DosMenu -Title "CONTRASEÑA (Actual: ******)" -Items $options -CancelValue 0
        
        if ($selection -eq 0) { return }
        if ($selection -eq 2) {
            $Llevar.Opciones.Clave = $null
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
        $Llevar.Opciones.Clave = $plainPass1
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
    .PARAMETER Llevar
        Objeto TransferConfig que se modificará directamente
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Llevar
    )
    
    $wasISO = ($Llevar.Destino.Tipo -eq "ISO")
    
    if (-not $wasISO) {
        $options = @("*CD (700 MB)", "*DVD (4.5 GB)", "*USB (4.5 GB)")
        $selection = Show-DosMenu -Title "TIPO DE ISO" -Items $options -CancelValue 0 -DefaultValue 2
        
        if ($selection -eq 0) { return }
        
        $isoSize = switch ($selection) {
            1 { "cd" }
            2 { "dvd" }
            3 { "usb" }
        }
        
        $Llevar.Destino.Tipo = "ISO"
        $Llevar.Destino.ISO.OutputPath = $env:TEMP
        $Llevar.Destino.ISO.Size = $isoSize
        
        Show-ConsolePopup -Title "Modo ISO" -Message "Se generarán imágenes ISO de tipo: $($isoSize.ToUpper())" -Options @("*OK") | Out-Null
    }
    else {
        $Llevar.Destino.Tipo = "Local"
        $Llevar.Destino.Local.Path = $null
        Show-ConsolePopup -Title "Modo ISO" -Message "Modo ISO desactivado" -Options @("*OK") | Out-Null
    }
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
