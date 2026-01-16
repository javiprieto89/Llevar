# ========================================================================== #
#                   MÓDULO: ROBOCOPY (COPIA ESPEJO)                          #
# ========================================================================== #
# Propósito: Funciones de sincronización con Robocopy
# Funciones:
#   - Get-RobocopyExePath: Resuelve robocopy.exe desde C:\Llevar\robocopy
#   - Invoke-RobocopyMirror: Copia espejo completa con Robocopy /MIR
# ========================================================================== #

function Get-RobocopyExePath {
    $preferred = "C:\Llevar\robocopy\robocopy.exe"
    if (Test-Path $preferred) {
        try {
            $null = & $preferred /? 2>$null
            if ($LASTEXITCODE -le 7) {
                return $preferred
            }
        }
        catch { }
    }
    return "robocopy.exe"
}

function Invoke-RobocopyMirror {
    <#
    .SYNOPSIS
        Realiza una copia espejo simple con Robocopy
    .DESCRIPTION
        Usa Robocopy con /MIR (mirror) para sincronizar origen con destino.
        El destino quedará idéntico al origen (elimina archivos extras en destino).
        
        ⚠ ADVERTENCIA: El modo MIRROR elimina archivos en destino que no
        existen en origen. Use con precaución.
    .PARAMETER Origen
        Carpeta de origen
    .PARAMETER Destino
        Carpeta de destino
    .EXAMPLE
        Invoke-RobocopyMirror -Origen "C:\Datos" -Destino "D:\Respaldo"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Origen,
        
        [Parameter(Mandatory = $true)]
        [string]$Destino
    )
    
    Show-Banner -Message "ROBOCOPY MIRROR - COPIA ESPEJO" -BorderColor Cyan -TextColor Yellow
    Write-Host "  Origen : " -NoNewline -ForegroundColor Gray
    Write-Host $Origen -ForegroundColor White
    Write-Host "  Destino: " -NoNewline -ForegroundColor Gray
    Write-Host $Destino -ForegroundColor White
    Write-Host ""
    Write-Host "⚠ ADVERTENCIA:" -ForegroundColor Yellow
    Write-Host "  El modo MIRROR sincroniza completamente origen y destino." -ForegroundColor Gray
    Write-Host "  Esto significa que:" -ForegroundColor Gray
    Write-Host "  • Copia archivos nuevos y modificados desde origen" -ForegroundColor Gray
    Write-Host "  • ELIMINA archivos en destino que no existen en origen" -ForegroundColor Gray
    Write-Host ""
    Write-Host "¿Desea continuar? (S/N): " -NoNewline -ForegroundColor Yellow
    $respuesta = Read-Host
    
    if ($respuesta -notmatch '^[SsYy]$') {
        Write-Host ""
        Write-Host "Operación cancelada por el usuario." -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "[*] Iniciando copia espejo con Robocopy..." -ForegroundColor Cyan
    Write-Host ""
    
    # Crear destino si no existe
    if (-not (Test-Path $Destino)) {
        Write-Host "    Creando carpeta de destino..." -ForegroundColor Gray
        New-Item -ItemType Directory -Path $Destino -Force | Out-Null
    }
    
    # Ejecutar Robocopy con /MIR
    $robocopyArgs = @(
        $Origen,
        $Destino,
        '/MIR',       # Mirror (elimina extras en destino)
        '/R:3',       # 3 reintentos en archivos bloqueados
        '/W:5',       # 5 segundos de espera entre reintentos
        '/NP'         # Sin mostrar progreso por archivo (más limpio)
    )
    
    Write-Host "    Ejecutando: robocopy $($robocopyArgs -join ' ')" -ForegroundColor DarkGray
    Write-Host ""
    
    $robocopyExe = Get-RobocopyExePath
    $process = Start-Process -FilePath $robocopyExe -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
    $exitCode = $process.ExitCode
    
    Write-Host ""
    
    # Robocopy devuelve códigos especiales (no son errores los códigos 0-7)
    if ($exitCode -le 3) {
        Write-Host "[✓] Copia espejo completada exitosamente" -ForegroundColor Green
        
        switch ($exitCode) {
            0 { Write-Host "    No hubo cambios, origen y destino ya estaban sincronizados" -ForegroundColor Gray }
            1 { Write-Host "    Se copiaron archivos nuevos o modificados" -ForegroundColor Gray }
            2 { Write-Host "    Se eliminaron archivos extras del destino" -ForegroundColor Gray }
            3 { Write-Host "    Se copiaron archivos y se eliminaron extras" -ForegroundColor Gray }
        }
    }
    elseif ($exitCode -le 7) {
        Write-Host "[!] Robocopy completado con advertencias (código: $exitCode)" -ForegroundColor Yellow
        Write-Host "    La sincronización se completó pero hubo algunos problemas menores" -ForegroundColor Gray
    }
    else {
        Write-Host "[X] Robocopy finalizó con errores (código: $exitCode)" -ForegroundColor Red
        Write-Host "    Algunos archivos pueden no haberse copiado correctamente" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "    Códigos de error comunes:" -ForegroundColor Gray
        Write-Host "    • 8  = Algunos archivos/carpetas no se pudieron copiar" -ForegroundColor Gray
        Write-Host "    • 16 = Error grave (falta de permisos, disco lleno, etc.)" -ForegroundColor Gray
    }
    
    Write-Host ""
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Get-RobocopyExePath',
    'Invoke-RobocopyMirror'
)
