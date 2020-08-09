
ifeq ($(CRYPTO_TYPE),)
$(error CRYPTO_TYPE was not specificed )
endif

ifeq ($(CRYPTO_VARIANT),)
$(error CRYPTO_VARIANT was not specificed )
endif

ifeq ($(OS),Windows_NT)
SO_EXT = dll
else
# works for cffi on Linux and macOS
SO_EXT = so
endif

#required only for schwaemm* variants, disables inlining of functions
ifneq ($(findstring schwaemm,$(CRYPTO_VARIANT)),)
CFLAGS += -D_DEBUG
endif

#Default optimization. Prepend, so can be overwritten 
CFLAGS := -Os $(CFLAGS)

CFLAGS += -shared -fPIC

CRYPTO_DIR=crypto_$(CRYPTO_TYPE)

REF_DIR=$(CRYPTO_DIR)/$(CRYPTO_VARIANT)/ref

C_SRCS=$(wildcard $(REF_DIR)/*.c)
C_HDRS=$(wildcard $(REF_DIR)/*.h) $(wildcard includes/*.h)

default: lib/$(CRYPTO_DIR)/$(CRYPTO_VARIANT).$(SO_EXT)

lib/$(CRYPTO_DIR):
	@mkdir -p $@

lib/$(CRYPTO_DIR)/$(CRYPTO_VARIANT).$(SO_EXT): $(C_SRCS) $(C_HDRS) lib/$(CRYPTO_DIR)
	$(CC) $(CFLAGS) -I$(REF_DIR) -Iincludes $(C_SRCS) -o $@