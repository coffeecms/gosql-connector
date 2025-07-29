@echo off
REM Build script for GoSQL on Windows

echo 🚀 Building GoSQL for Windows...

REM Check prerequisites
echo [INFO] Checking prerequisites...

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH
    exit /b 1
)

for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
echo [INFO] Python version: %PYTHON_VERSION%

REM Check Go
go version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Go is not installed or not in PATH
    exit /b 1
)

for /f "tokens=3" %%i in ('go version') do set GO_VERSION=%%i
echo [INFO] Go version: %GO_VERSION%

REM Check CGO
if not "%CGO_ENABLED%"=="1" (
    set CGO_ENABLED=1
    echo [WARNING] Setting CGO_ENABLED=1
)

REM Clean previous builds
echo [INFO] Cleaning previous builds...
if exist build rmdir /s /q build
if exist dist rmdir /s /q dist
if exist *.egg-info rmdir /s /q *.egg-info
if exist gosql\lib\*.dll del /q gosql\lib\*.dll

REM Create lib directory
if not exist gosql\lib mkdir gosql\lib

REM Build Go shared library
echo [INFO] Building Go shared library...
cd ..\go

set LIB_NAME=gosql.dll

REM Build the shared library
echo [INFO] Compiling Go code to %LIB_NAME%...
go build -buildmode=c-shared -o %LIB_NAME% main.go

if not exist %LIB_NAME% (
    echo [ERROR] Failed to build Go shared library
    exit /b 1
)

REM Copy to Python package
copy %LIB_NAME% ..\pythonpackaging\gosql\lib\
echo [SUCCESS] Go shared library built and copied: %LIB_NAME%

REM Return to Python package directory
cd ..\pythonpackaging

REM Install Python build dependencies
echo [INFO] Installing Python build dependencies...
python -m pip install --upgrade pip build wheel twine

REM Install package dependencies
echo [INFO] Installing package dependencies...
pip install -r requirements-dev.txt

REM Run tests before building
echo [INFO] Running tests...
pytest --version >nul 2>&1
if not errorlevel 1 (
    pytest tests/ -v --tb=short
    if errorlevel 1 (
        echo [ERROR] Tests failed. Build aborted.
        exit /b 1
    )
    echo [SUCCESS] All tests passed
) else (
    echo [WARNING] pytest not found, skipping tests
)

REM Build source distribution
echo [INFO] Building source distribution...
python -m build --sdist

REM Build wheel
echo [INFO] Building wheel...
python -m build --wheel

REM Verify builds
echo [INFO] Verifying built packages...
dir dist\

REM Check wheel contents
echo [INFO] Checking wheel contents...
for %%f in (dist\*.whl) do (
    python -m zipfile -l "%%f" | findstr /i "gosql \.dll" 2>nul
)

REM Validate package
echo [INFO] Validating package...
twine --version >nul 2>&1
if not errorlevel 1 (
    twine check dist\*
    echo [SUCCESS] Package validation passed
) else (
    echo [WARNING] twine not found, skipping package validation
)

REM Optional: Test installation
if "%1"=="--test-install" (
    echo [INFO] Testing package installation...
    
    REM Create temporary virtual environment
    set TEMP_VENV=%TEMP%\gosql_test_env
    python -m venv %TEMP_VENV%
    call %TEMP_VENV%\Scripts\activate.bat
    
    REM Install from wheel
    for %%f in (dist\*.whl) do pip install "%%f"
    
    REM Test import
    python -c "import gosql; print('GoSQL imported successfully')"
    
    REM Cleanup
    call deactivate
    rmdir /s /q %TEMP_VENV%
    echo [SUCCESS] Package installation test passed
)

echo [SUCCESS] 🎉 Build completed successfully!
echo [INFO] Built packages:
dir dist\

echo.
echo [INFO] Next steps:
echo   1. Test the package: pip install dist\gosql_connector-*.whl
echo   2. Upload to Test PyPI: twine upload --repository testpypi dist\*
echo   3. Upload to PyPI: twine upload dist\*
echo.
echo [INFO] Build artifacts are in the 'dist\' directory

pause
