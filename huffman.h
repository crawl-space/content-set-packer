#include <stdbool.h>
#include <stdint.h>

struct huffman_node {
	int weight;
	void *value;
	struct huffman_node *left;
	struct huffman_node *right;
};

struct huffman_node *huffman_build_tree(void **values, uint64_t count);

void *huffman_lookup (struct huffman_node *tree, unsigned char *bits,
		      int *bits_read, bool print);

void huffman_reverse_lookup (struct huffman_node *tree, void *value);
