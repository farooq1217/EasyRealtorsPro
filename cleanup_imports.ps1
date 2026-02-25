# Remove remaining GoogleFonts imports
$dartFiles = Get-ChildItem -Path ".\lib" -Filter "*.dart" -Recurse

foreach ($file in $dartFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    
    if ($content -match "import 'package:google_fonts/google_fonts.dart';") {
        $content = $content -replace "import 'package:google_fonts/google_fonts.dart';`r`n", ""
        $content = $content -replace "import 'package:google_fonts/google_fonts.dart';", ""
        
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Cleaned imports in: $($file.FullName)" -ForegroundColor Green
    }
}

Write-Host "Import cleanup complete!" -ForegroundColor Cyan
