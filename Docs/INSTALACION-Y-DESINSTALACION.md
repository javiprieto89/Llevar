# Instalación y Desinstalación de Llevar

## Instalación

Para instalar Llevar en el sistema:

### Opción 1: Instalador CMD (Recomendado)
```cmd
INSTALAR.CMD
```

Este script:
- Eleva automáticamente a permisos de administrador
- Verifica PowerShell 7+ (requerido)
- Configura ExecutionPolicy si es necesario
- Ejecuta la instalación completa

### Opción 2: PowerShell directo
```powershell
pwsh.exe -ExecutionPolicy Bypass -File Llevar.ps1 -Instalar
```

## ¿Qué hace la instalación?

La instalación realiza las siguientes acciones:

1. **Copia archivos a C:\Llevar**
   - Llevar.ps1 (script principal)
   - LLEVAR.CMD (launcher)
   - DESINSTALAR.CMD (desinstalador)
   - Módulos completos
   - Datos de configuración
   - 7-Zip portable (si está disponible)

2. **Configura el sistema**
   - Agrega C:\Llevar al PATH del sistema
   - Crea acceso directo en el escritorio

3. **Instala menú contextual**
   - Click derecho en carpetas → "Llevar A..."
   - Click derecho en unidades → "Llevar A..."

4. **Registra en Panel de Control**
   - Aparece en "Agregar o quitar programas"
   - Nombre: Llevar
   - Propietario: AlexSoft
   - Con opción de desinstalación

## Desinstalación

Para desinstalar Llevar completamente del sistema:

### Opción 1: Panel de Control (Recomendado)
1. Abrir "Configuración" → "Aplicaciones" → "Aplicaciones instaladas"
2. Buscar "Llevar"
3. Click en "Desinstalar"

### Opción 2: Desinstalador CMD
```cmd
C:\Llevar\DESINSTALAR.CMD
```

### Opción 3: PowerShell directo
```powershell
pwsh.exe -ExecutionPolicy Bypass -File C:\Llevar\Llevar.ps1 -Desinstalar
```

## ¿Qué hace la desinstalación?

La desinstalación elimina COMPLETAMENTE Llevar del sistema:

1. **Confirmación de seguridad**
   - Muestra popup pidiendo confirmación
   - Opción de cancelar en cualquier momento

2. **Elimina entradas del registro**
   - Menú contextual de carpetas (HKCR\Directory\shell\Llevar)
   - Menú contextual de unidades (HKCR\Drive\shell\Llevar)
   - Registro en Panel de Control (HKLM\...\Uninstall\Llevar)

3. **Elimina del PATH del sistema**
   - Remueve C:\Llevar del PATH
   - Actualiza variables de entorno

4. **Elimina accesos directos**
   - Acceso directo del escritorio
   - Acceso directo público (si existe)

5. **Elimina carpeta completa**
   - Segunda confirmación antes de eliminar
   - Borra C:\Llevar recursivamente
   - Incluye todos los archivos y subcarpetas

6. **Refresca el sistema**
   - Actualiza el explorador de archivos
   - Aplica cambios inmediatamente

## Códigos de salida

### Instalación
- `0` = Instalación exitosa
- `1` = Error durante la instalación

### Desinstalación
- `0` = Desinstalación completa exitosa
- `1` = Desinstalación con errores (algunos elementos no se pudieron eliminar)
- `98` = Desinstalación parcial (usuario canceló eliminación de carpeta)
- `99` = Desinstalación cancelada por el usuario

## Requisitos

- **Windows 10/11** (recomendado)
- **PowerShell 7 o superior** (obligatorio)
- **Permisos de administrador** (para instalación y desinstalación)

## Notas importantes

- La desinstalación es **irreversible** - elimina todos los archivos
- Se recomienda reiniciar después de desinstalar para que los cambios surtan efecto completo
- La desinstalación NO afecta archivos transferidos previamente con Llevar
- Si la desinstalación falla, puede ejecutar DESINSTALAR.CMD nuevamente

## Desinstalación manual (si falla la automática)

Si por alguna razón falla la desinstalación automática:

1. **Eliminar menú contextual**
   ```cmd
   reg delete "HKCR\Directory\shell\Llevar" /f
   reg delete "HKCR\Drive\shell\Llevar" /f
   ```

2. **Eliminar del Panel de Control**
   ```cmd
   reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Llevar" /f
   ```

3. **Eliminar del PATH**
   - Panel de Control → Sistema → Configuración avanzada
   - Variables de entorno → PATH del sistema
   - Eliminar `C:\Llevar`

4. **Eliminar carpeta**
   ```cmd
   rd /s /q "C:\Llevar"
   ```

5. **Eliminar acceso directo**
   - Eliminar `Llevar.lnk` del escritorio
