# 🚀 Guía Rápida: Sistema de Pruebas LLEVAR

## Sintaxis Base
```powershell
.\Llevar.ps1 -Test <Tipo>
```

## 📋 Todos los Comandos

### Pruebas de Interfaz
```powershell
# Probar el navegador de archivos
.\Llevar.ps1 -Test Navigator
```

### Pruebas de Transferencia
```powershell
# Probar conexión FTP (solicita credenciales)
.\Llevar.ps1 -Test FTP

# Probar acceso a recursos de red UNC
.\Llevar.ps1 -Test UNC
```

### Pruebas de Cloud
```powershell
# Probar autenticación OneDrive
.\Llevar.ps1 -Test OneDrive

# Probar autenticación Dropbox
.\Llevar.ps1 -Test Dropbox
```

### Pruebas de Almacenamiento
```powershell
# Detectar dispositivos USB
.\Llevar.ps1 -Test USB

# Generar imagen ISO de prueba
.\Llevar.ps1 -Test ISO
```

### Pruebas de Procesamiento
```powershell
# Probar compresión y división en bloques
.\Llevar.ps1 -Test Compression

# Probar sincronización con Robocopy
.\Llevar.ps1 -Test Robocopy
```

## 🎯 Casos de Uso

### Durante Desarrollo
```powershell
# Verificar que el navegador funciona después de cambios
.\Llevar.ps1 -Test Navigator

# Verificar que la compresión divide correctamente
.\Llevar.ps1 -Test Compression
```

### Debugging
```powershell
# Diagnosticar problemas de FTP
.\Llevar.ps1 -Test FTP

# Ver qué USBs detecta el sistema
.\Llevar.ps1 -Test USB
```

### Validación de Configuración
```powershell
# Verificar que OneDrive está configurado
.\Llevar.ps1 -Test OneDrive

# Verificar acceso a red corporativa
.\Llevar.ps1 -Test UNC
```

## 💡 Tips

- **Sin logo**: Las pruebas entran directo, sin animaciones
- **Auto-limpieza**: Los archivos temporales se eliminan solos
- **Seguro**: Las credenciales NO se guardan
- **Visual**: Todos los resultados tienen banners claros
- **Completo**: Cada prueba muestra información detallada

## ⚡ Ejemplo Real: Probar FTP

```powershell
PS> .\Llevar.ps1 -Test FTP

Servidor FTP: test.rebex.net
Puerto: 21
Usuario: demo
Contraseña: password
Ruta: /

# Resultado:
✓ Conexión exitosa
✓ 3 archivos encontrados
✓ readme.txt, pub, aspnet_client
```

## 📖 Documentación Completa

- **Guía Detallada**: `TEST-SYSTEM.md`
- **Resumen Implementación**: `IMPLEMENTACION-PRUEBAS.md`
- **Código Fuente**: `Modules\Parameters\Test.psm1`

---
**Versión**: 1.0  
**Fecha**: 4 de diciembre de 2025
