#!/bin/bash
# Publish script for GoSQL

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Parse command line arguments
REPOSITORY="pypi"
DRY_RUN=false
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --test|--testpypi)
            REPOSITORY="testpypi"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --test, --testpypi    Upload to Test PyPI instead of PyPI"
            echo "  --dry-run            Perform all checks but don't upload"
            echo "  --skip-build         Skip building and use existing dist/ files"
            echo "  --help, -h           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                   # Build and upload to PyPI"
            echo "  $0 --test            # Build and upload to Test PyPI"
            echo "  $0 --dry-run         # Check everything but don't upload"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_status "🚀 Publishing GoSQL to $REPOSITORY..."

# Check if we're in the right directory
if [ ! -f "setup.py" ] || [ ! -f "pyproject.toml" ]; then
    print_error "Not in the correct directory. Please run from the pythonpackaging directory."
    exit 1
fi

# Check for required tools
for tool in python twine git; do
    if ! command -v $tool &> /dev/null; then
        print_error "$tool is required but not installed"
        exit 1
    fi
done

# Check if we're on the main branch for PyPI uploads
if [ "$REPOSITORY" = "pypi" ]; then
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
        print_warning "Not on main/master branch. Current branch: $CURRENT_BRANCH"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Aborted by user"
            exit 0
        fi
    fi
fi

# Check for uncommitted changes
if [ "$REPOSITORY" = "pypi" ] && [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    print_warning "You have uncommitted changes"
    git status --short
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Aborted by user"
        exit 0
    fi
fi

# Build the package if not skipped
if [ "$SKIP_BUILD" = false ]; then
    print_status "Building package..."
    if [ -f "build.sh" ]; then
        ./build.sh
    else
        # Clean and build
        rm -rf build/ dist/ *.egg-info/
        python -m build
    fi
else
    print_status "Skipping build (using existing dist/ files)"
fi

# Check if dist directory exists and has files
if [ ! -d "dist" ] || [ -z "$(ls -A dist/)" ]; then
    print_error "No files found in dist/ directory. Run build first."
    exit 1
fi

# Validate the package
print_status "Validating package..."
twine check dist/*

if [ $? -ne 0 ]; then
    print_error "Package validation failed"
    exit 1
fi

print_success "Package validation passed"

# Show what will be uploaded
print_status "Files to upload:"
ls -la dist/

# Check for existing version on PyPI (if uploading to PyPI)
if [ "$REPOSITORY" = "pypi" ]; then
    VERSION=$(python setup.py --version 2>/dev/null)
    if [ -n "$VERSION" ]; then
        print_status "Checking if version $VERSION already exists on PyPI..."
        
        # Try to get package info
        PACKAGE_INFO=$(curl -s "https://pypi.org/pypi/gosql-connector/$VERSION/json" 2>/dev/null)
        if echo "$PACKAGE_INFO" | grep -q '"version"'; then
            print_error "Version $VERSION already exists on PyPI"
            print_status "Consider bumping the version in setup.py"
            exit 1
        fi
    fi
fi

# Final confirmation for PyPI uploads
if [ "$REPOSITORY" = "pypi" ] && [ "$DRY_RUN" = false ]; then
    echo ""
    print_warning "⚠️  You are about to upload to the REAL PyPI!"
    print_warning "This action cannot be undone."
    echo ""
    read -p "Are you absolutely sure? Type 'yes' to continue: " -r
    if [ "$REPLY" != "yes" ]; then
        print_status "Upload aborted by user"
        exit 0
    fi
fi

# Upload to repository
if [ "$DRY_RUN" = true ]; then
    print_status "🏃‍♂️ DRY RUN: Would upload to $REPOSITORY"
    print_status "Command that would be executed:"
    if [ "$REPOSITORY" = "testpypi" ]; then
        echo "twine upload --repository testpypi dist/*"
    else
        echo "twine upload dist/*"
    fi
else
    print_status "📤 Uploading to $REPOSITORY..."
    
    if [ "$REPOSITORY" = "testpypi" ]; then
        twine upload --repository testpypi dist/*
    else
        twine upload dist/*
    fi
    
    if [ $? -eq 0 ]; then
        print_success "🎉 Successfully uploaded to $REPOSITORY!"
        
        if [ "$REPOSITORY" = "testpypi" ]; then
            echo ""
            print_status "You can install from Test PyPI with:"
            echo "pip install --index-url https://test.pypi.org/simple/ gosql-connector"
            echo ""
            print_status "Test PyPI URL:"
            echo "https://test.pypi.org/project/gosql-connector/"
        else
            echo ""
            print_status "You can install with:"
            echo "pip install gosql-connector"
            echo ""
            print_status "PyPI URL:"
            echo "https://pypi.org/project/gosql-connector/"
        fi
    else
        print_error "Upload failed"
        exit 1
    fi
fi

# Suggest next steps
if [ "$REPOSITORY" = "testpypi" ] && [ "$DRY_RUN" = false ]; then
    echo ""
    print_status "Next steps:"
    echo "1. Test the package from Test PyPI"
    echo "2. If everything looks good, upload to PyPI:"
    echo "   ./publish.sh"
elif [ "$REPOSITORY" = "pypi" ] && [ "$DRY_RUN" = false ]; then
    echo ""
    print_status "Next steps:"
    echo "1. Create a GitHub release"
    echo "2. Update documentation"
    echo "3. Announce the release"
fi

print_success "✅ Publish process completed!"
