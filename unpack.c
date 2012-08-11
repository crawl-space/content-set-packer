#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <zlib.h>

#include "huffman.h"

#define CHUNK 1024

struct node {
	int count;
	char **paths;
	struct node **children;
};

static int 
load_dictionary(FILE *source, char ***dictionary, int *dictionary_size,
		bool stats)
{
	int ret;
	z_stream strm;
	unsigned char in[CHUNK];
	int read = 0;

	// XXX keep a ref to buf for free()
	unsigned char *buf = malloc(sizeof(char) * CHUNK);

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

	*dictionary = malloc (sizeof (char *) * (*dictionary_size + 1));
	for (i = 0; i < *dictionary_size; i++) {
		(*dictionary)[i] = (char *) buf + dictionary_offsets[i];
	}

	(*dictionary_size)++;
	// Add in the end of node sentinal string
	char *sentinal = malloc (sizeof (char));
	sentinal[0] = 0x00;
	(*dictionary)[i] = sentinal;

	// rewind back to unused zlib bytes
	if (fseek(source, (long) strm.avail_in * -1, SEEK_CUR)) {
		printf("Error seeking back in stream\n");
		return -1;
	}

	if (stats) {
		printf ("dictionary stats:\n");
		printf ("\tcompressed size: %zu\n", ftell(source));
		printf ("\tuncompressed size: %d\n", read);
		printf ("\tentries found: %d\n", *dictionary_size);
	}

	inflateEnd(&strm);

	return ret == Z_STREAM_END ? 0 : -1;
}

static int
load_content_sets(FILE *stream, struct node **list,
		  struct huffman_node *dictionary_tree, bool stats) {

	unsigned char *buf = malloc (sizeof (char *) * CHUNK);
	size_t read;
	struct node **nodes;
	int i;

	unsigned char count;
	fread(&count, sizeof (unsigned char), 1, stream);

	if (stats) {
		printf("node stats:\n");
		printf("\tnumber of nodes: %hd\n", count);
	}


	nodes = malloc (sizeof (struct node *) * (unsigned short) count);
	for (i = 0; i < (unsigned short) count; i++) {
		nodes[i] = malloc (sizeof (struct node));
	}

	read = fread (buf, sizeof (char), CHUNK, stream);
	if (stats) {
		printf("\tbytes: %zu\n", read);
	}

	/* 
	 * the parent node doesn't go in the huffman tree, as nothing else
	 * references it.
	 */
	struct huffman_node *tree =
		huffman_build_tree ((void **) nodes + 1,
				    (unsigned short) count - 1);

	int bits_read = 0;
	for (i = 0; i < count; i++) {
		struct node *node = nodes[i];
		node->count = 0;

		// XXX hard coded
		node->paths = malloc (sizeof (char *) * 64);
		node->children = malloc (sizeof (struct node *) * 64);

		while (true) {
			char *path = (char *) huffman_lookup (dictionary_tree,
							      buf, &bits_read);
			buf = buf + bits_read / 8;
			bits_read = bits_read % 8;

			if (path[0] == '\0') {
				break;
			}

			struct node *child =
				(struct node *) huffman_lookup (tree, buf,
								&bits_read);
			buf = buf + bits_read / 8;
			bits_read = bits_read % 8;
		
			node->paths[node->count] = path;
			node->children[node->count] = child;
			node->count++;
		}
	}

	*list = nodes[0];
	return 0;
}

struct stack {
	struct stack *next;
	struct stack *prev;
	char *path;
};

static void
dump_content_set (struct node *content_sets, struct stack *head,
		  struct stack *tail)
{
	int i;
	struct stack stack;
	stack.prev = tail;
	tail->next = &stack;

	for (i = 0; i < content_sets->count; i++) {
		stack.path = content_sets->paths[i];
		dump_content_set(content_sets->children[i], head, &stack);
	}

	if (content_sets->count == 0) {
		struct stack *cur = head;

		for (cur = head->next; cur != &stack; cur = cur->next) {
			printf("/%s", cur->path);
		}
		printf("\n");
	}
}

static void
dump_content_sets (struct node *content_sets)
{
	struct stack stack;
	stack.next = NULL;
	stack.path = NULL;

	dump_content_set (content_sets, &stack, &stack);
}

static void
count_content_set (struct node *content_sets, struct stack *head,
		   struct stack *tail, int *count)
{
	int i;
	struct stack stack;
	tail->next = &stack;

	for (i = 0; i < content_sets->count; i++) {
		stack.path = content_sets->paths[i];
		count_content_set(content_sets->children[i], head, &stack,
				  count);
	}

	if (content_sets->count == 0) {
		(*count)++;
	}
}

static void
count_content_sets (struct node *content_sets, int *count)
{
	struct stack stack;
	stack.next = NULL;
	stack.path = NULL;

	count_content_set (content_sets, &stack, &stack, count);
}

static void
check_content_set (struct node *content_sets, const char *path)
{
	struct node *cur = content_sets;
	struct stack head;
	head.next = NULL;
	head.path = NULL;
	struct stack *stack;
	stack = &head;

	bool found;
	while(cur != NULL) {
		int i;
		found = false;
		if (cur->count == 0) {
			found = true;
			break;
		}
		for (i = 0; i < cur->count; i++) {
			int len = strlen(cur->paths[i]);
			if (cur->paths[i][0] == '$' ||
			    !strncmp(cur->paths[i], path, len)) {
				char *slash = index(path, '/');
				/*
				 * we've hit then end. if the content set isn't
				 * also at the end, it's not a match
				 */
				if (slash == NULL ||
				    strlen(slash + 1) == 0) {
					if (cur->count != 0) {
						found = false;
						break;
					}
				}
				path = slash + 1;	
				found = true;

				struct stack *top =
					malloc (sizeof (struct stack));
				stack->next = top;
				top->path = cur->paths[i];
				stack = top;
				cur = cur->children[i];
				break;
			}
		}
		if (!found) {
			break;
		}
	}

	if (!found) {
		printf ("no match found\n");
	} else {
		struct stack *cur;
		for (cur = head.next; cur != NULL; cur = cur->next) {
			printf("/%s", cur->path);
		}
		printf ("\n");
	}
}

int
main(int argc, char **argv) {
	FILE *fp;
	char **dictionary;
	int dictionary_size;
	struct node *content_sets;

	bool stats = false;
	bool dump = false;
	bool check = false;

	if (argc < 3) {
		printf("usage: unpack [mode] [bin file]\n");
		printf("mode is one of:\n");
		printf("s - print stats for the binary content set blob\n");
		printf("d - dump the blob contents to stdout\n");
		printf("c - check if a path is allowed by the blob\n");
		printf("\n");
		printf("c requires an extra argument after the bin file,\n"
		       "for the path to check. the path must start  with "
		       "a '/'\n\n");
		return -1;
	}

	switch (argv[1][0]) {
		case 's':
			stats = true;
			break;
		case 'd':
			dump = true;
			break;
		case 'c':
			check = true;
			if (argc != 4) {
				printf("error: must specify a path "
				       "with check\n");
				return -1;
			}
			break;
	}

	fp = fopen(argv[2], "r");
	if (fp == NULL) {
		printf("error: unable to open file: %s\n", argv[1]);
		return -1;
	}

	if (load_dictionary(fp, &dictionary, &dictionary_size, stats)) {
		printf("dictionary inflation failed. exiting\n");
		return -1;
	}

	struct huffman_node *dictionary_tree =
		huffman_build_tree ((void **) dictionary, dictionary_size);

	if (load_content_sets(fp, &content_sets, dictionary_tree, stats)) {
		printf("node list parsing failed. exiting\n");
		return -1;
	}

	if (stats) {
		int count = 0;
		count_content_sets(content_sets, &count);
		printf("\tcontent paths: %d\n", count);
	} else if (dump) {
		dump_content_sets (content_sets);
	} else if (check) {
		const char *path = argv[3];
		if (path[0] == '/') {
			path++;
		}
		check_content_set (content_sets, path);
	}

	return 0;
}
