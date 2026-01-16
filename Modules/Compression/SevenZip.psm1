# ============================================================================ #
# Archivo: Q:\Utilidad\LLevar\Modules\Compression\SevenZip.psm1
# Descripción: Funciones para localizar y usar 7-Zip para compresión/descompresión
# ============================================================================ #

# Asegurar dependencias UI (barra de progreso)
$modulesRoot = Split-Path $PSScriptRoot -Parent
$progressModule = Join-Path $modulesRoot "UI\ProgressBar.psm1"
if (-not (Get-Command Write-LlevarProgressBar -ErrorAction SilentlyContinue)) {
    Import-Module $progressModule -Force -Global -ErrorAction SilentlyContinue
}

function Get-SevenZipLlevar {
    <#
    .SYNOPSIS
        Localiza o descarga 7-Zip para usar en compresión
    #>

    Write-Log "Buscando 7-Zip..." "DEBUG"

    # Construir lista de todas las ubicaciones candidatas
    $scriptRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Write-Log "Script root: $scriptRoot" "DEBUG"

    $candidates = @()

    # 1) 7z/7za en PATH
    try {
        $cmd = Get-Command 7z -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) {
            $candidates += $cmd.Source
            Write-Log "Candidato PATH: $($cmd.Source)" "DEBUG"
        }
    }
    catch { }

    # 2) 7z/7za en el root del script (Q:\Utilidad\Llevar\)
    $localPaths = @(
        (Join-Path $scriptRoot "7z.exe"),
        (Join-Path $scriptRoot "7za.exe")
    )

    foreach ($p in $localPaths) {
        $resolved = [System.IO.Path]::GetFullPath($p)
        Write-Log "Verificando local: $resolved" "DEBUG"
        if (Test-Path $resolved) {
            $candidates += $resolved
            Write-Log " Encontrado" "DEBUG"
        }
        else {
            Write-Log " No existe" "DEBUG"
        }
    }

    # 3) Instalaciones estandar del sistema
    $systemPaths = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe"
    )

    foreach ($p in $systemPaths) {
        Write-Log "Verificando sistema: $p" "DEBUG"
        if (Test-Path $p) {
            $candidates += $p
            Write-Log "  ✓ Encontrado" "DEBUG"
        }
    }

    # Probar cada candidato
    foreach ($candidate in $candidates) {
        Write-Log "Probando: $candidate" "DEBUG"
        try {
            $testResult = & $candidate 2>&1
            if ($testResult) {
                Write-Host "7-Zip encontrado: $candidate" -ForegroundColor Green
                Write-Log "7-Zip seleccionado: $candidate" "INFO"
                return $candidate
            }
        }
        catch {
            Write-Log "Error probando $candidate : $($_.Exception.Message)" "DEBUG"
        }
    }

    # 4) Descargar versión portable si no se encontró ninguno
    Write-Host "7-Zip no encontrado. Intentando descargar versión portable..." -ForegroundColor Yellow
    Write-Log "Descargando 7-Zip portable..." "INFO"

    try {
        $url = "https://www.7-zip.org/a/7za920.zip"
        $zipPath = Join-Path $scriptRoot "7za_portable.zip"
        $destExe = Join-Path $scriptRoot "7za.exe"

        Write-Log "URL: $url" "DEBUG"
        Write-Log "Destino: $destExe" "DEBUG"

        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $scriptRoot, $true)

        Remove-Item $zipPath -ErrorAction SilentlyContinue

        if (Test-Path $destExe) {
            Write-Host "7-Zip portable descargado: $destExe" -ForegroundColor Green
            Write-Log "7-Zip portable instalado: $destExe" "INFO"
            return $destExe
        }
        else {
            Write-Log "No se pudo extraer 7za.exe del ZIP" "ERROR"
            Write-Host "No se pudo extraer 7za.exe del ZIP descargado." -ForegroundColor Red
        }
    }
    catch {
        Write-Log "Error descargando 7-Zip: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        Write-Host "No se pudo descargar 7-Zip portable: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 5) Ofrecer compresión ZIP nativa como último recurso
    if (Test-Windows10OrLater) {
        Write-Host ""
        Write-Host "7-Zip no está disponible, pero se detectó Windows 10 o superior." -ForegroundColor Yellow
        Write-Host "Puede usar la compresión ZIP nativa de Windows (sin soporte para contraseñas)." -ForegroundColor Yellow
        Write-Host ""
        $response = Read-Host "Desea usar compresión ZIP nativa? (S/N)"

        if ($response -match '^[SsYy]') {
            Write-Log "Usuario seleccionó compresión ZIP nativa" "INFO"
            return "NATIVE_ZIP"
        }
    }

    Write-Log "7-Zip no encontrado y no se pudo descargar" "ERROR"
    throw "7-Zip no encontrado ni descargado. No se puede continuar."
}

function Get-SevenZip {
    <#
    .SYNOPSIS
        Versión simplificada de Get-SevenZipLlevar para usar en instaladores
    #>

    # 1) Intentar ejecutar 7z desde el PATH (puede estar en variables de entorno)
    try {
        $cmd = Get-Command 7z -ErrorAction SilentlyContinue
        if ($cmd) {
            # Verificar que realmente funciona
            $testResult = & $cmd.Source 2>&1
            if ($LASTEXITCODE -ne 255 -and $testResult) {
                return $cmd.Source
            }
        }
    }
    catch {
        # Si falla, continuar con la búsqueda en rutas
    }

    # 2) Buscar 7z/7za junto al INSTALAR.ps1 (en la USB)
    $localCandidates = @(
        (Join-Path $PSScriptRoot "7za.exe"),
        (Join-Path $PSScriptRoot "7z.exe")
    )
    foreach ($p in $localCandidates) {
        if (Test-Path $p) { return $p }
    }

    # 3) Buscar instalación estándar en el sistema
    $paths = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe"
    )

    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }

    Write-Host "No se encontró 7-Zip ni en la USB ni en el sistema." -ForegroundColor Yellow
    throw "No se puede continuar la instalación sin 7-Zip."
}

function Invoke-SevenZipWithProgress {
    <#
    .SYNOPSIS
        Ejecuta 7-Zip con barra de progreso en tiempo real y estimación de tiempo inteligente
    #>
    param(
        [string]$SevenZipPath,
        [string[]]$Arguments,
        [datetime]$StartTime,
        [int]$BarTop
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $SevenZipPath
    if (-not $Arguments) { $Arguments = @() }

    # ============================================================================
    # CORRECCIÓN DE ARGUMENTOS (ERROR 7)
    # ============================================================================
    if ($psi.PSObject.Properties.Name -contains 'ArgumentList') {
        # En PowerShell moderno (Core), ArgumentList maneja el escape automáticamente
        foreach ($arg in $Arguments) {
            [void]$psi.ArgumentList.Add($arg)
        }
    }
    else {
        # En Windows PowerShell 5.1, debemos construir la cadena manualmente con cuidado
        $psi.Arguments = (
            $Arguments | ForEach-Object {
                if ($_ -match ' ') {
                    # Envolvemos en comillas dobles estándar SIN el acento grave (`)
                    # 7-zip necesita recibir: "C:\Ruta con espacio"
                    "`"$_`""
                }
                else { $_ }
            }
        ) -join ' '
    }

    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardInput = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = Get-Location

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    # Loguear comando para depuración exacta
    $logCmd = "`"$SevenZipPath`""
    foreach ($arg in $Arguments) {
        if ($arg -match ' ') { $logCmd += " `"$arg`"" }
        else { $logCmd += " $arg" }
    }
    Write-Log "Iniciando 7-Zip: $logCmd" "DEBUG"

    # --- Variables de control ---
    $lastPct = 0
    $estimatedTotal = $null
    $firstBlockPct = 10
    $firstBlockTime = $null
    $estimationActive = $false
    $maxLogLines = 200
    $outputBuffer = New-Object System.Collections.Generic.List[string]
    $script:forceStop = $false
    $script:forcedExitCode = 2
    $script:promptRegex = '(?i)(overwrite|replace|y/n|yes/no|enter password|type password|press any key|continue\?)'

    # Limpiar buffer de teclado
    while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) }

    try {
        $null = $process.Start()
        $process.StandardInput.Close() # Evita bloqueos por peticiones de input
    }
    catch {
        Write-Log "Error al iniciar 7-Zip: $($_.Exception.Message)" "ERROR"
        throw "No se pudo iniciar 7-Zip: $($_.Exception.Message)"
    }

    # --- Bloques de procesamiento de salida ---
    $addOutputLine = {
        param([string]$line)
        if ([string]::IsNullOrWhiteSpace($line)) { return }
        $outputBuffer.Add($line)
        if ($outputBuffer.Count -gt $maxLogLines) {
            $outputBuffer.RemoveRange(0, $outputBuffer.Count - $maxLogLines)
        }
    }

    $updateFromLine = {
        param([string]$line)
        if (-not $line) { return }

        if ($line -match $script:promptRegex) {
            Write-Log "7-Zip esperaba entrada (prompt detectado); abortando." "ERROR"
            try { $process.Kill() } catch { }
            $script:forceStop = $true
            return
        }

        if ($line -match '\s*(\d+)%') {
            $rawPct = [int]$matches[1]
            if ($rawPct -lt $lastPct) { return }

            if (-not $estimationActive -and $rawPct -ge $firstBlockPct) {
                $firstBlockTime = (Get-Date) - $StartTime
                $estimatedTotal = $firstBlockTime.TotalSeconds * (100 / [double]$rawPct)
                $estimationActive = $true
            }

            $displayPct = $rawPct
            if ($estimationActive -and $estimatedTotal -gt 0) {
                $elapsed = (Get-Date) - $StartTime
                $estimatedPct = [int](($elapsed.TotalSeconds / $estimatedTotal) * 100)
                if ($estimatedPct -gt $rawPct -and $estimatedPct -le 100) { $displayPct = $estimatedPct }
            }

            if ($displayPct -gt 100) { $displayPct = 100 }
            Write-LlevarProgressBar -Percent $displayPct -StartTime $StartTime -Label "Compresión..." -Top $BarTop
            $lastPct = $displayPct
        }
    }

    # --- Bucle de ejecución ---
    $timeout = 0
    while (-not $process.HasExited) {
        if ([Console]::KeyAvailable) {
            if (([Console]::ReadKey($true)).Key -eq 'Escape') {
                try { $process.Kill() } catch { }
                throw "Compresión cancelada por el usuario (ESC)"
            }
        }

        $hadOutput = $false
        while ($process.StandardError.Peek() -ge 0) {
            $line = $process.StandardError.ReadLine()
            & $addOutputLine $line; & $updateFromLine $line; $hadOutput = $true
        }
        while ($process.StandardOutput.Peek() -ge 0) {
            $line = $process.StandardOutput.ReadLine()
            & $addOutputLine $line; & $updateFromLine $line; $hadOutput = $true
        }

        if ($hadOutput) { $timeout = 0 } else { $timeout++ }
        if ($timeout -ge 600) {
            # 60 segundos (600 * 100ms)
            try { $process.Kill() } catch { }
            throw "7-Zip no responde (timeout de 60 segundos)"
        }
        Start-Sleep -Milliseconds 100
        if ($script:forceStop) { break }
    }

    $process.WaitForExit()
    $exitCode = $process.ExitCode
    if ($script:forceStop -and $exitCode -eq 0) { $exitCode = 2 }

    # Limpieza final de logs y salida
    Write-Log "7-Zip terminó con código de salida: $exitCode" "DEBUG"

    if ($exitCode -ne 0) {
        Write-Log "Error detallado de 7-Zip:" "ERROR"
        
        # Mostramos los errores en pantalla antes de la pausa
        Write-Host "`n--- ERROR DETECTADO EN 7-ZIP (Código $exitCode) ---" -ForegroundColor Red
        $outputBuffer | ForEach-Object { 
            Write-Log $_ "ERROR"
            Write-Host " [7z]: $_" -ForegroundColor Yellow 
        }

        # ESTA ES LA PAUSA: Solo frena si hay error
        Write-Host "`nEl proceso se detuvo por un error." -ForegroundColor White
        Write-Host "Presiona cualquier tecla para ver el log y cerrar..." -ForegroundColor Cyan
        $null = [Console]::ReadKey($true) 

        return $exitCode
    }

    return 0
}

function Compress-Folder {
    <#
    .SYNOPSIS
        Comprime una carpeta usando 7-Zip o ZIP nativo
    #>
    param(
        $Origen,
        $Temp,
        $SevenZ,
        $Clave,
        [int]$BlockSizeMB,
        [string]$DestinoFinal = "",
        [string]$CustomName = ""
    )

    # Detectar si es un drive raíz (C:\, LLEVAR_ORIGEN:\, etc.)
    $isDriveRoot = $Origen -match '^[A-Z_]+:\\?$'

    # Determinar el nombre del archivo
    if ($CustomName) {
        $Name = $CustomName
    }
    elseif ($isDriveRoot) {
        # Si es drive raíz, usar el nombre del drive sin :\
        $Name = ($Origen -replace ':\\?$', '')
    }
    else {
        $Name = Split-Path $Origen -Leaf
    }

    # Verificar si se usa ZIP nativo
    if ($SevenZ -eq "NATIVE_ZIP") {
        $zipFile = Compress-WithNativeZip -Origen $Origen -Temp $Temp -Clave $Clave -DestinoFinal $DestinoFinal

        # Si BlockSizeMB > 0, dividir el ZIP en bloques
        if ($BlockSizeMB -gt 0) {
            Write-Host "`nDividiendo archivo ZIP en bloques de ${BlockSizeMB}MB..." -ForegroundColor Cyan
            $blocks = Split-IntoBlocks -File $zipFile -BlockSizeMB $BlockSizeMB -Temp $Temp
            return @{
                Files           = $blocks
                CompressionType = "NATIVE_ZIP"
                OriginalArchive = $zipFile
            }
        }
        else {
            return @{
                Files           = @($zipFile)
                CompressionType = "NATIVE_ZIP"
                OriginalArchive = $zipFile
            }
        }
    }

   # ============================================================================
    # Nombre de salida según volúmenes
    # CON volúmenes (-v): SIN extensión → 7-Zip genera Name.001, .002, etc.
    # SIN volúmenes: CON extensión .7z → genera Name.7z
    # ============================================================================

    # Asegurar que la carpeta temporal existe ANTES
    if (-not (Test-Path $Temp)) {
        Write-Log "Creando carpeta temporal: $Temp" "DEBUG"
        New-Item -ItemType Directory -Path $Temp -Force | Out-Null
    }

    # Determinar nombre base seguro
    if ($CustomName) {
        $baseName = $CustomName
    }
    elseif ($Origen) {
        $baseName = Split-Path $Origen -Leaf
    }
    else {
        throw "No se pudo determinar un nombre base para el archivo comprimido."
    }

    if ($BlockSizeMB -gt 0) {
        # CON volúmenes: SIN extensión
        $Out = Join-Path $Temp $baseName
    }
    else {
        # SIN volúmenes: CON extensión .7z
        $Out = Join-Path $Temp ("{0}.7z" -f $baseName)
    }

    # ============================================================================
    # Si $Out apunta a una CARPETA, resolver automáticamente el archivo dentro
    # ============================================================================

    if (Test-Path $Out -PathType Container) {
        Write-Log "Destino es carpeta, resolviendo archivo base dentro: $baseName" "DEBUG"
        $Out = Join-Path $Out $baseName
    }

    # ============================================================================
    # Limpieza segura de temporales
    # ============================================================================

    try {
        if ($Temp.Length -lt 5 -or $Temp -match '^[A-Z]:\\?$') {
            throw "Ruta Temp inválida o peligrosa: $Temp"
        }

        Get-ChildItem -Path $Temp -Force -ErrorAction SilentlyContinue |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log "No se pudo limpiar la carpeta temporal: $Temp" "WARN"
    }

    # ============================================================================
    # Mostrar información de origen y destino
    # ============================================================================

    Write-Host ""
    Write-Host "Comprimiendo:" -ForegroundColor Cyan
    Write-Host "  Origen:  $Origen" -ForegroundColor Gray
    $destinoMostrar = if ($DestinoFinal) { $DestinoFinal } else { "(no especificado)" }
    Write-Host "  Destino: $destinoMostrar" -ForegroundColor Gray
    Write-Host "  Método:  7-Zip" -ForegroundColor Gray
    Write-Host "  Bloques: ${BlockSizeMB}MB" -ForegroundColor Gray
    Write-Host ""

    $startTime = Get-Date
    $barTop = [console]::CursorTop
    Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Compresión..." -Top $barTop

    # Mostrar información de origen y destino
    Write-Host ""
    Write-Host "Comprimiendo:" -ForegroundColor Cyan
    Write-Host "  Origen:  $Origen" -ForegroundColor Gray
    $destinoMostrar = if ($DestinoFinal) { $DestinoFinal } else { "(no especificado)" }
    Write-Host "  Destino: $destinoMostrar" -ForegroundColor Gray
    Write-Host "  Método:  7-Zip" -ForegroundColor Gray
    Write-Host "  Bloques: ${BlockSizeMB}MB" -ForegroundColor Gray
    Write-Host ""

    $startTime = Get-Date
    $barTop = [console]::CursorTop
    Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Compresión..." -Top $barTop

    # ============================================================================
    # CONSTRUIR ARGUMENTOS EN EL ORDEN CORRECTO
    # ============================================================================
    $sevenArgs = @(
        "a",
        "-t7z",
        "-mx=9",
        "-y",
        "-aoa",
        "-bsp1",   # ← PROGRESO OBLIGATORIO
        "-bb1"     # ← VERBOSIDAD MÍNIMA
    )

    if ($Clave) {
        $sevenArgs += "-p$Clave"
    }

    # Agregar archivo de salida
    $sevenArgs += $Out

    # El parámetro de volumen (-v) DEBE ir al final de todos los argumentos
    $volumeArg = $null
    # CON volúmenes
    if ($BlockSizeMB -gt 0) {
        Get-ChildItem $Temp -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "$baseName.7z.*" } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
    else {
        if (Test-Path $Out) {
            Remove-Item $Out -Force -ErrorAction SilentlyContinue
        }
}



    # ============================================================================
    # EJECUCIÓN CON PROGRESO REAL
    # ============================================================================

    # Limpiar archivos previos para evitar prompts
    if ($BlockSizeMB -gt 0) {
        # Limpiar volúmenes previos: baseName.001, baseName.002, etc.
        $pattern = '^' + [regex]::Escape($baseName) + '\.\d+$'
        Get-ChildItem -Path $Temp -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match $pattern
        } | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    else {
        # Limpiar archivo único previo
        if (Test-Path $Out) {
            Remove-Item -Path $Out -Force -ErrorAction SilentlyContinue
        }
    }

    if ($isDriveRoot) {
        Push-Location $Origen
        try {
            # Comprimir todo el contenido del directorio actual
            $sevenArgs += "*"
            if ($volumeArg) { $sevenArgs += $volumeArg }

            Write-Log "Ejecutando desde directorio raíz: $Origen" "DEBUG"
            $logArgs = $sevenArgs | ForEach-Object { if ($_ -match '[\s]') { "`"$_`"" } else { $_ } }
            Write-Log "Argumentos: $($logArgs -join ' ')" "DEBUG"

            $exitCode = Invoke-SevenZipWithProgress `
                -SevenZipPath $SevenZ `
                -Arguments $sevenArgs `
                -StartTime $startTime `
                -BarTop $barTop

            if ($exitCode -ne 0) {
                Write-Log "7-Zip terminó con código de error: $exitCode" "ERROR"
                throw "7-Zip falló con código: $exitCode"
            }
        }
        finally {
            Pop-Location
        }
    }
    else {
        Push-Location $Origen
        try {
            $sevenArgs += "*"
            if ($volumeArg) { $sevenArgs += $volumeArg }

            Write-Log "Ejecutando compresión normal (pushd): $Origen" "DEBUG"
            $logArgs = $sevenArgs | ForEach-Object { if ($_ -match '[\s]') { "`"$_`"" } else { $_ } }
            Write-Log "Argumentos: $($logArgs -join ' ')" "DEBUG"

            $exitCode = Invoke-SevenZipWithProgress `
                -SevenZipPath $SevenZ `
                -Arguments $sevenArgs `
                -StartTime $startTime `
                -BarTop $barTop

            if ($exitCode -ne 0) {
                Write-Log "7-Zip terminó con código de error: $exitCode" "ERROR"
                throw "7-Zip falló con código: $exitCode"
            }
        }
        finally {
            Pop-Location
        }
    }

    Write-LlevarProgressBar -Percent 100 -StartTime $startTime -Label "Compresión..." -Top $barTop

    # ============================================================================
    # RECOLECTAR ARCHIVOS GENERADOS
    # ============================================================================
    if ($BlockSizeMB -le 0) {
        # Sin división: un solo .7z
        if (-not (Test-Path $Out)) {
            throw "7-Zip no generó el archivo esperado: $Out"
        }
        return @{
            Files           = @($Out)
            CompressionType = "7ZIP"
        }
    }

    # Con división: buscar volúmenes baseName.001, .002, etc.
    Write-Log "Buscando volúmenes en: ${Temp} con patrón: ${baseName}.0*" "DEBUG"

    $volumes = Get-ChildItem -Path $Temp -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -like "${baseName}.0*"
    } | Sort-Object Name

    Write-Log "Volúmenes encontrados: $($volumes.Count)" "DEBUG"
    if ($volumes) {
        foreach ($v in $volumes) {
            Write-Log "  - $($v.Name)" "DEBUG"
        }
    }

    if (-not $volumes -or $volumes.Count -eq 0) {
        # Verificar si se generó un archivo único (contenido menor al tamaño de bloque)
        $singleFilePath = Join-Path $Temp "${Name}.7z"
        Write-Log "No se encontraron volúmenes, verificando archivo único: ${singleFilePath}" "DEBUG"

        if (Test-Path -LiteralPath $singleFilePath) {
            Write-Host "Archivo comprimido menor a ${BlockSizeMB}MB, generado como archivo único." -ForegroundColor Yellow
            return @{
                Files           = @($singleFilePath)
                CompressionType = "7ZIP"
            }
        }

        # Listar todos los archivos en Temp para diagnóstico
        Write-Log "Archivos en ${Temp}:" "ERROR"
        Get-ChildItem -Path $Temp -File -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Log "  - $($_.Name) ($($_.Length) bytes)" "ERROR"
        }

        throw "7-Zip no generó ningún archivo de salida. Patrón buscado: ${baseName}.0*"
    }

    return @{
        Files           = ($volumes | Select-Object -ExpandProperty FullName)
        CompressionType = "7ZIP"
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Get-SevenZipLlevar',
    'Get-SevenZip',
    'Compress-Folder',
    'Invoke-SevenZipWithProgress'
)
