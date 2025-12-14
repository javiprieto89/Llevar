# Correcciones del Menú Contextual, Acceso Directo e Instalación

## Problemas Resueltos

### 1. ❌ Problema: Abría PowerShell 5 en lugar de PowerShell 7
**Solución:** LLEVAR.CMD y INSTALAR.CMD verifican y requieren PowerShell 7+ antes de ejecutar

### 2. ❌ Problema: No mostraba el icono en el menú contextual
**Solución:** Se corrigió la configuración del registro para usar comillas correctas alrededor de la ruta del icono

### 3. ❌ Problema: Requería ExecutionPolicy configurado manualmente
**Solución:** LLEVAR.CMD e INSTALAR.CMD detectan y habilitan ExecutionPolicy automáticamente si es necesario

### 4. ❌ Problema: Instalación fallaba sin ExecutionPolicy configurado
**Solución:** Nuevo INSTALAR.CMD que no requiere scripts habilitados previamente, habilita automáticamente

### 5. ❌ Problema: El acceso directo del escritorio apuntaba a Llevar.ps1
**Solución:** Ahora apunta a LLEVAR.CMD, permitiendo arrastrar carpetas/archivos directamente al icono

### 6. ❌ Problema: Requería interacción del usuario para permisos
**Solución:** LLEVAR.CMD, INSTALAR.CMD y Llevar.ps1 elevan automáticamente sin pedir confirmación (solo UAC del sistema)

## Archivos Nuevos y Modificados

### INSTALAR.CMD (NUEVO)
Instalador que no requiere ExecutionPolicy configurado:
- ✅ Eleva permisos automáticamente
- ✅ Verifica PowerShell 7+ (muestra error si falta)
- ✅ Detecta y habilita ExecutionPolicy automáticamente
- ✅ Ejecuta `Llevar.ps1 -Instalar`
- ✅ Manejo de errores con mensajes claros
- ✅ No requiere ejecutar scripts directamente

### LLEVAR.CMD (MEJORADO)
Launcher inteligente con auto-configuración:
- ✅ Verifica si ya es administrador antes de elevar
- ✅ Eleva permisos automáticamente si no es admin
- ✅ Busca PowerShell 7 en múltiples ubicaciones
- ✅ Detecta y habilita ExecutionPolicy automáticamente
- ✅ Pasa argumentos correctamente al script principal
- ✅ Soporta arrastrar carpetas/archivos al icono
- ✅ Maneja cancelación de UAC con popup de advertencia

### Llevar.ps1 (SIN CAMBIOS EN AUTO-ELEVACIÓN)
Script principal que mantiene su auto-elevación:
- ✅ Verifica versión de PowerShell al inicio
- ✅ Auto-elevación si no detecta que ya es admin
- ✅ Si LLEVAR.CMD ya elevó, detecta y continúa sin re-elevar
- ✅ Preserva todos los parámetros al elevar
- ✅ Muestra popup de advertencia si el usuario cancela UAC
- ✅ Funciona ejecutándose directamente o desde LLEVAR.CMD

### MenuContextual.ps1
Instalador del menú contextual:
- ✅ Usa LLEVAR.CMD en lugar de llamar directamente a PowerShell
- ✅ Configura icono correctamente con comillas en el registro
- ✅ Verifica que tanto Llevar.ps1 como LLEVAR.CMD existan
- ✅ Fallback a icono del sistema si falta el personalizado

### SystemInstall.psm1
Instalación del sistema:
- ✅ Crea acceso directo que apunta directamente a LLEVAR.CMD
- ✅ Permite arrastrar carpetas/archivos al icono del escritorio
- ✅ Descripción actualizada: "Llevar - Sistema de transferencia de archivos (arrastre carpetas/archivos aquí)"

## Comportamiento Actual

### Instalación del Sistema

**Opción 1: Usando INSTALAR.CMD (RECOMENDADO para instalación inicial)**
```cmd
# Desde la carpeta de Llevar, doble clic en:
INSTALAR.CMD

# O desde CMD:
cd Q:\Utilidad\Llevar
INSTALAR.CMD
```

**Flujo de INSTALAR.CMD:**
1. Verifica si es administrador, si no → eleva automáticamente
2. Verifica PowerShell 7+ (muestra error y link si falta)
3. Detecta ExecutionPolicy, si es Restricted/Undefined → lo habilita automáticamente
4. Ejecuta `Llevar.ps1 -Instalar`
5. Muestra resultado de instalación

**Ventajas:**
- ✅ No requiere ExecutionPolicy configurado previamente
- ✅ No requiere ejecutar scripts directamente
- ✅ Ideal para sistemas con políticas restrictivas
- ✅ Configura todo automáticamente

**Opción 2: Usando Llevar.ps1 directamente**
```powershell
# Desde PowerShell 7 como administrador:
.\Llevar.ps1 -Instalar
```

### Al hacer clic derecho → "Llevar A..." o arrastrar al icono del escritorio

**Flujo completo:**

1. **LLEVAR.CMD verifica si es administrador**
   - Si NO es admin → eleva automáticamente y re-ejecuta
   - Si usuario cancela UAC → popup de advertencia

2. **LLEVAR.CMD verifica PowerShell 7+**
   - Busca `pwsh.exe` en PATH, Program Files, Program Files (x86)
   - Si no encuentra → popup de error + abre navegador con link de descarga

3. **LLEVAR.CMD verifica ExecutionPolicy**
   - Lee política actual con `Get-ExecutionPolicy -Scope LocalMachine`
   - Si es Restricted o Undefined → ejecuta `Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force`
   - Si falla configuración → popup de error con instrucciones

4. **LLEVAR.CMD ejecuta Llevar.ps1**
   - Pasa argumentos correctamente (incluyendo -Origen si se arrastró carpeta)
   - Ejecuta con `-ExecutionPolicy Bypass` por seguridad

5. **Llevar.ps1 verifica si es admin (doble verificación)**
   - Si ya es admin (porque LLEVAR.CMD elevó) → continúa ejecutando
   - Si no es admin (ejecutado directamente) → auto-eleva y re-ejecuta
   - Preserva todos los parámetros

6. **Ejecución normal**
   - Muestra menú interactivo o ejecuta con parámetros
   - Icono visible en menú contextual

## Uso del Acceso Directo del Escritorio

El acceso directo "Llevar.lnk" en el escritorio:

### Método 1: Doble clic
1. Doble clic en el icono "Llevar" del escritorio
2. Se abre el menú interactivo de Llevar
3. Solicita elevación de permisos automáticamente

### Método 2: Arrastrar y soltar (RECOMENDADO)
1. Arrastre una carpeta o archivo al icono "Llevar" del escritorio
2. El sistema detecta automáticamente la carpeta/archivo como origen
3. Solicita elevación de permisos automáticamente
4. Abre el menú con la carpeta/archivo ya seleccionado como origen

### Ventajas del arrastrar y soltar:
- ✅ Más rápido que usar menú contextual
- ✅ No requiere clic derecho
- ✅ Funciona con múltiples archivos/carpetas
- ✅ Ideal para uso frecuente

## Icono del Menú Contextual

**Ubicación:** `C:\Llevar\Data\Llevar_ContextMenu.ico`

**Fallback:** Si el icono personalizado no existe, usa:
- `%SystemRoot%\System32\shell32.dll,43` (icono de carpeta con flecha)

**Para personalizar:**
1. Reemplace `C:\Llevar\Data\Llevar_ContextMenu.ico` con su icono .ico
2. O edite MenuContextual.ps1 línea 21 para cambiar el fallback

## Comandos de Instalación/Desinstalación

### Instalar menú contextual:
```powershell
# Como administrador en PowerShell 7:
C:\Llevar\Instalar-MenuContextual.ps1
```

### Desinstalar menú contextual:
```powershell
# Como administrador en PowerShell 7:
C:\Llevar\Instalar-MenuContextual.ps1 -Uninstall
```

## Registro de Windows

El menú contextual se registra en:

```registry
HKEY_CLASSES_ROOT\Directory\shell\Llevar
├── (Default) = "Llevar A..."
├── Icon = "C:\Llevar\Data\Llevar_ContextMenu.ico"
└── command
    └── (Default) = "C:\Llevar\LLEVAR.CMD" "%1"

HKEY_CLASSES_ROOT\*\shell\Llevar
├── (Default) = "Llevar A..."
├── Icon = "C:\Llevar\Data\Llevar_ContextMenu.ico"
└── command
    └── (Default) = "C:\Llevar\LLEVAR.CMD" "%1"

HKEY_CLASSES_ROOT\Drive\shell\Llevar
├── (Default) = "Llevar A..."
├── Icon = "C:\Llevar\Data\Llevar_ContextMenu.ico"
└── command
    └── (Default) = "C:\Llevar\LLEVAR.CMD" "%1"
```

## Troubleshooting

### El icono no aparece
1. Verificar que existe: `C:\Llevar\Data\Llevar_ContextMenu.ico`
2. Reinstalar menú contextual
3. Reiniciar explorador de archivos: `taskkill /f /im explorer.exe && start explorer.exe`

### Dice que falta PowerShell 7
1. Descargar desde: https://aka.ms/powershell-release?tag=stable
2. Instalar PowerShell 7.x o superior
3. Verificar con: `pwsh -Version`

### UAC no aparece / No eleva permisos
1. Verificar configuración de UAC en Windows
2. Revisar política de grupo que pueda bloquear elevación
3. Intentar ejecutar manualmente como admin:
   - Clic derecho en "Llevar.lnk" → "Ejecutar como administrador"
   - O abrir PowerShell 7 como administrador y ejecutar: `C:\Llevar\Llevar.ps1`

### Usuario cancela UAC repetidamente
- **Comportamiento esperado:** Muestra popup de advertencia y termina
- **Solución:** El usuario debe aceptar UAC para que el programa funcione
- **Alternativa:** Ejecutar PowerShell 7 como administrador de inicio

### Popup de advertencia no aparece
- Si el sistema no puede mostrar MessageBox por restricciones:
  - Se mostrará mensaje en consola como fallback
  - Presionar cualquier tecla para cerrar
  - Los mensajes de consola contienen la misma información

### Error "No se encuentra LLEVAR.CMD"
1. Verificar instalación completa en C:\Llevar
2. Verificar que LLEVAR.CMD existe
3. Reinstalar con: `INSTALAR.CMD` o `.\Llevar.ps1 -Instalar`

### Error de ExecutionPolicy al instalar
- **Solución:** Use `INSTALAR.CMD` en lugar de ejecutar Llevar.ps1 directamente
- INSTALAR.CMD habilita ExecutionPolicy automáticamente

---

## Para Aplicar los Cambios

### Si NO tiene Llevar instalado aún:

```cmd
# Método 1: INSTALAR.CMD (más fácil, recomendado)
cd Q:\Utilidad\Llevar
INSTALAR.CMD

# Método 2: PowerShell directo (requiere ExecutionPolicy configurado)
pwsh.exe -File Q:\Utilidad\Llevar\Llevar.ps1 -Instalar
```

### Si YA tiene Llevar instalado:

```cmd
# Reinstalar desde la ubicación instalada
C:\Llevar\LLEVAR.CMD -Instalar

# O copiar INSTALAR.CMD y LLEVAR.CMD actualizados y ejecutar:
C:\Llevar\INSTALAR.CMD
```

---

## Arquitectura de Elevación de Permisos

### Escenario 1: Instalación con INSTALAR.CMD
```
Usuario ejecuta INSTALAR.CMD
  ↓
¿Es admin? NO → INSTALAR.CMD se auto-eleva
  ↓
INSTALAR.CMD (como admin) verifica ExecutionPolicy
  ↓
INSTALAR.CMD habilita ExecutionPolicy si es necesario
  ↓
INSTALAR.CMD ejecuta: pwsh -File Llevar.ps1 -Instalar
  ↓
Llevar.ps1 detecta que ya es admin → continúa instalación
```

### Escenario 2: Ejecutar desde menú contextual
```
Usuario: clic derecho → "Llevar A..."
  ↓
Se ejecuta LLEVAR.CMD con carpeta como argumento
  ↓
¿Es admin? NO → LLEVAR.CMD se auto-eleva
  ↓
LLEVAR.CMD (como admin) verifica ExecutionPolicy
  ↓
LLEVAR.CMD habilita ExecutionPolicy si es necesario
  ↓
LLEVAR.CMD ejecuta: pwsh -File Llevar.ps1 -Origen "C:\Carpeta"
  ↓
Llevar.ps1 detecta que ya es admin → ejecuta normalmente
```

### Escenario 3: Ejecutar Llevar.ps1 directamente
```
Usuario ejecuta: pwsh -File Llevar.ps1
  ↓
Llevar.ps1 verifica: ¿Es admin? NO
  ↓
Llevar.ps1 se auto-eleva: Start-Process pwsh -Verb RunAs
  ↓
Llevar.ps1 (como admin) ejecuta normalmente
```

### Resumen
- **INSTALAR.CMD** y **LLEVAR.CMD**: Elevan antes de llamar a Llevar.ps1
- **Llevar.ps1**: Verifica si ya es admin, si no → auto-eleva
- **Doble protección**: Funciona desde CMD o PowerShell directamente
- **ExecutionPolicy**: Los CMD lo habilitan automáticamente si es necesario
