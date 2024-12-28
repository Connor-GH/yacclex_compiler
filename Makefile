# variables defined for "cc_and_flags" API
PACKAGE_NAME_NOTSTRING = lang parser
PACKAGE_NAME = "$(PACKAGE_NAME_NOTSTRING)"
PACKAGE_VERSION = 0.0.1
C_STD ?= c11
# setting up sources
SRCDIR = src
OBJDIR = obj
BINDIR = bin
TARGET = $(BINDIR)/lang
INCLUDES = $(wildcard $(SRCDIR)/include/*.h)
LANG_NAME = $(TARGET)
# parsing/frontend
SOURCES_C = $(wildcard $(SRCDIR)/*.c)
OBJECTS_C = $(SOURCES_C:$(SRCDIR)/%.c=$(OBJDIR)/%.o)

GENERATED_C = $(wildcard $(OBJDIR)/*.c)
GENERATED_C_OBJ = $(GENERATED_C:$(OBJDIR)/%.c=$(OBJDIR)/%.o)

SOURCES_D = $(wildcard $(SRCDIR)/*.d)
OBJECTS_D = $(SOURCES_D:$(SRCDIR)/%.d=$(OBJDIR)/%.o)

TARGET_ARCH ?= x86
ifeq ($(TARGET_ARCH), x86)
	MARCH = x86-64
endif



IVARS = -I$(SRCDIR)/include -I$(SRCDIR)

COMMON_FLAGS = -O2 -pipe $(IVARS)
COMMON_FLAGS_C = -DLANGNAME_STRING=\"$(LANG_NAME)\"
include cc_and_flags.mk
the_CFLAGS = -pedantic $(_CFLAGS)
the_LFLAGS = -lm $(LDFLAGS) $(IVARS) $(_LFLAGS)
the_DFLAGS = $(IVARS) $(_DFLAGS)
the_D_LFLAGS = $(_LD_DFLAGS)
DIRECTORIES = $(BINDIR) $(OBJDIR)
.PHONY: all clean remove

all:
	$(MAKE) $(DIRECTORIES)
	$(MAKE) gen
	$(MAKE) $(TARGET)


gen:
	$(LEX) -o $(OBJDIR)/lexer.c $(SRCDIR)/lexer.l
	$(YACC) -t --location --feature=caret -Wconflicts-rr -Wcounterexamples -Wno-yacc -d -o $(OBJDIR)/parser.c $(SRCDIR)/parser.y

$(TARGET): $(OBJECTS_C) $(GENERATED_C_OBJ)
	$(CC) $(the_CFLAGS) -o $@ $^ $(IVARS) $(the_LFLAGS) -lfl

$(OBJDIR)/%.o : $(SRCDIR)/%.d
	$(DCC) $(DCC_BASIC_O)$@ $(the_DFLAGS) $^ $(DCC_BASIC_C)

$(OBJDIR)/%.o : $(SRCDIR)/%.c
	$(CC) -Iobj -o $@ $(the_CFLAGS) $^ -c

$(OBJDIR)/%.o : $(OBJDIR)/%.c
	$(CC) -o $@ $(the_CFLAGS) $^ -c

$(OBJDIR)/%.o : $(SRCDIR)/%.d
	$(DCC) $(DCC_BASIC_O)$@ $(the_DFLAGS) $^ $(DCC_BASIC_C)

$(DIRECTORIES):
	mkdir -p $@

clean:
	rm obj/*
	rm -rf $(BINDIR)/$(TARGET)

