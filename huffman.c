#include "huffman.h"

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

static int
find_smallest (struct huffman_node **nodes, int count, int different)
{
	// 'real' weights will always be positive.
	int smallest = -1;
	int i;

	for (i = 0; i < count; i++) {
		if (i == different) {
			continue;
		}

		if (smallest == -1 ||
		    nodes[i]->weight < nodes[smallest]->weight) {
			smallest = i;
		}
	}

	return smallest;
}

static void
shift_nodes (struct huffman_node **nodes, int count, int start)
{
	int i;
	for (i = start; i + 1 < count; i++) {
		nodes[i] = nodes[i + 1];
	}
	nodes[i] = NULL;
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
		node->weight = i + 1;
		node->left = NULL;
		node->right = NULL;

		nodes[i] = node;
	}

	int tree1;
	int tree2;
	for (; count > 1; count--) {
		struct huffman_node *tmp;

		tree1 = find_smallest (nodes, count, -1);
		tree2 = find_smallest (nodes, count, tree1);

		tmp = malloc (sizeof (struct huffman_node));
		tmp->weight = nodes[tree1]->weight + nodes[tree2]->weight;
		tmp->value = NULL;
		tmp->left = nodes[tree1];
		tmp->right = nodes[tree2];

		if (tree1 > tree2) {
			shift_nodes (nodes, count, tree1);
			shift_nodes (nodes, count, tree2);
		} else {
			shift_nodes (nodes, count, tree2);
			shift_nodes (nodes, count, tree1);
		}

		nodes[count - 2] = tmp;
	}

	return nodes[0];
}

void *
huffman_lookup (struct huffman_node *tree, unsigned char *bits, int *bits_read,
		bool print)
{

	struct huffman_node *node = tree;

	while (true) {
		if (node == NULL) {
			return NULL;
		}
		if (node->value != NULL) {
			return node->value;
		}

		if ((bits[0] << *bits_read % 8 & 0x80) == 0) {
			node = node->left;
			if (print) {
				putchar ('0');
			}
		} else {
			node = node->right;
			if (print) {
				putchar ('1');
			}
		}

		(*bits_read)++;
		if (*bits_read % 8 == 0) {
			bits++;
		}
	}
}

struct stack {
	struct stack *next;
	bool val;
};

static void
huffman_lookup_driver (struct huffman_node *tree, void *value,
		       struct stack *head, struct stack *cur)
{
	if (tree->value == value) {
		struct stack *x = head->next;
		while (x != NULL) {
			if (x->val) {
				putchar ('1');
			} else {
				putchar ('0');
			}
			x = x->next;
		}

		return;
	}

	struct stack *next = malloc (sizeof (struct stack));
	next->next = NULL;
	cur->next = next;
	
	if (tree->left != NULL) {
		next->val = false;
		huffman_lookup_driver (tree->left, value, head, next);
	}
	if (tree->right != NULL) {
		next->val = true;
		huffman_lookup_driver (tree->right, value, head, next);
	}

	cur->next = NULL;
	free (next);
}

// given a value, print its code to stdout.
void
huffman_reverse_lookup (struct huffman_node *tree, void *value)
{
	struct stack head;
	head.next = NULL;
	huffman_lookup_driver (tree, value, &head, &head);
}
