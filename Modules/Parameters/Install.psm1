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
            
            Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"", "-Instalar" -Verb RunAs
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

Export-ModuleMember -Function Invoke-InstallParameter
