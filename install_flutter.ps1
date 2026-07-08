$FlutterDir = "C:\Users\Omprakash Maury\flutter"
$ZipFile = "C:\Users\Omprakash Maury\flutter.zip"

if (-not (Test-Path "$FlutterDir\bin\flutter.bat")) {
    Write-Host "Downloading Flutter SDK..."
    # Using curl/Invoke-WebRequest might be slow. We'll use BITS which is robust for large files in PowerShell
    Import-Module BitsTransfer
    Start-BitsTransfer -Source "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.22.2-stable.zip" -Destination $ZipFile
    
    Write-Host "Extracting Flutter SDK (This will take a few minutes)..."
    Expand-Archive -Path $ZipFile -DestinationPath "C:\Users\Omprakash Maury\" -Force
    
    Write-Host "Cleaning up zip file..."
    Remove-Item $ZipFile
} else {
    Write-Host "Flutter is already extracted."
}

Write-Host "Adding to PATH for this session..."
$env:PATH += ";$FlutterDir\bin"

Write-Host "Running flutter doctor..."
flutter doctor

Write-Host "Running flutter pub get in the project..."
Set-Location "C:\Users\Omprakash Maury\Documents\project\missme"
flutter pub get
Write-Host "Flutter installation and setup complete!"
