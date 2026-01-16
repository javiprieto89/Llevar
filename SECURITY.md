# 🔒 Política de Seguridad

## 🛡️ Versiones Soportadas

Actualmente se proporciona soporte de seguridad para las siguientes versiones:

| Versión | Soportada          |
| ------- | ------------------ |
| master  | :white_check_mark: |
| < 1.0   | :x:                |

## 🐛 Reportar una Vulnerabilidad

Si descubres una vulnerabilidad de seguridad en **Llevar**, por favor repórtala de forma responsable.

### 📧 Cómo Reportar

**NO** crees un Issue público para vulnerabilidades de seguridad.

En su lugar:

1. **Envía un email** con los detalles a través de GitHub Security Advisories
2. **O crea un Issue privado** usando la opción "Report a security vulnerability" en la pestaña Security

### 📋 Información a Incluir

Para ayudarnos a resolver el problema rápidamente, incluye:

- **Tipo de vulnerabilidad** (ej: ejecución de código, inyección, escalada de privilegios)
- **Ubicación del código afectado** (archivo y línea)
- **Pasos para reproducir** el problema
- **Impacto potencial** de la vulnerabilidad
- **Posibles soluciones** (si las tienes)
- **Versión afectada** de PowerShell y Windows

### ⏱️ Tiempo de Respuesta

- **Confirmación inicial**: Dentro de 48 horas
- **Evaluación completa**: Dentro de 7 días
- **Corrección y publicación**: Depende de la severidad
  - **Crítico**: 1-2 semanas
  - **Alto**: 2-4 semanas
  - **Medio/Bajo**: 1-2 meses

### 🎯 Alcance de Seguridad

#### ✅ En el Alcance

- Ejecución de código arbitrario
- Escalada de privilegios
- Inyección de comandos
- Bypass de validaciones
- Exposición de credenciales
- Path traversal
- Manipulación de archivos fuera del scope

#### ❌ Fuera del Alcance

- Vulnerabilidades en dependencias de terceros (reportar a los mantenedores originales)
- Vulnerabilidades en PowerShell 7 (reportar a Microsoft)
- Vulnerabilidades en Windows (reportar a Microsoft)
- Problemas de usabilidad que no involucran seguridad
- Bugs sin implicaciones de seguridad

## 🔐 Mejores Prácticas de Seguridad

Al usar **Llevar**, recomendamos:

### Para Usuarios

- ✅ **Ejecutar como administrador** solo cuando sea necesario (instalación/desinstalación)
- ✅ **Verificar rutas** antes de operaciones destructivas
- ✅ **Revisar logs** en `C:\Llevar\Logs\` para detectar anomalías
- ✅ **Mantener PowerShell 7 actualizado**
- ✅ **No ejecutar scripts** de fuentes no confiables
- ❌ **No compartir credenciales** de FTP/OneDrive/Dropbox en logs

### Para Desarrolladores

- ✅ Usar funciones de validación de `Core/Validation.psm1`
- ✅ Sanitizar inputs de usuario
- ✅ Evitar `Invoke-Expression` con datos no confiables
- ✅ Validar rutas antes de operaciones de archivo
- ✅ No hardcodear credenciales
- ✅ Usar `-WhatIf` en funciones destructivas durante desarrollo

## 🔄 Proceso de Divulgación

1. **Recepción**: Recibimos tu reporte
2. **Confirmación**: Confirmamos recepción en 48h
3. **Evaluación**: Evaluamos severidad e impacto
4. **Desarrollo**: Trabajamos en una corrección
5. **Testing**: Probamos la solución
6. **Release**: Publicamos versión corregida
7. **Divulgación**: Publicamos advisory con crédito al descubridor

## 🏆 Reconocimientos

Agradecemos a los siguientes investigadores de seguridad por reportar vulnerabilidades de forma responsable:

*(Ninguno hasta la fecha)*

## 📚 Recursos de Seguridad

- [PowerShell Security Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/learn/security-best-practices)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE - Common Weakness Enumeration](https://cwe.mitre.org/)

## 📞 Contacto

Para cuestiones de seguridad urgentes, usa el sistema de Security Advisories de GitHub en:

`https://github.com/javiprieto89/Llevar/security/advisories`

---

**Gracias por ayudar a mantener Llevar seguro para todos.** 🙏
