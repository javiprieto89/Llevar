# Documentación LLEVAR.PS1

Sistema de transferencia y compresión de archivos con soporte para múltiples orígenes y destinos.

## 📚 Guías Principales

### [TRANSFERCONFIG.md](TRANSFERCONFIG.md)
Sistema unificado de configuración para todas las transferencias.
- Estructura de datos
- Funciones helper
- Uso de credenciales (FTP, UNC, OAuth)
- Ejemplos de configuración

### [MENU-INTERACTIVO.md](MENU-INTERACTIVO.md)
Sistema de menús interactivos para configurar transferencias.
- Menú principal
- Configuración de origen/destino
- Opciones de compresión
- Flujo de usuario

### [TESTING.md](TESTING.md)
Sistema modular de pruebas para validar componentes.
- 9 tipos de pruebas disponibles
- Uso del parámetro `-Test`
- Cómo agregar nuevas pruebas
- Ejemplos de uso

## 🧩 Componentes

### [NAVEGADOR.md](NAVEGADOR.md)
Navegador de archivos estilo Norton Commander.
- Navegación con flechas
- Cálculo de tamaño de carpetas (ESPACIO)
- Búsqueda y filtrado (F4)
- Selector de unidades (F2)
- Recursos de red UNC (F3)

### [BANNERS.md](BANNERS.md)
Sistema de banners y mensajes formateados.
- Función `Show-Banner`
- Alineación y colores
- Posicionamiento
- Múltiples líneas de texto

### [HELPER-FUNCTIONS.md](HELPER-FUNCTIONS.md)
Funciones helper para TransferConfig.
- OneDrive, Dropbox, FTP, UNC
- Local, USB, ISO, Diskette
- Get/Set configuraciones
- Validación de rutas

## 🌐 Servicios Cloud

### [ONEDRIVE-README.md](ONEDRIVE-README.md)
Integración con Microsoft OneDrive.
- Autenticación OAuth2 con MFA
- Upload/Download de archivos
- Módulos Microsoft.Graph
- Formato de rutas

## 🎯 Estructura del Proyecto

```
LLEVAR/
├── Llevar.ps1              # Script principal
├── Llevar.CMD              # Lanzador Windows
├── Modules/                # Módulos PowerShell
│   ├── Core/               # TransferConfig, Logger
│   ├── Transfer/           # FTP, UNC, OneDrive, Dropbox
│   ├── Compression/        # 7-Zip, ZIP nativo
│   ├── UI/                 # Navigator, Banners, Popups
│   ├── Parameters/         # Modos de ejecución, Test
│   └── ...
├── Tests/                  # Scripts de pruebas
└── Docs/                   # Esta documentación
```

## 🚀 Inicio Rápido

### Modo Interactivo
```powershell
.\Llevar.ps1
```
Se abre el menú interactivo para configurar todo.

### Modo CLI
```powershell
# Local a USB
.\Llevar.ps1 -Origen "C:\Datos" -Destino "E:\"

# Local a FTP
.\Llevar.ps1 -Origen "C:\Datos" -Destino "ftp://servidor/ruta" -FTPDestino

# OneDrive a Local
.\Llevar.ps1 -Origen "onedrive:///Documents" -Destino "C:\Backup" -OnedriveOrigen
```

### Modo Pruebas
```powershell
# Probar navegador
.\Llevar.ps1 -Test Navigator

# Probar FTP
.\Llevar.ps1 -Test FTP

# Probar compresión
.\Llevar.ps1 -Test Compression
```

## 📖 Documentos por Tema

### Configuración
- [TRANSFERCONFIG.md](TRANSFERCONFIG.md) - Sistema de configuración unificado
- [HELPER-FUNCTIONS.md](HELPER-FUNCTIONS.md) - Funciones auxiliares

### Interfaz de Usuario
- [MENU-INTERACTIVO.md](MENU-INTERACTIVO.md) - Menús de configuración
- [NAVEGADOR.md](NAVEGADOR.md) - Explorador de archivos
- [BANNERS.md](BANNERS.md) - Sistema de mensajes

### Transferencias
- [ONEDRIVE-README.md](ONEDRIVE-README.md) - Integración OneDrive
- [TRANSFERCONFIG.md](TRANSFERCONFIG.md) - FTP, UNC, Dropbox

### Testing
- [TESTING.md](TESTING.md) - Sistema completo de pruebas

## 🔧 Mantenimiento

### Actualizar Documentación

Al agregar nuevas funcionalidades:
1. Actualizar el documento correspondiente
2. Agregar enlace en este README si es necesario
3. Mantener ejemplos actualizados
4. Actualizar estructura del proyecto si cambia

### Archivos Obsoletos Eliminados

Los siguientes documentos fueron eliminados por estar obsoletos:
- CAMBIOS-FTP.md (cambio ya implementado)
- CORRECCIONES-TRANSFERCONFIG.md (correcciones aplicadas)
- FIX-WARNINGS.md (fix aplicado)
- FTP-PSCREDENTIAL-UPDATE.md (ya implementado)
- FUNCTION-AUDIT-REPORT.md (auditoría vieja)
- IMPORT-EXPORT-AUDIT.md (problemas resueltos)
- LIMPIEZA-FUNCIONES-OBSOLETAS.md (limpieza completa)
- MODULARIZATION-SUMMARY.md (modularización completa)
- VERIFICATION-COMPLETE.md (verificación vieja)
- IMPLEMENTACION-PRUEBAS.md (redundante con TESTING.md)
- TRANSFERCONFIG-ARCHITECTURE.md (integrado en TRANSFERCONFIG.md)
- TRANSFERCONFIG-TYPE.md (integrado en TRANSFERCONFIG.md)
- TEST-SYSTEM.md (integrado en TESTING.md)
- TEST-QUICK-GUIDE.md (integrado en TESTING.md)

## 📅 Última Actualización

14 de diciembre de 2025

## 📄 Licencia

Parte del proyecto LLEVAR.PS1
