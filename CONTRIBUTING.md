# 🤝 Contribuir a Llevar

¡Gracias por tu interés en contribuir a **Llevar**! Este documento te guiará sobre cómo participar en el proyecto.

## 📋 Tabla de Contenidos

- [Código de Conducta](#código-de-conducta)
- [¿Cómo puedo contribuir?](#cómo-puedo-contribuir)
- [Reportar Bugs](#reportar-bugs)
- [Sugerir Mejoras](#sugerir-mejoras)
- [Enviar Pull Requests](#enviar-pull-requests)
- [Guías de Estilo](#guías-de-estilo)
- [Configuración del Entorno](#configuración-del-entorno)

---

## 📜 Código de Conducta

Este proyecto se adhiere al [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). Al participar, se espera que respetes este código.

---

## 🤔 ¿Cómo puedo contribuir?

Hay muchas formas de contribuir a Llevar:

- 🐛 **Reportar bugs** - Encuentra y reporta problemas
- 💡 **Sugerir mejoras** - Propón nuevas funcionalidades
- 📝 **Mejorar documentación** - Clarifica o expande la documentación
- 🔧 **Corregir bugs** - Envía Pull Requests con correcciones
- ✨ **Agregar funcionalidades** - Implementa nuevas características
- 🧪 **Escribir tests** - Mejora la cobertura de tests

---

## 🐛 Reportar Bugs

### Antes de reportar un bug

1. **Verifica** que estés usando PowerShell 7+ en Windows 10+
2. **Busca** en [Issues](https://github.com/javiprieto89/Llevar/issues) para ver si ya fue reportado
3. **Revisa** los logs en `C:\Llevar\Logs\` para detalles del error
4. **Reproduce** el bug para confirmar que es consistente

### Cómo reportar un bug

Crea un nuevo [Issue](https://github.com/javiprieto89/Llevar/issues/new) incluyendo:

- **Título descriptivo** - Resumen claro del problema
- **Pasos para reproducir** - Lista numerada de acciones
- **Comportamiento esperado** - Qué debería pasar
- **Comportamiento actual** - Qué está pasando
- **Logs** - Contenido relevante de archivos .log
- **Entorno**:
  - Versión de PowerShell: `$PSVersionTable.PSVersion`
  - Versión de Windows: `[System.Environment]::OSVersion.Version`
  - Versión de Llevar: Ver línea 1 de `Llevar.ps1`
- **Capturas de pantalla** - Si aplica

---

## 💡 Sugerir Mejoras

¿Tienes una idea para mejorar Llevar? Abre un [Issue](https://github.com/javiprieto89/Llevar/issues/new) con:

- **Título claro** - Resumen de la mejora propuesta
- **Problema actual** - Qué limitación o problema resuelve
- **Solución propuesta** - Cómo funcionaría tu idea
- **Alternativas consideradas** - Otras opciones evaluadas
- **Casos de uso** - Ejemplos reales de uso

---

## 🔄 Enviar Pull Requests

### Proceso de contribución

1. **Fork** el repositorio
2. **Clona** tu fork localmente:
   ```powershell
   git clone https://github.com/TU_USUARIO/Llevar.git
   cd Llevar
   ```

3. **Crea un branch** desde `master`:
   ```powershell
   git checkout -b feature/mi-nueva-funcionalidad
   # o
   git checkout -b fix/correccion-de-bug
   ```

4. **Realiza tus cambios** siguiendo las [Guías de Estilo](#guías-de-estilo)

5. **Prueba tus cambios**:
   ```powershell
   # Ejecutar tests relevantes
   .\Tests\Test-LocalToLocal.ps1
   .\Tests\Run-AllTests.ps1
   ```

6. **Commit** con mensaje descriptivo:
   ```powershell
   git commit -m "feat: agregar soporte para Mega.nz"
   # o
   git commit -m "fix: corregir cálculo de bloques en archivos >4GB"
   ```

7. **Push** a tu fork:
   ```powershell
   git push origin feature/mi-nueva-funcionalidad
   ```

8. **Crea un Pull Request** desde GitHub

### Convenciones de commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` Nueva funcionalidad
- `fix:` Corrección de bug
- `docs:` Cambios en documentación
- `style:` Formato de código (sin cambios funcionales)
- `refactor:` Refactorización de código
- `test:` Agregar o modificar tests
- `chore:` Tareas de mantenimiento

**Ejemplos:**
```
feat: agregar transferencia a Google Drive
fix: corregir detección de rutas UNC
docs: actualizar README con ejemplos de OneDrive
refactor: centralizar validaciones en Core/Validation.psm1
test: agregar tests para FTP a FTP
```

---

## 🎨 Guías de Estilo

### PowerShell

#### Nombres de Funciones
- **Verbos aprobados**: `Get-`, `Set-`, `New-`, `Test-`, `Invoke-`, `Copy-`, `Send-`, `Show-`
- **PascalCase**: `Get-TransferPath`, `Test-IsFtpPath`
- **Prefijo Llevar**: Para funcionalidad específica: `Copy-LlevarLocalToFtp`

#### Estructura de Funciones
```powershell
function Get-MiFuncion {
    <#
    .SYNOPSIS
        Descripción breve
    .DESCRIPTION
        Descripción detallada
    .PARAMETER Nombre
        Descripción del parámetro
    .EXAMPLE
        Get-MiFuncion -Nombre "Valor"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Nombre
    )
    
    # Implementación
}
```

#### Convenciones
- ✅ Usar `PascalCase` para funciones y parámetros
- ✅ Usar `$camelCase` para variables locales
- ✅ Incluir help comments completos
- ✅ Exportar funciones públicas: `Export-ModuleMember -Function @('Func1', 'Func2')`
- ❌ NO duplicar código (excepto en `Installation/Installer.psm1`)
- ❌ NO duplicar validaciones - usar `Core/Validation.psm1`

#### Captura de Valores Booleanos
```powershell
# ❌ MAL - puede imprimir True/False en consola
if (-not (Test-SomeCondition)) { }

# ✅ BIEN - capturar primero
$result = Test-SomeCondition
if (-not $result) { }
```

### Organización de Módulos

```
Modules/
├── Core/           # Funcionalidad central (Config, Validation, Logger)
├── Transfer/       # Módulos de transferencia (FTP, OneDrive, etc.)
├── UI/             # Interfaz de usuario (Menus, Banners, etc.)
├── System/         # Funciones del sistema (Audio, ISO, etc.)
├── Compression/    # Compresión y división de bloques
├── Installation/   # Instalación y desinstalación
└── Utilities/      # Utilidades varias
```

### Documentación

- ✅ Mantener actualizado `AGENTS.md` con cambios de arquitectura
- ✅ Documentar funciones complejas en `Docs/`
- ✅ Actualizar README si agregas funcionalidad importante
- ✅ Incluir ejemplos de uso en módulos

---

## 🔧 Configuración del Entorno

### Requisitos

- **PowerShell 7.0+**: `winget install Microsoft.PowerShell`
- **Windows 10+**
- **Git**: `winget install Git.Git`
- **VS Code** (recomendado): `winget install Microsoft.VisualStudioCode`

### Extensiones de VS Code recomendadas

- PowerShell
- GitLens
- EditorConfig

### Configuración Inicial

1. **Clonar el repositorio**:
   ```powershell
   git clone https://github.com/javiprieto89/Llevar.git
   cd Llevar
   ```

2. **Instalar Llevar** (para testing):
   ```powershell
   # Ejecutar como Administrador
   .\INSTALAR.CMD
   ```

3. **Abrir en VS Code**:
   ```powershell
   code .
   ```

4. **Importar módulos** (para desarrollo):
   ```powershell
   .\Import-LlevarModules.ps1
   ```

### Estructura de Testing

- **Tests individuales**: `.\Tests\Test-*.ps1`
- **Suite completa**: `.\Tests\Run-AllTests.ps1`
- **Tests de integración**: `.\Tests\Test-Integration.ps1`

### Sincronizar Q: → C:

Si desarrollas en `Q:\Utilidad\Llevar`:

```powershell
.\Actualiza.cmd
```

---

## 📚 Recursos

- **Documentación del Proyecto**: [Docs/](Docs/)
- **Guía para Agentes IA**: [AGENTS.md](AGENTS.md)
- **Arquitectura del Sistema**: [Docs/TRANSFERCONFIG.md](Docs/TRANSFERCONFIG.md)
- **Testing**: [Docs/TESTING.md](Docs/TESTING.md)

---

## 🎓 Preguntas Frecuentes

### ¿Puedo agregar soporte para otro servicio cloud?

¡Sí! Crea un nuevo módulo en `Modules/Transfer/` siguiendo el patrón de `OneDrive.psm1` o `Dropbox.psm1`.

### ¿Cómo pruebo cambios sin afectar mi instalación?

Desarrolla en `Q:\Utilidad\Llevar` y usa `Actualiza.cmd` solo cuando quieras sincronizar a `C:\Llevar`.

### ¿Debo actualizar AGENTS.md?

Sí, si tus cambios:
- Agregan/eliminan módulos
- Cambian la arquitectura
- Introducen nuevas convenciones
- Crean excepciones a reglas existentes

---

## 📞 Contacto

- **Issues**: [GitHub Issues](https://github.com/javiprieto89/Llevar/issues)
- **Pull Requests**: [GitHub PRs](https://github.com/javiprieto89/Llevar/pulls)

---

¡Gracias por contribuir a **Llevar**! 🚀

**Homenaje al trabajo original de Alejandro Nacir (Alex Soft)**
