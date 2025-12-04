# Show-Banner - Documentación

## Descripción

`Show-Banner` es una función mejorada para mostrar banners formateados con bordes automáticos en PowerShell. Calcula automáticamente el ancho según el texto más largo y proporciona múltiples opciones de personalización.

## Ventajas sobre el Método Anterior

### Antes (método manual):
```powershell
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ROBOCOPY MIRROR - COPIA ESPEJO" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
```

**Problemas**:
- Bordes de ancho fijo (hay que contarlos manualmente)
- Si el texto cambia, hay que ajustar los bordes
- No hay alineación automática
- No soporta posicionamiento
- Código repetitivo

### Ahora (con Show-Banner):
```powershell
Show-Banner -Text "ROBOCOPY MIRROR - COPIA ESPEJO" -BorderColor Cyan -TextColor Yellow
```

**Ventajas**:
- ✅ Ancho automático según el texto
- ✅ Alineación configurable (Center, Left, Right)
- ✅ Múltiples líneas de texto
- ✅ Colores personalizables (borde, texto, fondo)
- ✅ Caracteres de borde configurables
- ✅ Padding ajustable
- ✅ Posicionamiento opcional (X, Y)
- ✅ Código más limpio y mantenible

## Sintaxis

```powershell
Show-Banner [-Text] <string[]>
            [-Alignment <string>]
            [-BorderColor <ConsoleColor>]
            [-TextColor <ConsoleColor>]
            [-BackgroundColor <ConsoleColor>]
            [-BorderChar <char>]
            [-Padding <int>]
            [-X <int>]
            [-Y <int>]
```

## Parámetros

### -Text (Obligatorio)
Texto o array de textos a mostrar. Soporta una sola línea o múltiples.

**Tipo**: `string[]`  
**Ejemplos**:
```powershell
-Text "TÍTULO"
-Text @("Línea 1", "Línea 2", "Línea 3")
```

### -Alignment
Alineación del texto dentro del banner.

**Tipo**: `string`  
**Valores**: `'Center'` (default), `'Left'`, `'Right'`  
**Default**: `'Center'`

**Ejemplos**:
```powershell
-Alignment Left
-Alignment Center
-Alignment Right
```

### -BorderColor
Color de los bordes horizontales.

**Tipo**: `ConsoleColor`  
**Default**: `Cyan`  
**Valores**: Black, DarkBlue, DarkGreen, DarkCyan, DarkRed, DarkMagenta, DarkYellow, Gray, DarkGray, Blue, Green, Cyan, Red, Magenta, Yellow, White

**Ejemplo**:
```powershell
-BorderColor Yellow
```

### -TextColor
Color del texto principal.

**Tipo**: `ConsoleColor`  
**Default**: `White`

**Ejemplo**:
```powershell
-TextColor Cyan
```

### -BackgroundColor
Color de fondo del banner.

**Tipo**: `ConsoleColor`  
**Default**: `Black`

**Ejemplo**:
```powershell
-BackgroundColor DarkBlue
```

### -BorderChar
Carácter usado para dibujar los bordes.

**Tipo**: `char`  
**Default**: `'═'`

**Ejemplos**:
```powershell
-BorderChar '═'  # Estilo DOS
-BorderChar '-'  # Estilo simple
-BorderChar '*'  # Estilo asteriscos
-BorderChar '─'  # Estilo Unicode ligero
```

### -Padding
Espacios adicionales a cada lado del texto.

**Tipo**: `int`  
**Default**: `2`  
**Rango recomendado**: 1-10

**Ejemplo**:
```powershell
-Padding 5  # Banner más ancho
```

### -X
Posición horizontal (columna) donde dibujar el banner.

**Tipo**: `int`  
**Default**: `-1` (sin posicionamiento, usa posición actual)

**Ejemplo**:
```powershell
-X 10  # Dibujar en la columna 10
```

### -Y
Posición vertical (fila) donde dibujar el banner.

**Tipo**: `int`  
**Default**: `-1` (sin posicionamiento, usa posición actual)

**Ejemplo**:
```powershell
-Y 5  # Dibujar en la fila 5
```

## Ejemplos de Uso

### Ejemplo 1: Banner Simple
```powershell
Show-Banner -Text "LLEVAR.PS1"
```
**Salida**:
```
═════════════
  LLEVAR.PS1
═════════════
```

### Ejemplo 2: Banner con Colores Personalizados
```powershell
Show-Banner -Text "ADVERTENCIA" -BorderColor Red -TextColor Yellow
```

### Ejemplo 3: Banner Multi-Línea
```powershell
Show-Banner -Text @("ROBOCOPY MIRROR", "COPIA ESPEJO") -BorderColor Cyan -TextColor Yellow
```
**Salida**:
```
═════════════════
  ROBOCOPY MIRROR
  COPIA ESPEJO
═════════════════
```

### Ejemplo 4: Banner Alineado a la Izquierda
```powershell
Show-Banner -Text "INSTALACIÓN COMPLETA" -Alignment Left -BorderColor Green -TextColor Green
```
**Salida**:
```
════════════════════════
  INSTALACIÓN COMPLETA
════════════════════════
```

### Ejemplo 5: Banner Alineado a la Derecha
```powershell
Show-Banner -Text "ERROR" -Alignment Right -BorderColor Red -TextColor Red
```
**Salida**:
```
═════════
    ERROR
═════════
```

### Ejemplo 6: Banner con Caracteres Personalizados
```powershell
Show-Banner -Text "PROGRESO" -BorderChar '-' -BorderColor Magenta -TextColor White
```
**Salida**:
```
------------
  PROGRESO
------------
```

### Ejemplo 7: Banner con Padding Amplio
```powershell
Show-Banner -Text "IMPORTANTE" -Padding 5 -BorderColor Cyan -TextColor Yellow
```
**Salida**:
```
═══════════════════
     IMPORTANTE
═══════════════════
```

### Ejemplo 8: Banner Posicionado
```powershell
Show-Banner -Text "MENÚ" -X 10 -Y 5 -BorderColor White -TextColor Cyan
```
Dibuja el banner en la posición específica (columna 10, fila 5).

### Ejemplo 9: Banner Estilo Error
```powershell
Show-Banner -Text "✗ ERROR CRÍTICO" -BorderColor Red -TextColor White -BackgroundColor DarkRed
```

### Ejemplo 10: Banner Estilo Éxito
```powershell
Show-Banner -Text "✓ OPERACIÓN COMPLETADA" -BorderColor Green -TextColor White -BackgroundColor DarkGreen
```

### Ejemplo 11: Banner Multi-Línea Centrado
```powershell
Show-Banner -Text @("SISTEMA DE TRANSFERENCIA", "LLEVAR.PS1", "Versión 3.0") -BorderColor Cyan -TextColor White
```
**Salida**:
```
═══════════════════════════
  SISTEMA DE TRANSFERENCIA
  LLEVAR.PS1
  Versión 3.0
═══════════════════════════
```

## Casos de Uso en Llevar.ps1

### 1. Títulos de Sección
```powershell
Show-Banner -Text "MODO INTERACTIVO" -BorderColor Cyan -TextColor Cyan
```

### 2. Mensajes de Estado
```powershell
Show-Banner -Text "CONFIGURACIÓN COMPLETA" -BorderColor Green -TextColor Green
```

### 3. Advertencias
```powershell
Show-Banner -Text "⚠ ADVERTENCIA" -BorderColor Yellow -TextColor Yellow
```

### 4. Errores
```powershell
Show-Banner -Text "✗ ERROR" -BorderColor Red -TextColor Red
```

### 5. Confirmaciones
```powershell
Show-Banner -Text "✓ ÉXITO" -BorderColor Green -TextColor Green
```

### 6. Información Multi-Línea
```powershell
Show-Banner -Text @("ROBOCOPY MIRROR", "Sincronización Completa") -BorderColor Cyan -TextColor Yellow
```

## Integración con Otras Funciones

### Show-ConsolePopup
Ahora soporta parámetros `-X` y `-Y` para posicionamiento:
```powershell
Show-ConsolePopup -Title "Error" -Message "Archivo no encontrado" -X 10 -Y 5
```

### Show-DosMenu
También soporta parámetros `-X` y `-Y`:
```powershell
Show-DosMenu -Title "Menú Principal" -Items $options -X 5 -Y 3
```

## Comparación de Código

### Antes
```powershell
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ROBOCOPY MIRROR - COPIA ESPEJO" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
```
**Líneas**: 5  
**Caracteres**: ~220  
**Mantenibilidad**: Baja (bordes hardcoded)

### Ahora
```powershell
Write-Host ""
Show-Banner -Text "ROBOCOPY MIRROR - COPIA ESPEJO" -BorderColor Cyan -TextColor Yellow
Write-Host ""
```
**Líneas**: 3  
**Caracteres**: ~85  
**Mantenibilidad**: Alta (ancho automático)

**Reducción**: 40% menos líneas, 61% menos caracteres

## Demo

Ejecutar el script de demostración:
```powershell
.\Demo-Banner.ps1
```

Este script muestra 12 ejemplos diferentes de uso de `Show-Banner` con diferentes configuraciones.

## Notas Técnicas

### Cálculo de Ancho
El ancho del banner se calcula automáticamente:
```
Ancho = LongitudTextoMásLargo + (Padding * 2)
```

### Alineación
- **Center**: Padding distribuido equitativamente
- **Left**: Padding completo a la derecha
- **Right**: Padding completo a la izquierda

### Posicionamiento
- Si `X` o `Y` son `-1`, no se posiciona
- Si se especifican, se ajustan a límites de ventana
- El posicionamiento es seguro (no produce errores fuera de límites)

### Compatibilidad
- ✅ PowerShell 5.1+
- ✅ PowerShell Core 6+
- ✅ Windows Terminal
- ✅ PowerShell ISE
- ✅ VS Code Terminal

## Mejoras Futuras (Opcional)

- [ ] Soporte para bordes laterales personalizados
- [ ] Esquinas redondeadas opcionales
- [ ] Sombras
- [ ] Animaciones de entrada
- [ ] Gradientes de color
- [ ] Bordes dobles/simples alternos
- [ ] Auto-ajuste a ancho de terminal

## Conclusión

`Show-Banner` simplifica la creación de banners formateados, reduce código repetitivo y mejora la mantenibilidad del script. La función es flexible, fácil de usar y produce resultados consistentes y profesionales.
