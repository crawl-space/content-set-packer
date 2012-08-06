== Overview ==

POC to compile a data set into a modified radix tree, 
and applying huffman encoding.


== Usage ==

Take in an v1 x509 certificate, and extract the 
content sets, output them to newline delimited output

  `$> ruby ./thing.rb d this-cert.pem`

This would produce a file named 'this-cert.txt'

To see this txt list, in the tree format, do:

  `$> ruby ./thing.rb p this-cert.txt | less`

Process this output to generate the compiled dictionary output

  `$> ruby ./thing.rb c this-cert.txt`

This would produce a file named 'this-cert.bin'
Then, the unpack the binary with:

  `$> ./unpack this-cert.bin`
or
  `$> ruby ./unpack.rb this-cert.bin`


The 'thing.rb' supports a "-v" verbose flag.

== Code compiles ==

To compile the 'unpack' command, just run `make`.
( this requires make, gcc, and zlib-devel)

