# ========================================================================== #
#                   MÓDULO: FUNCIONES DE AUDIO                               #
# ========================================================================== #
# Propósito: Reproducción de sonidos y efectos de audio estilo DOS
# Funciones:
#   - Invoke-DOSBeep: Reproduce beeps estilo PC Speaker
# ========================================================================== #

function Invoke-DOSBeep {
    <#
    .SYNOPSIS
        Reproduce sonidos estilo PC Speaker / DOS MIDI
    .DESCRIPTION
        Genera beeps con frecuencias variables siguiendo un patrón
        de notas musicales estilo PC Speaker de DOS. Usado para feedback
        auditivo durante operaciones largas.
    .PARAMETER LineIndex
        �ndice de línea actual (para ciclo de frecuencias)
    .PARAMETER TotalLines
        Total de líneas a procesar (no usado actualmente)
    .EXAMPLE
        Invoke-DOSBeep -LineIndex 5 -TotalLines 100
    #>
    param(
        [int]$LineIndex = 0,
        [int]$TotalLines = 100
    )
    
    try {
        # Patrón de frecuencias estilo DOS MIDI (notas musicales típicas de PC Speaker)
        # Usamos un patrón cíclico de 8 notas que se repite
        $frequencies = @(523, 587, 659, 698, 784, 880, 988, 1047)  # Do-Do (octava)
        $freq = $frequencies[$LineIndex % $frequencies.Count]
        
        # Duración muy corta para no ser molesto (50ms)
        $duration = 50
        
        # Cada 3 líneas hacemos un beep más largo y grave para ritmo
        if ($LineIndex % 3 -eq 0) {
            [Console]::Beep(440, 80)  # La grave, más largo
        }
        else {
            [Console]::Beep($freq, $duration)
        }
    }
    catch {
        # Si falla el beep (por ejemplo en entornos sin soporte de sonido), lo ignoramos
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Invoke-DOSBeep'
)
