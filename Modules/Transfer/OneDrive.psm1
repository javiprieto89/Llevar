# ========================================================================== #
#                      MÓDULO: ONEDRIVE (WRAPPER)                            #
# ========================================================================== #
# Propósito: Importa y re-exporta submódulos de OneDrive                    #
# Estructura modular:                                                        #
#   - OneDrive\OneDriveAuth.psm1: Autenticación OAuth                        #
#   - OneDrive\OneDriveTransfer.psm1: Transferencia y helpers Navigator     #
# ========================================================================== #

# Importar submódulos
$oneDriveModulesPath = Join-Path $PSScriptRoot "OneDrive"
Import-Module (Join-Path $oneDriveModulesPath "OneDriveAuth.psm1") -Force -Global
Import-Module (Join-Path $oneDriveModulesPath "OneDriveTransfer.psm1") -Force -Global

# ========================================================================== #
# RE-EXPORTAR FUNCIONES DE SUBMÓDULOS
# ========================================================================== #

Export-ModuleMember -Function @(
    # OneDriveAuth.psm1
    'Update-OneDriveToken',
    'Test-OneDriveToken',
    'Get-OneDriveAuth',
    'Test-MicrosoftGraphModule',
    'Get-OneDriveConfigFromUser',
    
    # OneDriveTransfer.psm1
    'Test-IsOneDrivePath',
    'Invoke-OneDriveApiCall',
    'Get-OneDriveFiles',
    'Send-OneDriveFile',
    'Receive-OneDriveFile',
    'Test-OneDriveConnection',
    'Send-LlevarOneDriveFile',
    'New-OneDriveFolder',
    'Resolve-OneDrivePath',
    'Get-OneDriveParentPath',
    'Convert-GraphItemToNavigatorEntry',
    'Get-OneDriveNavigatorItems',
    'Get-OneDriveFolderSize',
    'Select-OneDrivePath',
    'Select-OneDriveFolder',
    'Copy-LlevarLocalToOneDrive',
    'Copy-LlevarOneDriveToLocal'
)
