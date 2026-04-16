# Script para reemplazar todas las instancias de withOpacity con withValues en el proyecto
# Este script convierte valores de opacidad de 0.0 a 1.0 a valores hexadecimales de 0x00 a 0xFF

# Función para convertir opacidad decimal a hexadecimal
function Convert-OpacityToHex {
    param (
        [double]$opacity
    )

    # Redondear al entero más cercano (0-255)
    $alpha = [math]::Round($opacity * 255)
    # Asegurar que esté en el rango 0-255
    $alpha = [math]::Max(0, [math]::Min(255, $alpha))
    # Convertir a hexadecimal con dos dígitos
    return "0x{0:X2}" -f $alpha
}

# Obtener todos los archivos Dart en el proyecto
$dartFiles = Get-ChildItem -Path "d:\PROJECTS\bluesnafer_pro\lib" -Recurse -Filter "*.dart" -File

# Procesar cada archivo
foreach ($file in $dartFiles) {
    $content = Get-Content -Path $file.FullName -Raw

    # Buscar todas las instancias de withOpacity
    $matches = [regex]::Matches($content, 'Colors\.\w+\.withOpacity\(([0-9.]+)\)')

    if ($matches.Count -gt 0) {
        Write-Host "Procesando $($file.FullName) - $($matches.Count) instancias encontradas"

        # Reemplazar cada instancia
        foreach ($match in $matches) {
            $colorName = $match.Groups[0].Value -replace 'Colors\.(\w+)\.withOpacity', '$1'
            $opacityValue = [double]$match.Groups[1].Value
            $hexValue = Convert-OpacityToHex -opacity $opacityValue
            $replacement = "Colors.$colorName.withValues(alpha: $hexValue)"

            $content = $content -replace $match.Value, $replacement
        }

        # Guardar el archivo modificado
        Set-Content -Path $file.FullName -Value $content -Force
    }
}

Write-Host "Proceso completado. Todos los withOpacity han sido reemplazados con withValues."
