# ========================================================================== #
#                   MÓDULO: AYUDA Y DOCUMENTACIÓN                            #
# ========================================================================== #
# Propósito: Mostrar ayuda completa del script Llevar.ps1
# Funciones:
#   - Show-Help: Muestra documentación completa de uso
# ========================================================================== #

function Show-Help {
    <#
    .SYNOPSIS
        Muestra la ayuda completa del script Llevar.ps1
    .DESCRIPTION
        Presenta documentación detallada incluyendo sinopsis, uso, parámetros,
        ejemplos, flujo de trabajo, métodos de compresión, soporte de servicios
        en la nube (OneDrive, Dropbox), y opciones avanzadas.
    #>
    Show-Banner "LLEVAR-USB - Sistema de transporte de carpetas en múltiples USBs`nVersión PowerShell del clásico LLEVAR.BAT de Alex Soft" -BorderColor Cyan -TextColor Cyan
    Write-Host "SINOPSIS:" -ForegroundColor Yellow
    Write-Host "  Comprime y divide carpetas grandes en bloques para transportar en múltiples USBs."
    Write-Host "  Genera instalador automático que reconstruye el contenido en la máquina destino."
    Write-Host ""
    Write-Host "USO:" -ForegroundColor Yellow
    Write-Host "  .\Llevar.ps1 [-Origen <ruta>] [-Destino <ruta>] [-BlockSizeMB <n>] [opciones]"
    Write-Host ""
    Write-Host "PAR�METROS PRINCIPALES:" -ForegroundColor Yellow
    Write-Host "  -Origen <ruta>       Carpeta que se desea transportar (se comprime completa)"
    Write-Host "                       Si no se especifica, se solicitará interactivamente"
    Write-Host ""
    Write-Host "  -Destino <ruta>      Carpeta de destino recomendada en la máquina final"
    Write-Host "                       Se guarda dentro del INSTALAR.ps1 generado"
    Write-Host "                       Si no se especifica, se solicitará interactivamente"
    Write-Host ""
    Write-Host "  -BlockSizeMB <n>     Tamaño de cada bloque .alx en megabytes (por defecto: 10)"
    Write-Host "                       Ajustar según capacidad de los USBs disponibles"
    Write-Host "                       Ejemplo: -BlockSizeMB 50 para bloques de 50 MB"
    Write-Host ""
    Write-Host "  -Clave <password>    Contraseña para encriptar el archivo (solo con 7-Zip)"
    Write-Host "                       NOTA: ZIP nativo NO soporta contraseñas"
    Write-Host ""
    Write-Host "OPCIONES DE COMPRESIÓN:" -ForegroundColor Yellow
    Write-Host "  -UseNativeZip        Fuerza el uso de compresión ZIP nativa de Windows"
    Write-Host "                       Requiere Windows 10 o superior"
    Write-Host "                       No requiere 7-Zip instalado"
    Write-Host "                       Sin soporte para contraseñas"
    Write-Host ""
    Write-Host "                       Si NO se especifica:"
    Write-Host "                       • Busca 7-Zip automáticamente (recomendado)"
    Write-Host "                       • Si no encuentra 7-Zip, ofrece usar ZIP nativo"
    Write-Host ""
    Write-Host "OPCIONES AVANZADAS:" -ForegroundColor Yellow
    Write-Host "  -Iso                 Genera una imagen ISO en lugar de copiar a USBs"
    Write-Host "  -IsoDestino <tipo>   Tipo de medio ISO: 'usb', 'cd', 'dvd' (por defecto: dvd)"
    Write-Host "                       • cd  → 700 MB (divide en múltiples ISOs si excede)"
    Write-Host "                       • dvd → 4.5 GB (divide en múltiples ISOs si excede)"
    Write-Host "                       • usb → 4.5 GB (divide en múltiples ISOs si excede)"
    Write-Host "                       Si el contenido supera la capacidad, genera múltiples"
    Write-Host "                       volúmenes ISO (VOL01, VOL02, etc.) con lógica similar"
    Write-Host "                       a USBs: instalador en VOL01, __EOF__ en último volumen"
    Write-Host ""
    Write-Host "  -Ejemplo             Modo demostración automático"
    Write-Host "                       Ejecuta proceso completo de demostración"
    Write-Host "                       No requiere interacción del usuario"
    Write-Host "                       Limpia todos los archivos al finalizar"
    Write-Host ""
    Write-Host "  -TipoEjemplo <tipo>  Tipo de demostración (solo con -Ejemplo)"
    Write-Host "                       Valores: local, iso-cd, iso-dvd, ftp, onedrive, dropbox"
    Write-Host "                       • local    → Carpeta a carpeta (predeterminado)"
    Write-Host "                       • iso-cd   → Genera imagen ISO de 700MB"
    Write-Host "                       • iso-dvd  → Genera imagen ISO de 4.5GB"
    Write-Host "                       • ftp      → Muestra ejemplo de uso FTP"
    Write-Host "                       • onedrive → Muestra ejemplo de uso OneDrive"
    Write-Host "                       • dropbox  → Muestra ejemplo de uso Dropbox"
    Write-Host ""
    Write-Host "  -Ayuda, -h           Muestra esta ayuda y termina"
    Write-Host ""
    Write-Host "  -RobocopyMirror      Modo copia espejo simple con Robocopy"
    Write-Host "                       Sincroniza origen con destino (MIRROR)"
    Write-Host "                       ⚠ ELIMINA archivos en destino que no existen en origen"
    Write-Host "                       Uso: .\Llevar.ps1 -RobocopyMirror [-Origen <ruta>] [-Destino <ruta>]"
    Write-Host "                       Si no se especifican rutas, las solicitará interactivamente"
    Write-Host ""
    Write-Host "FLUJO DE TRABAJO:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [M�QUINA ORIGEN]" -ForegroundColor Green
    Write-Host "  1. Ejecutar: .\Llevar.ps1 -Origen C:\MiCarpeta -Destino D:\Restaurar"
    Write-Host "  2. El programa comprime la carpeta (7-Zip o ZIP nativo)"
    Write-Host "  3. Divide en bloques: MiCarpeta.alx0001, .alx0002, .alx0003, etc."
    Write-Host "  4. Solicita USBs uno por uno y copia los bloques"
    Write-Host "  5. Genera INSTALAR.ps1 en la primera USB"
    Write-Host "  6. Marca la última USB con __EOF__"
    Write-Host ""
    Write-Host "  [M�QUINA DESTINO]" -ForegroundColor Green
    Write-Host "  1. Insertar primera USB (la que tiene INSTALAR.ps1)"
    Write-Host "  2. Ejecutar: .\INSTALAR.ps1"
    Write-Host "  3. El instalador pide los demás USBs automáticamente"
    Write-Host "  4. Reconstruye y descomprime la carpeta original"
    Write-Host "  5. Deja el contenido en la ruta especificada"
    Write-Host ""
    Write-Host "MÉTODOS DE COMPRESIÓN:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [7-ZIP] - Recomendado" -ForegroundColor Green
    Write-Host "  ✓ Mejor compresión que ZIP"
    Write-Host "  ✓ Soporta contraseñas y encriptación"
    Write-Host "  ✓ Búsqueda automática: PATH → script → instalación → descarga"
    Write-Host ""
    Write-Host "  [ZIP NATIVO] - Fallback o forzado con -UseNativeZip" -ForegroundColor Cyan
    Write-Host "  ✓ Requiere Windows 10 o superior"
    Write-Host "  ✓ No requiere software adicional"
    Write-Host "  ✗ NO soporta contraseñas"
    Write-Host "  • Comprime en un solo ZIP y luego lo divide en bloques"
    Write-Host ""
    Write-Host "EJEMPLOS:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  # Uso básico con 7-Zip (automático):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen C:\Proyectos -Destino D:\Proyectos -BlockSizeMB 100"
    Write-Host ""
    Write-Host "  # Forzar ZIP nativo de Windows:" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen C:\Datos -Destino D:\Datos -UseNativeZip"
    Write-Host ""
    Write-Host "  # Con contraseña (requiere 7-Zip):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen C:\Secreto -Destino D:\Secreto -Clave "MiPassword123""
    Write-Host ""
    Write-Host "  # Generar ISO en lugar de copiar a USBs:" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen C:\App -Destino D:\App -Iso -IsoDestino dvd"
    Write-Host ""
    Write-Host "  # Generar múltiples ISOs de CD (700MB cada uno, divide automáticamente):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen C:\GranProyecto -Destino D:\Proyecto -Iso -IsoDestino cd"
    Write-Host ""
    Write-Host "  # Modo interactivo (sin parámetros):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1"
    Write-Host ""
    Write-Host "  # Modo ejemplo automático (demostración local):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Ejemplo"
    Write-Host ""
    Write-Host "  # Ejemplo ISO para CD (700MB):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Ejemplo -TipoEjemplo iso-cd"
    Write-Host ""
    Write-Host "  # Ejemplo ISO para DVD (4.5GB):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Ejemplo -TipoEjemplo iso-dvd"
    Write-Host ""
    Write-Host "  # Subir carpeta local a OneDrive (con compresión):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen C:\MiProyecto -Destino onedrive:///Backups/Proyecto -OnedriveDestino"
    Write-Host ""
    Write-Host "  # Descargar desde OneDrive a local (transferencia directa):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen onedrive:///Documentos/Importante -Destino C:\Descargas -OnedriveOrigen"
    Write-Host ""
    Write-Host "  # OneDrive a OneDrive con compresión:" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -OnedriveOrigen -OnedriveDestino -BlockSizeMB 50"
    Write-Host ""
    Write-Host "  # Subir a Dropbox con compresión:" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen C:\Documentos -Destino dropbox:///Backups/Docs -DropboxDestino"
    Write-Host ""
    Write-Host "  # Descargar desde Dropbox a local (directo):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -Origen dropbox:///Proyectos/App -Destino C:\Proyectos -DropboxOrigen"
    Write-Host ""
    Write-Host "  # Copia espejo con Robocopy (sincronización simple):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -RobocopyMirror -Origen C:\Datos -Destino D:\Respaldo"
    Write-Host ""
    Write-Host "  # Robocopy sin especificar rutas (modo interactivo):" -ForegroundColor Gray
    Write-Host "  .\Llevar.ps1 -RobocopyMirror"
    Write-Host ""
    Write-Host "SOPORTE ONEDRIVE:" -ForegroundColor Yellow
    Write-Host "  -OnedriveOrigen      Indica que el origen es OneDrive"
    Write-Host "  -OnedriveDestino     Indica que el destino es OneDrive"
    Write-Host ""
    Write-Host "  Requisitos:" -ForegroundColor Cyan
    Write-Host "  • Módulo Microsoft.Graph (se instala automáticamente si falta)"
    Write-Host "  • Permisos: Files.ReadWrite.All"
    Write-Host "  • Autenticación con MFA soportada"
    Write-Host ""
    Write-Host "  Formato de rutas OneDrive:" -ForegroundColor Cyan
    Write-Host "  • onedrive:///carpeta/subcarpeta"
    Write-Host "  • ONEDRIVE:/carpeta/archivo.txt"
    Write-Host "  • Si no se especifica ruta, se solicitará interactivamente"
    Write-Host ""
    Write-Host "  Modos de transferencia:" -ForegroundColor Cyan
    Write-Host "  • Directo: Copia archivos sin comprimir (más rápido)"
    Write-Host "  • Comprimir: Genera bloques + INSTALAR.ps1 (para reinstalar en otro equipo)"
    Write-Host ""
    Write-Host "SOPORTE DROPBOX:" -ForegroundColor Yellow
    Write-Host "  -DropboxOrigen       Indica que el origen es Dropbox"
    Write-Host "  -DropboxDestino      Indica que el destino es Dropbox"
    Write-Host ""
    Write-Host "  Requisitos:" -ForegroundColor Cyan
    Write-Host "  • Autenticación OAuth2 con MFA soportada"
    Write-Host "  • Navegador para autorizar la aplicación"
    Write-Host "  • Token se obtiene automáticamente"
    Write-Host ""
    Write-Host "  Formato de rutas Dropbox:" -ForegroundColor Cyan
    Write-Host "  • dropbox:///carpeta/subcarpeta"
    Write-Host "  • DROPBOX:/archivo.txt"
    Write-Host "  • Si no se especifica ruta, se solicitará interactivamente"
    Write-Host ""
    Write-Host "  Modos de transferencia:" -ForegroundColor Cyan
    Write-Host "  • Directo: Copia archivos sin comprimir (más rápido)"
    Write-Host "  • Comprimir: Genera bloques + INSTALAR.ps1 (para reinstalar en otro equipo)"
    Write-Host ""
    Write-Host "  Características:" -ForegroundColor Cyan
    Write-Host "  • Soporta archivos grandes (>150MB) con upload por sesiones"
    Write-Host "  • Barra de progreso para archivos grandes"
    Write-Host "  • Upload/Download de carpetas completas"
    Write-Host ""
    Write-Host "LOGS:" -ForegroundColor Yellow
    Write-Host "  Solo se generan en caso de error:"
    Write-Host "  • Origen:  %TEMP%\LLEVAR_ERROR.log"
    Write-Host "  • Destino: %TEMP%\INSTALAR_ERROR.log"
    Write-Host ""
}

# Exportar funciones
Export-ModuleMember -Function @(
    'Show-Help'
)
