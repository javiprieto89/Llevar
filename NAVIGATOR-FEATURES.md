# NAVEGADOR DE ARCHIVOS - NUEVAS FUNCIONALIDADES

## 🎯 Resumen de Mejoras

El navegador de archivos estilo Norton Commander ahora incluye:

### 1. 📁 Cálculo de Tamaño de Carpetas (ESPACIO)

**Cómo usar:**
- Navega hasta una carpeta con las flechas
- Presiona la **BARRA ESPACIADORA**
- Se mostrará un spinner animado mientras se calcula el tamaño
- El cálculo es recursivo (incluye todos los archivos y subcarpetas)
- **Presiona ESC** en cualquier momento para cancelar el cálculo

**Características:**
- ✅ Spinner animado grande y visible
- ✅ Muestra progreso en tiempo real (tamaño, archivos, carpetas)
- ✅ Cancelable con ESC
- ✅ Resultado guardado en caché para acceso rápido
- ✅ Formato inteligente según tamaño:
  - Menos de 1 KB → muestra en Bytes (B)
  - 1 KB - 1 MB → muestra en Kilobytes (KB)
  - 1 MB - 1 GB → muestra en Megabytes (MB)
  - 1 GB - 1 TB → muestra en Gigabytes (GB)
  - Más de 1 TB → muestra en Terabytes (TB)

**Ejemplo visual:**
```
╔════════════════════════════════════════════════════════════╗
║           CALCULANDO TAMAÑO DE DIRECTORIO                  ║
╠════════════════════════════════════════════════════════════╣
║                                                            ║
║  📁 Modules                                                ║
║                                                            ║
║    ⠋  2.45 MB - 87 archivos - 12 carpetas                 ║
║                                                            ║
╠════════════════════════════════════════════════════════════╣
║            Presione ESC para cancelar                      ║
╚════════════════════════════════════════════════════════════╝
```

### 2. 🔍 Buscador con Filtrado (F4)

**Cómo usar:**
- Presiona **F4** para activar el modo búsqueda
- Escribe el patrón de búsqueda (soporta expresiones regulares)
- Usa **flechas ↑↓** para navegar entre resultados
- Presiona **Enter** para aplicar el filtro y seguir navegando
- Presiona **ESC** para salir del modo búsqueda

**Características:**
- ✅ Filtrado en tiempo real mientras escribes
- ✅ Soporte completo para expresiones regulares
- ✅ Muestra contador de resultados encontrados
- ✅ Navegación con flechas en modo búsqueda
- ✅ Backspace para borrar caracteres

**Ejemplos de búsqueda:**

```regex
# Búsqueda simple
test          → encuentra archivos que contengan "test"

# Por extensión
\.ps1$        → encuentra todos los archivos .ps1
\.txt$        → encuentra todos los archivos .txt

# Por prefijo
^Demo         → encuentra archivos que empiecen con "Demo"
^Test         → encuentra archivos que empiecen con "Test"

# Combinaciones
^Test.*\.ps1$ → archivos .ps1 que empiecen con "Test"

# Case insensitive (por defecto en PowerShell)
module        → encuentra "Module", "MODULE", "module", etc.
```

**Ejemplo visual en modo búsqueda:**
```
╔════════════════════════════════════════════════════════════╗
║           DEMO: Navegador Mejorado                         ║
╠════════════════════════════════════════════════════════════╣
║  🔍 BÚSQUEDA: \.ps1$                                       ║
╠════════════════════════════════════════════════════════════╣
║  📄 Demo-Banner.ps1                          3.33 KB      ║
║  📄 Demo-MenusYPopups.ps1                    4.28 KB      ║
║  📄 Llevar.ps1                              12.45 KB      ║
║  📄 Test-Actualizaciones.ps1                 2.11 KB      ║
╠════════════════════════════════════════════════════════════╣
║   Escriba para buscar │ ESC:Salir búsqueda │ Enter:Aplicar║
╚════════════════════════════════════════════════════════════╝

 Seleccionado: Archivo - Demo-Banner.ps1 │ Total: 4 items
```

## 🎮 Controles del Navegador

### Navegación Normal
| Tecla | Acción |
|-------|--------|
| `↑` / `↓` | Navegar arriba/abajo |
| `Enter` | Entrar a carpeta o volver atrás (..) |
| `←` | Ir a carpeta padre |
| `Backspace` | Ir a carpeta padre (alternativo) |
| `→` | Entrar a carpeta seleccionada |
| `ESPACIO` | **Calcular tamaño de carpeta** |
| `F2` | Selector de unidades |
| `F3` | Descubrir recursos de red |
| `F4` | **Activar buscador** |
| `F10` | Seleccionar item actual |
| `ESC` | Salir del navegador |

### Modo Búsqueda (F4)
| Tecla | Acción |
|-------|--------|
| `a-z, 0-9, . * + ? [ ] ( ) { } | \ ^ $ - _` | Escribir patrón |
| `Backspace` | Borrar último carácter |
| `↑` / `↓` | Navegar entre resultados |
| `Enter` | Aplicar filtro y salir de modo búsqueda |
| `ESC` | Cancelar búsqueda |

### Cálculo de Tamaño (ESPACIO)
| Tecla | Acción |
|-------|--------|
| `ESC` | Cancelar cálculo en progreso |

## 💡 Consejos de Uso

1. **Caché de tamaños**: Los tamaños calculados se guardan durante la sesión actual. Si calculas el tamaño de una carpeta, no necesitas hacerlo nuevamente hasta que cierres el navegador.

2. **Regex complejas**: Puedes usar expresiones regulares muy complejas:
   - `(Test|Demo).*\.ps1$` → archivos .ps1 que empiecen con Test o Demo
   - `^[A-Z].*\.txt$` → archivos .txt que empiecen con mayúscula

3. **Cálculo en carpetas grandes**: El cálculo puede tardar en carpetas muy grandes. Usa ESC si tarda demasiado.

4. **Formato de tamaño**: El navegador siempre usa el formato más apropiado para el tamaño:
   - 500 B (bytes)
   - 1.23 KB
   - 45.67 MB
   - 2.34 GB
   - 1.50 TB

## 🔧 Implementación Técnica

### Variables Globales
```powershell
$script:DirectorySizeCache = @{}  # Caché de tamaños calculados
```

### Funciones Agregadas
```powershell
Format-FileSize              # Formatea tamaños en B, KB, MB, GB, TB
Get-DirectorySize            # Calcula tamaño recursivo cancelable
Show-CalculatingSpinner      # Muestra diálogo con spinner animado
Update-Spinner               # Actualiza spinner con progreso actual
```

### Mejoras en Select-PathNavigator
- Modo búsqueda con variable `$searchMode`
- Filtrado con regex en tiempo real
- Cálculo asíncrono con Jobs de PowerShell
- Caché persistente durante la sesión

## 📊 Rendimiento

- **Búsqueda**: Instantánea, se ejecuta en el cliente
- **Cálculo de tamaño**: Depende del tamaño de la carpeta
  - Carpetas pequeñas (< 1000 archivos): < 1 segundo
  - Carpetas medianas (1000-10000 archivos): 1-5 segundos
  - Carpetas grandes (> 10000 archivos): 5+ segundos
- **Spinner**: Se actualiza cada 100ms para fluidez visual

## 🐛 Manejo de Errores

- Errores de acceso a archivos se ignoran silenciosamente
- Regex inválidas muestran todos los items
- Cancelación limpia con ESC sin dejar procesos huérfanos
- Jobs se limpian automáticamente al terminar

## 📝 Ejemplo de Uso Completo

```powershell
# Importar módulo
Import-Module ".\Modules\UI\Navigator.psm1" -Force

# Usar navegador
$carpeta = Select-PathNavigator -Prompt "Seleccione carpeta" -AllowFiles $false

# Resultado
if ($carpeta) {
    Write-Host "Seleccionaste: $carpeta"
}
```

## 🎨 Aspecto Visual

El navegador mantiene el estilo Norton Commander con:
- Bordes box-drawing UTF-8 (╔═╗║╚╝)
- Colores consistentes (Cyan para bordes, amarillo para path, verde para instrucciones)
- Iconos emoji para visual appeal (📁 📄 💾 🔍 ⠋)
- Spinner con caracteres Braille para animación fluida
- Alineación perfecta de bordes derechos

---

**Autor**: Sistema LLevar.ps1  
**Versión**: 2.0 - Navegador Mejorado  
**Fecha**: 4 de diciembre de 2025
