# Fix incorrect import paths for font_utils.dart
$dartFiles = Get-ChildItem -Path ".\lib" -Filter "*.dart" -Recurse

foreach ($file in $dartFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    $originalContent = $content
    
    # Fix incorrect import paths
    if ($content -match "import '../core/font_utils.dart';") {
        # Calculate correct relative path based on file location
        $relativePath = $file.FullName.Replace((Get-Location).Path + "\", "").Replace("\lib\", "")
        $pathParts = $relativePath.Split("\")
        $depth = $pathParts.Length - 1
        
        $correctPath = ""
        for ($i = 0; $i -lt $depth; $i++) {
            $correctPath += "../"
        }
        $correctPath += "core/font_utils.dart"
        
        $content = $content -replace "import '../core/font_utils.dart';", "import '$correctPath';"
        
        # Only write file if content changed
        if ($content -ne $originalContent) {
            Set-Content -Path $file.FullName -Value $content -NoNewline
            Write-Host "Fixed import in: $($file.FullName)" -ForegroundColor Green
        }
    }
}

Write-Host "Import fix complete!" -ForegroundColor Cyan
