# ========================================================================== #
#                   MÓDULO: GENERADOR DE SCRIPT INSTALADOR                   #
# ========================================================================== #
# Propósito: Generar script INSTALAR.ps1 para USBs con contenido comprimido
# Funciones:
#   - New-InstallerScript: Genera INSTALAR.ps1 personalizado
# ========================================================================== #

# Importar dependencias
$ModulesPath = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $ModulesPath "Compression\BlockSplitter.psm1") -Force -Global

# ========================================================================== #
#                    PLANTILLA DEL INSTALADOR (EMBUTIDA)                     #
# ========================================================================== #

$script:InstallerBaseScript = @'
<#
INSTALAR.ps1  
Reconstruye bloques <Nombre>.alx0001 .  
Recrea archivo .7z  
Descomprime carpeta original  
Logs solo en caso de error: %TEMP%\INSTALAR_ERROR.log
#>

param(
    [string]$Destino
)

# Si no se especificó destino, usar el directorio actual de ejecución
if (-not $Destino) {
    if ($script:DefaultDestino) {
        $Destino = $script:DefaultDestino
    }
    else {
        # Usar el directorio actual desde donde se ejecuta el script
        $Destino = Get-Location | Select-Object -ExpandProperty Path
    }
}

# ========================================================================== #
#                          LOG Y MANEJO DE ERRORES                           #
# ========================================================================== #

$Global:LogFile = Join-Path $env:TEMP "INSTALAR_ERROR.log"

function Write-ErrorLog {
    param($Message, $ErrorRecord)

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $Global:LogFile ""
    Add-Content $Global:LogFile "[$time] ERROR: $Message"

    if ($ErrorRecord) {
        Add-Content $Global:LogFile "Línea: $($ErrorRecord.InvocationInfo.ScriptLineNumber)"
        Add-Content $Global:LogFile "Columna: $($ErrorRecord.InvocationInfo.OffsetInLine)"
        Add-Content $Global:LogFile "CallStack: $($ErrorRecord.InvocationInfo.PositionMessage)"
    }
}

# ========================================================================== #
#                           EXPLORADOR DOS CL�SICO                           #
# ========================================================================== #

function Select-FolderDOS {
    param([string]$Prompt)

    Write-Host ""
    Write-Host "=== $Prompt ===" -ForegroundColor Cyan

    $drives = Get-PSDrive -PSProvider FileSystem

    while ($true) {

        Write-Host ""
        Write-Host "Seleccione una unidad:"
        $i = 1
        foreach ($d in $drives) {
            Write-Host " [$i] $($d.Root)"
            $i++
        }
        Write-Host " [0] Cancelar"

        $sel = Read-Host "Opción"
        if ($sel -eq "0") { return $null }

        if ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $drives.Count) {
            $drive = $drives[[int]$sel - 1].Root

            while ($true) {
                Write-Host ""
                Write-Host "Contenido de $drive"
                $items = Get-ChildItem $drive -Directory -ErrorAction SilentlyContinue
                $j = 1
                foreach ($it in $items) {
                    Write-Host " [$j] $($it.Name)"
                    $j++
                }
                Write-Host " [..] Volver"
                Write-Host " [.] Seleccionar esta carpeta"

                $op = Read-Host "Opción"
                if ($op -eq '.') { return $drive }
                if ($op -eq '..') { break }

                if ($op -match '^\d+$' -and [int]$op -ge 1 -and [int]$op -le $items.Count) {
                    $drive = $items[[int]$op - 1].FullName
                }
            }
        }
    }
}

# ========================================================================== #
#                        DETECTAR VERSIÓN DE WINDOWS                         #
# ========================================================================== #

# Test-Windows10OrLater ahora está en Modules/Core/Validation.psm1

# Compress-WithNativeZip ahora está en Modules/Compression/NativeZip.psm1

# Get-SevenZip ahora está en Modules/Compression/SevenZip.psm1

# ========================================================================== #
#                     FUNCIONES DE BLOQUES (INYECTADAS)                      #
# ========================================================================== #

function Get-BlocksFromUnit {
    <#
    .SYNOPSIS
        Detecta bloques en una unidad (USB, carpeta, etc.)
    #>
    param([string]$Path)

    Get-ChildItem $Path -File |
    Where-Object {
        $_.Name -match '\.7z($|\.)' -or $_.Name -match '\.\d{3}$' -or $_.Name -match '\.alx\d{4}$' -or $_.Name -match '\.zip$'
    } |
    Sort-Object Name |
    Select-Object -ExpandProperty FullName
}

function Get-AllBlocks {
    <#
    .SYNOPSIS
        Recopila todos los bloques desde la carpeta actual
    #>
    param($InitialPath)

    $blocks = @{}
    $current = Get-BlocksFromUnit $InitialPath
    
    foreach ($c in $current) {
        $name = Split-Path $c -Leaf
        $blocks[$name] = $c
    }

    return $blocks
}

# Alias para compatibilidad con versiones anteriores del instalador
function Get-7z {
    return Get-SevenZip
}

# ========================================================================== #
#                          RECONSTRUIR ARCHIVO .7Z                           #
# ========================================================================== #

function Restore-7z {
    param($Blocks, $Temp)

    # Para volúmenes nativos de 7-Zip no hay que reconstruir nada;
    # simplemente devolver la ruta del primer volumen.
    $firstKey = ($Blocks.Keys | Sort-Object)[0]
    return $Blocks[$firstKey]
}

# ========================================================================== #
#                                DESCOMPRIMIR                                #
# ========================================================================== #

function Expand-7z {
    param($SevenZ, $Destino, $7z)

    Write-Host "Descomprimiendo..." -ForegroundColor Cyan
    & $7z x $SevenZ "-o$Destino" -y | Out-Null
    Write-Host "Completado." -ForegroundColor Green
}

function Expand-NativeZip {
    param($ZipFile, $Destino)

    Write-Host "Descomprimiendo con ZIP nativo de Windows..." -ForegroundColor Cyan
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $Destino, $true)
        Write-Host "Completado." -ForegroundColor Green
    }
    catch {
        Write-Host "Error al descomprimir ZIP: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# ========================================================================== #
#                     RECONSTRUIR ZIP DESDE BLOQUES .alx                     #
# ========================================================================== #

function Restore-ZipFromBlocks {
    param($blocks, $Temp)

    Write-Host "Reconstruyendo archivo ZIP desde bloques..." -ForegroundColor Cyan
    
    $sorted = $blocks.Keys | Sort-Object
    $first = $sorted[0]
    
    # Determinar nombre base
    if ($first -match '^(?<name>.+)\.alx\d+$') {
        $baseName = $matches['name']
    }
    else {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($first)
    }
    
    $zipOutput = Join-Path $Temp "$baseName.zip"
    $outStream = [System.IO.File]::Create($zipOutput)
    
    $totalBlocks = $sorted.Count
    $current = 0
    
    foreach ($blockName in $sorted) {
        $current++
        $blockPath = $blocks[$blockName]
        
        Write-Host "Copiando bloque $current de $totalBlocks : $blockName" -ForegroundColor Gray
        
        if (-not (Test-Path $blockPath)) {
            $outStream.Close()
            throw "Falta el bloque: $blockName"
        }
        
        try {
            $inStream = [System.IO.File]::OpenRead($blockPath)
            $inStream.CopyTo($outStream)
            $inStream.Close()
        }
        catch {
            $outStream.Close()
            throw "Error al copiar bloque $blockName : $($_.Exception.Message)"
        }
    }
    
    $outStream.Close()
    Write-Host "Archivo ZIP reconstruido: $zipOutput" -ForegroundColor Green
    return $zipOutput
}

# ========================================================================== #
#                         MANEJAR CARPETA EXISTENTE                          #
# ========================================================================== #

function Resolve-ExistingFolder {
    param($Destino, $FolderName)

    $target = Join-Path $Destino $FolderName

    if (-not (Test-Path $target)) { return $target }

    Write-Host "La carpeta $FolderName ya existe." -ForegroundColor Yellow
    Write-Host "[1] Sobrescribir todo"
    Write-Host "[2] Sobrescribir solo más nuevos"
    Write-Host "[3] Elegir otra carpeta"
    Write-Host "[4] Cancelar"

    $opt = Read-Host "Opción"
    switch ($opt) {
        "1" { return $target }
        "2" { return $target } # la lógica se aplica al descomprimir
        "3" {
            $nuevo = Select-FolderDOS "Seleccione nuevo destino"
            return "$nuevo\$FolderName"
        }
        "4" { throw "Instalación cancelada" }
        default { return $target }
    }
}

# ========================================================================== #
#                       FLUJO PRINCIPAL DEL INSTALADOR                       #
# ========================================================================== #

try {

    # Determinar unidad de origen
    $myPath = $PSScriptRoot + "\"
    Write-Host "Buscando bloques en $myPath"

    $blocks = Get-AllBlocks $myPath

    if ($blocks.Count -eq 0) { throw "No hay bloques de archivo comprimido." }

    # Determinar nombre base (sin extensión de volumen ni .7z)
    $first = ($blocks.Keys | Sort-Object)[0]
    
    # Casos posibles:
    # - Duke_3D.7z.001 → Duke_3D
    # - Duke_3D.7z → Duke_3D
    # - Duke_3D.001 → Duke_3D
    # - Duke_3D.alx001 → Duke_3D
    
    if ($first -match '^(?<n>.+?)\.(?:7z\.)?(?:alx)?\d{3}$') {
        # Tiene extensión de volumen (.001, .7z.001, .alx001)
        $FolderName = $matches['n']
    }
    elseif ($first -match '^(?<n>.+?)\.7z$') {
        # Solo .7z sin volúmenes
        $FolderName = $matches['n']
    }
    elseif ($first -match '^(?<n>.+?)\.zip$') {
        # Solo .zip
        $FolderName = $matches['n']
    }
    else {
        # Fallback: quitar extensión
        $FolderName = [System.IO.Path]::GetFileNameWithoutExtension($first)
    }

    # Determinar destino
    # Ya viene configurado desde el bloque param() con fallback al directorio actual
    
    if (-not (Test-Path $Destino)) {
        Write-Host "Destino no existe. Creando..."
        New-Item -ItemType Directory -Path $Destino -Force | Out-Null
    }

    # Manejar carpeta existente
    $Destino = Resolve-ExistingFolder $Destino $FolderName

    # Crear temporales
    $Temp = Join-Path $env:TEMP "INSTALAR_TEMP"
    if (Test-Path $Temp) { Remove-Item $Temp -Recurse -Force }
    New-Item -ItemType Directory -Path $Temp | Out-Null

    # Verificar tipo de compresión (por defecto 7ZIP si no está definido)
    if (-not $script:CompressionType) {
        $script:CompressionType = "7ZIP"
    }

    Write-Host "Tipo de compresión detectado: $script:CompressionType" -ForegroundColor Cyan

    if ($script:CompressionType -eq "NATIVE_ZIP") {
        # Flujo para ZIP nativo
        Write-Host "Procesando archivo comprimido con ZIP nativo de Windows..." -ForegroundColor Cyan
        
        # Reconstruir ZIP desde bloques .alx
        $zipFull = Restore-ZipFromBlocks $blocks $Temp
        
        # Descomprimir con ZIP nativo
        Expand-NativeZip $zipFull $Destino
    }
    else {
        # Flujo para 7-Zip (por defecto)
        # Reconstruir 7z
        $SevenZFull = Restore-7z $blocks $Temp

        # Detectar 7z
        $7z = Get-7z

        # Descomprimir
        Expand-7z $SevenZFull $Destino $7z
    }

    # Limpieza
    Remove-Item $Temp -Recurse -Force

    Write-Host "`n✓ Instalación completada."
}
catch {
    Write-ErrorLog "Error en instalación" $_
    Write-Host "Ocurrió un error. Revise el log en $Global:LogFile" -ForegroundColor Red
}
'@

function New-InstallerScript {
    <#
    .SYNOPSIS
        Genera el ecosistema de restauración: Instalar.ps1 (lógica) e Instalar.cmd (lanzador).
    #>
    param(
        [string]$Destino,        
        [Parameter(Mandatory = $true)]
        [string]$Temp,        
        [string]$CompressionType = "7ZIP"
    )
    
    # 1. Obtener el template base
    if (-not $script:InstallerBaseScript) {
        Write-Log "Error: El template base del instalador no está cargado." "ERROR"
        return $null
    }

    # Dividir template en líneas
    $lines = $script:InstallerBaseScript -split "`r?`n"
    
    # 2. Localizar bloque param() para inyectar variables de configuración
    $paramStart = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*param\(') {
            $paramStart = $i
            break
        }
    }
    
    if ($null -eq $paramStart) {
        $installerPath = Join-Path $Temp "Instalar.ps1"
        Set-Content -Path $installerPath -Value $lines -Encoding UTF8
    }
    else {
        # Encontrar fin del bloque param()
        $paramEnd = $paramStart
        while ($paramEnd -lt ($lines.Count - 1) -and $lines[$paramEnd] -notmatch '^\s*\)') {
            $paramEnd++
        }
        $insertIndex = $paramEnd + 1
        
        # Preparar líneas a inyectar (Destino y Tipo de Compresión)
        $escapedDestino = if ($Destino) { $Destino -replace "'", "''" } else { "" }
        $injectionBlock = @(
            "",
            "# --- Variables inyectadas por LLEVAR-USB ---",
            "`$script:DefaultDestino = '$escapedDestino'",
            "`$script:CompressionType = '$CompressionType'",
            "# ------------------------------------------",
            ""
        )
        
        # Reconstruir con las variables inyectadas
        $newLines = $lines[0..($insertIndex - 1)] + $injectionBlock + $lines[$insertIndex..($lines.Count - 1)]
        
        # 3. Inyectar la función Get-SevenZip (Búsqueda inteligente en destino)
        $get7zInsertIndex = -1
        for ($i = 0; $i -lt $newLines.Count; $i++) {
            if ($newLines[$i] -match "# Get-SevenZip ahora está en Modules") {
                $get7zInsertIndex = $i + 1
                break
            }
        }
        
        if ($get7zInsertIndex -gt 0) {
            $get7zPatch = @'
function Get-SevenZip {
    $llevar7z = "C:\Llevar\7za.exe"
    if (Test-Path $llevar7z) { return $llevar7z }
    
    # 1) Buscar en PATH
    $cmd = Get-Command 7za, 7z -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    
    # 2) Rutas estándar
    $stdPaths = @("${env:ProgramFiles}\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe")
    foreach ($p in $stdPaths) { if (Test-Path $p) { return $p } }
    
    # 3) Descarga de emergencia a C:\Llevar
    Write-Host ">> 7-Zip no encontrado. Descargando motor portable..." -ForegroundColor Yellow
    $url = "https://www.7-zip.org/a/7za920.zip"
    $t = Join-Path $env:TEMP "7z_Llevar"
    New-Item $t -ItemType Directory -Force | Out-Null
    Invoke-WebRequest $url -OutFile "$t\7z.zip" -UseBasicParsing
    Expand-Archive "$t\7z.zip" -DestinationPath $t -Force
    
    if (-not (Test-Path "C:\Llevar")) {
        New-Item -Path "C:\Llevar" -ItemType Directory -Force | Out-Null
    }
    
    Copy-Item -Path "$t\7za.exe" -Destination $llevar7z -Force -ErrorAction SilentlyContinue
    if (Test-Path $llevar7z) { return $llevar7z }
    
    throw "7-Zip no encontrado ni descargado. No se puede continuar."
}
'@ -split "`r?`n"
            
            $newLines = $newLines[0..($get7zInsertIndex - 1)] + $get7zPatch + $newLines[$get7zInsertIndex..($newLines.Count - 1)]
        }
        
        # 4. Guardar el script Instalar.ps1 final
        $installerPath = Join-Path $Temp "Instalar.ps1"
        $newLines | Set-Content -Path $installerPath -Encoding UTF8
    }

    # ==========================================================================
    # 5. GENERAR EL LANZADOR .CMD (El "Puente" de compatibilidad)
    # ==========================================================================
    $installerCmd = Join-Path $Temp "Instalar.cmd"
    $cmdContent = @'
@echo off
setlocal
title RESTAURANDO ARCHIVOS - LLEVAR v2.0
echo ------------------------------------------------------------
echo  LLEVAR: Lanzando instalador de PowerShell...
echo ------------------------------------------------------------

:: Detectar PowerShell 7 (pwsh) o fallback a 5.1 (powershell)
where pwsh.exe >nul 2>&1
if %errorlevel% == 0 (set "PS=pwsh.exe") else (set "PS=powershell.exe")

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar.ps1"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] La restauracion no pudo completarse.
    pause
) else (
    echo [OK] Proceso terminado.
    timeout /t 5
)
'@
    $cmdContent | Set-Content -Path $installerCmd -Encoding ASCII

    Write-Log "Ecosistema de instalación generado en: $Temp" "INFO"
    return $installerPath
}
# Exportar funciones
Export-ModuleMember -Function @(
    'New-InstallerScript'
)
