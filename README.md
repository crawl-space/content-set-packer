== Overview

POC to compile a data set into a modified radix tree, 
and applying huffman encoding.


== Usage

Take in an v1 x509 certificate, and extract the 
content sets, output them to newline delimited output

  $> ruby ./thing.rb d this-cert.pem > this-cert.list

Process this output to generate the compiled output

  $> ruby ./thing.rb c this-cert.list

This would produce a file named 'this-cert.bin'
Then, the unpack the binary with:

  $> ./unpack this-cert.bin


== Code compiles

To compile the 'unpack' command, just run `make`.
( this requires make, gcc, and zlib-devel)

