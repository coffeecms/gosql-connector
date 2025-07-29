# PyPI Configuration Instructions

## 1. Create PyPI Account
- Go to https://pypi.org/account/register/
- Create your account and verify email

## 2. Create TestPyPI Account (for testing)
- Go to https://test.pypi.org/account/register/
- Create your account and verify email

## 3. Generate API Tokens

### For Production PyPI:
1. Go to https://pypi.org/manage/account/
2. Scroll to "API tokens" section
3. Click "Add API token"
4. Give it a name like "gosql-connector-upload"
5. Select scope: "Entire account" or specific project
6. Copy the token (starts with pypi-)

### For TestPyPI:
1. Go to https://test.pypi.org/manage/account/
2. Follow same steps as above

## 4. Configure Credentials

### Method 1: Using .pypirc file (Recommended)
Create/edit `~/.pypirc` file:

```ini
[distutils]
index-servers =
    pypi
    testpypi

[pypi]
repository = https://upload.pypi.org/legacy/
username = __token__
password = pypi-your-production-token-here

[testpypi]
repository = https://test.pypi.org/legacy/
username = __token__
password = pypi-your-test-token-here
```

### Method 2: Environment Variables
Set these environment variables:
```bash
# For production PyPI
export TWINE_USERNAME=__token__
export TWINE_PASSWORD=pypi-your-production-token-here

# For TestPyPI
export TWINE_REPOSITORY_URL=https://test.pypi.org/legacy/
export TWINE_USERNAME=__token__
export TWINE_PASSWORD=pypi-your-test-token-here
```

### Method 3: Interactive Input (Least secure)
You'll be prompted for username/password when uploading.

## 5. Upload Commands

### Test upload:
```bash
python upload_to_pypi.py
```

### Manual upload commands:
```bash
# Upload to TestPyPI
python -m twine upload --repository testpypi dist/*

# Upload to production PyPI
python -m twine upload dist/*
```

## 6. Verify Upload

### After TestPyPI upload:
- Visit: https://test.pypi.org/project/gosql-connector/
- Test install: `pip install -i https://test.pypi.org/simple/ gosql-connector`

### After production PyPI upload:
- Visit: https://pypi.org/project/gosql-connector/
- Test install: `pip install gosql-connector`

## Security Notes
- Keep your API tokens secure
- Use environment variables or .pypirc file instead of hardcoding tokens
- Consider using project-scoped tokens instead of account-wide tokens
- Rotate tokens periodically
