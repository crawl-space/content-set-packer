Overview
========

A POC to take a list of content sets (basically a listing of directories) and
pack them into a format optimized for space efficieny and reading.

Compilation and Usage
=====================

This repo holds two commands, `thing.rb` (TODO: give it a better name) and
`unpack`. `thing.rb` is used to pack content sets into our custom data format.
`unpack` reads the format.

To compile the `unpack` command, just run `make`.
This requires make, gcc, and zlib-devel.

thing.rb
--------

`thing.rb` generates files in our packed data format from newline delimited
lists of content sets. It can also dump content sets from a hosted v1
entitlement certificate, and print the tree structure of the content sets.

Take in an v1 x509 certificate, and extract the content sets, output them to
newline delimited output

  `./thing.rb d this-cert.pem`

This would produce a file named `this-cert.txt`

To see this txt list, in the tree format, do:

  `./thing.rb p this-cert.txt | less`

Process this output to generate the packed data format:

  `./thing.rb c this-cert.txt`

This would produce a file named `this-cert.bin`. The `c` command expects as
input a file containing a newline delimited list of content sets; you are free
to manipulate the output from a pem file or come up with your own crazy listing
to push the boundaries of the data format.

`thing.rb` supports a "-v" verbose flag to print debug information.

unpack
------

`unpack` can read and examine files in our data format.

To view stats on a packed file (size of dictionary, number of unique nodes,
etc):

  `./unpack s this-cert.bin`

To reconstruct the content sets and dump them to stdout:

  `./unpack d this-cert.bin`

To check if the path `/content/rhel/6/6Server/x86_64/os/repodata/repomd.xml`
matches a content set in `this-cert.bin`:

  `./unpack c this-cert.bin /content/rhel/6/6Server/x86_64/os/repodata/repomd.xml`

There is also a WIP ruby version of unpack, unpack.rb
