<#
.SYNOPSIS
    Módulo de pruebas individuales para componentes de LLEVAR

.DESCRIPTION
    Este módulo permite probar componentes individuales del sistema LLEVAR
    sin ejecutar el flujo completo. Útil para debugging y desarrollo.
    
    Archivo: q:\Utilidad\LLevar\Modules\Parameters\Test.psm1
    
.NOTES
    No muestra logo ASCII ni nombre cuando se ejecuta en modo pruebas.
    Cada prueba es independiente y muestra el resultado en un banner.
#>

# ========================================================================== #
#                     FUNCIÓN PRINCIPAL DE PRUEBAS                           #
# ========================================================================== #

function Invoke-TestParameter {
    <#
    .SYNOPSIS
        Ejecuta pruebas individuales de componentes del sistema LLEVAR.
    
    .DESCRIPTION
        Permite probar componentes específicos sin ejecutar todo el flujo.
        Cada prueba simula la funcionalidad y muestra el resultado.
    
    .PARAMETER Test
        Tipo de prueba a ejecutar. Valores válidos:
        - Navigator: Prueba el navegador de archivos
        - FTP: Prueba conexión FTP (solicita destino FTP como si se hubiera elegido)
        - OneDrive: Prueba autenticación OneDrive
        - Dropbox: Prueba autenticación Dropbox
        - Compression: Prueba compresión y división en bloques
        - Robocopy: Prueba funcionalidad de sincronización
        - UNC: Prueba acceso a recursos de red
        - USB: Prueba detección de dispositivos USB
        - ISO: Prueba generación de imágenes ISO
    
    .EXAMPLE
        .\Llevar.ps1 -Test Navigator
        Abre el navegador y muestra el archivo/carpeta seleccionado
    
    .EXAMPLE
        .\Llevar.ps1 -Test FTP
        Simula selección de destino FTP y prueba conexión
    
    .OUTPUTS
        Boolean - $true si se ejecutó una prueba, $false si no
    #>
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Navigator", "FTP", "OneDrive", "Dropbox", "Compression", "Robocopy", "UNC", "USB", "ISO")]
        [string]$Test
    )
    
    # Si no se especificó -Test, no hacer nada
    if (-not $Test) { return $false }
    
    # Mostrar header de pruebas (sin logo ASCII)
    Write-Host ""
    Write-Host "���������������������������������������������������������������" -ForegroundColor Cyan
    Write-Host "                    MODO PRUEBAS - LLEVAR" -ForegroundColor Yellow
    Write-Host "���������������������������������������������������������������" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Probando: " -NoNewline -ForegroundColor Gray
    Write-Host $Test -ForegroundColor White
    Write-Host ""
    
    try {
        # Ejecutar la prueba correspondiente
        switch ($Test) {
            "Navigator" { Test-NavigatorComponent }
            "FTP" { Test-FTPComponent }
            "OneDrive" { Test-OneDriveComponent }
            "Dropbox" { Test-DropboxComponent }
            "Compression" { Test-CompressionComponent }
            "Robocopy" { Test-RobocopyComponent }
            "UNC" { Test-UNCComponent }
            "USB" { Test-USBComponent }
            "ISO" { Test-ISOComponent }
        }
        
        return $true
    }
    catch {
        # Registrar error en log
        Write-Log "ERROR en prueba -Test $Test" "ERROR"
        Write-Log "Mensaje: $_" "ERROR"
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
        
        Show-Banner "ERROR EN PRUEBA" -BorderColor Red -TextColor White
        Write-Host "Error: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Stack Trace:" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
        Write-Host ""
        Write-Host "El error ha sido registrado en: " -NoNewline -ForegroundColor Gray
        Write-Host $Global:LogFile -ForegroundColor Cyan
        return $true
    }
}

# ========================================================================== #
#                          PRUEBAS INDIVIDUALES                              #
# ========================================================================== #

function Test-NavigatorComponent {
    <#
    .SYNOPSIS
        Prueba el componente Navigator permitiendo navegar y seleccionar archivos/carpetas.
    
    .DESCRIPTION
        Abre el navegador interactivo completo. Cuando se selecciona un archivo/carpeta,
        muestra un banner con el objeto seleccionado y termina.
    #>
    
    Write-Host "Iniciando navegador de archivos..." -ForegroundColor Cyan
    Write-Host "Use flechas para navegar, ENTER para seleccionar, ESC para cancelar" -ForegroundColor Gray
    Write-Host ""
    
    # Abrir el navegador permitiendo seleccionar archivos
    $selected = Select-PathNavigator -Prompt "PRUEBA: Seleccione archivo o carpeta" -AllowFiles $true
    
    Write-Host ""
    
    if ($selected) {
        Show-Banner "ARCHIVO/OBJETO SELECCIONADO" -BorderColor Green -TextColor White
        Write-Host ""
        Write-Host "  Ruta: " -NoNewline -ForegroundColor Gray
        Write-Host $selected -ForegroundColor White
        Write-Host ""
        
        # Determinar tipo
        if (Test-Path $selected -PathType Container) {
            $tipo = "CARPETA"
            $icono = "[DIR]"
        }
        else {
            $tipo = "ARCHIVO"
            $icono = "[FILE]"
        }
        
        Write-Host "  Tipo: " -NoNewline -ForegroundColor Gray
        Write-Host "$icono $tipo" -ForegroundColor Cyan
        Write-Host ""
        
        # Mostrar información adicional
        try {
            $item = Get-Item $selected -ErrorAction Stop
            Write-Host "  Nombre: " -NoNewline -ForegroundColor Gray
            Write-Host $item.Name -ForegroundColor White
            
            if (-not $item.PSIsContainer) {
                $sizeMB = [math]::Round($item.Length / 1MB, 2)
                Write-Host "  Tamaño: " -NoNewline -ForegroundColor Gray
                Write-Host "$sizeMB MB" -ForegroundColor White
            }
            
            Write-Host "  Modificado: " -NoNewline -ForegroundColor Gray
            Write-Host $item.LastWriteTime -ForegroundColor White
        }
        catch {
            # Ignorar errores de información adicional
        }
        
        Write-Host ""
        Show-Banner "PRUEBA COMPLETADA" -BorderColor Green -TextColor White
    }
    else {
        Show-Banner "PRUEBA CANCELADA" -BorderColor Yellow -TextColor Black
        Write-Host ""
        Write-Host "  No se seleccionó ningún archivo/carpeta" -ForegroundColor Yellow
        Write-Host ""
    }
}

function Test-FTPComponent {
    <#
    .SYNOPSIS
        Prueba el componente FTP simulando selección de destino.
    
    .DESCRIPTION
        Simula que el usuario eligió destino FTP en el menú y solicita
        las credenciales y configuración como lo haría el flujo normal.
        Luego prueba la conexión y muestra el resultado.
    #>
    
    Write-Host "Simulando seleccion de destino FTP..." -ForegroundColor Cyan
    Write-Host ""
    
    # Usar Show-Banner en lugar de dibujarlo manualmente
    Show-Banner "CONFIGURACION DE SERVIDOR FTP (PRUEBA)" -BorderColor DarkCyan -TextColor Cyan
    Write-Host ""
    
    # Solicitar datos FTP
    $ftpHost = Read-Host "Servidor FTP (ej: ftp.ejemplo.com)"
    if (-not $ftpHost) {
        Write-Host "[X] Prueba cancelada: no se ingreso servidor" -ForegroundColor Yellow
        return
    }
    
    $ftpPort = Read-Host "Puerto (ENTER para 21)"
    if (-not $ftpPort) { $ftpPort = 21 }
    
    $ftpUser = Read-Host "Usuario"
    if (-not $ftpUser) {
        Write-Host "[X] Prueba cancelada: no se ingreso usuario" -ForegroundColor Yellow
        return
    }
    
    $ftpPassSecure = Read-Host "Contraseña" -AsSecureString
    $ftpPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ftpPassSecure)
    )
    
    $ftpPath = Read-Host "Ruta remota (ENTER para /)"
    if (-not $ftpPath) { $ftpPath = "/" }
    
    Write-Host ""
    Write-Host "Probando conexión..." -ForegroundColor Yellow
    Write-Host ""
    
        
    # Prueba completa: conectar, listar, subir, descargar
    try {
        $ftpUri = "ftp://${ftpHost}:${ftpPort}${ftpPath}"
        
        Write-Host "`n╔��������������������������������������╗" -ForegroundColor Cyan
        Write-Host "║  PRUEBA DE CONEXIÓN Y OPERACIONES   ║" -ForegroundColor Cyan
        Write-Host "╚���������������������������������������" -ForegroundColor Cyan
        Write-Host ""
        
        # 1. CONECTAR Y LISTAR
        Write-Host "[1/3] Conectando y listando directorio..." -ForegroundColor Yellow
        Write-Host "  → Servidor: ftp://${ftpHost}:${ftpPort}${ftpPath}" -ForegroundColor Gray
        
        $request = [System.Net.FtpWebRequest]::Create($ftpUri)
        $request.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
        $request.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
        $request.UsePassive = $true
        $request.UseBinary = $true
        $request.KeepAlive = $false
        $request.Timeout = 10000
        
        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $content = $reader.ReadToEnd()
        $reader.Close()
        $stream.Close()
        $response.Close()
        
        Write-Host "✓ Conexión exitosa" -ForegroundColor Green
        
        if ($content) {
            $files = $content -split "`n" | Where-Object { $_ }
            Write-Host "✓ Archivos encontrados: $($files.Count)" -ForegroundColor Green
            
            if ($files.Count -gt 0) {
                foreach ($file in $files | Select-Object -First 10) {
                    Write-Host "  📄 $file" -ForegroundColor Gray
                }
                if ($files.Count -gt 10) {
                    Write-Host "  ... y $($files.Count - 10) más" -ForegroundColor DarkGray
                }
            }
        }
        
        # 2. CREAR Y SUBIR ARCHIVO
        Write-Host "`n[2/3] Creando y subiendo archivo de prueba..." -ForegroundColor Yellow
        
        $testFileName = "LLEVAR_Test_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $tempFile = Join-Path $env:TEMP $testFileName
        $testContent = @"
╔����������������������������������������╗
║     ARCHIVO DE PRUEBA - LLEVAR         ║
╚�����������������������������������������

Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Usuario: $ftpUser@$ftpHost
Sistema: $env:COMPUTERNAME

Este archivo fue creado automáticamente
para probar la conexión FTP.

✓ Subida exitosa
"@
        
        [System.IO.File]::WriteAllText($tempFile, $testContent, [System.Text.Encoding]::UTF8)
        Write-Host "  Archivo temporal creado: $testFileName" -ForegroundColor Gray
        
        # Subir archivo
        $uploadUri = $ftpUri.TrimEnd('/') + "/$testFileName"
        $uploadRequest = [System.Net.FtpWebRequest]::Create($uploadUri)
        $uploadRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
        $uploadRequest.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
        $uploadRequest.UsePassive = $true
        $uploadRequest.UseBinary = $true
        $uploadRequest.KeepAlive = $false
        
        $fileContent = [System.IO.File]::ReadAllBytes($tempFile)
        $uploadRequest.ContentLength = $fileContent.Length
        
        $uploadStream = $uploadRequest.GetRequestStream()
        $uploadStream.Write($fileContent, 0, $fileContent.Length)
        $uploadStream.Close()
        
        $uploadResponse = $uploadRequest.GetResponse()
        $uploadResponse.Close()
        
        Write-Host "✓ Archivo subido al FTP: $testFileName" -ForegroundColor Green
        
        # 3. DESCARGAR ARCHIVO
        Write-Host "`n[3/3] Descargando archivo desde FTP..." -ForegroundColor Yellow
        
        $downloadPath = "C:\Temp"
        if (-not (Test-Path $downloadPath)) {
            New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
        }
        
        $downloadFile = Join-Path $downloadPath $testFileName
        
        $downloadRequest = [System.Net.FtpWebRequest]::Create($uploadUri)
        $downloadRequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
        $downloadRequest.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
        $downloadRequest.UsePassive = $true
        $downloadRequest.UseBinary = $true
        $downloadRequest.KeepAlive = $false
        
        $downloadResponse = $downloadRequest.GetResponse()
        $downloadStream = $downloadResponse.GetResponseStream()
        $fileStream = [System.IO.File]::Create($downloadFile)
        
        $buffer = New-Object byte[] 1024
        $bytesRead = 0
        do {
            $bytesRead = $downloadStream.Read($buffer, 0, $buffer.Length)
            $fileStream.Write($buffer, 0, $bytesRead)
        } while ($bytesRead -gt 0)
        
        $fileStream.Close()
        $downloadStream.Close()
        $downloadResponse.Close()
        
        if (Test-Path $downloadFile) {
            Write-Host "✓ Archivo descargado correctamente" -ForegroundColor Green
            Write-Host "  Ubicación: $downloadFile" -ForegroundColor Gray
            
            # Mostrar contenido
            Write-Host "  Contenido del archivo descargado:" -ForegroundColor Cyan
            Get-Content $downloadFile | ForEach-Object {
                Write-Host "  $_" -ForegroundColor White
            }
        }
        
        # Limpiar archivo temporal
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
        
        Write-Host ""
        Write-Host "📌 Archivo de prueba en FTP: $testFileName" -ForegroundColor Cyan
        Write-Host "📂 Archivo descargado localmente: $downloadFile" -ForegroundColor Cyan
        
        Write-Host ""
        Show-Banner "PRUEBA COMPLETADA" -BorderColor Green -TextColor White
    }
    catch {
        # Registrar error en log
        Write-Log "ERROR en Test-FTPComponent" "ERROR"
        Write-Log "Servidor: $ftpHost Puerto: $ftpPort Usuario: $ftpUser" "ERROR"
        Write-Log "Mensaje: $_" "ERROR"
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
        
        Show-Banner "ERROR DE CONEXION FTP" -BorderColor Red -TextColor White
        Write-Host ""
        Write-Host "  [X] No se pudo conectar al servidor FTP" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Servidor: $ftpHost" -ForegroundColor Gray
        Write-Host "  Puerto: $ftpPort" -ForegroundColor Gray
        Write-Host "  Usuario: $ftpUser" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Error: " -NoNewline -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        
        # Sugerencias
        Write-Host "  Sugerencias:" -ForegroundColor Yellow
        Write-Host "    • Verifique que el servidor esté accesible" -ForegroundColor Gray
        Write-Host "    • Verifique usuario y contraseña" -ForegroundColor Gray
        Write-Host "    • Verifique que el puerto sea correcto" -ForegroundColor Gray
        Write-Host "    • Verifique su firewall" -ForegroundColor Gray
        Write-Host ""
    }
}

function Test-OneDriveComponent {
    <#
    .SYNOPSIS
        Prueba la autenticación y operaciones con OneDrive.
    
    .DESCRIPTION
        Simula el flujo completo de autenticación, listado de archivos,
        subida y descarga de un archivo de prueba.
    #>
    
    Write-Host "Probando autenticación con OneDrive..." -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Write-Host "Intentando autenticar con OneDrive..." -ForegroundColor Yellow
        Write-Host ""
        
        $result = Get-OneDriveAuth
        
        if ($result) {
            Show-Banner "ONEDRIVE: AUTENTICACION EXITOSA" -BorderColor Green -TextColor White
            Write-Host ""
            Write-Host "  [OK] Autenticacion completada correctamente" -ForegroundColor Green
            Write-Host "  [OK] Acceso a OneDrive configurado" -ForegroundColor Green
            Write-Host ""
            
            if ($result.UseLocal) {
                Write-Host "  Modo: " -NoNewline -ForegroundColor Gray
                Write-Host "Local" -ForegroundColor Cyan
                Write-Host "  Ruta: " -NoNewline -ForegroundColor Gray
                Write-Host $result.LocalPath -ForegroundColor White
                Write-Host ""
                Show-Banner "PRUEBA COMPLETADA" -BorderColor Green -TextColor White
            }
            else {
                Write-Host "  Modo: " -NoNewline -ForegroundColor Gray
                Write-Host "API" -ForegroundColor Cyan
                Write-Host "  Email: " -NoNewline -ForegroundColor Gray
                Write-Host $result.Email -ForegroundColor White
                Write-Host "  Token: " -NoNewline -ForegroundColor Gray
                Write-Host "********" -ForegroundColor DarkGray
                
                # Ejecutar pruebas de operaciones
                Test-OneDriveConnection -OneDriveConfig $result
                
                Write-Host ""
                Show-Banner "PRUEBA COMPLETADA" -BorderColor Green -TextColor White
            }
        }
        else {
            Show-Banner "ONEDRIVE: AUTENTICACION FALLIDA" -BorderColor Red -TextColor White
            Write-Host ""
            Write-Host "  [X] No se pudo completar la autenticacion" -ForegroundColor Red
            Write-Host ""
        }
    }
    catch {
        Write-Log "ERROR en Test-OneDriveComponent" "ERROR"
        Write-Log "Mensaje: $_" "ERROR"
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
        
        Show-Banner "ERROR EN AUTENTICACIÓN ONEDRIVE" -BorderColor Red -TextColor White
        Write-Host ""
        Write-Host "  Error: $_" -ForegroundColor Red
        Write-Host ""
    }
}

function Test-DropboxComponent {
    <#
    .SYNOPSIS
        Prueba la autenticación con Dropbox.
    
    .DESCRIPTION
        Simula el flujo de autenticación con Dropbox y muestra
        si se pudo obtener acceso correctamente.
    #>
    
    Write-Host "Probando autenticación con Dropbox..." -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Write-Host "Iniciando autenticacion con Dropbox..." -ForegroundColor Yellow
        Write-Host "(Esto abrira el navegador web para autenticacion OAuth)" -ForegroundColor Gray
        Write-Host ""
        
        $result = Get-DropboxAuth
        
        if ($result) {
            Show-Banner "DROPBOX: AUTENTICACION EXITOSA" -BorderColor Green -TextColor White
            Write-Host ""
            Write-Host "  [OK] Autenticacion completada correctamente" -ForegroundColor Green
            Write-Host "  [OK] Token de acceso obtenido" -ForegroundColor Green
            Write-Host ""
            
            if ($result.UseLocal) {
                Write-Host "  Modo: " -NoNewline -ForegroundColor Gray
                Write-Host "Local" -ForegroundColor Cyan
                Write-Host "  Ruta: " -NoNewline -ForegroundColor Gray
                Write-Host $result.LocalPath -ForegroundColor White
            }
            else {
                Write-Host "  Modo: " -NoNewline -ForegroundColor Gray
                Write-Host "API" -ForegroundColor Cyan
                Write-Host "  Token: " -NoNewline -ForegroundColor Gray
                Write-Host "********" -ForegroundColor DarkGray
                Write-Host "  API URL: " -NoNewline -ForegroundColor Gray
                Write-Host $result.ApiUrl -ForegroundColor White
            }
            Write-Host ""
            Show-Banner "PRUEBA COMPLETADA" -BorderColor Green -TextColor White
        }
        else {
            Show-Banner "DROPBOX: AUTENTICACION FALLIDA" -BorderColor Red -TextColor White
            Write-Host ""
            Write-Host "  [X] No se pudo completar la autenticacion" -ForegroundColor Red
            Write-Host ""
        }
    }
    catch {
        Write-Log "ERROR en Test-DropboxComponent" "ERROR"
        Write-Log "Mensaje: $_" "ERROR"
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
        
        Show-Banner "ERROR EN AUTENTICACIÓN DROPBOX" -BorderColor Red -TextColor White
        Write-Host ""
        Write-Host "  Error: $_" -ForegroundColor Red
        Write-Host ""
    }
}

function Test-CompressionComponent {
    <#
    .SYNOPSIS
        Prueba el sistema de compresión y división en bloques.
    
    .DESCRIPTION
        Crea datos de prueba, los comprime y divide en bloques,
        mostrando estadísticas del proceso.
    #>
    
    Write-Host "Probando compresión y división en bloques..." -ForegroundColor Cyan
    Write-Host ""
    
    # Crear carpeta temporal de prueba
    $testPath = Join-Path $env:TEMP "LLEVAR_TEST_COMPRESSION"
    $outputPath = Join-Path $env:TEMP "LLEVAR_TEST_OUTPUT"
    
    try {
        # Limpiar si existe
        if (Test-Path $testPath) { Remove-Item $testPath -Recurse -Force }
        if (Test-Path $outputPath) { Remove-Item $outputPath -Recurse -Force }
        
        New-Item -Type Directory $testPath | Out-Null
        New-Item -Type Directory $outputPath | Out-Null
        
        # Crear archivos de prueba
        Write-Host "Generando archivos de prueba (20MB)..." -ForegroundColor Yellow
        
        # Crear 5 archivos de 4MB cada uno
        for ($i = 1; $i -le 5; $i++) {
            $file = Join-Path $testPath "test_file_$i.dat"
            $stream = [System.IO.File]::Create($file)
            $stream.SetLength(4MB)
            $stream.Close()
            Write-Host "  [OK] test_file_$i.dat (4 MB)" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "Comprimiendo y dividiendo en bloques de 5MB..." -ForegroundColor Yellow
        Write-Host ""
        
        # Obtener 7-Zip
        $sevenZ = Get-SevenZipLlevar
        if (-not $sevenZ) {
            throw "No se pudo obtener 7-Zip"
        }
        
        # Comprimir y dividir
        $result = Compress-Folder $testPath $outputPath $sevenZ $null 5 $null
        
        if ($result -and $result.Files) {
            Show-Banner "COMPRESION EXITOSA" -BorderColor Green -TextColor White
            Write-Host ""
            Write-Host "  [OK] Compresion completada" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Tipo de compresión: " -NoNewline -ForegroundColor Gray
            Write-Host $result.CompressionType -ForegroundColor Cyan
            Write-Host "  Bloques generados: " -NoNewline -ForegroundColor Gray
            Write-Host $result.Files.Count -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  Archivos generados:" -ForegroundColor Gray
            
            $totalSize = 0
            foreach ($file in $result.Files) {
                $item = Get-Item $file
                $sizeMB = [math]::Round($item.Length / 1MB, 2)
                $totalSize += $item.Length
                Write-Host "    • $($item.Name) - $sizeMB MB" -ForegroundColor DarkGray
            }
            
            Write-Host ""
            Write-Host "  Tamaño total: " -NoNewline -ForegroundColor Gray
            Write-Host "$([math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor Cyan
            Write-Host ""
            Show-Banner "PRUEBA COMPLETADA" -BorderColor Green -TextColor White
        }
        else {
            throw "No se generaron archivos de salida"
        }
    }
    catch {
        Write-Log "ERROR en Test-CompressionComponent" "ERROR"
        Write-Log "Mensaje: $_" "ERROR"
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
        
        Show-Banner "ERROR EN COMPRESIÓN" -BorderColor Red -TextColor White
        Write-Host ""
        Write-Host "  Error: $_" -ForegroundColor Red
        Write-Host ""
    }
    finally {
        # Limpiar
        if (Test-Path $testPath) { Remove-Item $testPath -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $outputPath) { Remove-Item $outputPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Test-RobocopyComponent {
    <#
    .SYNOPSIS
        Prueba la funcionalidad de sincronización con Robocopy.
    
    .DESCRIPTION
        Crea carpetas de prueba y ejecuta una sincronización,
        mostrando las estadísticas del proceso.
    #>
    
    Write-Host "Probando sincronización con Robocopy..." -ForegroundColor Cyan
    Write-Host ""
    
    $sourcePath = Join-Path $env:TEMP "LLEVAR_TEST_SOURCE"
    $destPath = Join-Path $env:TEMP "LLEVAR_TEST_DEST"
    
    try {
        # Limpiar si existe
        if (Test-Path $sourcePath) { Remove-Item $sourcePath -Recurse -Force }
        if (Test-Path $destPath) { Remove-Item $destPath -Recurse -Force }
        
        New-Item -Type Directory $sourcePath | Out-Null
        New-Item -Type Directory $destPath | Out-Null
        
        # Crear archivos de prueba
        Write-Host "Generando archivos de prueba..." -ForegroundColor Yellow
        
        "Contenido archivo 1" | Out-File (Join-Path $sourcePath "file1.txt")
        "Contenido archivo 2" | Out-File (Join-Path $sourcePath "file2.txt")
        
        $subDir = Join-Path $sourcePath "subcarpeta"
        New-Item -Type Directory $subDir | Out-Null
        "Contenido archivo 3" | Out-File (Join-Path $subDir "file3.txt")
        
        Write-Host "  [OK] 3 archivos en 2 carpetas" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Ejecutando sincronización..." -ForegroundColor Yellow
        Write-Host ""
        
        # Ejecutar Robocopy
        $result = Invoke-RobocopyTransfer -SourcePath $sourcePath -DestinationPath $destPath
        
        if ($result.Success) {
            Show-Banner "SINCRONIZACION EXITOSA" -BorderColor Green -TextColor White
            Write-Host ""
            Write-Host "  [OK] Sincronizacion completada" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Archivos copiados: " -NoNewline -ForegroundColor Gray
            Write-Host $result.FilesCopied -ForegroundColor Cyan
            Write-Host "  Directorios: " -NoNewline -ForegroundColor Gray
            Write-Host $result.DirectoriesCopied -ForegroundColor Cyan
            Write-Host "  Bytes copiados: " -NoNewline -ForegroundColor Gray
            Write-Host $result.BytesCopied -ForegroundColor Cyan
            Write-Host ""
            
            # Verificar destino
            $destFiles = Get-ChildItem $destPath -Recurse -File
            Write-Host "  Verificación destino: " -NoNewline -ForegroundColor Gray
            Write-Host "$($destFiles.Count) archivos" -ForegroundColor Cyan
            Write-Host ""
            Show-Banner "PRUEBA COMPLETADA" -BorderColor Green -TextColor White
        }
        else {
            throw "Robocopy retornó código de error: $($result.ExitCode)"
        }
    }
    catch {
        Write-Log "ERROR en Test-RobocopyComponent" "ERROR"
        Write-Log "Mensaje: $_" "ERROR"
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
        
        Show-Banner "ERROR EN SINCRONIZACIÓN" -BorderColor Red -TextColor White
        Write-Host ""
        Write-Host "  Error: $_" -ForegroundColor Red
        Write-Host ""
    }
    finally {
        # Limpiar
        if (Test-Path $sourcePath) { Remove-Item $sourcePath -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $destPath) { Remove-Item $destPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Test-UNCComponent {
    <#
    .SYNOPSIS
        Prueba el acceso a recursos de red UNC.
    
    .DESCRIPTION
        Lista los recursos de red disponibles y permite probar
        el acceso a una ruta UNC específica.
    #>
    
    Write-Host "Probando acceso a recursos de red UNC..." -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Buscando recursos compartidos en la red..." -ForegroundColor Yellow
    Write-Host "(Esto puede tardar unos segundos)" -ForegroundColor Gray
    Write-Host ""
    
    try {
        # Buscar recursos con net view
        $netView = net view /all 2>$null
        $computers = @()
        
        foreach ($line in $netView) {
            if ($line -match '\\\\(.+?)\s') {
                $computers += $matches[1]
            }
        }
        
        if ($computers.Count -gt 0) {
            Write-Host "  Recursos encontrados: " -NoNewline -ForegroundColor Gray
            Write-Host $computers.Count -ForegroundColor Cyan
            Write-Host ""
            
            foreach ($comp in $computers) {
                Write-Host "    • \\$comp" -ForegroundColor DarkGray
            }
            
            Write-Host ""
            $testPath = Read-Host "Ingrese ruta UNC para probar (ej: \\servidor\recurso) o ENTER para omitir"
            
            if ($testPath) {
                Write-Host ""
                Write-Host "Probando acceso a: $testPath" -ForegroundColor Yellow
                
                if (Test-Path $testPath) {
                    Show-Banner "ACCESO UNC EXITOSO" -BorderColor Green -TextColor White
                    Write-Host ""
                    Write-Host "  [OK] Ruta accesible: $testPath" -ForegroundColor Green
                    Write-Host ""
                    
                    # Listar contenido
                    $items = Get-ChildItem $testPath -ErrorAction SilentlyContinue
                    if ($items) {
                        Write-Host "  Contenido (primeros 10):" -ForegroundColor Gray
                        $items | Select-Object -First 10 | ForEach-Object {
                            $icon = if ($_.PSIsContainer) { "[DIR]" } else { "[FILE]" }
                            Write-Host "    $icon $($_.Name)" -ForegroundColor DarkGray
                        }
                    }
                    Write-Host ""
                    Show-Banner "PRUEBA COMPLETADA" -BorderColor Green -TextColor White
                }
                else {
                    Show-Banner "ERROR DE ACCESO UNC" -BorderColor Red -TextColor White
                    Write-Host ""
                    Write-Host "  [X] No se pudo acceder a: $testPath" -ForegroundColor Red
                    Write-Host ""
                    Write-Host "  Posibles causas:" -ForegroundColor Yellow
                    Write-Host "    • El recurso no existe" -ForegroundColor Gray
                    Write-Host "    • No tiene permisos de acceso" -ForegroundColor Gray
                    Write-Host "    • El servidor no está disponible" -ForegroundColor Gray
                    Write-Host ""
                }
            }
            else {
                Write-Host "Prueba omitida por el usuario" -ForegroundColor Yellow
            }
        }
        else {
            Show-Banner "NO HAY RECURSOS UNC" -BorderColor Yellow -TextColor Black
            Write-Host ""
            Write-Host "  ⚠ No se encontraron recursos compartidos en la red" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  Posibles causas:" -ForegroundColor Gray
            Write-Host "    • No hay equipos en la red local" -ForegroundColor DarkGray
            Write-Host "    • El descubrimiento de red está deshabilitado" -ForegroundColor DarkGray
            Write-Host "    • Firewall bloqueando" -ForegroundColor DarkGray
            Write-Host ""
        }
    }
    catch {
        Write-Log "ERROR en Test-UNCComponent" "ERROR"
        Write-Log "Mensaje: $_" "ERROR"
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
        
        Show-Banner "ERROR EN BÚSQUEDA UNC" -BorderColor Red -TextColor White
        Write-Host ""
        Write-Host "  Error: $_" -ForegroundColor Red
        Write-Host ""
    }
}

function Test-USBComponent {
    <#
    .SYNOPSIS
        Prueba la detección de dispositivos USB.
    
    .DESCRIPTION
        Lista todos los dispositivos USB conectados y muestra
        información detallada sobre cada uno.
    #>
    
    Write-Host "Probando detección de dispositivos USB..." -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Write-Host "Buscando dispositivos USB..." -ForegroundColor Yellow
        Write-Host ""
        
        # Obtener unidades removibles
        $usbDrives = Get-Volume | Where-Object { 
            $_.DriveType -eq 'Removable' -and $_.DriveLetter 
        }
        
        if ($usbDrives) {
            Show-Banner "DISPOSITIVOS USB ENCONTRADOS" -BorderColor Green -TextColor White
            Write-Host ""
            Write-Host "  Total de dispositivos: " -NoNewline -ForegroundColor Gray
            Write-Host $usbDrives.Count -ForegroundColor Cyan
            Write-Host ""
            
            foreach ($usb in $usbDrives) {
                $drive = $usb.DriveLetter + ":\"
                $sizeGB = [math]::Round($usb.Size / 1GB, 2)
                $freeGB = [math]::Round($usb.SizeRemaining / 1GB, 2)
                $usedGB = $sizeGB - $freeGB
                $percentUsed = if ($sizeGB -gt 0) { [math]::Round(($usedGB / $sizeGB) * 100, 1) } else { 0 }
                
                Write-Host "  ╔����������������������������������������������������╗" -ForegroundColor DarkCyan
                Write-Host "  ║ " -NoNewline -ForegroundColor DarkCyan
                Write-Host "USB: $drive" -NoNewline -ForegroundColor White
                Write-Host (" " * (47 - $drive.Length)) -NoNewline
                Write-Host "║" -ForegroundColor DarkCyan
                Write-Host "  ╠����������������������������������������������������╣" -ForegroundColor DarkCyan
                
                Write-Host "  ║ " -NoNewline -ForegroundColor DarkCyan
                Write-Host "Etiqueta: " -NoNewline -ForegroundColor Gray
                $label = if ($usb.FileSystemLabel) { $usb.FileSystemLabel } else { "(Sin etiqueta)" }
                Write-Host $label -NoNewline -ForegroundColor Cyan
                Write-Host (" " * (38 - $label.Length)) -NoNewline
                Write-Host "║" -ForegroundColor DarkCyan
                
                Write-Host "  ║ " -NoNewline -ForegroundColor DarkCyan
                Write-Host "Tamaño: " -NoNewline -ForegroundColor Gray
                Write-Host "$sizeGB GB" -NoNewline -ForegroundColor Cyan
                Write-Host (" " * (40 - "$sizeGB GB".Length)) -NoNewline
                Write-Host "║" -ForegroundColor DarkCyan
                
                Write-Host "  ║ " -NoNewline -ForegroundColor DarkCyan
                Write-Host "Libre: " -NoNewline -ForegroundColor Gray
                Write-Host "$freeGB GB" -NoNewline -ForegroundColor Green
                Write-Host (" " * (41 - "$freeGB GB".Length)) -NoNewline
                Write-Host "║" -ForegroundColor DarkCyan
                
                Write-Host "  ║ " -NoNewline -ForegroundColor DarkCyan
                Write-Host "Usado: " -NoNewline -ForegroundColor Gray
                Write-Host "$usedGB GB ($percentUsed%)" -NoNewline -ForegroundColor Yellow
                Write-Host (" " * (32 - "$usedGB GB ($percentUsed%)".Length)) -NoNewline
                Write-Host "║" -ForegroundColor DarkCyan
                
                Write-Host "  ║ " -NoNewline -ForegroundColor DarkCyan
                Write-Host "Sistema: " -NoNewline -ForegroundColor Gray
                Write-Host $usb.FileSystem -NoNewline -ForegroundColor Cyan
                Write-Host (" " * (39 - $usb.FileSystem.Length)) -NoNewline
                Write-Host "║" -ForegroundColor DarkCyan
                
                Write-Host "  ╚�����������������������������������������������������" -ForegroundColor DarkCyan
                Write-Host ""
            }
            
            Show-Banner "PRUEBA COMPLETADA" -BorderColor Green -TextColor White
        }
        else {
            Show-Banner "NO HAY DISPOSITIVOS USB" -BorderColor Yellow -TextColor Black
            Write-Host ""
            Write-Host "  ⚠ No se detectaron dispositivos USB conectados" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  Conecte un dispositivo USB y vuelva a intentar" -ForegroundColor Gray
            Write-Host ""
        }
    }
    catch {
        Write-Log "ERROR en Test-USBComponent" "ERROR"
        Write-Log "Mensaje: $_" "ERROR"
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
        
        Show-Banner "ERROR EN DETECCIÓN USB" -BorderColor Red -TextColor White
        Write-Host ""
        Write-Host "  Error: $_" -ForegroundColor Red
        Write-Host ""
    }
}

function Test-ISOComponent {
    <#
    .SYNOPSIS
        Prueba la generación de imágenes ISO.
    
    .DESCRIPTION
        Crea archivos de prueba y genera una imagen ISO de ejemplo,
        mostrando el proceso y el resultado.
    #>
    
    Write-Host "Probando generación de imágenes ISO..." -ForegroundColor Cyan
    Write-Host ""
    
    $testPath = Join-Path $env:TEMP "LLEVAR_TEST_ISO_DATA"
    $isoPath = Join-Path $env:TEMP "LLEVAR_TEST.iso"
    
    try {
        # Limpiar si existe
        if (Test-Path $testPath) { Remove-Item $testPath -Recurse -Force }
        if (Test-Path $isoPath) { Remove-Item $isoPath -Force }
        
        New-Item -Type Directory $testPath | Out-Null
        
        # Crear archivos de prueba
        Write-Host "Generando archivos de prueba..." -ForegroundColor Yellow
        
        "Contenido de prueba 1" | Out-File (Join-Path $testPath "archivo1.txt")
        "Contenido de prueba 2" | Out-File (Join-Path $testPath "archivo2.txt")
        "README ISO de prueba" | Out-File (Join-Path $testPath "README.txt")
        
        Write-Host "  [OK] 3 archivos de prueba creados" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Generando imagen ISO..." -ForegroundColor Yellow
        Write-Host ""
        
        # Generar ISO (usando función del módulo ISO.psm1)
        $result = New-IsoImage -SourcePath $testPath -IsoPath $isoPath -VolumeLabel "LLEVAR_TEST"
        
        if ($result -and (Test-Path $isoPath)) {
            $isoFile = Get-Item $isoPath
            $sizeMB = [math]::Round($isoFile.Length / 1MB, 2)
            
            Show-Banner "IMAGEN ISO GENERADA" -BorderColor Green -TextColor White
            Write-Host ""
            Write-Host "  ✓ ISO creada correctamente" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Ruta: " -NoNewline -ForegroundColor Gray
            Write-Host $isoPath -ForegroundColor White
            Write-Host "  Tamaño: " -NoNewline -ForegroundColor Gray
            Write-Host "$sizeMB MB" -ForegroundColor Cyan
            Write-Host "  Etiqueta: " -NoNewline -ForegroundColor Gray
            Write-Host "LLEVAR_TEST" -ForegroundColor Cyan
            Write-Host ""
            
            Write-Host "  La imagen ISO está lista en:" -ForegroundColor Gray
            Write-Host "    $isoPath" -ForegroundColor DarkGray
            Write-Host ""
            Show-Banner "PRUEBA COMPLETADA" -BorderColor Green -TextColor White
        }
        else {
            throw "No se pudo generar la imagen ISO"
        }
    }
    catch {
        Write-Log "ERROR en Test-ISOComponent" "ERROR"
        Write-Log "Mensaje: $_" "ERROR"
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
        
        Show-Banner "ERROR EN GENERACIÓN ISO" -BorderColor Red -TextColor White
        Write-Host ""
        Write-Host "  Error: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Posibles causas:" -ForegroundColor Yellow
        Write-Host "    • oscdimg.exe no disponible" -ForegroundColor Gray
        Write-Host "    • Permisos insuficientes" -ForegroundColor Gray
        Write-Host "    • Espacio en disco insuficiente" -ForegroundColor Gray
        Write-Host ""
    }
    finally {
        # Limpiar datos de prueba (pero dejar ISO para inspección)
        if (Test-Path $testPath) { Remove-Item $testPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ========================================================================== #
#                           EXPORTAR FUNCIONES                               #
# ========================================================================== #

Export-ModuleMember -Function Invoke-TestParameter
