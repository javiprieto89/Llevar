# GameboySound.ps1
# Mini melodía tipo 8-bit / Game Boy usando beeps de consola

# Tabla de notas (frecuencias aproximadas en Hz)
$Notes = @{
    'C4'  = 262
    'Cs4' = 277
    'D4'  = 294
    'Ds4' = 311
    'E4'  = 330
    'F4'  = 349
    'Fs4' = 370
    'G4'  = 392
    'Gs4' = 415
    'A4'  = 440
    'As4' = 466
    'B4'  = 494

    'C5'  = 523
    'Cs5' = 554
    'D5'  = 587
    'Ds5' = 622
    'E5'  = 659
    'F5'  = 698
    'Fs5' = 740
    'G5'  = 784
    'Gs5' = 831
    'A5'  = 880
    'As5' = 932
    'B5'  = 988
}

# Define tempo (cuanto más alto, más lento)
$Tempo = 1.0   # prueba 0.7, 0.9, 1.2, etc.

# Pequeña melodía 8-bit (no es ningún tema famoso, solo “chip tune genérico”)
# N = Nota, D = Duración en ms (antes de aplicar tempo)
$Melody = @(
    @{ N = 'C5'; D = 200 }
    @{ N = 'E5'; D = 200 }
    @{ N = 'G5'; D = 200 }
    @{ N = 'C6'; D = 400 }

    @{ N = 'G5'; D = 200 }
    @{ N = 'E5'; D = 200 }
    @{ N = 'C5'; D = 400 }

    # Segunda parte
    @{ N = 'E5'; D = 200 }
    @{ N = 'G5'; D = 200 }
    @{ N = 'B5'; D = 200 }
    @{ N = 'E6'; D = 400 }

    @{ N = 'B5'; D = 200 }
    @{ N = 'G5'; D = 200 }
    @{ N = 'E5'; D = 400 }

    # Final
    @{ N = 'C5'; D = 150 }
    @{ N = 'D5'; D = 150 }
    @{ N = 'E5'; D = 150 }
    @{ N = 'G5'; D = 300 }
    @{ N = 'E5'; D = 300 }
    @{ N = 'C5'; D = 600 }
)

Write-Host "Reproduciendo mini-melodía estilo Game Boy..." -ForegroundColor Cyan
Write-Host "Presioná Ctrl + C para cortar." -ForegroundColor DarkGray

foreach ($note in $Melody) {
    $name = $note.N
    $baseDuration = [int]$note.D

    if ($name -and $Notes.ContainsKey($name)) {
        $freq = $Notes[$name]
        $duration = [int]($baseDuration * $Tempo)
        [Console]::Beep($freq, $duration)
    }
    else {
        # Silencio (pausa)
        Start-Sleep -Milliseconds $baseDuration
    }
}
