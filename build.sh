#!/bin/bash
# Build script for GoSQL on Unix-like systems (Linux/macOS)

set -e  # Exit on any error

echo "🚀 Building GoSQL for Unix-like systems..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
print_status "Checking prerequisites..."

# Check Python
if ! command -v python &> /dev/null; then
    print_error "Python is not installed or not in PATH"
    exit 1
fi

PYTHON_VERSION=$(python --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1-2)
print_status "Python version: $PYTHON_VERSION"

# Check Go
if ! command -v go &> /dev/null; then
    print_error "Go is not installed or not in PATH"
    exit 1
fi

GO_VERSION=$(go version | cut -d' ' -f3)
print_status "Go version: $GO_VERSION"

# Check CGO
if [ "$CGO_ENABLED" != "1" ]; then
    export CGO_ENABLED=1
    print_warning "Setting CGO_ENABLED=1"
fi

# Clean previous builds
print_status "Cleaning previous builds..."
rm -rf build/ dist/ *.egg-info/
rm -rf gosql/lib/*.so gosql/lib/*.dylib

# Create lib directory
mkdir -p gosql/lib

# Build Go shared library
print_status "Building Go shared library..."
cd ../go

# Determine shared library extension
if [[ "$OSTYPE" == "darwin"* ]]; then
    LIB_EXT="dylib"
    BUILD_FLAGS="-buildmode=c-shared"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    LIB_EXT="so"
    BUILD_FLAGS="-buildmode=c-shared"
else
    print_error "Unsupported operating system: $OSTYPE"
    exit 1
fi

LIB_NAME="libgosql.$LIB_EXT"

# Build the shared library
print_status "Compiling Go code to $LIB_NAME..."
go build $BUILD_FLAGS -o "$LIB_NAME" main.go

if [ ! -f "$LIB_NAME" ]; then
    print_error "Failed to build Go shared library"
    exit 1
fi

# Copy to Python package
cp "$LIB_NAME" "../pythonpackaging/gosql/lib/"
print_success "Go shared library built and copied: $LIB_NAME"

# Return to Python package directory
cd ../pythonpackaging

# Install Python build dependencies
print_status "Installing Python build dependencies..."
python -m pip install --upgrade pip build wheel twine

# Install package dependencies
print_status "Installing package dependencies..."
pip install -r requirements-dev.txt

# Run tests before building
print_status "Running tests..."
if command -v pytest &> /dev/null; then
    pytest tests/ -v --tb=short
    if [ $? -ne 0 ]; then
        print_error "Tests failed. Build aborted."
        exit 1
    fi
    print_success "All tests passed"
else
    print_warning "pytest not found, skipping tests"
fi

# Build source distribution
print_status "Building source distribution..."
python -m build --sdist

# Build wheel
print_status "Building wheel..."
python -m build --wheel

# Verify builds
print_status "Verifying built packages..."
ls -la dist/

# Check wheel contents
print_status "Checking wheel contents..."
WHEEL_FILE=$(ls dist/*.whl | head -n 1)
if [ -f "$WHEEL_FILE" ]; then
    python -m zipfile -l "$WHEEL_FILE" | grep -E "(gosql|\.so|\.dylib)" || true
fi

# Validate package
print_status "Validating package..."
if command -v twine &> /dev/null; then
    twine check dist/*
    print_success "Package validation passed"
else
    print_warning "twine not found, skipping package validation"
fi

# Optional: Test installation
if [ "$1" == "--test-install" ]; then
    print_status "Testing package installation..."
    
    # Create temporary virtual environment
    TEMP_VENV=$(mktemp -d)
    python -m venv "$TEMP_VENV"
    source "$TEMP_VENV/bin/activate"
    
    # Install from wheel
    pip install dist/*.whl
    
    # Test import
    python -c "import gosql; print('GoSQL imported successfully')"
    
    # Cleanup
    deactivate
    rm -rf "$TEMP_VENV"
    print_success "Package installation test passed"
fi

print_success "🎉 Build completed successfully!"
print_status "Built packages:"
ls -la dist/

echo ""
print_status "Next steps:"
echo "  1. Test the package: pip install dist/gosql_connector-*.whl"
echo "  2. Upload to Test PyPI: twine upload --repository testpypi dist/*"
echo "  3. Upload to PyPI: twine upload dist/*"
echo ""
print_status "Build artifacts are in the 'dist/' directory"
