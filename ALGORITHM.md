PACKING ALGORITHM
=================

Begin with a list of content set paths:
'''
/content/dist/rhel/$releasever/$basearch/os
/content/dist/rhel/$releasever/$basearch/debug
/content/dist/rhel/$releasever/$basearch/source/SRPMS
/content/dist/jboss/source
/content/beta/rhel/$releasever/$basearch/os
/content/beta/rhel/$releasever/$basearch/debug
/content/beta/rhel/$releasever/$basearch/source/SRPMS
'''

Create a prefix tree out of the paths, where each node in the tree contains the
names of its children, rather than the children containing its own name:

'''
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
'''

This eliminates the duplication in the prefixes of our paths. We now only have
one instance of the word "content", for example. We now find any duplicate
subtrees, remove the duplicate, and point all references from the duplicate to
the original:

'''
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
+-------+-------------------+rhel   |           |
|       |                   +-------+           |
|-------|                                       |
|rhel   +--+-----------+                        |
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
'''

