# Script para generar automáticamente los Include en Llevar.vcxproj
# basándose en los archivos reales del disco

param(
    [string]$ProjectPath = "Q:\Utilidad\Llevar"
)

# Extensiones válidas a incluir
$validExtensions = @(".ps1", ".psm1", ".json", ".xml", ".txt", ".md", ".cfg")

# Función para obtener rutas relativas
function Get-RelativePath {
    param([string]$fullPath, [string]$basePath)
    return $fullPath.Replace($basePath + "\", "").Replace($basePath, ".")
}

# Obtener todos los archivos válidos
$files = @()
$basePath = $ProjectPath

foreach ($ext in $validExtensions) {
    $foundFiles = Get-ChildItem -Path $basePath -Filter "*$ext" -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $foundFiles) {
        # Excluir carpetas no deseadas
        if ($file.FullName -notmatch '\\(\.git|\.vs|\.vscode|logs|bin|obj|\.tmp)\\') {
            $relPath = $file.FullName.Replace($basePath + "\", "")
            $files += $relPath
        }
    }
}

# Generar XML ItemGroup
$itemGroup = '  <ItemGroup>' + "`r`n"
foreach ($file in $files | Sort-Object) {
    $itemGroup += "    <None Include=`"$file`" />`r`n"
}
$itemGroup += '  </ItemGroup>'

Write-Host "Se encontraron $($files.Count) archivos"
Write-Host "`nGenerado ItemGroup (cópialo en tu .vcxproj):`n"
Write-Host $itemGroup

# Opcional: guardar en archivo
$outputFile = Join-Path $basePath "ItemGroup_generated.txt"
$itemGroup | Out-File -FilePath $outputFile -Encoding UTF8
Write-Host "`nGuardado también en: $outputFile"