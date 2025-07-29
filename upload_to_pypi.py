#!/usr/bin/env python3
"""
Script to upload GoSQL package to PyPI
"""
import os
import sys
import subprocess
import getpass
from pathlib import Path

def run_command(cmd, description):
    """Run a command and handle errors"""
    print(f"\n🔄 {description}...")
    print(f"Running: {' '.join(cmd)}")
    
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        if result.stdout:
            print(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Error: {e}")
        if e.stdout:
            print(f"STDOUT: {e.stdout}")
        if e.stderr:
            print(f"STDERR: {e.stderr}")
        return False

def check_prerequisites():
    """Check if all prerequisites are met"""
    print("🔍 Checking prerequisites...")
    
    # Check if dist directory exists and has files
    dist_dir = Path("dist")
    if not dist_dir.exists():
        print("❌ dist/ directory not found. Please run 'python -m build' first.")
        return False
    
    package_files = list(dist_dir.glob("*.whl")) + list(dist_dir.glob("*.tar.gz"))
    if not package_files:
        print("❌ No package files found in dist/. Please run 'python -m build' first.")
        return False
    
    print(f"✅ Found {len(package_files)} package files:")
    for file in package_files:
        print(f"   - {file.name} ({file.stat().st_size / 1024 / 1024:.1f}MB)")
    
    # Check if twine is installed
    try:
        subprocess.run(["python", "-m", "twine", "--version"], 
                      check=True, capture_output=True)
        print("✅ twine is installed")
    except subprocess.CalledProcessError:
        print("❌ twine is not installed. Please run 'pip install twine'")
        return False
    
    return True

def upload_to_test_pypi():
    """Upload to TestPyPI first"""
    print("\n🧪 Uploading to TestPyPI first for validation...")
    
    cmd = [
        "python", "-m", "twine", "upload",
        "--repository", "testpypi",
        "--verbose",
        "dist/*"
    ]
    
    if run_command(cmd, "Uploading to TestPyPI"):
        print("✅ Successfully uploaded to TestPyPI!")
        print("🔗 Check your package at: https://test.pypi.org/project/gosql-connector/")
        return True
    else:
        print("❌ Failed to upload to TestPyPI")
        return False

def upload_to_pypi():
    """Upload to production PyPI"""
    print("\n🚀 Uploading to production PyPI...")
    
    # Ask for confirmation
    response = input("\n⚠️  Are you sure you want to upload to production PyPI? (yes/no): ")
    if response.lower() != 'yes':
        print("❌ Upload cancelled by user")
        return False
    
    cmd = [
        "python", "-m", "twine", "upload",
        "--verbose",
        "dist/*"
    ]
    
    if run_command(cmd, "Uploading to production PyPI"):
        print("🎉 Successfully uploaded to PyPI!")
        print("🔗 Your package is now available at: https://pypi.org/project/gosql-connector/")
        print("📦 Users can install it with: pip install gosql-connector")
        return True
    else:
        print("❌ Failed to upload to PyPI")
        return False

def validate_package():
    """Validate the built package"""
    print("\n🔍 Validating package...")
    
    cmd = ["python", "-m", "twine", "check", "dist/*"]
    
    if run_command(cmd, "Validating package"):
        print("✅ Package validation passed!")
        return True
    else:
        print("❌ Package validation failed")
        return False

def main():
    """Main upload process"""
    print("🚀 GoSQL Package Upload Tool")
    print("=" * 50)
    
    # Check prerequisites
    if not check_prerequisites():
        sys.exit(1)
    
    # Validate package
    if not validate_package():
        print("\n❌ Package validation failed. Please fix issues before uploading.")
        sys.exit(1)
    
    # Show upload options
    print("\n📋 Upload Options:")
    print("1. Upload to TestPyPI only (recommended for testing)")
    print("2. Upload to TestPyPI then production PyPI")
    print("3. Upload directly to production PyPI (not recommended)")
    print("4. Exit")
    
    while True:
        choice = input("\nEnter your choice (1-4): ")
        
        if choice == "1":
            upload_to_test_pypi()
            break
        elif choice == "2":
            if upload_to_test_pypi():
                print("\n⏳ Please test your package from TestPyPI first:")
                print("   pip install -i https://test.pypi.org/simple/ gosql-connector")
                print("\nPress Enter when ready to upload to production PyPI...")
                input()
                upload_to_pypi()
            break
        elif choice == "3":
            upload_to_pypi()
            break
        elif choice == "4":
            print("👋 Goodbye!")
            break
        else:
            print("❌ Invalid choice. Please enter 1, 2, 3, or 4.")

if __name__ == "__main__":
    main()
