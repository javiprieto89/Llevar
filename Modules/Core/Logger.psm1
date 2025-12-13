# Q:\Utilidad\LLevar\Modules\Core\Logger.psm1
# Módulo de gestión de logs para Llevar.ps1
# Proporciona funciones para escribir logs con diferentes niveles (INFO, WARNING, ERROR, DEBUG)
# y manejo de errores con detalles completos incluyendo stack traces

# ========================================================================== #
#                          VARIABLES GLOBALES                                #
# ========================================================================== #

$Global:ScriptDir = Split-Path -Parent $PSCommandPath | Split-Path -Parent | Split-Path -Parent
$Global:LogsDir = Join-Path $Global:ScriptDir "Logs"
$Global:LogFile = $null
$Global:VerboseLogging = $false

# ========================================================================== #
#                          FUNCIONES DE LOGGING                              #
# ========================================================================== #

function Initialize-LogFile {
    <#
    .SYNOPSIS
        Inicializa el archivo de log con timestamp
    .DESCRIPTION
        Crea la carpeta de logs si no existe y establece el archivo de log actual
    .PARAMETER Verbose
        Activa el modo verbose para logging detallado
    #>
    param(
        [switch]$Verbose
    )
    
    # Crear carpeta de logs si no existe
    if (-not (Test-Path $Global:LogsDir)) {
        New-Item -Path $Global:LogsDir -ItemType Directory -Force | Out-Null
    }
    
    # Nombre del log con fecha, hora y minuto
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $Global:LogFile = Join-Path $Global:LogsDir "LLEVAR_$timestamp.log"
    
    # Variable global para modo verbose
    $Global:VerboseLogging = $Verbose
    
    # Log inicial
    Write-Log "========================================" "INFO"
    Write-Log "Iniciando LLEVAR.PS1" "INFO"
    Write-Log "Usuario: $env:USERNAME" "INFO"
    Write-Log "Computadora: $env:COMPUTERNAME" "INFO"
    Write-Log "Modo Verbose: $Verbose" "INFO"
    Write-Log "========================================" "INFO"
    
    # En modo verbose, interceptar Write-Host para registrar en log
    if ($Verbose) {
        # Crear función wrapper para Write-Host
        $Global:OriginalWriteHost = Get-Command Write-Host -CommandType Cmdlet
        
        function Global:Write-Host {
            [CmdletBinding()]
            param(
                [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromRemainingArguments = $true)]
                $Object,
                [switch]$NoNewline,
                $Separator = ' ',
                $ForegroundColor,
                $BackgroundColor
            )
            
            # Capturar el mensaje
            $message = if ($Object -is [array]) {
                $Object -join $Separator
            }
            else {
                $Object
            }
            
            # Registrar en log (si hay mensaje)
            if ($message) {
                $colorInfo = if ($ForegroundColor) { " [$ForegroundColor]" } else { "" }
                Write-Log "[CONSOLE]$colorInfo $message" "DEBUG"
            }
            
            # Llamar al Write-Host original
            $params = @{}
            if ($PSBoundParameters.ContainsKey('Object')) { $params['Object'] = $Object }
            if ($PSBoundParameters.ContainsKey('NoNewline')) { $params['NoNewline'] = $NoNewline }
            if ($PSBoundParameters.ContainsKey('Separator')) { $params['Separator'] = $Separator }
            if ($PSBoundParameters.ContainsKey('ForegroundColor')) { $params['ForegroundColor'] = $ForegroundColor }
            if ($PSBoundParameters.ContainsKey('BackgroundColor')) { $params['BackgroundColor'] = $BackgroundColor }
            
            & $Global:OriginalWriteHost @params
        }
        
        Write-Log "Interceptor de Write-Host activado para logging completo" "INFO"
    }
}

function Write-Log {
    <#
    .SYNOPSIS
        Escribe una entrada en el archivo de log
    .DESCRIPTION
        Registra mensajes con diferentes niveles de severidad y detalles completos de errores
    .PARAMETER Message
        Mensaje a registrar
    .PARAMETER Level
        Nivel de severidad: INFO, WARNING, ERROR, DEBUG
    .PARAMETER ErrorRecord
        Objeto ErrorRecord para registrar detalles completos del error
    #>
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [System.Management.Automation.ErrorRecord]$ErrorRecord = $null
    )
    
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Obtener información de línea si estamos en modo verbose
    $lineInfo = ""
    if ($Global:VerboseLogging) {
        $callStack = Get-PSCallStack
        if ($callStack.Count -gt 1) {
            $caller = $callStack[1]
            $lineInfo = " [Line: $($caller.ScriptLineNumber), Function: $($caller.FunctionName)]"
        }
    }
    
    $logEntry = "[$time] [$Level]$lineInfo $Message"
    
    # Si hay un ErrorRecord, agregar detalles del error
    if ($ErrorRecord) {
        $logEntry += "`n    Exception: $($ErrorRecord.Exception.Message)"
        $logEntry += "`n    Category: $($ErrorRecord.CategoryInfo.Category)"
        $logEntry += "`n    TargetObject: $($ErrorRecord.TargetObject)"
        if ($ErrorRecord.InvocationInfo) {
            $logEntry += "`n    At: $($ErrorRecord.InvocationInfo.ScriptName):$($ErrorRecord.InvocationInfo.ScriptLineNumber)"
        }
        
        # En modo verbose, agregar stack trace completo
        if ($Global:VerboseLogging -and $ErrorRecord.ScriptStackTrace) {
            $logEntry += "`n    StackTrace:"
            $logEntry += "`n" + $ErrorRecord.ScriptStackTrace
        }
    }
    
    # Escribir al archivo de log
    try {
        if ($Global:LogFile) {
            Add-Content -Path $Global:LogFile -Value $logEntry -Encoding UTF8
        }
        else {
            # Si no hay LogFile global definido, usar TEMP
            $tempLog = Join-Path $env:TEMP "LLEVAR_ERROR.log"
            Add-Content -Path $tempLog -Value $logEntry -Encoding UTF8
        }
    }
    catch {
        # Si falla el log, intentar escribir en TEMP
        $tempLog = Join-Path $env:TEMP "LLEVAR_ERROR.log"
        Add-Content -Path $tempLog -Value $logEntry -Encoding UTF8
    }
    
    # En modo verbose, mostrar logs INFO, WARNING y ERROR en consola
    # pero NO los DEBUG (que son los Write-Host interceptados) para evitar duplicados
    if ($Global:VerboseLogging -and $Level -ne "DEBUG") {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            default { "DarkGray" }
        }
        # Usar el Write-Host original si existe para evitar recursión
        if ($Global:OriginalWriteHost) {
            & $Global:OriginalWriteHost "[LOG] $logEntry" -ForegroundColor $color
        }
        else {
            Microsoft.PowerShell.Utility\Write-Host "[LOG] $logEntry" -ForegroundColor $color
        }
    }
}

function Write-ErrorLog {
    <#
    .SYNOPSIS
        Escribe un error en el log
    .DESCRIPTION
        Wrapper de Write-Log específico para errores
    .PARAMETER Message
        Mensaje del error
    .PARAMETER ErrorRecord
        Objeto ErrorRecord con detalles del error
    #>
    param(
        $Message,
        $ErrorRecord
    )
    
    Write-Log -Message $Message -Level "ERROR" -ErrorRecord $ErrorRecord
}

# ========================================================================== #
#                          EXPORTAR FUNCIONES                                #
# ========================================================================== #

Export-ModuleMember -Function @(
    'Initialize-LogFile',
    'Write-Log',
    'Write-ErrorLog'
) -Variable @(
    'LogFile',
    'LogsDir',
    'VerboseLogging',
    'ScriptDir'
)
