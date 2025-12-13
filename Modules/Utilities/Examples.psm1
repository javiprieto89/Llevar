# ========================================================================== #
#                   MÓDULO: MODO EJEMPLO Y DATOS DE PRUEBA                   #
# ========================================================================== #
# Propósito: Generar datos de ejemplo para demostración del script
# Funciones:
#   - New-ExampleData: Crea carpeta con archivo de prueba
#   - Invoke-ExampleMode: Modo automático completo con ejemplo
#   - Remove-ExampleData: Limpia archivos de ejemplo
# ========================================================================== #

function New-ExampleData {
    <#
    .SYNOPSIS
        Genera carpeta EJEMPLO con archivo de prueba
    .DESCRIPTION
        Crea una carpeta EJEMPLO con un archivo TMP de tamaño configurable
        lleno de datos aleatorios para demostración.
    .PARAMETER BaseDir
        Directorio base donde crear la carpeta EJEMPLO
    .PARAMETER SizeMB
        Tamaño del archivo de prueba en megabytes (por defecto: 20)
    .OUTPUTS
        String con la ruta de la carpeta EJEMPLO creada
    #>
    param(
        [string]$BaseDir,
        [int]$SizeMB = 20
    )
    
    $exampleDir = Join-Path $BaseDir "EJEMPLO"
    
    if (Test-Path $exampleDir) {
        Write-ColorOutput "Eliminando directorio de ejemplo anterior..." -ForegroundColor Yellow
        Remove-Item $exampleDir -Recurse -Force
    }
    
    Show-Banner -Message "MODO EJEMPLO - Generando datos de prueba" -BorderColor Cyan -TextColor Cyan
    
    Write-Host "Creando carpeta: $exampleDir" -ForegroundColor Gray
    New-Item -ItemType Directory -Path $exampleDir -Force | Out-Null
    
    $tmpFile = Join-Path $exampleDir "EJEMPLO.TMP"
    Write-Host "Generando archivo de ${SizeMB}MB: EJEMPLO.TMP" -ForegroundColor Gray
    
    # Generar archivo con datos aleatorios
    $chunkSize = 1MB
    $totalBytes = $SizeMB * 1MB
    $written = 0
    
    $stream = [System.IO.File]::Create($tmpFile)
    $random = New-Object System.Random
    
    while ($written -lt $totalBytes) {
        $remaining = $totalBytes - $written
        $size = [Math]::Min($chunkSize, $remaining)
        
        $buffer = New-Object byte[] $size
        $random.NextBytes($buffer)
        
        $stream.Write($buffer, 0, $size)
        $written += $size
        
        $percent = [int](($written * 100) / $totalBytes)
        Write-Progress -Activity "Generando archivo de prueba" -Status "$percent% completado" -PercentComplete $percent
    }
    
    $stream.Close()
    Write-Progress -Activity "Generando archivo de prueba" -Completed
    
    Write-Host "✓ Archivo generado: $('{0:N2}' -f ((Get-Item $tmpFile).Length / 1MB)) MB" -ForegroundColor Green
    Write-Host ""
    
    return $exampleDir
}

function Invoke-ExampleMode {
    <#
    .SYNOPSIS
        Ejecuta modo ejemplo automático completo
    .DESCRIPTION
        Crea datos de ejemplo, solicita configuración de destino,
        verifica acceso (incluyendo red con credenciales), y ejecuta
        el proceso completo de compresión y división.
    .OUTPUTS
        Hashtable con configuración del ejemplo (Origen, Destino, etc.)
    #>
    Show-Banner -Message "MODO EJEMPLO AUTOM�TICO" -BorderColor Cyan -TextColor Cyan
    Write-Host "Este modo creará automáticamente:" -ForegroundColor Yellow
    Write-Host "  • Una carpeta EJEMPLO con un archivo EJEMPLO.TMP de 50 MB"
    Write-Host "  • Ejecutará el proceso completo de compresión y división"
    Write-Host "  • Copiará los bloques al destino especificado"
    Write-Host "  • Limpiará todos los archivos temporales al finalizar"
    Write-Host ""
    
    # Generar datos de ejemplo
    $baseDir = $PSScriptRoot
    if (-not $baseDir) {
        $baseDir = Get-Location
    }
    
    $origenEjemplo = New-ExampleData -BaseDir $baseDir -SizeMB 50
    
    # Solicitar destino
    Show-Banner -Message "CONFIGURACIÓN DE DESTINO" -BorderColor Gray -TextColor Yellow
    Write-Host "Ingrese la ruta de destino para copiar los bloques."
    Write-Host "Ejemplos:" -ForegroundColor Cyan
    Write-Host "  • Carpeta local:    C:\Temp\Destino"
    Write-Host "  • Red UNC:          \\servidor\compartido\carpeta"
    Write-Host "  • Ruta relativa:    .\Destino"
    Write-Host ""
    
    $destinoEjemplo = Read-Host "Destino"
    
    if (-not $destinoEjemplo) {
        $destinoEjemplo = Join-Path $baseDir "DESTINO_EJEMPLO"
        Write-Host "Usando destino por defecto: $destinoEjemplo" -ForegroundColor Yellow
    }
    
    # Analizar tipo de destino
    $tipoDestino = Test-DestinoType -Path $destinoEjemplo
    Write-Host ""
    Write-Host "Tipo de destino detectado: $tipoDestino" -ForegroundColor Cyan
    
    # Verificar acceso al destino
    $destinoAccesible = $false
    $credenciales = $null
    
    if ($destinoEjemplo -match '^\\\\') {
        Write-Host "Verificando acceso a la ubicación de red..." -ForegroundColor Gray
        
        try {
            if (-not (Test-Path $destinoEjemplo)) {
                New-Item -ItemType Directory -Path $destinoEjemplo -Force -ErrorAction Stop | Out-Null
            }
            "test" | Out-File -FilePath (Join-Path $destinoEjemplo "__test__.tmp") -ErrorAction Stop
            Remove-Item (Join-Path $destinoEjemplo "__test__.tmp") -ErrorAction SilentlyContinue
            $destinoAccesible = $true
            Write-Host "✓ Acceso a red verificado" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ No se pudo acceder a la ruta de red" -ForegroundColor Red
            Write-Host ""
            $pedirCred = Read-Host "¿Desea proporcionar credenciales de red? (S/N)"
            
            if ($pedirCred -match '^[SsYy]') {
                $credenciales = Get-Credential -Message "Credenciales para $destinoEjemplo"
                
                try {
                    # Usar Mount-LlevarNetworkPath para verificar credenciales
                    $tempDrive = "LLEVAR_EJEMPLO"
                    $null = Mount-LlevarNetworkPath -Path $destinoEjemplo -Credential $credenciales -DriveName $tempDrive
                    
                    # Desmontar después de verificar
                    if (Get-PSDrive -Name $tempDrive -ErrorAction SilentlyContinue) {
                        Remove-PSDrive -Name $tempDrive -Force
                    }
                    
                    $destinoAccesible = $true
                    Write-Host "✓ Credenciales aceptadas" -ForegroundColor Green
                }
                catch {
                    Write-Host "✗ Credenciales incorrectas o destino inaccesible" -ForegroundColor Red
                    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                    throw "No se puede continuar sin acceso al destino"
                }
            }
            else {
                throw "Acceso al destino requerido para continuar"
            }
        }
    }
    else {
        # Destino local
        if (-not (Test-Path $destinoEjemplo)) {
            Write-Host "Creando directorio de destino..." -ForegroundColor Gray
            New-Item -ItemType Directory -Path $destinoEjemplo -Force | Out-Null
        }
        $destinoAccesible = $true
        Write-Host "✓ Destino local verificado" -ForegroundColor Green
    }
    
    if (-not $destinoAccesible) {
        throw "No se pudo verificar acceso al destino"
    }
    
    # Mostrar parámetros de ejecución
    Show-Banner "PAR�METROS DE EJECUCIÓN" -BorderColor Cyan -TextColor Cyan
    Write-Host "  Origen:           $origenEjemplo" -ForegroundColor White
    Write-Host "  Destino:          $destinoEjemplo" -ForegroundColor White
    Write-Host "  Tipo Destino:     $tipoDestino" -ForegroundColor White
    Write-Host "  Tamaño Bloque:    $($script:BlockSizeMB) MB" -ForegroundColor White
    Write-Host "  Usar ZIP Nativo:  $($script:UseNativeZip)" -ForegroundColor White
    Write-Host "  Credenciales Red: $(if ($credenciales) { 'Sí (Usuario: ' + $credenciales.UserName + ')' } else { 'No' })" -ForegroundColor White
    Write-Host ""
    Write-Host "Presione ENTER para continuar o CTRL+C para cancelar..." -ForegroundColor Yellow
    Read-Host
    
    # Ejecutar el proceso
    Show-Banner "INICIANDO PROCESO" -BorderColor Cyan -TextColor Cyan
    
    return @{
        Origen             = $origenEjemplo
        Destino            = $destinoEjemplo
        Credenciales       = $credenciales
        DirectoriosLimpiar = @($origenEjemplo)
    }
}

function Remove-ExampleData {
    <#
    .SYNOPSIS
        Limpia archivos y directorios de ejemplo
    .DESCRIPTION
        Elimina los directorios especificados y archivos temporales
        generados durante el modo ejemplo.
    .PARAMETER Directories
        Array de rutas de directorios a eliminar
    .PARAMETER TempDir
        Directorio temporal adicional a eliminar
    #>
    param(
        [string[]]$Directories,
        [string]$TempDir
    )
    
    Show-Banner "LIMPIEZA DE ARCHIVOS DE EJEMPLO" -BorderColor Cyan -TextColor Cyan
    
    foreach ($dir in $Directories) {
        if (Test-Path $dir) {
            Write-Host "Eliminando: $dir" -ForegroundColor Gray
            Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path $dir) {
                Write-Host "  ✗ No se pudo eliminar completamente" -ForegroundColor Yellow
            }
            else {
                Write-Host "  ✓ Eliminado" -ForegroundColor Green
            }
        }
    }
    
    if ($TempDir -and (Test-Path $TempDir)) {
        Write-Host "Eliminando archivos temporales: $TempDir" -ForegroundColor Gray
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $TempDir) {
            Write-Host "  ✗ No se pudo eliminar completamente" -ForegroundColor Yellow
        }
        else {
            Write-Host "  ✓ Eliminado" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    Write-Host "✓ Limpieza completada" -ForegroundColor Green
    Write-Host ""
}

function Initialize-ExampleTransfer {
    <#
    .SYNOPSIS
        Configura TransferConfig con datos de ejemplo para demostración
    .PARAMETER TransferConfig
        Referencia al objeto TransferConfig a configurar
    .PARAMETER FileCount
        Número de archivos de prueba a generar (por defecto: 5)
    .PARAMETER FileSizeMB
        Tamaño de cada archivo en MB (por defecto: 20)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$TransferConfig,
        
        [int]$FileCount = 5,
        [int]$FileSizeMB = 20
    )
    
    Show-Banner "MODO EJEMPLO - Generando datos de prueba" -BorderColor Cyan -TextColor Cyan
    
    # Crear carpetas temporales
    $baseTemp = Join-Path $env:TEMP "LlevarTest_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $origenTemp = Join-Path $baseTemp "Origen"
    $destinoTemp = Join-Path $baseTemp "Destino"
    
    Write-Host "📂 Creando estructura temporal..." -ForegroundColor Gray
    New-Item -ItemType Directory -Path $origenTemp -Force | Out-Null
    New-Item -ItemType Directory -Path $destinoTemp -Force | Out-Null
    
    # Generar archivos de prueba
    Write-Host "📝 Generando $FileCount archivos de ${FileSizeMB}MB cada uno..." -ForegroundColor Gray
    
    for ($i = 1; $i -le $FileCount; $i++) {
        $fileName = "TestFile_$i.tmp"
        $filePath = Join-Path $origenTemp $fileName
        
        $chunkSize = 1MB
        $totalBytes = $FileSizeMB * 1MB
        $written = 0
        
        $stream = [System.IO.File]::Create($filePath)
        $random = New-Object System.Random
        
        while ($written -lt $totalBytes) {
            $remaining = $totalBytes - $written
            $size = [Math]::Min($chunkSize, $remaining)
            
            $buffer = New-Object byte[] $size
            $random.NextBytes($buffer)
            
            $stream.Write($buffer, 0, $size)
            $written += $size
        }
        
        $stream.Close()
        
        $sizeStr = "{0:N2}" -f ((Get-Item $filePath).Length / 1MB)
        Write-Host "  ✓ $fileName ($sizeStr MB)" -ForegroundColor Green
    }
    
    # Configurar TransferConfig por referencia
    Set-TransferType -Config $TransferConfig -Section "Origen" -Type "Local"
    Set-TransferPath -Config $TransferConfig -Section "Origen" -Value $origenTemp
    Set-TransferConfigValue -Config $TransferConfig -Path "OrigenIsSet" -Value $true
    
    Set-TransferType -Config $TransferConfig -Section "Destino" -Type "Local"
    Set-TransferPath -Config $TransferConfig -Section "Destino" -Value $destinoTemp
    Set-TransferConfigValue -Config $TransferConfig -Path "DestinoIsSet" -Value $true
    
    Write-Host ""
    Write-Host "✅ Datos de ejemplo generados correctamente" -ForegroundColor Green
    Write-Host "   Origen:  $origenTemp" -ForegroundColor Cyan
    Write-Host "   Destino: $destinoTemp" -ForegroundColor Cyan
    Write-Host ""
    
    # Retornar info para limpieza
    return @{
        BaseDir     = $baseTemp
        Origen      = $origenTemp
        Destino     = $destinoTemp
        FileCount   = $FileCount
        TotalSizeMB = $FileCount * $FileSizeMB
    }
}

function Show-ExampleSummary {
    <#
    .SYNOPSIS
        Muestra resumen de ejecución del modo ejemplo
    .PARAMETER ExampleInfo
        Hashtable con información del ejemplo
    .PARAMETER TransferConfig
        Objeto TransferConfig con la configuración usada
    .PARAMETER ElapsedTime
        Tiempo transcurrido en la operación
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ExampleInfo,
        
        [Parameter(Mandatory = $true)]
        $TransferConfig,
        
        [timespan]$ElapsedTime
    )
    
    Show-Banner "EJEMPLO EJECUTADO EXITOSAMENTE" -BorderColor Green -TextColor Green
    
    Write-Host ""
    Write-Host "📊 RESUMEN DE LA OPERACIÓN" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "  📂 Origen:        " -NoNewline -ForegroundColor Yellow
    Write-Host "$($ExampleInfo.Origen)" -ForegroundColor White
    Write-Host "     └─ Archivos:   " -NoNewline -ForegroundColor Gray
    Write-Host "$($ExampleInfo.FileCount) archivos ($($ExampleInfo.TotalSizeMB) MB)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "  📂 Destino:       " -NoNewline -ForegroundColor Yellow
    Write-Host "$($ExampleInfo.Destino)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "  ⚙️  Configuración:" -ForegroundColor Yellow
    Write-Host "     └─ Tamaño bloque:  " -NoNewline -ForegroundColor Gray
    Write-Host "$($TransferConfig.Opciones.BlockSizeMB) MB" -ForegroundColor White
    Write-Host "     └─ Compresión:     " -NoNewline -ForegroundColor Gray
    Write-Host "$(if ($TransferConfig.Opciones.UseNativeZip) { 'ZIP Nativo' } else { '7-Zip' })" -ForegroundColor White
    Write-Host ""
    
    Write-Host "  ⏱️  Tiempo:       " -NoNewline -ForegroundColor Yellow
    Write-Host "$($ElapsedTime.ToString('hh\:mm\:ss'))" -ForegroundColor White
    Write-Host ""
    
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host ""
    
    # Preguntar si limpiar
    $cleanup = Read-Host "¿Desea eliminar los archivos de ejemplo? (S/N)"
    
    if ($cleanup -match '^[SsYy]') {
        Remove-ExampleData -Directories @($ExampleInfo.BaseDir)
        Write-Host "✓ Archivos temporales eliminados" -ForegroundColor Green
    }
    else {
        Write-Host "Los archivos permanecen en: $($ExampleInfo.BaseDir)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Presione ENTER para salir..." -ForegroundColor Cyan
    Read-Host
}

# Exportar funciones
Export-ModuleMember -Function @(
    'New-ExampleData',
    'Invoke-ExampleMode',
    'Remove-ExampleData',
    'Initialize-ExampleTransfer',
    'Show-ExampleSummary'
)
