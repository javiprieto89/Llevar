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
            Write-Log "  ✓ Encontrado" "DEBUG"
        }
        else {
            Write-Log "  ✗ No existe" "DEBUG"
        }
    }
    
    # 3) Instalaciones estándar del sistema
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
        $response = Read-Host "¿Desea usar compresión ZIP nativa? (S/N)"
        
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
        Ejecuta 7-Zip con barra de progreso en tiempo real y estimación inteligente
    .DESCRIPTION
        Usa System.Diagnostics.Process para leer STDERR de 7-Zip en streaming real.
        Implementa estimación de tiempo basada en el primer bloque procesado.
    #>
    param(
        [string]$SevenZipPath,
        [string[]]$Arguments,
        [datetime]$StartTime,
        [int]$BarTop
    )

    # ============================================================================
    # CONFIGURAR PROCESS PARA STREAMING REAL
    # ============================================================================
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $SevenZipPath
    $psi.Arguments = ($Arguments -join ' ')
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = Get-Location

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    Write-Log "Iniciando 7-Zip con streaming real: `"$SevenZipPath`" $($Arguments -join ' ')" "DEBUG"

    # Variables de control de progreso
    $lastPct = 0
    $estimatedTotal = $null
    $firstBlockPct = 10          # Porcentaje de referencia para la primera medición
    $firstBlockTime = $null
    $estimationActive = $false
    
    # Iniciar proceso
    $null = $process.Start()

    # ============================================================================
    # LEER STDERR EN TIEMPO REAL (aquí es donde 7-Zip emite el %)
    # ============================================================================
    while (-not $process.HasExited) {
        # Verificar cancelación con ESC
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq 'Escape') {
                Write-Log "Cancelando compresión (ESC presionado)..." "INFO"
                $process.Kill()
                $process.WaitForExit()
                throw "Compresión cancelada por el usuario (ESC)"
            }
        }
        
        # Leer todas las líneas disponibles sin bloquear
        while (-not $process.StandardError.EndOfStream) {
            $line = $process.StandardError.ReadLine()

            # Detectar porcentaje en la salida: "  5%" o " 42%"
            if ($line -match '\s*(\d+)%') {
                $rawPct = [int]$matches[1]

                # ============================================================
                # FALLBACK INTELIGENTE: evitar retrocesos en el porcentaje
                # ============================================================
                if ($rawPct -lt $lastPct) {
                    Write-Log "Porcentaje retrocedió de $lastPct% a $rawPct%, ignorando" "DEBUG"
                    continue
                }

                # ============================================================
                # ESTIMACIÓN BASADA EN PRIMER BLOQUE
                # ============================================================
                if (-not $estimationActive -and $rawPct -ge $firstBlockPct) {
                    # Primera vez que alcanzamos el umbral de referencia
                    $firstBlockTime = (Get-Date) - $StartTime
                    $estimatedTotal = $firstBlockTime.TotalSeconds * (100 / $rawPct)
                    $estimationActive = $true
                    
                    Write-Log "Estimación activada: $rawPct% en $($firstBlockTime.TotalSeconds)s → Total estimado: $([int]$estimatedTotal)s" "DEBUG"
                }

                # Calcular porcentaje a mostrar (acumulado vs real)
                $displayPct = $rawPct
                
                if ($estimationActive) {
                    # Calcular progreso estimado basado en tiempo transcurrido
                    $elapsed = (Get-Date) - $StartTime
                    $estimatedPct = [int](($elapsed.TotalSeconds / $estimatedTotal) * 100)
                    
                    # Usar el MAYOR entre el real y el estimado para suavizar
                    # Esto evita que la barra se "congele" si 7-Zip se detiene en un %
                    if ($estimatedPct -gt $rawPct -and $estimatedPct -le 100) {
                        $displayPct = $estimatedPct
                        Write-Log "Usando estimado: $displayPct% (real: $rawPct%)" "DEBUG"
                    }
                }

                # Limitar a 100% máximo
                if ($displayPct -gt 100) { $displayPct = 100 }

                # Actualizar barra de progreso
                Write-LlevarProgressBar `
                    -Percent $displayPct `
                    -StartTime $StartTime `
                    -Label "Compresión..." `
                    -Top $BarTop `
                    -CheckCancellation

                $lastPct = $displayPct
            }
        }

        # Pequeña pausa para no saturar CPU
        Start-Sleep -Milliseconds 100
    }

    # Esperar a que el proceso termine completamente
    $process.WaitForExit()
    $exitCode = $process.ExitCode

    # Cerrar streams
    $process.StandardError.Close()
    $process.StandardOutput.Close()

    Write-Log "7-Zip terminó con código de salida: $exitCode" "DEBUG"

    return $exitCode
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
        $zipFile = Compress-WithNativeZip -Origen $Origen -Temp $Temp -Clave $Clave -DestinoFinal $DestinoFinal -BlockSizeMB $BlockSizeMB
        
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
    # FIX: Determinar el nombre de salida según si hay volúmenes o no
    # ============================================================================
    if ($BlockSizeMB -gt 0) {
        # CON volúmenes: NO incluir extensión .7z
        # 7-Zip añadirá automáticamente .7z.001, .7z.002, etc.
        $Out = Join-Path $Temp $Name
    }
    else {
        # SIN volúmenes: incluir extensión .7z normal
        $Out = Join-Path $Temp "$Name.7z"
    }
    # ============================================================================

    # Verificar que la carpeta temporal existe
    if (-not (Test-Path $Temp)) {
        Write-Log "Creando carpeta temporal: $Temp" "DEBUG"
        New-Item -ItemType Directory -Path $Temp -Force | Out-Null
    }

    # Mostrar información de origen y destino
    Write-Host ""
    Write-Host "Comprimiendo:" -ForegroundColor Cyan
    Write-Host "  Origen:  $Origen" -ForegroundColor Gray
    Write-Host "  Destino: $(if ($DestinoFinal) { $DestinoFinal } else { $Temp })" -ForegroundColor Gray
    Write-Host "  Método:  7-Zip" -ForegroundColor Gray
    Write-Host "  Bloques: ${BlockSizeMB}MB" -ForegroundColor Gray
    Write-Host ""

    $startTime = Get-Date
    $barTop = [console]::CursorTop
    Write-LlevarProgressBar -Percent 0 -StartTime $startTime -Label "Compresión..." -Top $barTop

    # ============================================================================
    # FIX: Construir argumentos en el orden correcto
    # El parámetro -v DEBE ir AL FINAL, después del path de origen
    # ============================================================================
    $sevenArgs = @(
        "a",           # Agregar
        "-t7z",        # Tipo 7z
        "-mx=9"        # Compresión máxima
    )
    
    if ($Clave) {
        $sevenArgs += "-p$Clave"
    }
    
    # Agregar archivo de salida
    $sevenArgs += $Out
    
    # ============================================================================
    # EJECUCIÓN CON PROGRESO REAL
    # ============================================================================
    $exitCode = 0
    
    if ($isDriveRoot) {
        Push-Location $Origen
        try {
            # Comprimir todo el contenido del directorio actual
            $sevenArgs += "*"
            
            # IMPORTANTE: -v va AL FINAL, después del origen
            if ($BlockSizeMB -gt 0) {
                $sevenArgs += "-v{0}m" -f $BlockSizeMB
            }
            
            Write-Log "Ejecutando desde directorio raíz: $Origen" "DEBUG"
            
            # USAR STREAMING REAL EN LUGAR DE & $SevenZ
            $exitCode = Invoke-SevenZipWithProgress `
                -SevenZipPath $SevenZ `
                -Arguments $sevenArgs `
                -StartTime $startTime `
                -BarTop $barTop
            
            if ($exitCode -ne 0) {
                Write-Log "7-Zip terminó con código de error: $exitCode" "ERROR"
            }
        }
        finally {
            Pop-Location
        }
    }
    else {
        # Agregar \* al final para comprimir el CONTENIDO
        $origenConWildcard = Join-Path $Origen "*"
        $sevenArgs += $origenConWildcard
        
        # IMPORTANTE: -v va AL FINAL, después del origen
        if ($BlockSizeMB -gt 0) {
            $sevenArgs += "-v{0}m" -f $BlockSizeMB
        }
        
        Write-Log "Ejecutando compresión normal" "DEBUG"
        
        # USAR STREAMING REAL EN LUGAR DE & $SevenZ
        $exitCode = Invoke-SevenZipWithProgress `
            -SevenZipPath $SevenZ `
            -Arguments $sevenArgs `
            -StartTime $startTime `
            -BarTop $barTop
        
        if ($exitCode -ne 0) {
            Write-Log "7-Zip terminó con código de error: $exitCode" "ERROR"
        }
    }

    Write-LlevarProgressBar -Percent 100 -StartTime $startTime -Label "Compresión..." -Top $barTop

    # Sin división: un solo .7z
    if ($BlockSizeMB -le 0) {
        return @{
            Files           = @($Out)
            CompressionType = "7ZIP"
        }
    }

    # Con división: devolver los volúmenes nativos Nombre.7z.001, .002, ...
    Write-Log "Buscando volúmenes en: $Temp con patrón: $Name.7z.*" "DEBUG"
    
    $volumes = Get-ChildItem -Path $Temp -File | Where-Object { 
        $_.Name -like "$Name.7z.0*" 
    } | Sort-Object Name
    
    Write-Log "Volúmenes encontrados: $($volumes.Count)" "DEBUG"
    if ($volumes) {
        foreach ($v in $volumes) {
            Write-Log "  - $($v.Name)" "DEBUG"
        }
    }

    if (-not $volumes -or $volumes.Count -eq 0) {
        # Verificar si hay un .7z sin división
        $singleFile = Join-Path $Temp "$Name.7z"
        Write-Log "No se encontraron volúmenes, verificando archivo único: $singleFile" "DEBUG"
        
        if (Test-Path $singleFile) {
            Write-Host "Archivo comprimido menor a ${BlockSizeMB}MB, generado como archivo único." -ForegroundColor Yellow
            return @{
                Files           = @($singleFile)
                CompressionType = "7ZIP"
            }
        }
        
        # Listar todos los archivos en Temp para diagnóstico
        Write-Log "Archivos en $Temp :" "ERROR"
        Get-ChildItem -Path $Temp -File | ForEach-Object {
            Write-Log "  - $($_.Name) ($($_.Length) bytes)" "ERROR"
        }
        
        throw "7-Zip no generó ningún archivo de salida. Patrón buscado: $Name.7z.0*"
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
