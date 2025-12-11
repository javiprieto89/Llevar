<#
.SYNOPSIS
    Módulo para manejo de copias a diskettes (disquetes)

.DESCRIPTION
    Implementa la funcionalidad del LLEVAR.BAT original para copiar datos
    comprimidos a diskettes de 1.44MB con formateo, verificación y reintento automático.
#>

# Imports necesarios
$ModulesPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ModulesPath "Modules\Compression\SevenZip.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Compression\BlockSplitter.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\UI\Banners.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Core\Logger.psm1") -Force -Global

# ========================================================================== #
#                    CONSTANTES Y CONFIGURACIÓN                              #
# ========================================================================== #

$Script:FloppyDrive = "A:\"
$Script:FloppyCapacity = 1440KB  # 1.44MB diskette estándar
$Script:MaxFloppies = 30
$Script:FloppyBlockSize = 1440  # KB para ARJ/7-Zip

# ========================================================================== #
#                    FUNCIONES DE DETECCIÓN Y VALIDACIÓN                     #
# ========================================================================== #

function Test-FloppyDriveAvailable {
    <#
    .SYNOPSIS
        Verifica si existe una unidad de diskette disponible
    #>
    
    try {
        $floppyDrives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 }
        
        if ($floppyDrives) {
            $Script:FloppyDrive = "$($floppyDrives[0].DeviceID)\"
            return $true
        }
        
        # Verificar si A:\ existe (método alternativo)
        if (Test-Path "A:\") {
            $Script:FloppyDrive = "A:\"
            return $true
        }
        
        return $false
    }
    catch {
        Write-Log "Error verificando unidad de diskette: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

function Test-FloppyInserted {
    <#
    .SYNOPSIS
        Verifica si hay un diskette insertado en la unidad
    #>
    param(
        [string]$DriveLetter = "A:\"
    )
    
    try {
        $volume = Get-Volume -DriveLetter $DriveLetter.Replace(":\", "") -ErrorAction SilentlyContinue
        return $null -ne $volume
    }
    catch {
        # Método alternativo: intentar listar contenido
        try {
            $null = Get-ChildItem $DriveLetter -ErrorAction Stop
            return $true
        }
        catch {
            return $false
        }
    }
}

# ========================================================================== #
#                    FUNCIONES DE FORMATEO                                   #
# ========================================================================== #

function Format-FloppyDisk {
    <#
    .SYNOPSIS
        Formatea un diskette de manera rápida
        
    .PARAMETER DriveLetter
        Letra de la unidad (por defecto A:)
        
    .PARAMETER QuickFormat
        Si se debe hacer formateo rápido (por defecto $true)
    #>
    param(
        [string]$DriveLetter = "A:",
        [switch]$QuickFormat = $true,
        [int]$FloppyNumber = 1
    )
    
    Write-Log "Formateando diskette $FloppyNumber..." "INFO"
    
    try {
        # Limpiar letra de unidad
        $drive = $DriveLetter.Replace(":\", "").Replace(":", "")
        
        # Construir comando de formateo
        $formatArgs = @(
            "$($drive):"
            "/FS:FAT"
            "/V:LLEVAR_$FloppyNumber"
            "/Y"  # No pedir confirmación
        )
        
        if ($QuickFormat) {
            $formatArgs += "/Q"  # Formateo rápido
        }
        
        # Ejecutar format
        $process = Start-Process -FilePath "format.com" -ArgumentList $formatArgs -Wait -NoNewWindow -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Log "Diskette $FloppyNumber formateado correctamente" "INFO"
            return $true
        }
        else {
            Write-Log "Error formateando diskette $FloppyNumber (código: $($process.ExitCode))" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Excepción formateando diskette: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ========================================================================== #
#                    FUNCIONES DE COPIA Y VERIFICACIÓN                       #
# ========================================================================== #

function Copy-FileToFloppy {
    <#
    .SYNOPSIS
        Copia un archivo al diskette con reintentos
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SourceFile,
        
        [string]$DestinationPath = "A:\",
        
        [int]$MaxRetries = 3
    )
    
    $fileName = [System.IO.Path]::GetFileName($SourceFile)
    $destFile = Join-Path $DestinationPath $fileName
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-Log "Copiando $fileName (intento $attempt/$MaxRetries)..." "DEBUG"
            
            Copy-Item -Path $SourceFile -Destination $destFile -Force -ErrorAction Stop
            
            # Verificar que se copió
            if (Test-Path $destFile) {
                $sourceSize = (Get-Item $SourceFile).Length
                $destSize = (Get-Item $destFile).Length
                
                if ($sourceSize -eq $destSize) {
                    Write-Log "Archivo $fileName copiado correctamente" "INFO"
                    return $true
                }
                else {
                    Write-Log "Tamaño de archivo no coincide: origen=$sourceSize dest=$destSize" "WARNING"
                }
            }
        }
        catch {
            Write-Log "Error copiando archivo (intento $attempt): $($_.Exception.Message)" "WARNING"
        }
        
        if ($attempt -lt $MaxRetries) {
            Start-Sleep -Seconds 2
        }
    }
    
    return $false
}

function Test-FloppyArchiveIntegrity {
    <#
    .SYNOPSIS
        Verifica la integridad de un archivo comprimido en el diskette
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ArchivePath,
        
        [string]$CompressionTool = "7z"
    )
    
    try {
        Write-Log "Verificando integridad de: $ArchivePath" "DEBUG"
        
        if (-not (Test-Path $ArchivePath)) {
            Write-Log "Archivo no encontrado: $ArchivePath" "ERROR"
            return $false
        }
        
        # Verificar con 7-Zip
        if ($CompressionTool -eq "7z") {
            $sevenZ = Get-SevenZipLlevar
            
            if ($sevenZ -and $sevenZ -ne "NATIVE_ZIP") {
                $testProcess = Start-Process -FilePath $sevenZ -ArgumentList "t", "`"$ArchivePath`"" -Wait -NoNewWindow -PassThru -RedirectStandardOutput (Join-Path $env:TEMP "7z_test.log")
                
                if ($testProcess.ExitCode -eq 0) {
                    Write-Log "Verificación OK: $ArchivePath" "INFO"
                    return $true
                }
                else {
                    Write-Log "Verificación FALLÓ: $ArchivePath (código: $($testProcess.ExitCode))" "ERROR"
                    return $false
                }
            }
        }
        
        # Verificación simple: comparar tamaño
        $originalSize = (Get-Item $ArchivePath).Length
        if ($originalSize -gt 0) {
            Write-Log "Verificación básica OK (tamaño: $originalSize bytes)" "INFO"
            return $true
        }
        
        return $false
    }
    catch {
        Write-Log "Error verificando archivo: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ========================================================================== #
#                    FUNCIÓN PRINCIPAL DE COPIA A DISKETTES                  #
# ========================================================================== #

function Copy-ToFloppyDisks {
    <#
    .SYNOPSIS
        Copia archivos comprimidos a diskettes con formateo y verificación
        
    .DESCRIPTION
        Implementación moderna del LLEVAR.BAT original:
        1. Comprime y divide archivos en bloques de 1.44MB
        2. Formatea cada diskette automáticamente
        3. Copia los bloques con verificación
        4. Permite reintentar diskettes dañados
        5. Genera instalador para restaurar desde diskettes
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,
        
        [string]$TempDir = (Join-Path $env:TEMP "LLEVAR_FLOPPY"),
        
        [string]$SevenZPath,
        
        [string]$Password,
        
        [switch]$VerifyDisks = $true
    )
    
    # Validar unidad de diskette
    if (-not (Test-FloppyDriveAvailable)) {
        Show-Banner "ERROR - SIN UNIDAD DE DISKETTE" -BorderColor Red -TextColor Red
        Write-Host ""
        Write-Host "No se detectó una unidad de diskette en el sistema." -ForegroundColor Red
        Write-Host ""
        Write-Host "NOTA: Los diskettes de 1.44MB son tecnología obsoleta." -ForegroundColor Yellow
        Write-Host "      Se recomienda usar USB, ISO u otros destinos modernos." -ForegroundColor Yellow
        Write-Host ""
        return $false
    }
    
    Show-Banner "COPIA A DISKETTES - MODO LEGACY" -BorderColor Cyan -TextColor Yellow
    Write-Host ""
    Write-Host "⚠ ADVERTENCIA: Los diskettes de 1.44MB son medios obsoletos y poco confiables." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Configuración:" -ForegroundColor Cyan
    Write-Host "  • Unidad detectada:  $Script:FloppyDrive" -ForegroundColor White
    Write-Host "  • Capacidad:         1.44 MB por diskette" -ForegroundColor White
    Write-Host "  • Máximo diskettes:  $Script:MaxFloppies" -ForegroundColor White
    Write-Host ""
    
    # Crear directorio temporal
    if (-not (Test-Path $TempDir)) {
        New-Item -Type Directory $TempDir | Out-Null
    }
    
    # Comprimir con bloques de 1.44MB
    Show-Banner "COMPRIMIENDO CON BLOQUES DE 1.44MB" -BorderColor Cyan -TextColor Cyan
    Write-Host "Esto puede tardar varios minutos..." -ForegroundColor Gray
    Write-Host ""
    
    try {
        # Determinar herramienta de compresión
        if (-not $SevenZPath) {
            $SevenZPath = Get-SevenZipLlevar
        }
        
        $blocks = @()
        
        if ($SevenZPath -and $SevenZPath -ne "NATIVE_ZIP") {
            # Usar 7-Zip con volúmenes de 1440KB
            $baseArchive = Join-Path $TempDir "LLEVAR_FLP"
            
            $args = @(
                "a"
                "-v1440k"  # Volúmenes de 1.44MB
                "-tzip"
                "-mx=9"    # Máxima compresión
            )
            
            if ($Password) {
                $args += "-p$Password"
                $args += "-mhe=on"  # Cifrar headers
            }
            
            $args += $baseArchive
            $args += $SourcePath
            
            Write-Log "Ejecutando 7-Zip con volúmenes de 1440KB" "INFO"
            $process = Start-Process -FilePath $SevenZPath -ArgumentList $args -Wait -NoNewWindow -PassThru
            
            if ($process.ExitCode -ne 0) {
                throw "Error comprimiendo con 7-Zip (código: $($process.ExitCode))"
            }
            
            # Recopilar bloques generados
            $blocks = Get-ChildItem "$baseArchive.zip*" | Sort-Object Name
        }
        else {
            throw "Se requiere 7-Zip para copia a diskettes"
        }
        
        if ($blocks.Count -eq 0) {
            throw "No se generaron bloques comprimidos"
        }
        
        if ($blocks.Count -gt $Script:MaxFloppies) {
            Show-Banner "ERROR - DEMASIADOS DISKETTES" -BorderColor Red -TextColor Red
            Write-Host ""
            Write-Host "Los datos requieren $($blocks.Count) diskettes." -ForegroundColor Red
            Write-Host "El máximo soportado es $Script:MaxFloppies diskettes." -ForegroundColor Red
            Write-Host ""
            Write-Host "Soluciones:" -ForegroundColor Yellow
            Write-Host "  1. Usar destino USB (mayor capacidad)" -ForegroundColor Gray
            Write-Host "  2. Usar destino ISO" -ForegroundColor Gray
            Write-Host "  3. Reducir el tamaño del origen" -ForegroundColor Gray
            Write-Host ""
            return $false
        }
        
        Show-Banner "RESUMEN DE COMPRESIÓN" -BorderColor Cyan -TextColor Cyan
        Write-Host "Diskettes necesarios: $($blocks.Count)" -ForegroundColor White
        Write-Host ""
        
        # Copiar bloques a diskettes
        $copiedDisks = @()
        
        for ($i = 0; $i -lt $blocks.Count; $i++) {
            $diskNum = $i + 1
            $block = $blocks[$i]
            
            $success = $false
            $retries = 0
            $maxRetries = 3
            
            while (-not $success -and $retries -lt $maxRetries) {
                Show-Banner "DISKETTE $diskNum DE $($blocks.Count)" -BorderColor Cyan -TextColor Yellow
                
                if ($retries -gt 0) {
                    Write-Host "⚠ Reintento $retries de $maxRetries" -ForegroundColor Yellow
                    Write-Host ""
                }
                
                Write-Host "Inserte un diskette VAC�O en la unidad $Script:FloppyDrive" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Presione ENTER para continuar o ESC para cancelar..." -ForegroundColor Gray
                
                $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                if ($key.VirtualKeyCode -eq 27) {
                    # ESC
                    Write-Host ""
                    Write-Host "Operación cancelada por el usuario" -ForegroundColor Yellow
                    return $false
                }
                
                # Formatear diskette
                Write-Host ""
                Write-Host "Formateando diskette $diskNum..." -ForegroundColor Cyan
                
                $formatted = Format-FloppyDisk -DriveLetter $Script:FloppyDrive -QuickFormat -FloppyNumber $diskNum
                
                if (-not $formatted) {
                    Write-Host "✗ Error formateando diskette" -ForegroundColor Red
                    Write-Host ""
                    $retries++
                    continue
                }
                
                # Copiar archivo
                Write-Host "Copiando archivo al diskette..." -ForegroundColor Cyan
                
                $copied = Copy-FileToFloppy -SourceFile $block.FullName -DestinationPath $Script:FloppyDrive
                
                if (-not $copied) {
                    Write-Host "✗ Error copiando archivo" -ForegroundColor Red
                    Write-Host ""
                    $retries++
                    continue
                }
                
                # Verificar integridad si está habilitado
                if ($VerifyDisks) {
                    Write-Host "Verificando integridad..." -ForegroundColor Cyan
                    
                    $floppyFile = Join-Path $Script:FloppyDrive $block.Name
                    $verified = Test-FloppyArchiveIntegrity -ArchivePath $floppyFile -CompressionTool "7z"
                    
                    if (-not $verified) {
                        Write-Host "✗ Verificación FALLÓ - diskette dañado" -ForegroundColor Red
                        Write-Host ""
                        $retries++
                        continue
                    }
                }
                
                Write-Host "✓ Diskette $diskNum completado correctamente" -ForegroundColor Green
                Write-Host ""
                
                $copiedDisks += $diskNum
                $success = $true
            }
            
            if (-not $success) {
                Show-Banner "ERROR - DISKETTE NO COPIABLE" -BorderColor Red -TextColor Red
                Write-Host ""
                Write-Host "No se pudo copiar el diskette $diskNum después de $maxRetries intentos." -ForegroundColor Red
                Write-Host ""
                Write-Host "Posibles causas:" -ForegroundColor Yellow
                Write-Host "  • Diskette dañado (muy común en diskettes viejos)" -ForegroundColor Gray
                Write-Host "  • Unidad de diskette defectuosa" -ForegroundColor Gray
                Write-Host "  • Protección contra escritura activada" -ForegroundColor Gray
                Write-Host ""
                Write-Host "Recomendación: Use medios más modernos (USB, ISO)" -ForegroundColor Cyan
                Write-Host ""
                return $false
            }
        }
        
        # Crear instalador en el primer diskette
        Show-Banner "GENERANDO INSTALADOR" -BorderColor Cyan -TextColor Cyan
        Write-Host "Inserte el diskette 1 nuevamente..." -ForegroundColor Cyan
        Write-Host ""
        $null = Read-Host "Presione ENTER cuando esté listo"
        
        $installerContent = New-FloppyInstallerScript -TotalDisks $blocks.Count -ArchiveBaseName "LLEVAR_FLP"
        $installerPath = Join-Path $Script:FloppyDrive "INSTALAR.BAT"
        
        try {
            Set-Content -Path $installerPath -Value $installerContent -Encoding ASCII
            Write-Host "✓ Instalador creado en diskette 1" -ForegroundColor Green
        }
        catch {
            Write-Log "Error creando instalador: $($_.Exception.Message)" "WARNING"
        }
        
        # Copiar 7z.exe al primer diskette si existe
        if ($SevenZPath -and (Test-Path $SevenZPath)) {
            try {
                $sevenZDest = Join-Path $Script:FloppyDrive "7z.exe"
                Copy-Item -Path $SevenZPath -Destination $sevenZDest -Force
                Write-Host "✓ 7z.exe copiado a diskette 1" -ForegroundColor Green
            }
            catch {
                Write-Log "Error copiando 7z.exe: $($_.Exception.Message)" "WARNING"
            }
        }
        
        # Crear marcador __EOF__ en el ÚLTIMO diskette
        Write-Host ""
        Write-Host "Inserte el diskette $($blocks.Count) (ÚLTIMO) nuevamente..." -ForegroundColor Cyan
        Write-Host ""
        $null = Read-Host "Presione ENTER cuando esté listo"
        
        $eofPath = Join-Path $Script:FloppyDrive "__EOF__"
        try {
            New-Item -ItemType File -Path $eofPath -Force | Out-Null
            Write-Host "✓ Marcador __EOF__ creado en diskette $($blocks.Count)" -ForegroundColor Green
        }
        catch {
            Write-Log "Error creando marcador __EOF__: $($_.Exception.Message)" "WARNING"
        }
        
        Show-Banner "✓ COPIA A DISKETTES COMPLETADA" -BorderColor Green -TextColor Green
        Write-Host ""
        Write-Host "Diskettes copiados: $($copiedDisks.Count) de $($blocks.Count)" -ForegroundColor White
        Write-Host ""
        Write-Host "Para instalar en otro equipo:" -ForegroundColor Cyan
        Write-Host "  1. Inserte el diskette 1" -ForegroundColor Gray
        Write-Host "  2. Ejecute: A:\INSTALAR.BAT" -ForegroundColor Gray
        Write-Host "  3. Siga las instrucciones" -ForegroundColor Gray
        Write-Host ""
        
        return $true
    }
    catch {
        Write-ErrorLog "Error en copia a diskettes" $_
        Show-Banner "ERROR EN COPIA A DISKETTES" -BorderColor Red -TextColor Red
        Write-Host ""
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        return $false
    }
    finally {
        # Limpiar archivos temporales
        if (Test-Path $TempDir) {
            try {
                Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-Log "No se pudo limpiar directorio temporal: $TempDir" "WARNING"
            }
        }
    }
}

# ========================================================================== #
#                    GENERACIÓN DE INSTALADOR                                #
# ========================================================================== #

function New-FloppyInstallerScript {
    <#
    .SYNOPSIS
        Genera un script BAT de instalación para diskettes
    #>
    param(
        [int]$TotalDisks,
        [string]$ArchiveBaseName = "LLEVAR_FLP"
    )
    
    $installer = @"
@ECHO OFF
REM Instalador generado por LLEVAR.PS1
REM Restaura archivos desde diskettes

CLS
ECHO.
ECHO ========================================
ECHO   INSTALADOR DESDE DISKETTES
ECHO ========================================
ECHO.
ECHO Este proceso restaurara los archivos
ECHO desde diskettes (hasta encontrar __EOF__).
ECHO.
ECHO Presione CTRL+C para cancelar o
PAUSE

REM Crear directorio temporal
IF NOT EXIST C:\LLEVAR_TEMP MD C:\LLEVAR_TEMP
CD /D C:\LLEVAR_TEMP

ECHO.
ECHO Copiando archivos desde diskettes...
ECHO.

REM Copiar primer diskette
CLS
ECHO Inserte el diskette 1 y presione una tecla...
PAUSE >NUL
ECHO Copiando disco 1...
COPY A:\*.* C:\LLEVAR_TEMP\ >NUL
IF ERRORLEVEL 1 GOTO ERROR_COPY

REM Copiar diskettes restantes hasta encontrar __EOF__
SET DISK=2
:COPY_LOOP

REM Verificar si ya tenemos __EOF__
IF EXIST C:\LLEVAR_TEMP\__EOF__ GOTO DECOMPRESS

CLS
ECHO.
ECHO Inserte el diskette %DISK% y presione una tecla...
ECHO (o ESC si no hay mas diskettes)
PAUSE >NUL

REM Verificar si el diskette tiene archivos
IF NOT EXIST A:\*.* GOTO ERROR_COPY

ECHO Copiando disco %DISK%...
COPY A:\*.* C:\LLEVAR_TEMP\ >NUL
IF ERRORLEVEL 1 GOTO ERROR_COPY

REM Incrementar contador y continuar
SET /A DISK+=1
GOTO COPY_LOOP

:DECOMPRESS
REM Descomprimir
ECHO.
ECHO Descomprimiendo archivos...

REM Buscar 7-Zip
IF EXIST "C:\Program Files\7-Zip\7z.exe" (
    "C:\Program Files\7-Zip\7z.exe" x $ArchiveBaseName.zip.001 -o"C:\LLEVAR_RESTORED"
    IF ERRORLEVEL 0 GOTO DONE
)

IF EXIST "C:\Program Files (x86)\7-Zip\7z.exe" (
    "C:\Program Files (x86)\7-Zip\7z.exe" x $ArchiveBaseName.zip.001 -o"C:\LLEVAR_RESTORED"
    IF ERRORLEVEL 0 GOTO DONE
)

IF EXIST C:\LLEVAR_TEMP\7z.exe (
    C:\LLEVAR_TEMP\7z.exe x $ArchiveBaseName.zip.001 -o"C:\LLEVAR_RESTORED"
    IF ERRORLEVEL 0 GOTO DONE
)

ECHO ERROR: No se encontro 7-Zip
ECHO Instale 7-Zip desde www.7-zip.org
PAUSE
GOTO ERROR

:DONE
CLS
ECHO.
ECHO ========================================
ECHO   INSTALACION COMPLETADA
ECHO ========================================
ECHO.
ECHO Archivos restaurados en:
ECHO   C:\LLEVAR_RESTORED
ECHO.
ECHO Puede eliminar C:\LLEVAR_TEMP
ECHO.
PAUSE
EXIT

:ERROR_COPY
ECHO.
ECHO ERROR copiando desde diskette
PAUSE
GOTO ERROR

:ERROR
ECHO.
ECHO Hubo un error durante la instalacion
PAUSE
EXIT
"@

    return $installer
}

# ========================================================================== #
#                    FUNCIONES DE LECTURA DESDE DISKETTES                     #
# ========================================================================== #

function Request-NextFloppy {
    <#
    .SYNOPSIS
        Solicita insertar el siguiente diskette
    #>
    param(
        [string]$ExpectedBlock = "siguiente diskette",
        [int]$DiskNumber = 1
    )
    
    Write-Host ""
    Write-Host "Inserte el diskette $DiskNumber" -ForegroundColor Yellow
    if ($ExpectedBlock -ne "siguiente diskette") {
        Write-Host "Falta el bloque: $ExpectedBlock" -ForegroundColor Yellow
    }
    Write-Host "Presione ENTER cuando esté listo o ESC para cancelar..." -ForegroundColor Gray
    
    $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    if ($key.VirtualKeyCode -eq 27) {
        return $null
    }
    
    # Esperar a que se detecte el diskette
    $maxWait = 30
    $waited = 0
    while (-not (Test-FloppyInserted -DriveLetter $Script:FloppyDrive) -and $waited -lt $maxWait) {
        Start-Sleep -Seconds 1
        $waited++
    }
    
    if (Test-FloppyInserted -DriveLetter $Script:FloppyDrive) {
        return $Script:FloppyDrive
    }
    
    Write-Host "No se detectó diskette en la unidad" -ForegroundColor Red
    return $null
}

function Get-BlocksFromFloppy {
    <#
    .SYNOPSIS
        Obtiene bloques desde el diskette actual
    #>
    param([string]$FloppyPath = "A:\")
    
    if (-not (Test-FloppyInserted -DriveLetter $FloppyPath)) {
        return @()
    }
    
    try {
        $files = Get-ChildItem $FloppyPath -File -ErrorAction Stop | Where-Object {
            $_.Name -match '\.(zip|7z|alx)\d+$' -or 
            $_.Name -match '\.zip\.\d{3}$' -or 
            $_.Name -match '\.7z\.\d{3}$' -or
            $_.Name -match '\.alx\d{4}$'
        }
        return $files | Sort-Object Name | Select-Object -ExpandProperty FullName
    }
    catch {
        Write-Log "Error leyendo diskette: $($_.Exception.Message)" "WARNING"
        return @()
    }
}

function Get-AllBlocksFromFloppies {
    <#
    .SYNOPSIS
        Recopila todos los bloques desde múltiples diskettes
    .DESCRIPTION
        Lee diskettes secuencialmente hasta encontrar __EOF__
    #>
    param([string]$TempDir)
    
    if (-not (Test-FloppyDriveAvailable)) {
        throw "No se detectó unidad de diskette"
    }
    
    $blocks = @{}
    $diskNumber = 1
    $floppyPath = $Script:FloppyDrive
    
    Write-Host ""
    Write-Host "Leyendo bloques desde diskettes..." -ForegroundColor Cyan
    Write-Host "Inserte el diskette 1 y presione ENTER..." -ForegroundColor Yellow
    
    $null = Read-Host
    
    while ($true) {
        # Verificar si hay diskette insertado
        if (-not (Test-FloppyInserted -DriveLetter $floppyPath)) {
            $nextFloppy = Request-NextFloppy -DiskNumber $diskNumber
            if (-not $nextFloppy) {
                break
            }
            $floppyPath = $nextFloppy
        }
        
        # Leer bloques del diskette actual
        $currentBlocks = Get-BlocksFromFloppy -FloppyPath $floppyPath
        
        foreach ($block in $currentBlocks) {
            $name = Split-Path $block -Leaf
            if (-not $blocks.ContainsKey($name)) {
                # Copiar bloque a temporal
                $tempBlock = Join-Path $TempDir $name
                Copy-Item -Path $block -Destination $tempBlock -Force
                $blocks[$name] = $tempBlock
                Write-Host "  ✓ Bloque encontrado: $name" -ForegroundColor Green
            }
        }
        
        # Verificar si hay __EOF__
        $eofPath = Join-Path $floppyPath "__EOF__"
        if (Test-Path $eofPath) {
            Write-Host ""
            Write-Host "✓ Marcador __EOF__ encontrado - todos los bloques leídos" -ForegroundColor Green
            break
        }
        
        # Determinar siguiente bloque esperado
        $sortedKeys = $blocks.Keys | Sort-Object
        if ($sortedKeys.Count -eq 0) {
            Write-Host "No se encontraron bloques en el diskette $diskNumber" -ForegroundColor Yellow
            $nextFloppy = Request-NextFloppy -DiskNumber ($diskNumber + 1)
            if (-not $nextFloppy) {
                break
            }
            $floppyPath = $nextFloppy
            $diskNumber++
            continue
        }
        
        $lastBlock = $sortedKeys[-1]
        
        # Inferir siguiente bloque
        $nextBlock = $null
        if ($lastBlock -match '\.alx(\d{4})$') {
            $num = [int]$matches[1]
            $nextNum = $num + 1
            $nextBlock = $lastBlock -replace '\.alx\d{4}$', ('.alx{0:D4}' -f $nextNum)
        }
        elseif ($lastBlock -match '\.(zip|7z)\.(\d{3})$') {
            $ext = $matches[1]
            $num = [int]$matches[2]
            $nextNum = $num + 1
            $nextBlock = $lastBlock -replace '\.(zip|7z)\.\d{3}$', (".$ext.{0:D3}" -f $nextNum)
        }
        elseif ($lastBlock -match '\.(\d{3})$') {
            $num = [int]$matches[1]
            $nextNum = $num + 1
            $nextBlock = $lastBlock -replace '\.\d{3}$', ('.{0:D3}' -f $nextNum)
        }
        
        if ($nextBlock) {
            $nextBlockPath = Join-Path $floppyPath $nextBlock
            if (Test-Path $nextBlockPath) {
                # El bloque existe en el diskette actual
                continue
            }
        }
        
        # Solicitar siguiente diskette
        $diskNumber++
        $nextFloppy = Request-NextFloppy -ExpectedBlock $nextBlock -DiskNumber $diskNumber
        if (-not $nextFloppy) {
            break
        }
        $floppyPath = $nextFloppy
    }
    
    return $blocks
}

function Restore-FromFloppyBlocks {
    <#
    .SYNOPSIS
        Restaura archivo comprimido desde bloques de diskettes y lo descomprime
    #>
    param(
        [hashtable]$Blocks,
        [string]$TempDir,
        [string]$Password = $null
    )
    
    if ($Blocks.Count -eq 0) {
        throw "No hay bloques para restaurar"
    }
    
    # Ordenar bloques
    $sortedBlocks = $Blocks.Values | Sort-Object
    
    # Determinar tipo de archivo y nombre base
    $firstBlock = $sortedBlocks[0]
    $firstBlockName = Split-Path $firstBlock -Leaf
    
    $archivePath = $null
    $compressionType = $null
    
    if ($firstBlockName -match '^(.+?)\.(zip|7z)\.\d{3}$') {
        # Volúmenes 7-Zip o ZIP
        $baseName = $matches[1]
        $ext = $matches[2]
        $compressionType = if ($ext -eq "7z") { "7ZIP" } else { "ZIP" }
        
        # Para volúmenes 7-Zip/ZIP, usar el primer volumen directamente
        # 7-Zip puede leer volúmenes automáticamente si están en la misma carpeta
        $firstVolume = $sortedBlocks[0]
        $archivePath = $firstVolume
        
        # Si los bloques están en TempDir pero el primer volumen tiene otro path,
        # copiar todos los volúmenes a TempDir para que 7-Zip los encuentre
        $firstVolumeName = Split-Path $firstVolume -Leaf
        $expectedFirstVolume = Join-Path $TempDir $firstVolumeName
        if ($firstVolume -ne $expectedFirstVolume) {
            # Copiar todos los volúmenes a TempDir
            Write-Host "Copiando volúmenes a directorio temporal..." -ForegroundColor Cyan
            foreach ($block in $sortedBlocks) {
                $blockName = Split-Path $block -Leaf
                $destBlock = Join-Path $TempDir $blockName
                Copy-Item -Path $block -Destination $destBlock -Force
            }
            $archivePath = $expectedFirstVolume
        }
    }
    elseif ($firstBlockName -match '^(.+?)\.alx\d{4}$') {
        # Bloques .alx (ZIP nativo dividido)
        $baseName = $matches[1]
        $archivePath = Join-Path $TempDir "$baseName.zip"
        $compressionType = "NATIVE_ZIP"
        
        # Reconstruir ZIP desde bloques
        Write-Host "Reconstruyendo archivo $baseName.zip desde bloques..." -ForegroundColor Cyan
        Join-FromBlocks -Blocks $sortedBlocks -OutputFile $archivePath
    }
    else {
        throw "Formato de bloque no reconocido: $firstBlockName"
    }
    
    # Descomprimir
    Write-Host "Descomprimiendo archivo..." -ForegroundColor Cyan
    $extractPath = Join-Path $TempDir "EXTRACTED"
    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
    
    if ($compressionType -eq "7ZIP") {
        $sevenZ = Get-SevenZipLlevar
        if (-not $sevenZ -or $sevenZ -eq "NATIVE_ZIP") {
            throw "Se requiere 7-Zip para descomprimir"
        }
        
        $sevenArgs = @("x", "-o`"$extractPath`"", "-y")
        if ($Password) {
            $sevenArgs += "-p$Password"
        }
        $sevenArgs += "`"$archivePath`""
        
        $process = Start-Process -FilePath $sevenZ -ArgumentList $sevenArgs -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -ne 0) {
            throw "Error descomprimiendo con 7-Zip (código: $($process.ExitCode))"
        }
    }
    elseif ($compressionType -eq "NATIVE_ZIP" -or $compressionType -eq "ZIP") {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($archivePath, $extractPath, $true)
    }
    
    return $extractPath
}

# ========================================================================== #
#                    EXPORTAR FUNCIONES                                      #
# ========================================================================== #

Export-ModuleMember -Function @(
    'Test-FloppyDriveAvailable',
    'Test-FloppyInserted',
    'Format-FloppyDisk',
    'Copy-FileToFloppy',
    'Test-FloppyArchiveIntegrity',
    'Copy-ToFloppyDisks',
    'Request-NextFloppy',
    'Get-BlocksFromFloppy',
    'Get-AllBlocksFromFloppies',
    'Restore-FromFloppyBlocks'
)
