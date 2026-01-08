# Script to set JAVA_HOME environment variable for JDK 17+
# Run this script as Administrator after installing JDK

Write-Host "`n=== Java JDK Setup Script ===" -ForegroundColor Cyan
Write-Host "`nChecking for installed JDK..." -ForegroundColor Yellow

# Common JDK installation paths
$possiblePaths = @(
    "C:\Program Files\Microsoft\jdk-17*",
    "C:\Program Files\Java\jdk-17*",
    "C:\Program Files\Eclipse Adoptium\jdk-17*",
    "C:\Program Files\Eclipse Foundation\jdk-17*",
    "C:\Program Files\OpenJDK\jdk-17*"
)

$jdkPath = $null
foreach ($path in $possiblePaths) {
    $found = Get-ChildItem $path -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if ($found) {
        $jdkPath = $found.FullName
        Write-Host "`n✓ Found JDK at: $jdkPath" -ForegroundColor Green
        break
    }
}

if (-not $jdkPath) {
    Write-Host "`n✗ JDK 17+ not found in common locations." -ForegroundColor Red
    Write-Host "`nPlease install JDK 17 or higher first:" -ForegroundColor Yellow
    Write-Host "1. Microsoft Build: https://aka.ms/download-jdk/microsoft-jdk-17.0.13-windows-x64.msi" -ForegroundColor Cyan
    Write-Host "2. Oracle JDK: https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html" -ForegroundColor Cyan
    Write-Host "3. Eclipse Adoptium: https://adoptium.net/temurin/releases/?version=17" -ForegroundColor Cyan
    Write-Host "`nAfter installation, run this script again." -ForegroundColor Yellow
    exit 1
}

# Verify it's JDK 17 or higher
$javaExe = Join-Path $jdkPath "bin\java.exe"
if (Test-Path $javaExe) {
    $versionOutput = & $javaExe -version 2>&1
    Write-Host "`nJava Version:" -ForegroundColor Yellow
    Write-Host $versionOutput -ForegroundColor White
} else {
    Write-Host "`n✗ java.exe not found at: $javaExe" -ForegroundColor Red
    exit 1
}

# Set JAVA_HOME for current user
Write-Host "`nSetting JAVA_HOME environment variable..." -ForegroundColor Yellow
[Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkPath, "User")
$env:JAVA_HOME = $jdkPath

# Add to PATH if not already there
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$binPath = Join-Path $jdkPath "bin"

if ($currentPath -notlike "*$binPath*") {
    Write-Host "Adding Java bin to PATH..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$binPath", "User")
    $env:Path = "$env:Path;$binPath"
    Write-Host "✓ Added to PATH" -ForegroundColor Green
} else {
    Write-Host "✓ Java bin already in PATH" -ForegroundColor Green
}

Write-Host "`n=== Configuration Complete ===" -ForegroundColor Green
Write-Host "`nJAVA_HOME: $env:JAVA_HOME" -ForegroundColor Cyan
Write-Host "`nIMPORTANT: Please restart your IDE (Cursor/VS Code) and terminal for changes to take effect." -ForegroundColor Yellow
Write-Host "`nTo verify, run: java -version" -ForegroundColor Cyan

