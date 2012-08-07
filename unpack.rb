#!/usr/bin/env ruby

# stdlib
require 'stringio'
require 'zlib'

def inflate(data)
  Zlib::Inflate.inflate(data)
end

def deflate(data)
  Zlib::Deflate.deflate(data)
end

# there is not a difference for us, in these two
def inflate2(data)
  zlib = Zlib::Inflate.new(15)
  buff = zlib.inflate(data)
  zlib.finish
  zlib.close
  buff
end

def load_dictionary(data)
  data.split("\x00")
end

if $0 == __FILE__
  abort("usage: %s <bin_file> ..." % __FILE__) unless (ARGV.length > 0)

  ARGV.each do |arg|
    file = File.open(arg)

    z_data_io = StringIO.new(file.read())
    data = inflate(z_data_io.read())
    e_pos = deflate(data).bytesize()
    z_data_io.seek(e_pos)

    puts "data is:"
    puts load_dictionary(data).map {|x| "\t#{x}" }

    puts "dictionary stats:"
    puts "\tcompressed size: %d" % deflate(data).bytesize()
    puts "\tuncompressed size: %d" % data.bytesize()

    buf = z_data_io.read()
    puts "Read %d bytes\n" % buf.bytesize()

  end
end
 

