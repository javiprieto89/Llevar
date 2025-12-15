<#
.SYNOPSIS
    Maneja el parámetro -Instalar para realizar la instalación del sistema.

.DESCRIPTION
    Este módulo procesa el parámetro -Instalar que instala LLEVAR en C:\Llevar
    y configura el menú contextual de Windows.
#>

function Invoke-InstallParameter {
    <#
    .SYNOPSIS
        Procesa el parámetro -Instalar y ejecuta la instalación del sistema.
    
    .PARAMETER Instalar
        Switch que indica si se debe instalar el sistema.
    
    .PARAMETER IsAdmin
        Indica si el proceso actual tiene privilegios de administrador.
    
    .PARAMETER IsInIDE
        Indica si está ejecutándose desde un IDE (VS Code, ISE, etc.).
    
    .PARAMETER ScriptPath
        Ruta completa del script principal.
    
    .EXAMPLE
        Invoke-InstallParameter -Instalar -IsAdmin $true -ScriptPath "C:\...\Llevar.ps1"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Instalar,
        
        [Parameter(Mandatory = $true)]
        [bool]$IsAdmin,
        
        [Parameter(Mandatory = $true)]
        [bool]$IsInIDE,
        
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )
    
    if (-not $Instalar) {
        return $false
    }
    
    # Si está en IDE, omitir verificación de permisos
    if ($IsInIDE) {
        Write-Host "`n[DEBUG/IDE] Omitiendo verificación de permisos de administrador" -ForegroundColor Cyan
    }
    else {
        # Verificar permisos de administrador
        if (-not $IsAdmin) {
            Write-Host "`n⚠ Se requieren permisos de administrador para instalar." -ForegroundColor Yellow
            Write-Host "Elevando a administrador..." -ForegroundColor Cyan
            
            # Usar PowerShell 7 para elevar
            $ps7Check = Test-PowerShell7Installed
            $pwsh = if ($ps7Check.IsInstalled) { $ps7Check.Path } else { "pwsh.exe" }
            
            Start-Process $pwsh -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"", "-Instalar" -Verb RunAs
            exit
        }
    }
    
    # Realizar instalación
    $installed = Install-LlevarToSystem
    
    if ($installed) {
        Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    
    exit
}

function Invoke-UninstallParameter {
    <#
    .SYNOPSIS
        Procesa el parámetro -Desinstalar y ejecuta la desinstalación del sistema.
    
    .PARAMETER Desinstalar
        Switch que indica si se debe desinstalar el sistema.
    
    .PARAMETER IsAdmin
        Indica si el proceso actual tiene privilegios de administrador.
    
    .PARAMETER IsInIDE
        Indica si está ejecutándose desde un IDE (VS Code, ISE, etc.).
    
    .PARAMETER ScriptPath
        Ruta completa del script principal.
    
    .EXAMPLE
        Invoke-UninstallParameter -Desinstalar -IsAdmin $true -ScriptPath "C:\...\Llevar.ps1"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Desinstalar,
        
        [Parameter(Mandatory = $true)]
        [bool]$IsAdmin,
        
        [Parameter(Mandatory = $true)]
        [bool]$IsInIDE,
        
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )
    
    if (-not $Desinstalar) {
        return $false
    }
    
    # Si está en IDE, omitir verificación de permisos
    if ($IsInIDE) {
        Write-Host "`n[DEBUG/IDE] Omitiendo verificación de permisos de administrador" -ForegroundColor Cyan
    }
    else {
        # Verificar permisos de administrador
        if (-not $IsAdmin) {
            Write-Host "`n⚠ Se requieren permisos de administrador para desinstalar." -ForegroundColor Yellow
            Write-Host "Elevando a administrador..." -ForegroundColor Cyan
            
            # Usar PowerShell 7 para elevar
            $ps7Check = Test-PowerShell7Installed
            $pwsh = if ($ps7Check.IsInstalled) { $ps7Check.Path } else { "pwsh.exe" }
            
            Start-Process $pwsh -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"", "-Desinstalar" -Verb RunAs
            exit
        }
    }
    
    # Realizar desinstalación
    $exitCode = Uninstall-LlevarFromSystem
    
    if ($exitCode -eq 0 -or $exitCode -eq 98 -or $exitCode -eq 99) {
        Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    
    exit $exitCode
}

Export-ModuleMember -Function Invoke-InstallParameter, Invoke-UninstallParameter
