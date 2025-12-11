# Script de prueba automatizado para FTP
# Simula la interacción del usuario

$inputs = @(
    "1"           # Seleccionar Origen
    "2"           # Seleccionar FTP
    "192.168.7.107"   # Servidor FTP
    "21"          # Puerto
    "/"           # Directorio raíz
    "FTPUser"     # Usuario
    "Estroncio24" # Contraseña
    "0"           # Volver al menú principal
    "2"           # Seleccionar Destino
    "3"           # Seleccionar FTP
    "192.168.136.128"  # Servidor FTP
    "21"          # Puerto
    "/"           # Directorio raíz
    "javierp"     # Usuario
    "mw7oi12z88"  # Contraseña
    "0"           # Volver al menú principal
    "10"          # Ejecutar transferencia
)

$inputString = $inputs -join "`n"

# Ejecutar el script con la entrada simulada
$inputString | & "Q:\Utilidad\LLevar\Llevar.ps1" -Verbose
