
CFLAGS += $(shell pkg-config --libs --cflags zlib)
CFLAGS += -Wall -g

ifndef CC
CC = gcc
endif

APP = unpack
TMP_FILES = $(wildcard *~)

all: $(APP)

unpack: unpack.c huffman.c huffman.h
	$(CC) $(CFLAGS) -o $@ unpack.c huffman.c huffman.h

clean:
	rm -rf $(APP) $(TMP_FILES)

