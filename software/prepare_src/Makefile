#---------------------------------------------------------------------
# Primitives
#---------------------------------------------------------------------

# Include the modified / copied SuperCop crypto_aead/crypto_hash
# source code
include Makefile.paths

#---------------------------------------------------------------------
# settings
#---------------------------------------------------------------------
cc           = gcc

#BUILD_DLL Flag
CFLAGS		+= -DBUILD_DLL
# For Debugging w/ gdb
CFLAGS      += -ggdb3 -O2
# Use this option if needed
# CFLAGS 		+= -std=c++17

# Flags used for debug build
DEBUG_FLAGS  = -DDBG

LIBS         = -L/usr/local/bin
INCLUDES     = -I/usr/local/include

LIBDIR       = libs
BUILDDIR     = ${LIBDIR}/build

ifeq ($(OS),Windows_NT)
	suffix=dll
	LDFLAGS+=-Wl,--out-implib,$(ODIR)/$(OUTPUT).a
# Add SSL library for Windows (MingW32)  (if needed)
	# LIBS+=-llibeay32
else
	suffix=so
	CFLAGS+=-fpic
# Add SSL library for Linux (if needed)
	# LIBS+=-lssl
	LIBS+=-lcrypto
endif

all: create_all_libs


objs     := $(foreach p,${PRIMITIVE_PATHS},$(wildcard ${p}/*.c) $(wildcard ${p}/*.cpp))
objs     := $(objs:.c=.std.o)
objs     := $(objs:.cpp=.std.o)
objs     := $(addprefix ${BUILDDIR}/,${objs})

dbg_objs := $(objs:.std.o=.dbg.o)


### Utility functions
# Convert primitive path name to algorithm path name
# e.g. crypto_aead/gimli24v1/ref -> crypto_aead/gimli24v1--ref
GET_PRIM_PATH = $(word 1, $(subst /, ,$(1)))/$(word 2, $(subst /, ,$(1)))--$(word 3, $(subst /, ,$(1)))

# Filter data
FILTER_MATCH = $(foreach v,$1,$(if $(findstring $2,$(v)),$(v),))


### Aut-rule generation
# See http://blog.jgc.org/2012/01/using-gnu-makes-define-and-eval-to.html
# 	  https://stackoverflow.com/questions/6145041/makefile-filter-out-strings-containing-a-character

define auto-create-rules
PRIMITIVES += $1
TGTS += ${LIBDIR}/$1.${suffix}

${BUILDDIR}/$2:
	@mkdir -p $$(@)

CHECKBUILDDIR/$2: | ${BUILDDIR}/$2
	@echo
	@echo -- Compiling ${LIBDIR}/$1.${suffix} ...
	@echo

${LIBDIR}/$1.${suffix}:  $(call FILTER_MATCH,${objs},$2)
	$$(cc) -shared -o $$(LIBDIR)/$1.$${suffix} $${^} $${LDFLAGS} $${INCLUDES} $${LIBS}

${LIBDIR}/$1.${suffix}.dbg: $(call FILTER_MATCH,${dbg_objs},$2)
	$$(cc) -shared -o $$(LIBDIR)/$1_dbg.$${suffix} $${^} $${LDFLAGS} $${INCLUDES} $${LIBS}
	
${LIBDIR}/$1.${suffix}.wrapper: CHECKBUILDDIR/$2 ${LIBDIR}/$1.${suffix} ${LIBDIR}/$1.${suffix}.dbg

endef

$(foreach p,${PRIMITIVE_PATHS},$(eval $(call auto-create-rules,$(call GET_PRIM_PATH,${p}),${p})))

DLL := ${PRIMITIVES}
DLL := $(addsuffix .${suffix},${DLL})
DLL := $(addprefix ${LIBDIR}/,${DLL})

DLL_WRAPPER := $(addsuffix .wrapper,${DLL})

# Make lib directories as needed
LIB_FOLDERS = $(LIBDIR)/crypto_aead $(LIBDIR)/crypto_hash
${LIB_FOLDERS}:
	@mkdir -p $(@)	
create_lib_folders: | ${LIB_FOLDERS}

# Core rule
create_all_libs: create_lib_folders ${DLL_WRAPPER}  

# Build standard objects
${BUILDDIR}/%.std.o: %.c
	$(cc) $(CFLAGS) $(INCLUDES) -I$(shell dirname $(realpath $(<))) -o $(@) -c $(<)

# Build debug (verbose) objects
${BUILDDIR}/%.dbg.o: %.c
	$(cc) $(CFLAGS) $(INCLUDES) -I$(shell dirname $(realpath $(<))) $(DEBUG_FLAGS) -o $(@) -c $(<)


# Rule for echoing out make variables
p-%  : ; @echo $* = $($*)

clean:
	rm -rf ${BUILDDIR}

.PHONY: clean all create_folders create_all_libs 

ifneq (${MAKECMDGOALS},clean)
DEPS := $(OBJS:%.o=%.d)
-include ${DEPS} __dummy__
endif



