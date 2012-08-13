File/Data Format
================

This document details how the format is stored. For details on how to create
the structures that will populate this data format, and how to create the
structures from this format, please see the included source code (sorry!)

Data is stored in network byte order.  The format consists of 2 sections. Both
sections represent huffman trees ordered by weight, from least to most
important. In order, these sections are:

Path Dictionary
---------------

A DEFLATE encoded list of null terminated strings. strings are ordered by
frequency of apperance, begining with the least frequently seen string. DEFLATE
specifies an end of stream sentinel, so we don't need to demarque the end of
this section. No zlib header or footer should be included in this section.

node dictionary
---------------

The node dictionary begins with 1 or more bytes indicating the number of nodes. If there are less than 128 nodes, a single byte is used, as the unsigned integer number of nodes in the node dictionary. If there are more than 127 nodes, the first byte is used to indicate the number of subsequent bytes used to store the node dictionary count, after discarding the most significant bit from the first byte.

For example, if we had 512 nodes, we would need to store that in two bytes. Thus, the first byte in the node dictionary would be:

    10000010

Indicating that the next two bytes store a 16bit unsigned integer value.

Following the length encoding are N entries consisting of:
  1 or more pairs of (path index, node index)
  an end of node indicator

We store the path and node indicies as arbitrary length bit strings
(their addresses in their respective huffman tables/trees). The end of
node indicator is the huffman code for a special sentinal value added
to the dictionary huffman tree (and _not_ included in the dictionary
itself, as the value doesn't matter, only its lookup code). This sentinal
value should be added to the huffman tree with the highest weight.

### Rationale for length field

The path dictionary doesn't contain a length field, but the node dictionary
does. Why is this? Because the nodes within the node dictionary refer to the
huffman codings of other nodes in the dictionary, and because huffman codings
are variable length, we must know how many nodes exist in the dictionary to
prepopulate the huffman tree with empty nodes before we begin filling in their
values. That way, for each node, we can figure out which nodes it refers to,
and know where to terminate a huffman coding lookup, rather than just
consuming all the rest of the bits in the input.

Building the Huffman Trees
--------------------------

Huffman coding is ambiguous; a given list of (value, weight) pairs can create
different valid huffman trees, depending on the algorithm used. Thus it is
important to use an algorithm that will give the same ordering. See the code
for more details, but in a nuttshell:

When comparing nodes, the node that weighs the least becomes the left child. If
weight is tied, the node that was examined longest ago becomes the left child.
