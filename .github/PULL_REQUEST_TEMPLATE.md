## 📋 Descripción

<!-- Describe claramente qué cambios introduces y por qué -->


## 🔗 Issue Relacionado

<!-- Si resuelve un issue, enlázalo con: Closes #123 -->


## 🎯 Tipo de Cambio

<!-- Marca con [x] lo que aplica -->

- [ ] 🐛 Bug fix (corrección que resuelve un problema)
- [ ] ✨ Nueva funcionalidad (cambio que agrega funcionalidad)
- [ ] 💥 Breaking change (fix o feature que causa que funcionalidad existente no funcione como antes)
- [ ] 📝 Documentación (cambios solo en documentación)
- [ ] 🎨 Estilo (formato, punto y coma faltantes, etc; sin cambios de código)
- [ ] ♻️ Refactor (código que ni corrige bugs ni agrega features)
- [ ] ⚡ Performance (cambios que mejoran el rendimiento)
- [ ] ✅ Tests (agregar tests faltantes o corregir existentes)
- [ ] 🔧 Chore (cambios en build, configuración, etc)

## 🧪 Testing

<!-- Describe las pruebas que realizaste -->

- [ ] He probado mis cambios localmente
- [ ] He ejecutado los tests relevantes: 
  - [ ] `.\Tests\Test-LocalToLocal.ps1`
  - [ ] `.\Tests\Test-FTPToLocal.ps1`
  - [ ] `.\Tests\Run-AllTests.ps1`
  - [ ] Otro: _____________
- [ ] He probado en PowerShell 7+
- [ ] He probado en Windows 10/11

**Escenarios probados:**
<!-- Describe casos específicos que probaste -->
1. 
2. 
3. 

## 📸 Capturas de Pantalla

<!-- Si aplica, agrega capturas de pantalla -->


## ✅ Checklist

- [ ] Mi código sigue las guías de estilo del proyecto (ver [CONTRIBUTING.md](CONTRIBUTING.md))
- [ ] He realizado self-review de mi código
- [ ] He comentado código complejo o difícil de entender
- [ ] He actualizado la documentación correspondiente
- [ ] Mis cambios no generan nuevos warnings
- [ ] He agregado tests que prueban mi fix/feature (si aplica)
- [ ] Tests nuevos y existentes pasan localmente
- [ ] He verificado que NO duplico código (excepto en `Installation/Installer.psm1`)
- [ ] Uso funciones centralizadas de `Core/Validation.psm1` para validaciones
- [ ] He capturado resultados booleanos antes de usarlos en `if` statements
- [ ] Mis funciones tienen help comments completos
- [ ] He exportado las funciones públicas con `Export-ModuleMember`
- [ ] He actualizado `AGENTS.md` si cambié arquitectura/convenciones

## 📝 Convenciones de Commit

<!-- Verifica que tus commits sigan Conventional Commits -->

Ejemplos:
- `feat: agregar soporte para Google Drive`
- `fix: corregir cálculo de bloques en archivos >4GB`
- `docs: actualizar README con ejemplos de OneDrive`
- `refactor: centralizar validaciones en Core/Validation.psm1`
- `test: agregar tests para FTP a FTP`

## 🔄 Impacto

<!-- ¿Qué módulos/funcionalidades se ven afectados? -->

**Módulos modificados:**
- 

**Módulos que dependen de estos cambios:**
- 

**Breaking changes:**
- [ ] No hay breaking changes
- [ ] Sí, descritos arriba en "Descripción"

## 📚 Documentación Actualizada

<!-- Marca los archivos de documentación que actualizaste -->

- [ ] README.md
- [ ] AGENTS.md
- [ ] Docs/ (especifica cuál): _______________
- [ ] Help comments en funciones
- [ ] No requiere actualización de docs

## 💬 Notas Adicionales

<!-- Cualquier información adicional para los revisores -->


---

**Gracias por contribuir a Llevar! 🚀**

<!-- Homenaje al trabajo original de Alejandro Nacir (Alex Soft) -->
