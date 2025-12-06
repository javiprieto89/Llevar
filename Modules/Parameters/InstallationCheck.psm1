<#
.SYNOPSIS
    Verifica si el script está instalado en C:\Llevar y ofrece instalarlo si no lo está.

.DESCRIPTION
    Este módulo maneja la verificación automática de instalación que se ejecuta
    cuando el script NO se llama con -Ejemplo o -Ayuda.
    
    Si el script no está instalado en C:\Llevar, pregunta al usuario si desea instalarlo.
    Si el usuario acepta, procede con la instalación y luego continúa la ejecución normal.
#>

function Invoke-InstallationCheck {
    <#
    .SYNOPSIS
        Verifica la instalación y ofrece instalar si no está en C:\Llevar.
    
    .PARAMETER Ejemplo
        Si está presente, omite la verificación.
    
    .PARAMETER Ayuda
        Si está presente, omite la verificación.
    
    .PARAMETER IsAdmin
        Indica si el script se está ejecutando con permisos de administrador.
    
    .PARAMETER IsInIDE
        Indica si el script se está ejecutando en un IDE (VS Code, ISE, etc.).
    
    .PARAMETER ScriptPath
        Ruta completa del script principal.
    
    .PARAMETER LogoWasShown
        Indica si ya se mostró el logo ASCII (para no borrar la pantalla innecesariamente).
    
    .EXAMPLE
        Invoke-InstallationCheck -Ejemplo:$Ejemplo -Ayuda:$Ayuda -IsAdmin $isAdmin -IsInIDE $isInIDE -ScriptPath $MyInvocation.MyCommand.Path -LogoWasShown $script:LogoWasShown
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Ejemplo,
        
        [Parameter(Mandatory = $false)]
        [switch]$Ayuda,
        
        [Parameter(Mandatory = $true)]
        [bool]$IsAdmin,
        
        [Parameter(Mandatory = $true)]
        [bool]$IsInIDE,
        
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory = $false)]
        [bool]$LogoWasShown = $false
    )
    
    # Verificar si NO está ejecutándose desde C:\Llevar (excepto si es -Ejemplo o -Ayuda)
    if (-not $Ejemplo -and -not $Ayuda) {
        $isInstalled = Test-LlevarInstallation
        
        if (-not $isInstalled) {
            $wantsInstall = Show-InstallationPrompt
            
            if ($wantsInstall) {
                # Usuario dijo S� - proceder con instalación
                
                if ($IsInIDE) {
                    Write-Host "`n[DEBUG/IDE] Omitiendo verificación de permisos de administrador" -ForegroundColor Cyan
                    
                    # Instalar directamente sin verificar permisos
                    $installed = Install-LlevarToSystem
                    
                    if ($installed) {
                        Write-Host "`nPresione cualquier tecla para continuar con la ejecución normal..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                        Clear-Host
                    }
                    else {
                        Write-Host "`nNo se pudo completar la instalación." -ForegroundColor Red
                        Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                        exit
                    }
                }
                else {
                    # Verificar permisos de administrador
                    if (-not $IsAdmin) {
                        Write-Host "`n⚠ Se requieren permisos de administrador para instalar." -ForegroundColor Yellow
                        Write-Host "Relanzando como administrador..." -ForegroundColor Cyan
                        
                        Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"" -Verb RunAs
                        exit
                    }
                    else {
                        # Ya es admin, instalar directamente
                        $installed = Install-LlevarToSystem
                        
                        if ($installed) {
                            Write-Host "`nPresione cualquier tecla para continuar con la ejecución normal..." -ForegroundColor Gray
                            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                            Clear-Host
                        }
                        else {
                            Write-Host "`nNo se pudo completar la instalación." -ForegroundColor Red
                            Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
                            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                            exit
                        }
                    }
                }
            }
            # Si wantsInstall es FALSE, simplemente continuar sin hacer nada
            # El script seguirá ejecutándose normalmente desde su ubicación actual
        }
        # Si isInstalled es TRUE, simplemente continuar sin mostrar nada
    }
}

Export-ModuleMember -Function Invoke-InstallationCheck
