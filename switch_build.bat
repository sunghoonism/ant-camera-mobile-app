@echo off
setlocal enabledelayedexpansion

echo ======================================
echo     Build Type Switcher for Ant Camera
echo ======================================
echo.

REM Check current directory
if not exist "lib\config\build_config.dart" (
    echo Error: build_config.dart file not found!
    echo Please run this script from the project root directory.
    pause
    exit /b 1
)

if not exist "pubspec.yaml" (
    echo Error: pubspec.yaml file not found!
    echo Please run this script from the project root directory.
    pause
    exit /b 1
)

REM Check buildType in build_config.dart
echo Checking current build type...
findstr /c:"buildType = 'paid'" "lib\config\build_config.dart" >nul
if !errorlevel! equ 0 (
    set BUILD_TYPE=paid
    set NEW_NAME=ant_camera_paid
) else (
    set BUILD_TYPE=free
    set NEW_NAME=ant_camera
)

echo Current build type: !BUILD_TYPE!
echo Target app name: !NEW_NAME!
echo.

REM Check current name in pubspec.yaml
for /f "usebackq delims=" %%a in (`powershell -Command "(Get-Content 'pubspec.yaml' | Select-String '^name:').Line.Split(':')[1].Trim()"`) do set CURRENT_NAME=%%a

REM Set target label
if "!BUILD_TYPE!" == "paid" (
    set "TARGET_LABEL=Ant Camera(Paid)"
) else (
    set "TARGET_LABEL=Ant Camera"
)

echo Current name in pubspec.yaml: !CURRENT_NAME!
echo Target label will be: "!TARGET_LABEL!"

REM Check if name already correct
set NEED_UPDATE=0
if not "!CURRENT_NAME!" == "!NEW_NAME!" set NEED_UPDATE=1

REM Always update AndroidManifest.xml
set NEED_UPDATE=1

if !NEED_UPDATE! equ 0 (
    echo All configurations are already correct. No changes needed.
    echo Current name: !CURRENT_NAME!
    echo.
    pause
    exit /b 0
)

REM Create backups
echo Creating backups...
copy "pubspec.yaml" "pubspec.yaml.backup" >nul
if !errorlevel! neq 0 (
    echo Error: Failed to create pubspec.yaml backup!
    pause
    exit /b 1
)

copy "android\app\src\main\AndroidManifest.xml" "android\app\src\main\AndroidManifest.xml.backup" >nul
if !errorlevel! neq 0 (
    echo Error: Failed to create AndroidManifest.xml backup!
    exit /b 1
)

if exist "android\app\key.properties" (
    copy "android\app\key.properties" "android\app\key.properties.backup" >nul
    if !errorlevel! neq 0 (
        echo Error: Failed to create key.properties backup!
        exit /b 1
    )
)

REM 1. Update AndroidManifest.xml
echo Updating AndroidManifest.xml for !BUILD_TYPE! version...

if "!BUILD_TYPE!" == "paid" (
    if exist "android\app\src\main\AndroidManifest_paid.xml" (
        copy "android\app\src\main\AndroidManifest_paid.xml" "android\app\src\main\AndroidManifest.xml" >nul
        if !errorlevel! neq 0 (
            echo Error: Failed to copy AndroidManifest_paid.xml!
            goto :restore_backups
        )
        echo AndroidManifest.xml updated with paid version.
    ) else (
        echo Warning: AndroidManifest_paid.xml not found. Skipping AndroidManifest.xml update.
    )
) else (
    if exist "android\app\src\main\AndroidManifest_free.xml" (
        copy "android\app\src\main\AndroidManifest_free.xml" "android\app\src\main\AndroidManifest.xml" >nul
        if !errorlevel! neq 0 (
            echo Error: Failed to copy AndroidManifest_free.xml!
            goto :restore_backups
        )
        echo AndroidManifest.xml updated with free version.
    ) else (
        echo Warning: AndroidManifest_free.xml not found. Skipping AndroidManifest.xml update.
    )
)

REM 2. Copy resource files
echo Copying resource files for !BUILD_TYPE! version...
if "!BUILD_TYPE!" == "paid" (
    if exist "android\app\src\main\res_paid" (
        robocopy "android\app\src\main\res_paid" "android\app\src\main\res" /E /NFL /NDL /NJH /NJS
        set ROBOCOPY_EXIT=!errorlevel!
        if !ROBOCOPY_EXIT! gtr 7 (
            echo Error: Failed to copy paid resources! Exit code: !ROBOCOPY_EXIT!
            goto :restore_backups
        )
        echo Paid version resources copied successfully.
    ) else (
        echo Warning: res_paid folder not found. Skipping resource copy.
    )
) else (
    if exist "android\app\src\main\res_free" (
        robocopy "android\app\src\main\res_free" "android\app\src\main\res" /E /NFL /NDL /NJH /NJS
        set ROBOCOPY_EXIT=!errorlevel!
        if !ROBOCOPY_EXIT! gtr 7 (
            echo Error: Failed to copy free resources! Exit code: !ROBOCOPY_EXIT!
            goto :restore_backups
        )
        echo Free version resources copied successfully.
    ) else (
        echo Warning: res_free folder not found. Skipping resource copy.
    )
)

REM 3. Update appId in key.properties
echo Updating appId in key.properties...

if "!BUILD_TYPE!" == "paid" (
    set "NEW_APP_ID=com.ant_revolution.ant_camera_paid"
) else (
    set "NEW_APP_ID=com.ant_revolution.ant_camera"
)

if exist "android\app\key.properties" (
    echo Updating appId in key.properties...
    
    REM Use PowerShell to safely modify file content
    powershell -Command ^
        "try { " ^
        "  $content = Get-Content 'android\app\key.properties' -Raw -Encoding UTF8; " ^
        "  $newContent = $content -replace 'appId=.*?(\r?\n|$)', 'appId=!NEW_APP_ID!$1'; " ^
        "  if ($newContent -ne $content) { " ^
        "    $utf8NoBom = New-Object System.Text.UTF8Encoding($false); " ^
        "    [System.IO.File]::WriteAllText((Resolve-Path 'android\app\key.properties').Path, $newContent, $utf8NoBom); " ^
        "  } " ^
        "  exit 0; " ^
        "} catch { " ^
        "  Write-Host 'PowerShell Error:' $_.Exception.Message; " ^
        "  exit 1; " ^
        "}"
    
    if !errorlevel! neq 0 (
        echo Error: Failed to update key.properties!
        goto :restore_backups
    )
    
    echo key.properties appId updated to: !NEW_APP_ID!
) else (
    echo Warning: android\app\key.properties not found. Skipping appId update.
)

REM 4. Update pubspec.yaml (execute last)
if not "!CURRENT_NAME!" == "!NEW_NAME!" (
    echo Updating pubspec.yaml with UTF-8 encoding...
    powershell -Command "$content = Get-Content 'pubspec.yaml' -Encoding UTF8; $content[0] = 'name: !NEW_NAME!'; $content | Out-File 'pubspec.yaml' -Encoding UTF8"
    if !errorlevel! neq 0 (
        echo Error: Failed to update pubspec.yaml!
        echo Restoring backup...
        move "pubspec.yaml.backup" "pubspec.yaml" >nul
        exit /b 1
    )
    echo pubspec.yaml updated successfully.
)

echo.
echo ======================================
echo SUCCESS: Build configuration updated!
echo ======================================
echo Build type: !BUILD_TYPE!
echo App name: !NEW_NAME!
echo App label: !TARGET_LABEL!
echo.
echo Backups saved:
echo - pubspec.yaml.backup
echo - AndroidManifest.xml.backup
echo - key.properties.backup
echo.
echo Next steps:
echo 1. Run 'flutter clean' to clean build cache
echo 2. Run 'flutter pub get' to update dependencies
echo 3. Build your app with the new configuration
echo.
goto :end

:restore_backups
echo.
echo ======================================
echo ERROR: Restoring backups...
echo ======================================

if exist "pubspec.yaml.backup" (
    move "pubspec.yaml.backup" "pubspec.yaml" >nul
    echo pubspec.yaml restored.
)
if exist "android\app\src\main\AndroidManifest.xml.backup" (
    move "android\app\src\main\AndroidManifest.xml.backup" "android\app\src\main\AndroidManifest.xml" >nul
    echo AndroidManifest.xml restored.
)
if exist "android\app\key.properties.backup" (
    move "android\app\key.properties.backup" "android\app\key.properties" >nul
    echo key.properties restored.
)
echo.
exit /b 1

:end
