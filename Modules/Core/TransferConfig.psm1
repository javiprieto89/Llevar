# ========================================================================== #
#                  MÓDULO: CONFIGURACIÓN DE TRANSFERENCIA                    #
# ========================================================================== #
# Propósito: Objeto unificado para toda la configuración de transferencia
# Estructura jerárquica que evita mezcla de parámetros
# ========================================================================== #

# ========================================================================== #
#                     DEFINICIÓN DEL TIPO TRANSFERCONFIG                     #
# ========================================================================== #

class TransferConfig {
    # ====== ORIGEN ======
    [PSCustomObject]$Origen = [PSCustomObject]@{
        Tipo     = $null  # "Local", "FTP", "UNC", "OneDrive", "Dropbox", "USB"
        
        # Subestructura FTP
        FTP      = [PSCustomObject]@{
            Server    = $null
            Port      = 21
            User      = $null
            Password  = $null
            UseSsl    = $false
            Directory = "/"
        }
        
        # Subestructura UNC
        UNC      = [PSCustomObject]@{
            Path        = $null
            User        = $null
            Password    = $null
            Domain      = $null
            Credentials = $null
        }
        
        # Subestructura OneDrive
        OneDrive = [PSCustomObject]@{
            Path         = $null
            Token        = $null
            RefreshToken = $null
            Email        = $null
            ApiUrl       = "https://graph.microsoft.com/v1.0/me/drive"
        }
        
        # Subestructura Dropbox
        Dropbox  = [PSCustomObject]@{
            Path         = $null
            Token        = $null
            RefreshToken = $null
            Email        = $null
            ApiUrl       = "https://api.dropboxapi.com/2"
        }
        
        # Subestructura Local
        Local    = [PSCustomObject]@{
            Path = $null
        }
    }
    
    # ====== DESTINO ======
    [PSCustomObject]$Destino = [PSCustomObject]@{
        Tipo     = $null  # "Local", "USB", "FTP", "UNC", "OneDrive", "Dropbox", "ISO", "Diskette"
        
        # Subestructura FTP
        FTP      = [PSCustomObject]@{
            Server    = $null
            Port      = 21
            User      = $null
            Password  = $null
            UseSsl    = $false
            Directory = "/"
        }
        
        # Subestructura UNC
        UNC      = [PSCustomObject]@{
            Path        = $null
            User        = $null
            Password    = $null
            Domain      = $null
            Credentials = $null
        }
        
        # Subestructura OneDrive
        OneDrive = [PSCustomObject]@{
            Path         = $null
            Token        = $null
            RefreshToken = $null
            Email        = $null
            ApiUrl       = "https://graph.microsoft.com/v1.0/me/drive"
        }
        
        # Subestructura Dropbox
        Dropbox  = [PSCustomObject]@{
            Path         = $null
            Token        = $null
            RefreshToken = $null
            Email        = $null
            ApiUrl       = "https://api.dropboxapi.com/2"
        }
        
        # Subestructura Local
        Local    = [PSCustomObject]@{
            Path = $null
        }
        
        # Subestructura ISO
        ISO      = [PSCustomObject]@{
            OutputPath = $null
            Size       = "dvd"
            VolumeSize = $null
            VolumeName = "LLEVAR"
        }
        
        # Subestructura Diskette
        Diskette = [PSCustomObject]@{
            MaxDisks   = 30
            Size       = 1440
            OutputPath = $null
        }
    }
    
    # ====== OPCIONES GENERALES ======
    [PSCustomObject]$Opciones = [PSCustomObject]@{
        BlockSizeMB    = 10
        Clave          = $null
        UseNativeZip   = $false
        RobocopyMirror = $false
        TransferMode   = "Compress"
        Verbose        = $false
    }
    
    # ====== INTERNO (uso del sistema) ======
    [PSCustomObject]$Interno = [PSCustomObject]@{
        OrigenMontado  = $null
        DestinoMontado = $null
        OrigenDrive    = $null
        DestinoDrive   = $null
        TempDir        = $null
        SevenZipPath   = $null
    }
}

# ========================================================================== #
#                         FUNCIONES HELPER                                   #
# ========================================================================== #

function New-TransferConfig {
    <#
    .SYNOPSIS
        Crea un objeto de configuración unificado para transferencias
    .DESCRIPTION
        Crea una instancia del tipo TransferConfig con toda la estructura
        jerárquica inicializada. Este es el tipo de dato oficial para
        toda configuración de transferencia en LLEVAR.
    .OUTPUTS
        [TransferConfig] Objeto con estructura completa inicializada
    #>
    
    return [TransferConfig]::new()
}

function Get-TransferConfigValue {
    <#
    .SYNOPSIS
        Obtiene un valor de la configuración mediante notación de punto
    .DESCRIPTION
        Navega por la estructura de TransferConfig y retorna el valor solicitado.
        Soporta rutas como "Opciones.BlockSizeMB" o "Origen.FTP.Server"
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Path
        Ruta al valor usando notación de punto (ej: "Origen.FTP.Server", "Opciones.BlockSizeMB")
    .EXAMPLE
        $blockSize = Get-TransferConfigValue -Config $cfg -Path "Opciones.BlockSizeMB"
    .EXAMPLE
        $ftpServer = Get-TransferConfigValue -Config $cfg -Path "Origen.FTP.Server"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    $parts = $Path -split '\.'
    $current = $Config
    
    foreach ($part in $parts) {
        if ($current.PSObject.Properties.Name -contains $part) {
            $current = $current.$part
        }
        else {
            Write-Warning "Ruta no encontrada en TransferConfig: $Path (parte: $part)"
            return $null
        }
    }
    
    return $current
}

function Set-TransferConfigValue {
    <#
    .SYNOPSIS
        Establece un valor en la configuración mediante notación de punto
    .DESCRIPTION
        Navega por la estructura de TransferConfig y establece el valor solicitado.
        Soporta rutas como "Opciones.BlockSizeMB" o "Origen.FTP.Server"
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Path
        Ruta al valor usando notación de punto (ej: "Origen.FTP.Server", "Opciones.Clave")
    .PARAMETER Value
        Nuevo valor a establecer
    .EXAMPLE
        Set-TransferConfigValue -Config $cfg -Path "Opciones.BlockSizeMB" -Value 50
    .EXAMPLE
        Set-TransferConfigValue -Config $cfg -Path "Origen.FTP.Server" -Value "ftp.example.com"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        $Value
    )
    
    $parts = $Path -split '\.'
    $current = $Config
    
    # Navegar hasta el penúltimo elemento
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        $part = $parts[$i]
        if ($current.PSObject.Properties.Name -contains $part) {
            $current = $current.$part
        }
        else {
            throw "Ruta de configuración inválida en TransferConfig: $Path (parte: $part no existe)"
        }
    }
    
    # Establecer el valor en la última propiedad
    $lastPart = $parts[$parts.Count - 1]
    if ($current.PSObject.Properties.Name -contains $lastPart) {
        $current.$lastPart = $Value
    }
    else {
        throw "Propiedad no existe en TransferConfig: $lastPart en ruta $Path"
    }
}


function Export-TransferConfig {
    <#
    .SYNOPSIS
        Exporta TransferConfig a archivo JSON
    .DESCRIPTION
        Serializa el objeto TransferConfig completo a JSON y lo guarda en archivo.
        Útil para persistencia de configuraciones entre sesiones.
    .PARAMETER Config
        Objeto TransferConfig a exportar
    .PARAMETER Path
        Ruta del archivo JSON de salida
    .EXAMPLE
        Export-TransferConfig -Config $cfg -Path "C:\Temp\llevar-config.json"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        # Convertir TransferConfig a JSON con profundidad completa
        $json = $Config | ConvertTo-Json -Depth 10
        
        # Guardar en archivo
        $json | Out-File -FilePath $Path -Encoding UTF8 -Force
        
        Write-Log "TransferConfig exportado a: $Path" "INFO"
    }
    catch {
        Write-Log "Error exportando TransferConfig: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        throw "No se pudo exportar TransferConfig a $Path"
    }
}

function Import-TransferConfig {
    <#
    .SYNOPSIS
        Importa TransferConfig desde archivo JSON
    .DESCRIPTION
        Lee un archivo JSON y reconstruye el objeto TransferConfig.
        Útil para cargar configuraciones guardadas previamente.
    .PARAMETER Path
        Ruta del archivo JSON a importar
    .OUTPUTS
        [TransferConfig] Objeto reconstruido desde JSON
    .EXAMPLE
        $cfg = Import-TransferConfig -Path "C:\Temp\llevar-config.json"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        throw "Archivo de configuración no encontrado: $Path"
    }
    
    try {
        # Leer JSON
        $json = Get-Content -Path $Path -Raw -Encoding UTF8
        $data = $json | ConvertFrom-Json
        
        # Crear nueva instancia de TransferConfig
        $config = [TransferConfig]::new()
        
        # Copiar propiedades desde JSON a TransferConfig
        # Origen
        if ($data.Origen) {
            $config.Origen.Tipo = $data.Origen.Tipo
            foreach ($prop in $data.Origen.FTP.PSObject.Properties) {
                $config.Origen.FTP.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Origen.UNC.PSObject.Properties) {
                $config.Origen.UNC.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Origen.OneDrive.PSObject.Properties) {
                $config.Origen.OneDrive.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Origen.Dropbox.PSObject.Properties) {
                $config.Origen.Dropbox.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Origen.Local.PSObject.Properties) {
                $config.Origen.Local.$($prop.Name) = $prop.Value
            }
        }
        
        # Destino
        if ($data.Destino) {
            $config.Destino.Tipo = $data.Destino.Tipo
            foreach ($prop in $data.Destino.FTP.PSObject.Properties) {
                $config.Destino.FTP.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Destino.UNC.PSObject.Properties) {
                $config.Destino.UNC.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Destino.OneDrive.PSObject.Properties) {
                $config.Destino.OneDrive.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Destino.Dropbox.PSObject.Properties) {
                $config.Destino.Dropbox.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Destino.Local.PSObject.Properties) {
                $config.Destino.Local.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Destino.ISO.PSObject.Properties) {
                $config.Destino.ISO.$($prop.Name) = $prop.Value
            }
            foreach ($prop in $data.Destino.Diskette.PSObject.Properties) {
                $config.Destino.Diskette.$($prop.Name) = $prop.Value
            }
        }
        
        # Opciones
        if ($data.Opciones) {
            foreach ($prop in $data.Opciones.PSObject.Properties) {
                $config.Opciones.$($prop.Name) = $prop.Value
            }
        }
        
        Write-Log "TransferConfig importado desde: $Path" "INFO"
        return $config
    }
    catch {
        Write-Log "Error importando TransferConfig: $($_.Exception.Message)" "ERROR" -ErrorRecord $_
        throw "No se pudo importar TransferConfig desde $Path"
    }
}

function Reset-TransferConfigSection {
    <#
    .SYNOPSIS
        Reinicia una sección de TransferConfig a valores por defecto
    .DESCRIPTION
        Limpia todos los valores de Origen o Destino, dejándolos como una instancia nueva.
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER Section
        Sección a reiniciar: "Origen" o "Destino"
    .EXAMPLE
        Reset-TransferConfigSection -Config $cfg -Section "Origen"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$Section
    )
    
    # Crear instancia temporal para obtener valores por defecto
    $default = [TransferConfig]::new()
    
    # Copiar la sección por defecto
    if ($Section -eq "Origen") {
        $Config.Origen = $default.Origen
    }
    else {
        $Config.Destino = $default.Destino
    }
    
    Write-Log "Sección $Section reiniciada a valores por defecto" "INFO"
}

function Copy-TransferConfigSection {
    <#
    .SYNOPSIS
        Copia una sección de TransferConfig a otra
    .DESCRIPTION
        Duplica todos los valores de Origen a Destino o viceversa.
        Útil cuando origen y destino tienen configuración similar.
    .PARAMETER Config
        Objeto TransferConfig
    .PARAMETER From
        Sección origen: "Origen" o "Destino"
    .PARAMETER To
        Sección destino: "Origen" o "Destino"
    .EXAMPLE
        Copy-TransferConfigSection -Config $cfg -From "Origen" -To "Destino"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [TransferConfig]$Config,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$From,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Origen", "Destino")]
        [string]$To
    )
    
    if ($From -eq $To) {
        Write-Warning "Origen y destino son la misma sección. No se realizó copia."
        return
    }
    
    # Serializar y deserializar para copia profunda
    $json = $Config.$From | ConvertTo-Json -Depth 10
    $Config.$To = $json | ConvertFrom-Json
    
    Write-Log "Sección $From copiada a $To" "INFO"
}

# ========================================================================== #
#                    HELPERS DE DSL PARA CONFIGURACIàN                       #
# ========================================================================== #

function New-ConfigNode {
    param([hashtable]$Initial = @{})

    $obj = [PSCustomObject]@{}
    foreach ($k in $Initial.Keys) {
        $obj | Add-Member -Name $k -Value $Initial[$k] -MemberType NoteProperty
    }
    return $obj
}

function with {
    <#
    .SYNOPSIS
        Permite acceso directo a propiedades y métodos de un objeto usando sintaxis "." 
    .DESCRIPTION
        Permite leer y escribir propiedades, llamar métodos y acceder a propiedades anidadas.
        Ejemplo:
            with $obj {
                .Prop = 123
                $value = .Prop
                .Method()
                .Child.Sub.Value = "Hola"
            }
    #>
    param(
        [Parameter(Mandatory)]
        $Object,

        [Parameter(Mandatory)]
        [ScriptBlock]$Block
    )

    # Crear variable $PSItem con el objeto para acceso directo
    $PSItem = $Object
    
    # Crear contexto de ejecución donde "." es el objeto
    # Esto permite usar "." para leer propiedades y llamar métodos
    $context = @{
        "." = $Object
        "PSItem" = $Object
    }
    
    # Para que las asignaciones funcionen, necesitamos modificar el ScriptBlock
    # Obtener el texto del ScriptBlock y transformarlo usando regex
    $blockText = $Block.ToString()
    
    # Reemplazar patrones como ".Prop" o ".FTP.Directory" con "$PSItem.Prop" o "$PSItem.FTP.Directory"
    # Patrón que captura "." seguido de una o más propiedades separadas por "."
    # (?<![A-Za-z0-9_$]) asegura que no hay un carácter alfanumérico antes (evita números como 3.14)
    # ([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*) captura la cadena completa de propiedades
    $modifiedScript = $blockText -replace '(?<![A-Za-z0-9_$])\.([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)', '$PSItem.$1'
    
    # Crear nuevo ScriptBlock modificado
    try {
        $modifiedBlock = [ScriptBlock]::Create($modifiedScript)
        
        # Ejecutar el bloque modificado con el contexto
        $result = $modifiedBlock.InvokeWithContext($null, $context)
    }
    catch {
        # Si falla la modificación, intentar ejecutar el bloque original
        # Esto puede no funcionar para asignaciones, pero al menos permite lectura
        Write-Log "Error en función with: $($_.Exception.Message). Intentando ejecución directa." "WARNING" -ErrorRecord $_
        $result = $Block.InvokeWithContext($null, $context)
    }
    
    # Retornar el resultado (si hay uno solo, retornarlo directamente)
    if ($result.Count -eq 1) {
        return $result[0]
    }
    return $result
}

# Exportar funciones
Export-ModuleMember -Function @(
    'New-TransferConfig',
    'Set-TransferConfigOrigen',
    'Set-TransferConfigDestino',
    'Get-TransferConfigOrigen',
    'Get-TransferConfigDestino',
    'Get-TransferConfigValue',
    'Set-TransferConfigValue',
    'Export-TransferConfig',
    'Import-TransferConfig',
    'Reset-TransferConfigSection',
    'Copy-TransferConfigSection',
    'New-ConfigNode',
    'with'
)
