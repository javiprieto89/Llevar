# ========================================================================== #
#                      MÓDULO: ONEDRIVE (WRAPPER)                            #
# ========================================================================== #
# Propósito: Punto de entrada único para funcionalidad OneDrive             #
# Importa submódulos que exportan automáticamente sus funciones              #
# Estructura modular:                                                        #
#   - OneDrive\OneDriveAuth.psm1: Autenticación OAuth                        #
#   - OneDrive\OneDriveTransfer.psm1: Transferencia y helpers Navigator     #
# ========================================================================== #

# Importar submódulos (las funciones se exportan automáticamente)
$oneDriveModulesPath = Join-Path $PSScriptRoot "OneDrive"
Import-Module (Join-Path $oneDriveModulesPath "OneDriveAuth.psm1") -Force -Global
Import-Module (Join-Path $oneDriveModulesPath "OneDriveTransfer.psm1") -Force -Global

