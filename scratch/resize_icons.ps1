$resPath = "android/app/src/main/res"
$mappings = @{
    "mipmap-mdpi" = 48
    "mipmap-hdpi" = 72
    "mipmap-xhdpi" = 96
    "mipmap-xxhdpi" = 144
    "mipmap-xxxhdpi" = 192
}

foreach ($folder in $mappings.Keys) {
    $size = $mappings[$folder]
    $contentSize = [math]::Round($size * 0.82) # Slightly smaller (82%) to be even safer
    $dir = Join-Path $resPath $folder
    
    if (Test-Path $dir) {
        Write-Host "Processing all icons in $folder (Target: $size, Content: $contentSize)..."
        $files = Get-ChildItem -Path $dir -Filter "*.png"
        foreach ($file in $files) {
            $fullPath = $file.FullName
            # Resize and pad with transparency
            magick convert "$fullPath" -resize "${contentSize}x${contentSize}" -background transparent -gravity center -extent "${size}x${size}" "$fullPath"
            Write-Host "  Processed $($file.Name)"
        }
    }
}
