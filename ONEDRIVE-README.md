# 🌐 Funcionalidad OneDrive para Llevar.ps1

## 📝 Descripción

El script `Llevar.ps1` ahora incluye soporte completo para **Microsoft OneDrive** como origen o destino de archivos, permitiendo:

- ✅ Subir archivos/carpetas desde PC a OneDrive
- ✅ Descargar archivos/carpetas desde OneDrive a PC
- ✅ Transferir entre carpetas de OneDrive
- ✅ Autenticación con MFA (Multi-Factor Authentication)
- ✅ Instalación automática de módulos requeridos
- ✅ Soporte para archivos grandes con upload chunked

---

## 🚀 Requisitos

### Módulos de PowerShell

El script detecta e instala automáticamente los siguientes módulos si no están presentes:

- `Microsoft.Graph.Authentication`
- `Microsoft.Graph.Files`

**El script intentará instalar automáticamente los módulos faltantes al primer uso.**

Si la instalación automática falla, puede instalar manualmente:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

### Permisos Requeridos

- **Files.ReadWrite.All**: Lectura y escritura de archivos en OneDrive

El script solicita automáticamente estos permisos durante la autenticación.

---

## 📖 Uso

### Parámetros OneDrive

```powershell
-OnedriveOrigen      # Indica que el origen es OneDrive
-OnedriveDestino     # Indica que el destino es OneDrive
```

### Formato de Rutas

Las rutas de OneDrive pueden especificarse de dos formas:

1. **Formato URI**: `onedrive:///carpeta/subcarpeta`
2. **Formato directo**: `ONEDRIVE:/carpeta/archivo.txt`
3. **Interactivo**: Si no se especifica, el script lo solicitará

### Ejemplos de Uso

#### 1️⃣ Subir Carpeta Local a OneDrive (Modo Compresión)

```powershell
.\Llevar.ps1 -Origen "C:\MiProyecto" -Destino "onedrive:///Backups/Proyecto" -OnedriveDestino
```

**Resultado**: 
- Comprime la carpeta local
- Divide en bloques
- Sube bloques + INSTALAR.ps1 a OneDrive
- Permite reinstalar en otro equipo

#### 2️⃣ Descargar desde OneDrive a Local (Modo Directo)

```powershell
.\Llevar.ps1 -Origen "onedrive:///Documentos/Importante" -Destino "C:\Descargas" -OnedriveOrigen
```

**Resultado**:
- Descarga archivos directamente sin comprimir
- Más rápido para transferencias simples

#### 3️⃣ OneDrive a OneDrive

```powershell
.\Llevar.ps1 -OnedriveOrigen -OnedriveDestino -BlockSizeMB 50
```

**Resultado**:
- Se solicitarán rutas de origen y destino interactivamente
- Descarga a temporal, comprime y sube al destino

#### 4️⃣ Subir con Parámetros Completos

```powershell
.\Llevar.ps1 `
    -Origen "C:\Datos" `
    -Destino "onedrive:///Respaldos/Datos" `
    -OnedriveDestino `
    -BlockSizeMB 100 `
    -UseNativeZip
```

---

## 🔄 Modos de Transferencia

Cuando se usa OneDrive, el script pregunta qué modo usar:

### Modo Directo (Transferencia Directa)
- ✅ **Ventaja**: Más rápido, no requiere espacio temporal
- ❌ **Desventaja**: No genera instalador para reinstalar en otro equipo
- 📌 **Uso recomendado**: Respaldos simples, sincronización de archivos

### Modo Comprimir (Compresión y Bloques)
- ✅ **Ventaja**: Genera INSTALAR.ps1 para reinstalar en otro equipo
- ✅ **Ventaja**: Divide en bloques manejables
- ❌ **Desventaja**: Requiere espacio temporal, más lento
- 📌 **Uso recomendado**: Distribución de software, instaladores portables

---

## 🔐 Autenticación

### Primera Vez

1. El script detecta que se requiere autenticación con OneDrive
2. Verifica si los módulos Microsoft.Graph están instalados
3. Si faltan, ofrece instalarlos automáticamente
4. Abre una ventana de navegador para autenticación
5. Solicita permisos: **Files.ReadWrite.All**
6. Soporta MFA (códigos 2FA, autenticación biométrica, etc.)

### Sesiones Subsecuentes

Si ya hay una sesión activa de Microsoft Graph:
```
[+] Ya estás autenticado como usuario@ejemplo.com
```

Para cerrar sesión:
```powershell
Disconnect-MgGraph
```

---

## 📊 Verificación de Módulos

El script incluye verificación automática:

```
══════════════════════════════════════════════════
  VERIFICACIÓN DE MÓDULOS MICROSOFT.GRAPH
══════════════════════════════════════════════════

Verificando módulo: Microsoft.Graph.Authentication... ✓ Instalado (v2.10.0)
Verificando módulo: Microsoft.Graph.Files... ✓ Instalado (v2.10.0)

✓ Todos los módulos requeridos están instalados
```

### Si Faltan Módulos

```
══════════════════════════════════════════════════
  INSTALACIÓN DE MÓDULOS FALTANTES
══════════════════════════════════════════════════

Se requiere instalar los siguientes módulos:
  • Microsoft.Graph.Authentication
  • Microsoft.Graph.Files

NOTA: La instalación puede tardar varios minutos.
      Se instalará para el usuario actual (no requiere administrador).

¿Desea instalar los módulos ahora? (S/N): S

Instalando módulos Microsoft.Graph...
Esto puede tardar varios minutos, por favor espere...

✓ Módulos instalados exitosamente
```

---

## ⚙️ Características Técnicas

### Upload de Archivos Grandes

Para archivos **> 4MB**, el script usa **upload chunked**:

- Divide el archivo en chunks de 3.2MB
- Sube secuencialmente con reintentos automáticos
- Muestra progreso de upload

```powershell
[*] Subiendo archivo a OneDrive → root:/Backups/archivo.zip:
  Progreso: 45%
[✓] Subida completada.
```

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
