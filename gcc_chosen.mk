CC = gcc
CXX = g++
LINKER = g++
LD = g++
LTO = -flto -fno-fat-lto-objects
BINUTILS_PREFIX =

export GCC_MAJOR_VERSION = $(shell gcc --version | sed -n 1p | awk -c '{print $$3}' | sed -E 's/\..*//g')
