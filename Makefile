
CFLAGS += $(shell pkg-config --libs --cflags zlib)
CFLAGS += -Wall

ifndef CC
CC = gcc
endif

APP = unpack
TMP_FILES = $(wildcard *~)

all: $(APP)

%: %.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -rf $(APP) $(TMP_FILES)

