# ============================================================================
# PowerShellVersion.psm1
# Verifica y gestiona la versión de PowerShell requerida
# ============================================================================

function Test-PowerShell7Available {
    <#
    .SYNOPSIS
        Verifica si PowerShell 7+ está disponible en el sistema
    
    .DESCRIPTION
        Comprueba si pwsh.exe está disponible en el PATH del sistema
    
    .OUTPUTS
        Boolean - $true si PowerShell 7+ está disponible, $false si no
    #>
    try {
        $pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
        return ($null -ne $pwshPath)
    }
    catch {
        return $false
    }
}

function Test-IsPowerShell7 {
    <#
    .SYNOPSIS
        Verifica si el script se está ejecutando en PowerShell 7+
    
    .DESCRIPTION
        Comprueba la versión actual de PowerShell
    
    .OUTPUTS
        Boolean - $true si es PowerShell 7+, $false si no
    #>
    return ($PSVersionTable.PSVersion.Major -ge 7)
}

function Show-PowerShell7RequiredDialog {
    <#
    .SYNOPSIS
        Muestra un diálogo indicando que se requiere PowerShell 7
    
    .DESCRIPTION
        Muestra un popup modal informando al usuario que PowerShell 7 es necesario
    
    .PARAMETER CanInstall
        Si se puede ofrecer la opción de instalar
    #>
    param(
        [switch]$CanInstall
    )
    
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'PowerShell 7 Requerido'
    $form.Size = New-Object System.Drawing.Size(500, 250)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true

    # Ícono de advertencia
    $iconLabel = New-Object System.Windows.Forms.Label
    $iconLabel.Location = New-Object System.Drawing.Point(20, 20)
    $iconLabel.Size = New-Object System.Drawing.Size(48, 48)
    $iconLabel.Image = [System.Drawing.SystemIcons]::Warning.ToBitmap()
    $form.Controls.Add($iconLabel)

    # Mensaje principal
    $messageLabel = New-Object System.Windows.Forms.Label
    $messageLabel.Location = New-Object System.Drawing.Point(80, 20)
    $messageLabel.Size = New-Object System.Drawing.Size(390, 60)
    $messageLabel.Text = "Este programa requiere PowerShell 7 o superior para funcionar correctamente.`n`nActualmente está ejecutando PowerShell $($PSVersionTable.PSVersion)."
    $form.Controls.Add($messageLabel)

    # Información adicional
    $infoLabel = New-Object System.Windows.Forms.Label
    $infoLabel.Location = New-Object System.Drawing.Point(80, 90)
    $infoLabel.Size = New-Object System.Drawing.Size(390, 60)
    
    if ($CanInstall) {
        $infoLabel.Text = "¿Desea descargar e instalar PowerShell 7 ahora?`n`nEsto abrirá el navegador con la página de descarga oficial."
    }
    else {
        $infoLabel.Text = "Por favor, descargue e instale PowerShell 7 desde:`nhttps://aka.ms/powershell"
    }
    $form.Controls.Add($infoLabel)

    # Botones
    $buttonY = 160
    
    if ($CanInstall) {
        # Botón Descargar
        $downloadButton = New-Object System.Windows.Forms.Button
        $downloadButton.Location = New-Object System.Drawing.Point(180, $buttonY)
        $downloadButton.Size = New-Object System.Drawing.Size(100, 30)
        $downloadButton.Text = 'Descargar'
        $downloadButton.DialogResult = [System.Windows.Forms.DialogResult]::Yes
        $form.Controls.Add($downloadButton)
        $form.AcceptButton = $downloadButton

        # Botón Cancelar
        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Location = New-Object System.Drawing.Point(290, $buttonY)
        $cancelButton.Size = New-Object System.Drawing.Size(100, 30)
        $cancelButton.Text = 'Cancelar'
        $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Controls.Add($cancelButton)
        $form.CancelButton = $cancelButton
    }
    else {
        # Solo botón OK
        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Location = New-Object System.Drawing.Point(200, $buttonY)
        $okButton.Size = New-Object System.Drawing.Size(100, 30)
        $okButton.Text = 'OK'
        $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Controls.Add($okButton)
        $form.AcceptButton = $okButton
    }

    return $form.ShowDialog()
}

function Install-PowerShell7 {
    <#
    .SYNOPSIS
        Intenta instalar PowerShell 7
    
    .DESCRIPTION
        Ofrece diferentes métodos para instalar PowerShell 7:
        1. winget (si está disponible)
        2. Descarga directa del instalador MSI
        3. Abrir página web de descarga
    
    .OUTPUTS
        Boolean - $true si se inició la instalación, $false si no
    #>
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " INSTALACIÓN DE POWERSHELL 7" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Método 1: winget (más rápido y automático)
    $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
    
    if ($wingetAvailable) {
        Write-Host "✓ winget detectado - Instalación automática disponible" -ForegroundColor Green
        Write-Host ""
        Write-Host "¿Desea instalar PowerShell 7 usando winget? (S/N): " -ForegroundColor Yellow -NoNewline
        $response = Read-Host
        
        if ($response -eq 'S' -or $response -eq 's') {
            Write-Host ""
            Write-Host "Instalando PowerShell 7..." -ForegroundColor Cyan
            Write-Host ""
            
            try {
                winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements
                
                Write-Host ""
                Write-Host "✓ PowerShell 7 instalado correctamente" -ForegroundColor Green
                Write-Host ""
                Write-Host "IMPORTANTE: Debe cerrar y volver a abrir el programa para usar PowerShell 7" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                return $true
            }
            catch {
                Write-Host ""
                Write-Host "✗ Error durante la instalación: $_" -ForegroundColor Red
                Write-Host ""
            }
        }
    }
    
    # Método 2: Descarga directa del instalador
    Write-Host "Descargando instalador de PowerShell 7..." -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Detectar arquitectura
        $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
        
        # URL del instalador más reciente
        $downloadUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7-win-$arch.msi"
        $installerPath = "$env:TEMP\PowerShell-7-Installer.msi"
        
        Write-Host "Descargando desde: $downloadUrl" -ForegroundColor Gray
        Write-Host ""
        
        # Descargar
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
        
        if (Test-Path $installerPath) {
            Write-Host "✓ Descarga completada" -ForegroundColor Green
            Write-Host ""
            Write-Host "Iniciando instalador..." -ForegroundColor Cyan
            Write-Host ""
            
            # Ejecutar instalador
            Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /qb" -Wait
            
            Write-Host ""
            Write-Host "✓ Instalación completada" -ForegroundColor Green
            Write-Host ""
            Write-Host "IMPORTANTE: Debe cerrar y volver a abrir el programa para usar PowerShell 7" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            
            # Limpiar
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            
            return $true
        }
    }
    catch {
        Write-Host ""
        Write-Host "✗ Error al descargar o instalar: $_" -ForegroundColor Red
        Write-Host ""
    }
    
    # Método 3: Abrir página web como último recurso
    Write-Host "Abriendo página de descarga oficial..." -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Start-Process "https://aka.ms/powershell"
        Write-Host "✓ Navegador abierto con la página de descargas" -ForegroundColor Green
        Write-Host ""
        Write-Host "Por favor, descargue e instale PowerShell 7 manualmente." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return $true
    }
    catch {
        Write-Host "✗ No se pudo abrir el navegador: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Visite manualmente: https://aka.ms/powershell" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return $false
    }
}

function Assert-PowerShell7 {
    <#
    .SYNOPSIS
        Verifica que se esté ejecutando PowerShell 7+ y maneja la situación si no
    
    .DESCRIPTION
        Función principal que:
        1. Verifica si se está ejecutando PowerShell 7+
        2. Si no, ofrece instalarlo
        3. Si no se puede/quiere instalar, muestra mensaje y cierra
    
    .OUTPUTS
        Boolean - $true si está en PowerShell 7+, $false si debe salir
    #>
    
    # Si ya estamos en PowerShell 7+, todo bien
    if (Test-IsPowerShell7) {
        return $true
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host " ⚠ POWERSHELL 7 REQUERIDO" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-Host "Este programa requiere PowerShell 7 o superior." -ForegroundColor White
    Write-Host "Versión actual: PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host ""
    
    # Verificar si PowerShell 7 está instalado pero no se está usando
    if (Test-PowerShell7Available) {
        Write-Host "✓ PowerShell 7 está instalado en el sistema" -ForegroundColor Green
        Write-Host ""
        Write-Host "Por favor, ejecute el programa usando PowerShell 7:" -ForegroundColor Yellow
        Write-Host "  pwsh.exe -File `"$(Join-Path $PSScriptRoot '..\..\Llevar.ps1')`"" -ForegroundColor White
        Write-Host ""
        Write-Host "O ejecute directamente: LLEVAR.CMD" -ForegroundColor White
        Write-Host ""
        Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return $false
    }
    
    # PowerShell 7 no está instalado - ofrecer instalarlo
    Write-Host "✗ PowerShell 7 no está instalado en el sistema" -ForegroundColor Red
    Write-Host ""
    Write-Host "¿Desea instalar PowerShell 7 ahora? (S/N): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    
    if ($response -eq 'S' -or $response -eq 's') {
        $installed = Install-PowerShell7
        if ($installed) {
            return $false  # Debe salir y reiniciar con PowerShell 7
        }
    }
    
    # Si llegamos aquí, mostrar diálogo final y salir
    $result = Show-PowerShell7RequiredDialog
    return $false
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Test-PowerShell7Available',
    'Test-IsPowerShell7',
    'Show-PowerShell7RequiredDialog',
    'Install-PowerShell7',
    'Assert-PowerShell7'
)
