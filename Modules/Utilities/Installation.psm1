# ========================================================================== #
#                   MÓDULO: UTILIDADES DE INSTALACIÓN                        #
# ========================================================================== #
# Propósito: Verificación y prompts de instalación del sistema
# Funciones:
#   - Test-LlevarInstallation: Verifica si está en C:\Llevar
#   - Show-InstallationPrompt: Muestra prompt para instalar
# ========================================================================== #

function Test-LlevarInstallation {
    <#
    .SYNOPSIS
        Verifica si el script está ejecutándose desde C:\Llevar
    .DESCRIPTION
        Compara la ruta actual del script con C:\Llevar para determinar
        si está instalado en el sistema o ejecutándose desde otra ubicación.
        También verifica si el script está en el PATH del sistema.
    .OUTPUTS
        Boolean - $true si está en C:\Llevar o en PATH, $false en caso contrario
    #>
    $currentPath = $PSCommandPath
    if (-not $currentPath) {
        $currentPath = $PSScriptRoot
    }
    
    $expectedPath = "C:\Llevar"
    
    # Normalizar rutas para comparación (sin distinguir mayúsculas/minúsculas)
    $currentDir = (Split-Path $currentPath -Parent).ToLower().TrimEnd('\')
    $expectedPathNormalized = $expectedPath.ToLower().TrimEnd('\')
    
    # Verificar si está en C:\Llevar
    $isInLlevarDir = ($currentDir -eq $expectedPathNormalized)
    
    # Verificar si C:\Llevar está en el PATH del sistema
    $systemPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $isInSystemPath = $systemPath -and ($systemPath.ToLower() -split ';' | Where-Object { $_.TrimEnd('\') -eq $expectedPathNormalized })
    
    # Considerar instalado si está en C:\Llevar O si C:\Llevar está en el PATH
    return ($isInLlevarDir -or $isInSystemPath)
}

function Show-InstallationPrompt {
    <#
    .SYNOPSIS
        Muestra un diálogo preguntando si se quiere instalar el script
    .DESCRIPTION
        Usa Show-ConsolePopup para presentar un diálogo amigable que explica
        qué se instalará y solicita confirmación del usuario.
    .OUTPUTS
        Boolean - $true si el usuario acepta instalar, $false en caso contrario
    #>
    
    $mensaje = @"
Este script no está instalado en C:\Llevar

¿Desea instalarlo en el sistema?

Esto copiará:
  • Script Llevar.ps1 a C:\Llevar
  • 7-Zip portable (si está disponible)
  • Agregará C:\Llevar al PATH del sistema
"@

    $respuesta = Show-ConsolePopup -Title "INSTALACIÓN DE LLEVAR EN EL SISTEMA" -Message $mensaje -Options @("*Sí, instalar", "*No, continuar sin instalar")
    
    # Opción 0 = Sí, Opción 1 = No
    return ($respuesta -eq 0)
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Test-LlevarInstallation',
    'Show-InstallationPrompt'
)
