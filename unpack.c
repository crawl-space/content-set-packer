#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <zlib.h>

#include "huffman.h"

#define CHUNK 1024

struct node {
	struct node *next;
	unsigned int path;
	unsigned int children[];
};

static int 
load_dictionary(FILE *source, char ***dictionary, int *dictionary_size)
{
	int ret;
	z_stream strm;
	unsigned char in[CHUNK];
	int read = 0;

	// XXX keep a ref to buf for free()
	unsigned char *buf = malloc(sizeof(char) * CHUNK);

	printf("unpacking string dictionary\n");


	/* allocate inflate state */
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	strm.opaque = Z_NULL;
	strm.avail_in = 0;
	strm.next_in = Z_NULL;
	ret = inflateInit(&strm);
	if (ret != Z_OK) {
		printf("ERROR\n");
		return ret;
	}

	/* decompress until deflate stream ends or end of file */
	do {
		strm.avail_in = fread(in, 1, CHUNK, source);
		if (ferror(source)) {
			(void)inflateEnd(&strm);
			return -1;
		}
		if (strm.avail_in == 0) {
		    printf("read entire file\n");
		    break;
		}
		strm.next_in = in;

		/* run inflate() on input until output buffer not full */
		do {
			    strm.avail_out = CHUNK;
			    strm.next_out = buf;
			    ret = inflate(&strm, Z_NO_FLUSH);
			    assert(ret != Z_STREAM_ERROR);  /* state not clobbered */
			    switch (ret) {
			    case Z_NEED_DICT:
				printf("NEED ERROR\n");
				ret = Z_DATA_ERROR;     /* and fall through */
			    case Z_DATA_ERROR:
				printf("DATA ERROR\n");
			    case Z_MEM_ERROR:
				(void)inflateEnd(&strm);
				printf("MEMORY ERROR\n");
				return -1;
			    }
			    read += CHUNK - strm.avail_out;
		} while (strm.avail_out == 0);

//		read += CHUNK;
		/* done when inflate() says it's done */
	} while (ret != Z_STREAM_END);

	int offset_size = 64;
	int *dictionary_offsets = malloc (sizeof (int) * offset_size);
	*dictionary_size = 1;

	int i;
	int j = 0;
	dictionary_offsets[j++] = 0;
	for (i = 0; i < read; i++) {
		if (buf[i] == '\0') {
			if (i != read - 1) {
				dictionary_offsets[j++] = i + 1;
				(*dictionary_size)++;
				if (j == offset_size) {
					offset_size = offset_size * 2;
					dictionary_offsets =
						realloc (dictionary_offsets,
							 sizeof (int) *
							 offset_size);
				}
			}
		}
	}

	*dictionary = malloc (sizeof (char *) * offset_size);
	for (i = 0; i < offset_size; i++) {
		(*dictionary)[i] = (char *) buf + dictionary_offsets[i];
	}

	// rewind back to unused zlib bytes
	if (fseek(source, (long) strm.avail_in * -1, SEEK_CUR)) {
		printf("Error seeking back in stream\n");
		return -1;
	}

	printf ("dictionary stats:\n");
	printf ("\tcompressed size: %zu\n", ftell(source));
	printf ("\tuncompressed size: %d\n", read);
	printf ("\tentries found: %d\n", *dictionary_size);
	inflateEnd(&strm);

	return ret == Z_STREAM_END ? 0 : -1;
}

static int
load_node_list(FILE *stream, struct node **list) {

	unsigned char buf[CHUNK];
	size_t read;
	struct node *np = malloc(sizeof(struct node));
	*list = np;

	read = fread(buf, 1, CHUNK, stream);
	printf("Read %zu bytes\n", read);

	return 0;
}

int
main(int argc, char **argv) {
	FILE *fp;
	char **dictionary;
	int dictionary_size;
	struct node *list;

	if (argc != 2) {
		printf("usage: unpack <bin file>\n");
		return -1;
	}

	fp = fopen(argv[1], "r");
	if (fp == NULL) {
		printf("error: unable to open file: %s\n", argv[1]);
		return -1;
	}

	if (load_dictionary(fp, &dictionary, &dictionary_size)) {
		printf("dictionary inflation failed. exiting\n");
		return -1;
	}

	struct huffman_node *tree = huffman_build_tree ((void **) dictionary,
							dictionary_size);

	int bits_read;
	short bits = 0xC0;

	printf("\n\n%s\n", huffman_lookup (tree, (unsigned char *) &bits, &bits_read));
	
	if (load_node_list(fp, &list)) {
		printf("node list parsing failed. exiting\n");
		return -1;
	}

	return 0;
}
