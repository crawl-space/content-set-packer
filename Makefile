CFLAGS += `pkg-config --libs --cflags zlib`
CFLAGS += -Wall
CC = gcc

all: unpack


%: %.c
	$(CC) $(CFLAGS) -o $@ $<

