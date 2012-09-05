PACKING ALGORITHM
=================

Begin with a list of content set paths:
```
/content/dist/rhel/$releasever/$basearch/os
/content/dist/rhel/$releasever/$basearch/debug
/content/dist/rhel/$releasever/$basearch/source/SRPMS
/content/dist/jboss/source
/content/beta/rhel/$releasever/$basearch/os
/content/beta/rhel/$releasever/$basearch/debug
/content/beta/rhel/$releasever/$basearch/source/SRPMS
```

Create a prefix tree out of the paths, where each node in the tree contains the
names of its children, rather than the children containing its own name:

```
+-------+                              +------+
|       |                              |      |
|-------+                              |------|
|content+--+-------+                   |source+-+---+
+-------+  |       |                   +------+ |   |
           |-------|                   |        |---|
           |dist   +--------+-------+  |        +---+
        +--+beta   |        |       |  |
        |  +-------+        |-------|  |
        |                   |jboss  +--+
+-------+                   |rhel   +--+
|       |                   +-------+  |
|-------|                              |
|rhel   +--+-----------+               +-----------+
+-------+  |           |               |           |
           |-----------|               |-----------|
+----------+$releasever|               |$releasever+--+
|          +-----------+               +-----------+  |
|                                                     |
+---------+                                 +---------+
|         |                                 |         |
|---------|                                 |---------|
|$basearch+--+                           +--+$basearch|    +---+
+---------+  |                           |  +---------+    |   |
             |                           |                 |---|
             +--------+                  +-------+         +---+
             |        |                  |       |         |
             |--------|                  |-------|         |
+---+--------+os      |                  |os     +---------+
|   |     +--+debug   |                  |debug  +-----------+---+
|---|     |  |source  +--+               |source +--+        |   |
+---+     |  +--------+  |               +-------+  |        |---|
          |              |                          |        +---+
      +---+              +------+                   |
      |   |              |      |                   +-----+
      |---|              |------|                   |     |
      +---+           +--+SRPMS |                   |-----|
                      |  +------+                   |SRPMS+--+---+
                      |                             +-----+  |   |
                  +---+                                      |---|
                  |   |                                      +---+
                  |---|
                  +---+
```

This eliminates the duplication in the prefixes of our paths. We now only have
one instance of the word "content", for example. We now find any duplicate
subtrees, remove the duplicate, and point all references from the duplicate to
the original:

```
+-------+                              +------+
|       |                              |      |
|-------+                              |------|
|content+--+-------+                   |source+-+
+-------+  |       |                   +------+ | 
           |-------|                   |        |
           |dist   +--------+-------+  |        |
        +--+beta   |        |       |  |        |
        |  +-------+        |-------|  |        |
        |                   |jboss  +--+        |
+-------+                +--+rhel   |           |
|       |                |  +-------+           |
|-------|                |                      |
|rhel   +--+-----------+-+                      |
+-------+  |           |                        |
           |-----------|                        |
+----------+$releasever|                        |
|          +-----------+                        |
|                                               |
+---------+                                     |
|         |                                     |
|---------|                                     |
|$basearch+--+                                  |
+---------+  |                                  |
             |                                  |
             +--------+                         |
             |        |                         |
             |--------|                         |
     +-------+os      |                         |
     |    +--+debug   |                         |
     |    |  |source  +--+                      |
     |    |  +--------+  |                      |
     |    |              |                      |
     |    |              +------+               |
     |    +-------+      |      |               |
     |            |      |------|               |
     |            |   +--+SRPMS |               |
     |            |   |  +------+               |
     |            |   |                         |
     +------------+---+-------------------------+
                  |   |           
                  |---|
                  +---+
```

With this structure, we can begin creating the packed data. The first step is
to build a huffman coding for the string components of the path. In the
example, all strings are used only once, except for rhel and source. We create
a list of all the strings, ordered from least to most occurance. This list is
the one written out in the path dictionary section of the binary packing. The
ordering used in the list is what we then feed into a huffman tree for paths.
thus, even though both os and debug occur just once in the above DAG, depending
on the ordering in the list, one will be assigned a higher weight than the
other (which helps the other side decode the binary format). The string huffman
tree also includes a special sentinal value to indicate end of node in the
binary format. This value should not be written to the binary packing, should
be given the highest weight, and should be some string that is not used in the
path strings themselves (to avoid collision).

Next, we order the nodes from the above DAG by order of reference from other
nodes, from least to most references. This ensures the root of the DAG is
always first, as it has no references. Similar to the strings, we create a
huffman tree for the nodes. The root node should not be included in the huffman
tree, as it is never referenced by any other nodes, so we don't need to use up
any potential address space on it.

We can then iterate over the node list, writing each one out to the binary
packing. Within each node, for each string and node pair that it references, we
look up each in their respective huffman trees, and write the huffman coding to
the binary packing.

At the end of a node, we use the special sentinal value from the string huffman
tree to indicate end of node.
