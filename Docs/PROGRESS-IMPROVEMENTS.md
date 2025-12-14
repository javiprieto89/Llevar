# Mejoras de Progreso y Cancelación

## 📊 Cambios Implementados

### ✅ 1. Sistema de Cancelación Universal con ESC

**Archivos modificados:**
- `Modules/UI/ProgressBar.psm1`
- `Modules/Compression/SevenZip.psm1`
- `Modules/Transfer/Unified.psm1`

**Funcionamiento:**
```powershell
# En cualquier operación con barra de progreso
Write-LlevarProgressBar -Percent 50 -StartTime $start -CheckCancellation

# Presionar ESC → lanza excepción inmediata
throw "Operación cancelada por el usuario (ESC)"
```

---

### ✅ 2. Barra de Progreso REAL para Compresión 7-Zip

**Problema anterior:**
```powershell
$output = & $SevenZ @args 2>&1  # ❌ Bufferizado → progreso solo al final
```

**Solución implementada:**
```powershell
# Streaming real usando System.Diagnostics.Process
$process.StandardError.ReadLine()  # ✅ Lee % en tiempo real

# Estimación inteligente basada en primer 10%
if ($pct >= 10) {
    $estimatedTotal = $elapsed * (100 / 10)
    $displayPct = Max($realPct, $estimatedPct)
}
```

**Características:**
- ✅ Progreso continuo (no bufferizado)
- ✅ Estimación de tiempo total
- ✅ Anti-retrocesos (evita % que disminuyen)
- ✅ Cancelación con ESC
- ✅ Funciona con volúmenes múltiples

---

### ✅ 3. Spinner Animado para Operaciones Sin Progreso Calculable

**Nueva función: `Write-LlevarSpinner`**

```powershell
# Para descargas FTP sin tamaño conocido
Write-LlevarSpinner -StartTime $start -Label "Descargando..." -CheckCancellation
```

**Animación:**
```
  ⠋  Descargando archivo.zip... [00:00:15]
  ⠙  Descargando archivo.zip... [00:00:16]
  ⠹  Descargando archivo.zip... [00:00:17]
```

---

### ✅ 4. Progreso en TODOS los Handlers de Transferencia

#### **Local → FTP**
```powershell
# Progreso por archivo con conteo
foreach ($file in $files) {
    $percent = ($uploadedFiles * 100 / $totalFiles)
    Write-LlevarProgressBar -Percent $percent -CheckCancellation
    Send-LlevarFtpFile -LocalPath $file -RemotePath $remote
    $uploadedFiles++
}
```

#### **Local → OneDrive/Dropbox**
```powershell
# Progreso por archivo
foreach ($file in $files) {
    $percent = ($uploadedFiles * 100 / $totalFiles)
    Write-LlevarProgressBar -Percent $percent -CheckCancellation
    Send-LlevarCloudFile -LocalPath $file -CloudPath $path
}
```

#### **FTP → Local**
```powershell
# Spinner (sin tamaño conocido)
Write-LlevarSpinner -Label "Descargando: $filename" -CheckCancellation
```

#### **Cloud → Local**
```powershell
# Spinner + barra combinada
Write-LlevarSpinner -Label "Descargando de nube..."
# ... descarga ...
Write-LlevarProgressBar -Percent 40 -Label "Comprimiendo..."
```

---

## 🎯 Modos de Visualización por Tipo de Operación

| Operación | Visualización | Cancelable |
|-----------|---------------|------------|
| Compresión 7-Zip | Barra real con estimación | ✅ ESC |
| Upload FTP/Cloud (archivos) | Barra por conteo | ✅ ESC |
| Download FTP | Spinner animado | ✅ ESC |
| Download Cloud | Spinner → Barra | ✅ ESC |
| Copia Local→Local (Robocopy) | Barra nativa Robocopy | ✅ ESC |
| Generación ISO | Barra por etapas | ✅ ESC |

---

## 📋 Cómo Usar en Código Nuevo

### **Opción 1: Barra de progreso con % conocido**
```powershell
$start = Get-Date
$barTop = [Console]::CursorTop

foreach ($item in $items) {
    $percent = ($current * 100 / $total)
    
    Write-LlevarProgressBar `
        -Percent $percent `
        -StartTime $start `
        -Label "Procesando: $item" `
        -Top $barTop `
        -CheckCancellation  # ← Permite ESC
    
    # Tu lógica aquí
    Process-Item $item
    $current++
}

Write-LlevarProgressBar -Percent 100 -StartTime $start -Top $barTop
```

### **Opción 2: Spinner para operaciones indeterminadas**
```powershell
$start = Get-Date
$barTop = [Console]::CursorTop

while ($processing) {
    Write-LlevarSpinner `
        -StartTime $start `
        -Label "Descargando archivo grande" `
        -Top $barTop `
        -CheckCancellation  # ← Permite ESC
    
    # Tu lógica aquí
    $chunk = Read-NetworkData
    
    Start-Sleep -Milliseconds 100
}
```

---

## 🧪 Pruebas

### **Test 1: Compresión con cancelación**
```powershell
.\Llevar.ps1 -Origen "C:\Test" -Destino "D:\Backup" -BlockSizeMB 100

# Durante la compresión:
# - Barra avanza continuamente
# - Presionar ESC → cancelación inmediata
# - Archivos temporales se limpian automáticamente
```

### **Test 2: FTP con progreso**
```powershell
.\Llevar.ps1 -Origen "C:\Data" -Destino "ftp://server.com/backup"

# Durante upload:
# - Barra muestra X de Y archivos
# - Presionar ESC → detiene upload
```

### **Test 3: OneDrive con spinner**
```powershell
.\Llevar.ps1 -OnedriveOrigen -OneDrivePath "/MyFolder" -Destino "C:\Local"

# Durante descarga:
# - Spinner animado (sin % conocido)
# - Luego barra para compresión local
# - ESC funciona en ambas fases
```

---

## 🔧 Resolución de Problemas

### **La barra no avanza**
- ✅ **Solución:** Verificar que `Invoke-SevenZipWithProgress` está siendo llamado
- ❌ **Evitar:** Usar `& $SevenZ` directamente (es bufferizado)

### **ESC no cancela**
- ✅ **Solución:** Agregar `-CheckCancellation` a `Write-LlevarProgressBar`
- ⚠️ **Nota:** Solo funciona en consola (no ISE)

### **Spinner no se ve**
- ✅ **Solución:** Asegurar que se llama en loop con `Start-Sleep -Milliseconds 100`
- ✅ **Verificar:** Que el `-Top` está configurado correctamente

---

## 📚 Referencias

- [ProgressBar.psm1](../Modules/UI/ProgressBar.psm1) - Funciones de visualización
- [SevenZip.psm1](../Modules/Compression/SevenZip.psm1) - Streaming real de 7-Zip
- [Unified.psm1](../Modules/Transfer/Unified.psm1) - Handlers con progreso

---

**Última actualización:** 14 de diciembre de 2025
