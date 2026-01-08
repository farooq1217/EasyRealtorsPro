# Script to force fresh download of Firebase SDKs
# This clears all caches and forces Flutter to re-download Firebase packages

Write-Host "`n=== Force Fresh Firebase SDK Download ===" -ForegroundColor Cyan
Write-Host "This will clear all caches and force a fresh download of Firebase SDKs`n" -ForegroundColor Yellow

# Get the project directory
$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectDir

Write-Host "Project directory: $projectDir" -ForegroundColor Cyan

# Step 1: Clear .dart_tool folder (contains package resolution cache)
Write-Host "`n[1/5] Clearing .dart_tool folder..." -ForegroundColor Yellow
$dartToolPath = Join-Path $projectDir ".dart_tool"
if (Test-Path $dartToolPath) {
    Remove-Item -Path $dartToolPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✓ Cleared .dart_tool folder" -ForegroundColor Green
} else {
    Write-Host "✓ .dart_tool folder doesn't exist" -ForegroundColor Green
}

# Step 2: Clear pub cache for Firebase packages
Write-Host "`n[2/5] Clearing Firebase packages from pub cache..." -ForegroundColor Yellow
$pubCachePath = Join-Path $env:LOCALAPPDATA "Pub\Cache"
if (Test-Path $pubCachePath) {
    $firebasePackages = @(
        "firebase_core",
        "cloud_firestore",
        "firebase_storage",
        "firebase_core_platform_interface",
        "firebase_core_web",
        "cloud_firestore_platform_interface",
        "firebase_storage_platform_interface"
    )
    
    $clearedCount = 0
    foreach ($package in $firebasePackages) {
        $packagePath = Join-Path $pubCachePath "hosted\pub.dev\$package*"
        $found = Get-ChildItem $packagePath -ErrorAction SilentlyContinue
        if ($found) {
            foreach ($item in $found) {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                $clearedCount++
            }
        }
    }
    
    if ($clearedCount -gt 0) {
        Write-Host "✓ Cleared $clearedCount Firebase package(s) from pub cache" -ForegroundColor Green
    } else {
        Write-Host "✓ No Firebase packages found in pub cache" -ForegroundColor Green
    }
} else {
    Write-Host "✓ Pub cache doesn't exist" -ForegroundColor Green
}

# Step 3: Clear Flutter's build cache for Firebase
Write-Host "`n[3/5] Clearing Flutter build cache..." -ForegroundColor Yellow
$buildPath = Join-Path $projectDir "build"
if (Test-Path $buildPath) {
    # Clear Firebase-related build artifacts
    $firebaseBuildPaths = @(
        (Join-Path $buildPath "windows\x64\plugins\firebase_core"),
        (Join-Path $buildPath "windows\x64\plugins\cloud_firestore"),
        (Join-Path $buildPath "windows\x64\plugins\firebase_storage")
    )
    
    foreach ($path in $firebaseBuildPaths) {
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  ✓ Cleared $($path.Split('\')[-1])" -ForegroundColor Green
        }
    }
    Write-Host "✓ Cleared Firebase build artifacts" -ForegroundColor Green
} else {
    Write-Host "✓ Build folder doesn't exist (will be created on next build)" -ForegroundColor Green
}

# Step 4: Clear pubspec.lock to force fresh resolution
Write-Host "`n[4/5] Clearing pubspec.lock..." -ForegroundColor Yellow
$pubspecLockPath = Join-Path $projectDir "pubspec.lock"
if (Test-Path $pubspecLockPath) {
    Remove-Item -Path $pubspecLockPath -Force -ErrorAction SilentlyContinue
    Write-Host "✓ Cleared pubspec.lock" -ForegroundColor Green
} else {
    Write-Host "✓ pubspec.lock doesn't exist" -ForegroundColor Green
}

# Step 5: Run flutter pub get to force fresh download
Write-Host "`n[5/5] Running 'flutter pub get' to force fresh download..." -ForegroundColor Yellow
Write-Host "This may take a few minutes as it downloads fresh SDKs...`n" -ForegroundColor Cyan

$flutterCmd = "flutter"
$pubGetArgs = "pub get"

try {
    $process = Start-Process -FilePath $flutterCmd -ArgumentList $pubGetArgs -NoNewWindow -Wait -PassThru
    
    if ($process.ExitCode -eq 0) {
        Write-Host "`n✓ Successfully downloaded fresh Firebase SDKs!" -ForegroundColor Green
        Write-Host "`nYou can now run 'flutter clean' (if you haven't already) and then build your project." -ForegroundColor Cyan
    } else {
        Write-Host "`n✗ 'flutter pub get' exited with code $($process.ExitCode)" -ForegroundColor Red
        Write-Host "Please check the output above for errors." -ForegroundColor Yellow
        exit $process.ExitCode
    }
} catch {
    Write-Host "`n✗ Error running 'flutter pub get': $_" -ForegroundColor Red
    Write-Host "Please make sure Flutter is installed and in your PATH." -ForegroundColor Yellow
    exit 1
}

Write-Host "`n=== Complete ===" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Run 'flutter clean' (if you haven't already)" -ForegroundColor White
Write-Host "2. Run 'flutter pub get' again to verify" -ForegroundColor White
Write-Host "3. Build your project: 'flutter build windows'" -ForegroundColor White

