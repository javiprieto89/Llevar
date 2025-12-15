<#
.SYNOPSIS
    Módulo común para importar todas las dependencias necesarias en los tests.

.DESCRIPTION
    Este archivo centraliza todos los imports necesarios para que los tests
    funcionen correctamente con la arquitectura modularizada de Llevar.ps1.
#>

# Ruta al directorio raíz del proyecto
$ProjectRoot = $PSScriptRoot
$ModulesPath = Join-Path $ProjectRoot "Modules"

# ========================================================================== #
#                        IMPORTAR TODOS LOS MÓDULOS                          #
# ========================================================================== #

# Módulos Core
Import-Module (Join-Path $ModulesPath "Core\TransferConfig.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Core\Validation.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Core\Logger.psm1") -Force -Global -ErrorAction SilentlyContinue

# Módulos UI
Import-Module (Join-Path $ModulesPath "UI\Console.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "UI\Banners.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "UI\ProgressBar.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "UI\Navigator.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "UI\Menus.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "UI\ConfigMenus.psm1") -Force -Global -ErrorAction SilentlyContinue

# Módulos de Compresión
Import-Module (Join-Path $ModulesPath "Compression\SevenZip.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Compression\NativeZip.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Compression\BlockSplitter.psm1") -Force -Global -ErrorAction SilentlyContinue

# Módulos de Transferencia
Import-Module (Join-Path $ModulesPath "Transfer\Local.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Transfer\FTP.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Transfer\UNC.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Transfer\OneDrive.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Transfer\Dropbox.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Transfer\Floppy.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Transfer\Unified.psm1") -Force -Global -ErrorAction SilentlyContinue

# Módulos de Instalación
Import-Module (Join-Path $ModulesPath "Installation\Uninstall.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Installation\Installer.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Installation\Installation.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Installation\Install.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Installation\InstallationCheck.psm1") -Force -Global -ErrorAction SilentlyContinue

# Módulos de Utilidades
Import-Module (Join-Path $ModulesPath "Utilities\Examples.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Utilities\Help.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Utilities\PathSelectors.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Utilities\VolumeManagement.psm1") -Force -Global -ErrorAction SilentlyContinue

# Módulos del Sistema
Import-Module (Join-Path $ModulesPath "System\PowerShell7Installer.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "System\Audio.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "System\FileSystem.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "System\Robocopy.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "System\ISO.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "System\Browser.psm1") -Force -Global -ErrorAction SilentlyContinue

# Módulos de Parámetros
Import-Module (Join-Path $ModulesPath "Parameters\Help.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Parameters\Example.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Parameters\Robocopy.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Parameters\InteractiveMenu.psm1") -Force -Global -ErrorAction SilentlyContinue
Import-Module (Join-Path $ModulesPath "Parameters\NormalMode.psm1") -Force -Global -ErrorAction SilentlyContinue

Write-Host "✓ Módulos de Llevar cargados para tests" -ForegroundColor Green
