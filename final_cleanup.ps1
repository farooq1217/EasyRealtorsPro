# Final cleanup of any remaining GoogleFonts references
$dartFiles = Get-ChildItem -Path ".\lib" -Filter "*.dart" -Recurse

foreach ($file in $dartFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    $originalContent = $content
    
    # Remove any remaining GoogleFonts imports
    $content = $content -replace "import 'package:google_fonts/google_fonts.dart';`r`n", ""
    $content = $content -replace "import 'package:google_fonts/google_fonts.dart';", ""
    
    # Replace any remaining GoogleFonts references
    $content = $content -replace 'GoogleFonts\.poppins\(', 'AppFonts.poppins('
    $content = $content -replace 'GoogleFonts\.', 'AppFonts.'
    
    # Only write file if content changed
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Final cleanup: $($file.FullName)" -ForegroundColor Green
    }
}

Write-Host "Final cleanup complete!" -ForegroundColor Cyan
