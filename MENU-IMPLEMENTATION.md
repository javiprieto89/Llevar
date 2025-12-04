# Sistema de Menú Interactivo - Llevar.ps1

## Resumen de Implementación

Se ha implementado un sistema completo de menús interactivos que se activa automáticamente cuando el script se ejecuta sin parámetros.

## Características Principales

### 1. Detección Automática
- El script detecta si se ejecutó sin parámetros
- Después de mostrar el logo, se presenta el menú interactivo
- Si se especifican parámetros, el script funciona normalmente

### 2. Menú Principal (Show-MainMenu)
Opciones disponibles:
1. **Origen**: Seleccionar tipo y ruta de origen
   - Local, FTP, OneDrive, Dropbox, UNC
2. **Destino**: Seleccionar tipo y ruta de destino
   - Local, USB, FTP, OneDrive, Dropbox, UNC
3. **Tamaño de Bloque**: Configurar MB para división
4. **Modo Robocopy Mirror**: Activar/desactivar sincronización
5. **Generar ISO**: En lugar de USB
6. **ZIP Nativo**: Usar Windows ZIP en lugar de 7-Zip
7. **Configurar Contraseña**: Protección con clave
8. **Modo Ejemplo**: Demo con datos temporales
9. **Ayuda**: Mostrar ayuda completa
0. **Salir**: Cancelar operación

### 3. Submenús Implementados

#### Show-OrigenMenu
- Local: Selector de carpeta con explorador
- FTP: Configuración completa con credenciales
- OneDrive: Autenticación Microsoft Graph
- Dropbox: OAuth2 con navegador
- UNC: Rutas de red con credenciales

#### Show-DestinoMenu
- Local: Selector de carpeta
- USB: Detección automática de unidades
- FTP: Configuración con validación
- OneDrive: Autenticación MFA
- Dropbox: OAuth2 automático
- UNC: Rutas compartidas

#### Get-FtpConfigFromUser
- Servidor FTP con validación
- Puerto (21 por defecto)
- Ruta remota
- Credenciales usuario/contraseña
- Prueba de conexión automática

#### Show-BlockSizeMenu
- Entrada interactiva de MB
- Sugerencias: 10, 50, 100, 500, 1024 MB
- Validación de rango (1-10240 MB)

#### Show-IsoMenu
- USB (sin ISO)
- CD-ROM (700 MB)
- DVD (4.7 GB)
- ISO-USB (híbrido)

#### Show-PasswordMenu
- Establecer nueva contraseña
- Cambiar contraseña existente
- Remover contraseña
- Entrada oculta con confirmación

### 4. Navegación del Menú
- **Flechas arriba/abajo**: Navegar opciones
- **Enter**: Seleccionar
- **Teclas con asterisco**: Hotkeys directos
- **Números**: Selección rápida
- **Esc/0**: Cancelar/Salir

### 5. Integración con el Flujo Principal

```powershell
# Flujo de ejecución:
1. Mostrar logo (siempre)
2. Si no hay parámetros → Menú interactivo
3. Usuario configura todo desde el menú
4. Al presionar "Ejecutar", se valida la configuración
5. Se mapea la configuración a variables del script
6. El script continúa con la ejecución normal
```

### 6. Validaciones Implementadas
- Origen y destino son obligatorios para ejecutar
- Para Robocopy Mirror, valida rutas locales
- FTP valida conectividad antes de continuar
- OneDrive/Dropbox requieren autenticación
- Contraseñas requieren confirmación
- Tamaño de bloque en rango válido

## Archivos Modificados

### Llevar.ps1
- **Líneas 2832-2908**: Show-MainMenu
- **Líneas 2910-2960**: Show-OrigenMenu
- **Líneas 2962-3082**: Show-DestinoMenu
- **Líneas 3022-3082**: Get-FtpConfigFromUser
- **Líneas 3084-3111**: Show-BlockSizeMenu
- **Líneas 3113-3149**: Show-IsoMenu
- **Líneas 3151-3206**: Show-PasswordMenu
- **Líneas 5217-5292**: Integración en flujo principal

## Funciones Utilizadas

### Show-DosMenu (existente)
Función base para renderizar menús con:
- Navegación con flechas
- Hotkeys con asterisco
- Selección numérica
- Estilo retro DOS

### Show-ConsolePopup (existente)
Para mensajes de confirmación y errores

### Get-PathOrPrompt (existente)
Para solicitar rutas con validación

## Ejemplos de Uso

### Ejecución Interactiva
```powershell
.\Llevar.ps1
```
Muestra el logo y luego el menú interactivo.

### Ejecución con Parámetros (tradicional)
```powershell
.\Llevar.ps1 -Origen "C:\Datos" -Destino "D:\Backup"
```
Funciona como siempre, sin menú.

### Ejecución Directa de Ayuda
```powershell
.\Llevar.ps1 -Ayuda
```
Muestra ayuda directamente sin menú.

## Testing

El sistema ha sido implementado con:
- ✅ Validación de sintaxis PowerShell
- ✅ Integración con funciones existentes
- ✅ Manejo de errores y validaciones
- ✅ Compatibilidad con flujo existente
- ✅ Soporte para todos los modos (Ejemplo, Robocopy, ISO)

## Notas Técnicas

### Configuración Retornada
El menú retorna un hashtable con:
```powershell
@{
    Action                 = "Execute" | "Example" | "Help" | "Exit"
    Origen                 = "ruta/del/origen"
    Destino                = "ruta/del/destino"
    OrigenTipo             = "Local|FTP|OneDrive|Dropbox|UNC"
    DestinoTipo            = "Local|USB|FTP|OneDrive|Dropbox|UNC"
    BlockSizeMB            = 10
    Clave                  = "password" | $null
    UseNativeZip           = $true | $false
    Iso                    = $true | $false
    IsoDestino             = "usb|cd|dvd|iso-usb"
    RobocopyMirror         = $true | $false
    SourceCredentials      = PSCredential | $null
    DestinationCredentials = PSCredential | $null
}
```

### Recursividad
Los menús son recursivos:
- Cada submenú modifica y retorna el objeto $config
- El menú principal mantiene el estado entre llamadas
- Los cambios son acumulativos hasta ejecutar

### Salida del Menú
- **Esc o seleccionar 0**: Retorna $null (salida limpia)
- **Seleccionar Ejecutar**: Retorna config con Action="Execute"
- **Seleccionar Ejemplo**: Retorna config con Action="Example"
- **Seleccionar Ayuda**: Retorna config con Action="Help"

## Próximos Pasos (Opcional)

- [ ] Agregar historial de configuraciones
- [ ] Guardar/cargar perfiles de configuración
- [ ] Modo batch para múltiples transferencias
- [ ] Integración con log detallado de operaciones
