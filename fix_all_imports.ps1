# fix_imports.ps1
Write-Host "Fixing all Dart imports..." -ForegroundColor Cyan

# Find and fix all Dart files with package:clash
$files = Get-ChildItem -Path . -Recurse -Filter *.dart | Where-Object { 
    $_.FullName -notlike "*\.dart_tool*" -and $_.FullName -notlike "*\build\*" 
}

$count = 0
foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match 'package:clash') {
        $newContent = $content -replace 'package:clash', 'package:clash'
        Set-Content $file.FullName $newContent -NoNewline
        Write-Host "Fixed: $($file.FullName)" -ForegroundColor Green
        $count++
    }
}

Write-Host "`nFixed $count files" -ForegroundColor Green

# Update pubspec.yaml if needed
if (Test-Path "pubspec.yaml") {
    $content = Get-Content "pubspec.yaml" -Raw
    if ($content -match 'name:\s*clash') {
        $newContent = $content -replace 'name:\s*clash', 'name: clash'
        Set-Content "pubspec.yaml" $newContent -NoNewline
        Write-Host "Updated pubspec.yaml name" -ForegroundColor Green
    }
}

Write-Host "`nDone! Run: flutter clean && flutter pub get && flutter run -d chrome" -ForegroundColor Cyan