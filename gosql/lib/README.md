# GoSQL Shared Libraries Directory

This directory contains the compiled Go shared libraries for different platforms:

- `libgosql.so` - Linux shared library
- `libgosql.dylib` - macOS shared library  
- `gosql.dll` - Windows shared library
- `gosql.h` - C header file for CGO interface

These libraries are automatically built during the package build process and provide
the high-performance Go backend for GoSQL Python operations.
