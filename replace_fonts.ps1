# Script to replace GoogleFonts.poppins() calls with AppFonts.poppins()
$libPath = ".\lib"

# Get all Dart files
$dartFiles = Get-ChildItem -Path $libPath -Filter "*.dart" -Recurse

foreach ($file in $dartFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    $originalContent = $content
    
    # Add import for AppFonts if GoogleFonts is used
    if ($content -match 'GoogleFonts\.poppins') {
        # Add import at the top after existing imports
        if ($content -match "import 'package:flutter/material\.dart';") {
            $content = $content -replace "import 'package:flutter/material\.dart';", "import 'package:flutter/material.dart';`nimport '../core/font_utils.dart';"
        } elseif ($content -match "import\s+'[^']*font_utils\.dart';") {
            # Already has font_utils import
        } elseif ($content -match "^import") {
            # Add after first import
            $content = $content -replace "(^import.+`r`n)", "`$1`nimport '../core/font_utils.dart';"
        }
    }
    
    # Replace GoogleFonts.poppins() calls with AppFonts.poppins()
    $content = $content -replace 'GoogleFonts\.poppins\(', 'AppFonts.poppins('
    
    # Replace GoogleFonts.poppins without parentheses (for style extensions)
    $content = $content -replace 'GoogleFonts\.poppins(?!\()', 'AppFonts.poppins'
    
    # Only write file if content changed
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Updated: $($file.FullName)" -ForegroundColor Green
    }
}

Write-Host "Font replacement complete!" -ForegroundColor Cyan
