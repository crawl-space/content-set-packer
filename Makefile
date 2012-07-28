CFLAGS=`pkg-config --libs --cflags zlib`

unpack: unpack.c
	gcc -Wall $(CFLAGS) -o unpack unpack.c
