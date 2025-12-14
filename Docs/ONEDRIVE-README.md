# OneDrive - Integración con Llevar.ps1

## Descripción

Soporte completo para Microsoft OneDrive como origen/destino de transferencias con autenticación OAuth2 y MFA.

## Requisitos

### Módulos PowerShell (instalación automática)
- `Microsoft.Graph.Authentication`
- `Microsoft.Graph.Files`

Instalación manual si falla automática:
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

### Permisos
- **Files.ReadWrite.All**: Lectura/escritura en OneDrive

## Uso en Modo Interactivo

```powershell
.\Llevar.ps1
# Seleccionar OneDrive en menú Origen/Destino
# Autenticación OAuth2 automática en navegador
# Seleccionar ruta en OneDrive
```

## Uso en Modo CLI

```powershell
# Subir a OneDrive
.\Llevar.ps1 -Origen "C:\Datos" -Destino "onedrive:///Backups" -OnedriveDestino

# Descargar de OneDrive
.\Llevar.ps1 -Origen "onedrive:///Documents" -Destino "C:\Local" -OnedriveOrigen

# OneDrive a OneDrive
.\Llevar.ps1 -OnedriveOrigen -OnedriveDestino
```

## Autenticación

**Primera vez:**
1. Navegador se abre automáticamente
2. Login con cuenta Microsoft
3. MFA si está configurado
4. Autorizar permisos Files.ReadWrite.All
5. Token guardado para sesiones futuras

**Cerrar sesión:**
```powershell
Disconnect-MgGraph
```

## Características

✅ Autenticación OAuth2 con MFA
✅ Upload chunked para archivos >4MB
✅ Descarga recursiva de carpetas
✅ Detección automática de módulos
✅ Instalación automática si faltan módulos
✅ Progreso en tiempo real
✅ Reintentos automáticos en errores de red

## Configuración en TransferConfig

```powershell
# Obtener configuración OneDrive
$onedrive = Get-OneDriveConfig -Config $config -Section "Origen"

# Establecer configuración OneDrive
Set-OneDriveConfig -Config $config -Section "Destino" `
    -Path "/Documents/LLEVAR" `
    -Email "user@outlook.com" `
    -Token "access_token" `
    -RefreshToken "refresh_token"
```

## Notas Técnicas

- Archivos <4MB: Upload directo
- Archivos >4MB: Upload chunked (3.2MB por chunk)
- Rutas formato: `/carpeta/subcarpeta` o `onedrive:///carpeta`
- API: Microsoft Graph v1.0

### Download Recursivo

Descarga carpetas completas manteniendo estructura:

```powershell
[*] Descargando carpeta desde OneDrive: /Documentos → C:\Descargas
  Descargando: archivo1.txt
  Descargando: archivo2.pdf
  Descargando: subfolder/archivo3.docx
[✓] Carpeta descargada completamente
```

### Limpieza Automática

Cuando se usa OneDrive como origen (modo comprimir):
- Descarga a `%TEMP%\LLEVAR_ONEDRIVE_ORIGEN`
- Comprime y transfiere
- Limpia automáticamente archivos temporales

---

## ❗ Solución de Problemas

### Error: "No se pueden usar funciones de OneDrive sin los módulos Microsoft.Graph"

**Causa**: Los módulos no están instalados y la instalación automática falló.

**Solución**:
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

### Error: "Error al autenticar"

**Causa**: Problemas de conexión o permisos.

**Solución**:
1. Verificar conexión a Internet
2. Cerrar sesión y reintentar:
   ```powershell
   Disconnect-MgGraph
   .\Llevar.ps1 -OnedriveDestino
   ```

### Error: "Error al subir/descargar"

**Causa**: Ruta inválida en OneDrive o permisos insuficientes.

**Solución**:
1. Verificar que la ruta existe en OneDrive
2. Asegurar que tiene permisos de escritura
3. Formato correcto: `onedrive:///Carpeta/Subcarpeta`

### Instalación de Módulos Falla

**Causas comunes**:
- Falta de conexión a Internet
- Problemas con PowerShell Gallery
- Firewall bloqueando la descarga

**Solución alternativa**:
```powershell
# Instalar con más opciones
Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
```

---

## 📋 Flujo Completo de Ejemplo

### Escenario: Respaldar Proyecto a OneDrive

1. **Ejecutar el script**:
   ```powershell
   .\Llevar.ps1 -Origen "C:\Proyectos\MiApp" -OnedriveDestino
   ```

2. **Verificación de módulos** (primera vez):
   ```
   ══════════════════════════════════════════════════
     VERIFICACIÓN DE MÓDULOS MICROSOFT.GRAPH
   ══════════════════════════════════════════════════
   
   Verificando módulo: Microsoft.Graph.Authentication... ✗ No encontrado
   Verificando módulo: Microsoft.Graph.Files... ✗ No encontrado
   
   ¿Desea instalar los módulos ahora? (S/N): S
   [Instalación en progreso...]
   ✓ Módulos instalados exitosamente
   ```

3. **Autenticación**:
   ```
   ═══════════════════════════════════════════════════
     AUTENTICACIÓN ONEDRIVE
   ═══════════════════════════════════════════════════
   
   [*] No hay sesión activa. Iniciando login con MFA...
   [Abre navegador para autenticación]
   [+] Autenticación correcta.
   ```

4. **Configuración**:
   ```
   Configurando destino OneDrive...
   Ingrese la ruta en OneDrive (ejemplo: /Documentos/Destino): /Backups/MiApp
   ✓ Destino OneDrive configurado: /Backups/MiApp
   ```

5. **Selección de modo**:
   ```
   ¿Cómo desea realizar la transferencia?
   • Transferir Directamente: Copia archivos sin comprimir
   • Comprimir Primero: Comprime, divide en bloques y transfiere
   [Selección: Comprimir]
   ```

6. **Compresión y upload**:
   ```
   Iniciando compresión y transferencia...
   [■■■■■■■■■■■■■■■■■■■■] 100% - Compresión...
   
   Subiendo bloques a OneDrive...
   [1/5] Subiendo: MiApp.alx0001
   [*] Subiendo archivo a OneDrive → root:/Backups/MiApp/MiApp.alx0001:
   [✓] Subida completada.
   [2/5] Subiendo: MiApp.alx0002
   ...
   
   ✓ Todos los archivos subidos a OneDrive
   ```

7. **Limpieza**:
   ```
   Limpiando archivos temporales...
   ✓ Archivos temporales eliminados
   
   ✓ Finalizado (Modo Comprimido).
   ```

---

## 🎯 Casos de Uso

### 1. Backup Automático
```powershell
# Script programado para backup nocturno
.\Llevar.ps1 `
    -Origen "C:\Datos" `
    -Destino "onedrive:///Backups/$(Get-Date -Format 'yyyy-MM-dd')" `
    -OnedriveDestino
```

### 2. Distribución de Instaladores
```powershell
# Generar instalador portable en OneDrive
.\Llevar.ps1 `
    -Origen "C:\Software\MiApp" `
    -Destino "onedrive:///Distribución/MiApp" `
    -OnedriveDestino `
    -BlockSizeMB 50
```

### 3. Sincronización Bidireccional
```powershell
# Subir
.\Llevar.ps1 -Origen "C:\Trabajo" -Destino "onedrive:///Trabajo" -OnedriveDestino

# Descargar en otro PC
.\Llevar.ps1 -Origen "onedrive:///Trabajo" -Destino "C:\Trabajo" -OnedriveOrigen
```

---

## 📞 Soporte

Para más información sobre el script principal, ejecute:

```powershell
.\Llevar.ps1 -Ayuda
```

---

## 📄 Licencia

Misma licencia que el proyecto principal Llevar.ps1

---

**Última actualización**: 2 de diciembre de 2025
