#include "huffman.h"

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

static int
find_smallest (struct huffman_node **nodes, int count, int different)
{
	int smallest;
	int i;

	for (i = 0; nodes[i]->weight == -1; i++);

	if (i == different) {
		for (i++; nodes[i]->weight == -1; i++);
	}
	smallest = i;

	for (i = smallest + 1; i < count; i++) {
		if (i == different || nodes[i]->weight == -1) {
			continue;
		}

		if (nodes[i]->weight < nodes[smallest]->weight) {
			smallest = i;
		}
	}

	return smallest;
}

struct huffman_node *
huffman_build_tree(void **values, int count)
{
	int i;
	struct huffman_node **nodes;


	nodes = malloc (sizeof (struct huffman_node *) * count);
	for (i = 0; i < count; i++) {
		struct huffman_node *node =
			malloc (sizeof (struct huffman_node));

		node->value = values[i];
		node->weight = i;
		node->left = NULL;
		node->right = NULL;

		nodes[i] = node;
	}

	int tree1;
	int tree2;
	for (i = 1; i < count; i++) {
		struct huffman_node *tmp;

		tree1 = find_smallest (nodes, count, -1);
		tree2 = find_smallest (nodes, count, tree1);

		tmp = nodes[tree1];

		nodes[tree1] = malloc (sizeof (struct huffman_node));
		nodes[tree1]->weight = tmp->weight + nodes[tree2]->weight;
		nodes[tree1]->value = NULL;
		nodes[tree1]->left = nodes[tree2];
		nodes[tree1]->right = tmp;

		nodes[tree2]->weight = -1;
	}

	return nodes[tree1];
}

void *
huffman_lookup (struct huffman_node *tree, unsigned char *bits, int *bits_read)
{

	struct huffman_node *node = tree;
	*bits_read = 0;

	while (true) {
		if (node->value != NULL) {
			return node->value;
		}

		if ((bits[0] << *bits_read % 8 & 0x80) == 0) {
			node = node->left;
		} else {
			node = node->right;
		}

		(*bits_read)++;
		if (*bits_read % 8 == 0) {
			bits++;
		}
	}
}
