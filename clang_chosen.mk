CC = clang
CXX = clang++
LINKER = clang++
LD = clang++
LTO = -flto=full
BINUTILS_PREFIX = llvm-

export CLANG_MAJOR_VERSION = $(shell clang --version | sed -n 1p | awk -c '{print $$3}' | sed -E 's/\..*//g')
