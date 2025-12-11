using module ".\Modules\Core\TransferConfig.psm1"

# Test completo del flujo TransferConfig
Write-Host "`n========== TEST TRANSFERCONFIG ==========" -ForegroundColor Magenta

# 1. Crear instancia
Write-Host "`n1. Creando TransferConfig..." -ForegroundColor Yellow
$tc = New-TransferConfig
Write-Host "   ✓ TransferConfig creado" -ForegroundColor Green

# 2. Configurar Origen FTP
Write-Host "`n2. Configurando Origen FTP..." -ForegroundColor Yellow
Set-TransferConfigOrigen -Config $tc -Tipo "FTP" -Parametros @{
    Server    = "ftp.ejemplo.com"
    Port      = 21
    User      = "usuario"
    Password  = "pass123"
    Directory = "/datos"
}
Write-Host "   ✓ Origen FTP configurado" -ForegroundColor Green

# 3. Configurar Destino ISO
Write-Host "`n3. Configurando Destino ISO..." -ForegroundColor Yellow
Set-TransferConfigDestino -Config $tc -Tipo "ISO" -Parametros @{
    OutputPath = "C:\temp\salida.iso"
    Size       = "dvd"
}
Write-Host "   ✓ Destino ISO configurado" -ForegroundColor Green

# 4. Verificar configuración
Write-Host "`n4. Verificando configuración..." -ForegroundColor Yellow
Write-Host "   Origen Tipo: $($tc.Origen.Tipo)" -ForegroundColor Cyan
Write-Host "   Origen Server: $($tc.Origen.FTP.Server)" -ForegroundColor Cyan
Write-Host "   Origen Port: $($tc.Origen.FTP.Port)" -ForegroundColor Cyan
Write-Host "   Origen User: $($tc.Origen.FTP.User)" -ForegroundColor Cyan
Write-Host "   Origen Directory: $($tc.Origen.FTP.Directory)" -ForegroundColor Cyan
Write-Host "`n   Destino Tipo: $($tc.Destino.Tipo)" -ForegroundColor Cyan
Write-Host "   Destino ISO OutputPath: $($tc.Destino.ISO.OutputPath)" -ForegroundColor Cyan
Write-Host "   Destino ISO Size: $($tc.Destino.ISO.Size)" -ForegroundColor Cyan

# 5. Probar obtención de path usando with
Write-Host "`n5. Probando derivación de path de origen usando with..." -ForegroundColor Yellow
$origenPath = switch ($tc.Origen.Tipo) {
    "FTP" {
        with $tc.Origen.FTP { .Directory }
    }
    "Local" {
        with $tc.Origen.Local { .Path }
    }
    "UNC" {
        with $tc.Origen.UNC { .Path }
    }
    "OneDrive" {
        with $tc.Origen.OneDrive { .Path }
    }
    "Dropbox" {
        with $tc.Origen.Dropbox { .Path }
    }
    default { $null }
}
Write-Host "   Path Origen: $origenPath" -ForegroundColor Green

Write-Host "`n6. Probando derivación de path de destino usando with..." -ForegroundColor Yellow
$destinoPath = switch ($tc.Destino.Tipo) {
    "FTP" {
        with $tc.Destino.FTP { .Directory }
    }
    "Local" {
        with $tc.Destino.Local { .Path }
    }
    "USB" {
        with $tc.Destino.USB { .Path }
    }
    "UNC" {
        with $tc.Destino.UNC { .Path }
    }
    "OneDrive" {
        with $tc.Destino.OneDrive { .Path }
    }
    "Dropbox" {
        with $tc.Destino.Dropbox { .Path }
    }
    "ISO" {
        with $tc.Destino.ISO { .OutputPath }
    }
    "Diskette" {
        with $tc.Destino.Diskette { .OutputPath }
    }
    default { $null }
}
Write-Host "   Path Destino: $destinoPath" -ForegroundColor Green

# 7. Validar completitud usando with
Write-Host "`n7. Validando configuración completa usando with..." -ForegroundColor Yellow
$errors = @()
if (-not $tc.Origen.Tipo) {
    $errors += "• Falta configurar el tipo de origen"
}
else {
    $origenPathCheck = switch ($tc.Origen.Tipo) {
        "FTP" {
            with $tc.Origen.FTP { .Directory }
        }
        "Local" {
            with $tc.Origen.Local { .Path }
        }
        "UNC" {
            with $tc.Origen.UNC { .Path }
        }
        "OneDrive" {
            with $tc.Origen.OneDrive { .Path }
        }
        "Dropbox" {
            with $tc.Origen.Dropbox { .Path }
        }
        default { $null }
    }
    if (-not $origenPathCheck) {
        $errors += "• Falta configurar la ruta de origen ($($tc.Origen.Tipo))"
    }
}

if (-not $tc.Destino.Tipo) {
    $errors += "• Falta configurar el tipo de destino"
}
else {
    $destinoPathCheck = switch ($tc.Destino.Tipo) {
        "FTP" {
            with $tc.Destino.FTP { .Directory }
        }
        "Local" {
            with $tc.Destino.Local { .Path }
        }
        "USB" {
            with $tc.Destino.USB { .Path }
        }
        "UNC" {
            with $tc.Destino.UNC { .Path }
        }
        "OneDrive" {
            with $tc.Destino.OneDrive { .Path }
        }
        "Dropbox" {
            with $tc.Destino.Dropbox { .Path }
        }
        "ISO" {
            with $tc.Destino.ISO { .OutputPath }
        }
        "Diskette" {
            with $tc.Destino.Diskette { .OutputPath }
        }
        default { $null }
    }
    if (-not $destinoPathCheck) {
        $errors += "• Falta configurar la ruta de destino ($($tc.Destino.Tipo))"
    }
}

$isComplete = ($errors.Count -eq 0)
if ($isComplete) {
    Write-Host "   ✓ Configuración COMPLETA y VÁLIDA" -ForegroundColor Green
}
else {
    Write-Host "   ✗ Configuración INCOMPLETA" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "     $error" -ForegroundColor Yellow
    }
}

Write-Host "`n========== TEST COMPLETADO ==========" -ForegroundColor Magenta
Write-Host ""
