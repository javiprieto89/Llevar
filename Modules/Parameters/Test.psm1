<#
.SYNOPSIS
    Módulo de pruebas individuales para componentes de LLEVAR

.DESCRIPTION
    Permite probar componentes individuales del sistema LLEVAR sin ejecutar el flujo completo.
    Refactorizado para usar TransferConfig como única fuente de verdad.

    Archivo: q:\Utilidad\LLevar\Modules\Parameters\Test.psm1
#>

# Importar TransferConfig al inicio
using module "Q:\Utilidad\LLevar\Modules\Core\TransferConfig.psm1"

# Imports necesarios
$ModulesPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ModulesPath "Modules\UI\Banners.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\UI\Navigator.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Transfer\FTP.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Transfer\OneDrive.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Transfer\Dropbox.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Compression\SevenZip.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Compression\BlockSplitter.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\System\Robocopy.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Transfer\UNC.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Utilities\VolumeManagement.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Installation\ISO.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\Core\Logging.psm1") -Force -Global
Import-Module (Join-Path $ModulesPath "Modules\UI\Menus.psm1") -Force -Global

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
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                    MODO PRUEBAS - LLEVAR" -ForegroundColor Yellow
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
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
        Prueba el componente Navigator
    
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
        Prueba el componente FTP usando TransferConfig
    
    .DESCRIPTION
        Simula que el usuario eligió destino FTP en el menú y solicita
        las credenciales y configuración como lo haría el flujo normal.
        Luego prueba la conexión y muestra el resultado.
    #>
    
    Write-Host "Simulando selección de destino FTP..." -ForegroundColor Cyan
    Write-Host ""
    
    # ✅ CREAR INSTANCIA DE TRANSFERCONFIG PARA PRUEBA
    $llevar = [TransferConfig]::new()
    
    # ✅ LLAMADA CORRECTA: PASA $llevar y "Destino"
    $success = Get-FtpConfigFromUser -Llevar $llevar -Cual "Destino"
    
    if ($success) {
        Show-Banner "PRUEBA FTP COMPLETADA" -BorderColor Green -TextColor White
        Write-Host ""
        Write-Host "✓ FTP Destino configurado:" -ForegroundColor Green
        Write-Host "  Servidor: $($llevar.Destino.FTP.Server)" -ForegroundColor White
        Write-Host "  Puerto: $($llevar.Destino.FTP.Port)" -ForegroundColor White
        Write-Host "  Usuario: $($llevar.Destino.FTP.User)" -ForegroundColor White
        Write-Host "  Directorio: $($llevar.Destino.FTP.Directory)" -ForegroundColor White
        Write-Host ""
    }
    else {
        Show-Banner "PRUEBA FTP CANCELADA" -BorderColor Yellow -TextColor Black
        Write-Host ""
        Write-Host "  Configuración FTP cancelada por el usuario" -ForegroundColor Yellow
        Write-Host ""
    }
}

function Test-OneDriveComponent {
    <#
    .SYNOPSIS
        Prueba el componente OneDrive usando TransferConfig
    
    .DESCRIPTION
        Simula el flujo completo de autenticación, listado de archivos,
        subida y descarga de un archivo de prueba.
    #>
    
    Write-Host "Probando autenticación con OneDrive..." -ForegroundColor Cyan
    Write-Host ""
    
    # ✅ CREAR INSTANCIA DE TRANSFERCONFIG PARA PRUEBA
    $llevar = [TransferConfig]::new()
    
    # ✅ LLAMADA CORRECTA: PASA $llevar y "Origen"
    $success = Get-OneDriveConfigFromUser -Llevar $llevar -Cual "Origen"
    
    if ($success) {
        Show-Banner "PRUEBA ONEDRIVE COMPLETADA" -BorderColor Green -TextColor White
        Write-Host ""
        Write-Host "✓ OneDrive Origen configurado:" -ForegroundColor Green
        Write-Host "  Ruta: $($llevar.Origen.OneDrive.Path)" -ForegroundColor White
        Write-Host "  Email: $($llevar.Origen.OneDrive.Email)" -ForegroundColor White
        Write-Host "  Token: ********" -ForegroundColor DarkGray
        Write-Host ""
    }
    else {
        Show-Banner "PRUEBA ONEDRIVE CANCELADA" -BorderColor Yellow -TextColor Black
        Write-Host ""
        Write-Host "  Configuración OneDrive cancelada" -ForegroundColor Yellow
        Write-Host ""
    }
}

function Test-DropboxComponent {
    <#
    .SYNOPSIS
        Prueba el componente Dropbox usando TransferConfig
    
    .DESCRIPTION
        Simula el flujo de autenticación con Dropbox y muestra
        si se pudo obtener acceso correctamente.
    #>
    
    Write-Host "Probando autenticación con Dropbox..." -ForegroundColor Cyan
    Write-Host ""
    
    # ✅ CREAR INSTANCIA DE TRANSFERCONFIG PARA PRUEBA
    $llevar = [TransferConfig]::new()
    
    # ✅ LLAMADA CORRECTA: PASA $llevar y "Destino"
    $success = Get-DropboxConfigFromUser -Llevar $llevar -Cual "Destino"
    
    if ($success) {
        Show-Banner "PRUEBA DROPBOX COMPLETADA" -BorderColor Green -TextColor White
        Write-Host ""
        Write-Host "✓ Dropbox Destino configurado:" -ForegroundColor Green
        Write-Host "  Ruta: $($llevar.Destino.Dropbox.Path)" -ForegroundColor White
        Write-Host "  Email: $($llevar.Destino.Dropbox.Email)" -ForegroundColor White
        Write-Host "  Token: ********" -ForegroundColor DarkGray
        Write-Host ""
    }
    else {
        Show-Banner "PRUEBA DROPBOX CANCELADA" -BorderColor Yellow -TextColor Black
        Write-Host ""
        Write-Host "  Configuración Dropbox cancelada" -ForegroundColor Yellow
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
    
    $computers = Get-NetworkComputers
    
    if ($computers.Count -gt 0) {
        Write-Host "  Recursos encontrados: $($computers.Count)" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($comp in $computers | Select-Object -First 5) {
            Write-Host "    • $($comp.Path)" -ForegroundColor DarkGray
        }
        
        Write-Host ""
        Show-Banner "PRUEBA COMPLETADA" -BorderColor Green -TextColor White
    }
    else {
        Show-Banner "NO HAY RECURSOS UNC" -BorderColor Yellow -TextColor Black
        Write-Host ""
        Write-Host "  ⚠ No se encontraron recursos compartidos" -ForegroundColor Yellow
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
    
    $usbDrives = Get-Volume | Where-Object { 
        $_.DriveType -eq 'Removable' -and $_.DriveLetter 
    }
    
    if ($usbDrives) {
        Show-Banner "DISPOSITIVOS USB ENCONTRADOS" -BorderColor Green -TextColor White
        Write-Host ""
        Write-Host "  Total de dispositivos: $($usbDrives.Count)" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($usb in $usbDrives) {
            $sizeGB = [math]::Round($usb.Size / 1GB, 2)
            Write-Host "  USB: $($usb.DriveLetter):\" -ForegroundColor White
            Write-Host "  Tamaño: $sizeGB GB" -ForegroundColor Gray
            Write-Host ""
        }
        
        Show-Banner "PRUEBA COMPLETADA" -BorderColor Green -TextColor White
    }
    else {
        Show-Banner "NO HAY DISPOSITIVOS USB" -BorderColor Yellow -TextColor Black
        Write-Host ""
        Write-Host "  ⚠ No se detectaron dispositivos USB conectados" -ForegroundColor Yellow
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
            Write-Host "  Ruta: $isoPath" -ForegroundColor White
            Write-Host "  Tamaño: $sizeMB MB" -ForegroundColor Cyan
            Write-Host ""
            Show-Banner "PRUEBA COMPLETADA" -BorderColor Green -TextColor White
        }
        else {
            throw "No se pudo generar la imagen ISO"
        }
    }
    catch {
        Write-Log "ERROR en Test-ISOComponent" "ERROR"
        Show-Banner "ERROR EN GENERACIÓN ISO" -BorderColor Red -TextColor White
        Write-Host "  Error: $_" -ForegroundColor Red
    }
    finally {
        if (Test-Path $testPath) { Remove-Item $testPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ========================================================================== #
#                           EXPORTAR FUNCIONES                               #
# ========================================================================== #

Export-ModuleMember -Function Invoke-TestParameter
