# ========================================================================== #
#                         AUDIO ENGINE 8-BIT                                 #
# ========================================================================== #


function Start-DOSBeepAsync {
    param(
        [string]$Style = 'GameBoy'
    )

    # Crear un runspace separado
    $ps = [PowerShell]::Create()
    $ps.AddScript({
            param($style)

            # Llamamos a tu función real dentro del runspace
            Invoke-DOSBeep -Style $style

        }) | Out-Null

    $ps.AddArgument($Style)

    # Comienza en segundo plano sin bloquear
    $null = $ps.BeginInvoke()
}

function Invoke-DOSBeep {
    param(
        [ValidateSet(
            'Retro', 'Synth', 'Ascendente', 'Relajado',
            'GameBoy', 'SuperMario', 'Spaceship', 'Boss', 'Victory'
        )]
        [string]$Style = 'Retro'
    )

    # === Tabla de notas (PC Speaker style) ===
    $Notes = @{
        'C4' = 262; 'Cs4' = 277; 'D4' = 294; 'Ds4' = 311; 'E4' = 330; 'F4' = 349; 'Fs4' = 370
        'G4' = 392; 'Gs4' = 415; 'A4' = 440; 'As4' = 466; 'B4' = 494

        'C5' = 523; 'Cs5' = 554; 'D5' = 587; 'Ds5' = 622; 'E5' = 659; 'F5' = 698; 'Fs5' = 740
        'G5' = 784; 'Gs5' = 831; 'A5' = 880; 'As5' = 932; 'B5' = 988

        'C6' = 1047; 'D6' = 1175; 'E6' = 1319; 'G6' = 1567
    }

    # === Definir melodías por estilo ===
    switch ($Style) {

        'Retro' {
            $Melody = @(
                @{N = 'C5'; D = 120 }; @{N = 'D5'; D = 120 }; @{N = 'G5'; D = 150 }; @{N = 'E5'; D = 200 }
            )
        }

        'Synth' {
            $Melody = @(
                @{N = 'C4'; D = 100 }; @{N = 'G4'; D = 100 }; @{N = 'C5'; D = 150 }; @{N = 'E5'; D = 180 }
            )
        }

        'Ascendente' {
            $Melody = @(
                @{N = 'C4'; D = 80 }; @{N = 'D4'; D = 80 }; @{N = 'E4'; D = 80 }; @{N = 'F4'; D = 100 };
                @{N = 'G4'; D = 120 }; @{N = 'A4'; D = 140 }; @{N = 'B4'; D = 160 }; @{N = 'C5'; D = 200 }
            )
        }

        'Relajado' {
            $Melody = @(
                @{N = 'A4'; D = 180 }; @{N = 'E5'; D = 200 }; @{N = 'D5'; D = 180 }; @{N = 'C5'; D = 250 }
            )
        }

        'GameBoy' {
            # Tu melodía original que suena bien
            $Melody = @(
                @{N = 'C5'; D = 200 }; @{N = 'E5'; D = 200 }; @{N = 'G5'; D = 200 }; @{N = 'C6'; D = 400 };
                @{N = 'G5'; D = 200 }; @{N = 'E5'; D = 200 }; @{N = 'C5'; D = 400 };
                @{N = 'E5'; D = 200 }; @{N = 'G5'; D = 200 }; @{N = 'B5'; D = 200 }; @{N = 'E6'; D = 400 };
                @{N = 'B5'; D = 200 }; @{N = 'G5'; D = 200 }; @{N = 'E5'; D = 400 };
                @{N = 'C5'; D = 150 }; @{N = 'D5'; D = 150 }; @{N = 'E5'; D = 150 };
                @{N = 'G5'; D = 300 }; @{N = 'E5'; D = 300 }; @{N = 'C5'; D = 600 }
            )
        }

        'SuperMario' {
            $Melody = @(
                @{N = 'E5'; D = 120 }; @{N = 'E5'; D = 120 }; @{N = 'E5'; D = 180 };
                @{N = 'C5'; D = 120 }; @{N = 'E5'; D = 180 }; @{N = 'G5'; D = 300 }
            )
        }

        'Spaceship' {
            $Melody = @(
                @{N = 'C6'; D = 40 }; @{N = 'B5'; D = 40 }; @{N = 'A5'; D = 40 };
                @{N = 'G5'; D = 60 }; @{N = 'E5'; D = 80 }; @{N = 'C5'; D = 120 }
            )
        }

        'Boss' {
            $Melody = @(
                @{N = 'A4'; D = 200 }; @{N = 'E4'; D = 150 }; @{N = 'A4'; D = 180 };
                @{N = 'D4'; D = 200 }; @{N = 'C4'; D = 250 }
            )
        }

        'Victory' {
            $Melody = @(
                @{N = 'C5'; D = 150 }; @{N = 'E5'; D = 150 }; @{N = 'G5'; D = 150 };
                @{N = 'C6'; D = 300 }; @{N = 'G5'; D = 200 }; @{N = 'E5'; D = 200 }; @{N = 'C5'; D = 300 }
            )
        }
    }

    # === Reproducir melodía ===
    foreach ($m in $Melody) {
        $name = $m.N
        $dur = [int]$m.D

        if ($Notes.ContainsKey($name)) {
            $freq = $Notes[$name]
            [Console]::Beep($freq, $dur)
        }
        else {
            Start-Sleep -Milliseconds $dur
        }
    }
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Invoke-DOSBeep',
    'Start-DOSBeepAsync'
)
