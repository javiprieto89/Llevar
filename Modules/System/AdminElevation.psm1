<#
.SYNOPSIS
    Módulo para gestión de permisos de administrador, elevación UAC y detección de entorno

.DESCRIPTION
    Proporciona funciones para:
    - Verificar si el proceso se ejecuta como administrador
    - Elevar automáticamente permisos cuando sea necesario
    - Manejar errores de UAC (cancelación, fallos)
    - Detectar si está ejecutándose en un IDE (VS Code, ISE, etc.)
#>

# Test-IsRunningInIDE vive en Modules/Core/Validation.psm1

function Test-IsAdministrator {
    <#
    .SYNOPSIS
        Verifica si el proceso actual se ejecuta con permisos de administrador
    #>
    try {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Invoke-AdminElevation {
    <#
    .SYNOPSIS
        Eleva el proceso actual a administrador si no lo es
    
    .PARAMETER ScriptPath
        Ruta del script a ejecutar con privilegios elevados
    
    .PARAMETER BoundParameters
        Parámetros originales del script a preservar
    
    .OUTPUTS
        No retorna - hace exit del proceso actual si la elevación es exitosa
        Retorna $false si la elevación falla
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory)]
        [System.Collections.Generic.Dictionary[string, object]]$BoundParameters
    )
    
    Write-Host "🔒 Esta operación requiere permisos de administrador..." -ForegroundColor Cyan
    Write-Host "   Elevando permisos..." -ForegroundColor Gray
    
    try {
        # Construir argumentos para mantener todos los parámetros
        $argList = @(
            '-NoProfile'
            '-ExecutionPolicy', 'Bypass'
            '-File', "`"$ScriptPath`""
        )
        
        # Agregar parámetros bound
        foreach ($param in $BoundParameters.GetEnumerator()) {
            if ($param.Value -is [switch]) {
                if ($param.Value) {
                    $argList += "-$($param.Key)"
                }
            }
            else {
                $argList += "-$($param.Key)"
                $argList += "`"$($param.Value)`""
            }
        }
        
        # Iniciar proceso elevado
        $process = Start-Process -FilePath "pwsh.exe" `
            -ArgumentList $argList `
            -Verb RunAs `
            -PassThru `
            -WindowStyle Normal `
            -ErrorAction Stop
        
        # Esperar a que termine el proceso elevado
        $process.WaitForExit()
        
        # Salir del proceso no elevado con el código de salida del proceso elevado
        exit $process.ExitCode
    }
    catch {
        Show-ElevationError -Exception $_
        exit 1
    }
}

function Show-ElevationError {
    <#
    .SYNOPSIS
        Muestra mensajes de error cuando falla la elevación UAC
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$Exception
    )
    
    $errorType = $Exception.Exception.GetType().Name
    
    # Si es una cancelación del usuario
    if ($errorType -eq "Win32Exception" -or $Exception.Exception.Message -match "cancel|1223") {
        try {
            Add-Type -AssemblyName PresentationFramework
            [System.Windows.MessageBox]::Show(
                "Esta operación requiere permisos de administrador.`n`n" +
                "La operación fue cancelada por el usuario.`n`n" +
                "No se puede continuar sin permisos de administrador.",
                "Permisos de Administrador Requeridos",
                "OK",
                "Warning"
            ) | Out-Null
        }
        catch {
            Write-Host ""
            Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
            Write-Host "║  ⚠ PERMISOS DE ADMINISTRADOR REQUERIDOS                      ║" -ForegroundColor Yellow
            Write-Host "║  La operación fue cancelada.                                  ║" -ForegroundColor Yellow
            Write-Host "║  No se puede continuar sin permisos de administrador.         ║" -ForegroundColor Yellow
            Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
    else {
        # Otro tipo de error
        try {
            Add-Type -AssemblyName PresentationFramework
            [System.Windows.MessageBox]::Show(
                "No se pudo elevar permisos de administrador.`n`n" +
                "Error: $($Exception.Exception.Message)`n`n" +
                "Por favor ejecute PowerShell como administrador manualmente.",
                "Error de Elevación de Permisos",
                "OK",
                "Error"
            ) | Out-Null
        }
        catch {
            Write-Host ""
            Write-Host "❌ No se pudo elevar permisos de administrador" -ForegroundColor Red
            Write-Host "Error: $($Exception.Exception.Message)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Por favor ejecute PowerShell como administrador manualmente." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Presione cualquier tecla para salir..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
}

function Show-AdminRequirementMessage {
    <#
    .SYNOPSIS
        Muestra mensaje informativo cuando no se requieren permisos de admin
    #>
    Write-Host "ℹ Ejecutando sin permisos de administrador" -ForegroundColor Cyan
    Write-Host "  (Solo se requiere admin para instalar/desinstalar)" -ForegroundColor Gray
    Write-Host ""
}

function Assert-AdminPrivileges {
    <#
    .SYNOPSIS
        Verifica y eleva permisos de administrador si son necesarios
    
    .PARAMETER RequiresAdmin
        Indica si la operación requiere permisos de administrador
    
    .PARAMETER ScriptPath
        Ruta del script actual (para elevación)
    
    .PARAMETRunningInIDE'
    'Test-IsER BoundParameters
        Parámetros del script a preservar
    
    .DESCRIPTION
        Función principal que verifica permisos, eleva si es necesario,
        o muestra mensaje informativo si no se requieren.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$RequiresAdmin,
        
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory)]
        [System.Collections.Generic.Dictionary[string, object]]$BoundParameters
    )
    
    $isAdmin = Test-IsAdministrator
    
    if ($RequiresAdmin -and -not $isAdmin) {
        # Necesita admin pero no lo tiene - elevar
        Invoke-AdminElevation -ScriptPath $ScriptPath -BoundParameters $BoundParameters
    }
    elseif (-not $RequiresAdmin -and -not $isAdmin) {
        # No necesita admin y no lo tiene - mostrar mensaje informativo
        Show-AdminRequirementMessage
    }
    
    # Si llegamos aquí, continuar normalmente (es admin o no lo necesita)
}

Export-ModuleMember -Function @(
    'Test-IsAdministrator'
    'Invoke-AdminElevation'
    'Show-ElevationError'
    'Show-AdminRequirementMessage'
    'Assert-AdminPrivileges'
)
