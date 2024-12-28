_WFLAGS = -Wformat-security -Warray-bounds -Wstack-protector \
		  -Wall -Wextra -Wpedantic -Wshadow -Wvla -Wpointer-arith -Wwrite-strings \
		  -Wfloat-equal -Wcast-align -Wcast-qual \
		  -Wunreachable-code -Wundef -Werror=format-security -Werror=array-bounds \
		  -Werror=uninitialized -Wno-unused-function
WGCC = -Wlogical-op -Wcast-align=strict

WNOFLAGS=
VISIBILITY ?= -fvisibility=hidden

DCC ?= dmd
DCC_BASIC_O ?= -o
DCC_BASIC_C ?= -c
_DFLAGS =


ifeq ($(RELEASE),true)
	_COMMON_CFLAGS = -march=$(MARCH)
	D_MCPU_DMD = baseline
else
	_COMMON_CFLAGS = -march=native
	D_MCPU_DMD = native
	MARCH = native
endif
_LFLAGS  =

# detect if the user chose GCC or Clang

ifeq ($(shell $(CC) -v 2>&1 | grep -c "gcc version"), 1)
	include gcc_chosen.mk
	ifeq ($(DEBUG),true)
		# gcc-specific security/debug flags
		WGCC   += -fanalyzer
		_COMMON_CFLAGS += -ggdb
	endif #debug
	_COMMON_CFLAGS += $(_WFLAGS) $(WGCC)

else ifeq ($(shell $(CC) -v 2>&1 | grep -c "clang version"), 1)
	include clang_chosen.mk
	ifeq ($(DEBUG),true)
	 # clang-specific security/debug flags
	 # CFI not supported with ldc2
	 __LLVM_C_FLAGS = -fsanitize=undefined,signed-integer-overflow,null,alignment,address #,leak
	 _COMMON_CFLAGS += $(__LLVM_C_FLAGS) -fsanitize-undefined-trap-on-error -ftrivial-auto-var-init=zero \
				  -mspeculative-load-hardening -mretpoline

endif #debug

	_COMMON_CFLAGS += $(_WFLAGS)
	WNOFLAGS += -Wno-disabled-macro-expansion
endif #compiler


ifeq ($(DEBUG),true)
	# generic security/debug flags
	_COMMON_CFLAGS += -Og -D_DEBUG -fno-builtin
	_LFLAGS += -Wl,-z,relro,-z,noexecstack
	_DFLAGS += -g
endif # DEBUG
ifeq ($(RELEASE),true)
	_COMMON_CFLAGS += -fstack-clash-protection -D_FORTIFY_SOURCE=2 -fcf-protection \
			  -Werror=format-security
	_LFLAGS += -fPIE -fPIC
endif


# Flags every compile will need
_COMMON_CFLAGS += $(COMMON_FLAGS) $(COMMON_FLAGS_C) -D_PACKAGE_NAME=\"$(PACKAGE_NAME)\" \
				 -D_PACKAGE_VERSION=\"$(PACKAGE_VERSION)\" \
		  $(VISIBILITY) $(WNOFLAGS) -D_POSIX_C_SOURCE=200809L
_CXXFLAGS = $(_COMMON_CFLAGS) -std=$(CXX_STD) $(CXXFLAGS)
_CFLAGS = $(_COMMON_CFLAGS) -std=$(C_STD) $(CFLAGS)
_LFLAGS += -L/usr/local/lib $(LDFLAGS)
_LD_DFLAGS =
# LTO will be turned on later
ifneq ($(DCC), gdc)
	DCC_BASIC_O = -of=
	_DFLAGS += -release -extern-std=$(CXX_STD)
	_LD_DFLAGS += -L-lstdc++
  ifeq ($(DCC),dmd)
	_LD_DFLAGS += -L-lphobos2
	_DFLAGS += -O -mcpu=$(D_MCPU_DMD)
  else # is ldc
	_DFLAGS += -O3 -mcpu=$(MARCH)
	_LD_DFLAGS += -L-lstdc++ -release
    ifeq ($(CC), clang)
    ifeq ($(DEBUG),true)
	__DEBUG_FLAGS_LLVM = -fsanitize=address,leak
	_DFLAGS +=  $(__DEBUG_FLAGS_LLVM) -Xcc="-fsplit-lto-unit"
	_CFLAGS += -fsplit-lto-unit
	_CXXFLAGS += -fsplit-lto-unit
	_LD_DFLAGS += $(__DEBUG_FLAGS_LLVM) -Xcc=-fsplit-lto-unit -Xcc="$(__LLVM_C_FLAGS)"
    endif
	  _DFLAGS += $(LTO)
	  _CFLAGS += $(LTO)
	  _CXXFLAGS += $(LTO)
	  _LD_DFLAGS += $(LTO) -Xcc="$(LTO)"
    endif

  endif # if dmd/ldc
else
	_DFLAGS += $(COMMON_FLAGS) -march=$(MARCH) $(DFLAGS) \
			   -fextern-std=$(CXX_STD) -frelease
	_LD_DFLAGS += -lstdc++ -lgphobos
	GDC_XD = -xd
endif # if gdc
_DFLAGS += $(DFLAGS)
_LD_DFLAGS += -L-O2 $(LDFLAGS) $(LFLAGS)
