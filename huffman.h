#include <stdbool.h>

struct huffman_node {
	int weight;
	void *value;
	struct huffman_node *left;
	struct huffman_node *right;
};

struct huffman_node *huffman_build_tree(void **values, int count);

void *huffman_lookup (struct huffman_node *tree, unsigned char *bits,
		      int *bits_read, bool print);
