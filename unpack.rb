#!/usr/bin/env ruby

$:.unshift(File.dirname(__FILE__))
require 'huffman.rb'
require 'thing.rb'

def inflate(data)
  Zlib::Inflate.inflate(data)
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

    z_data = file.read()
    data = inflate(z_data)
    puts "data is:"
    puts load_dictionary(data).map {|x| "\t#{x}" }

    puts "dictionary stats:"
    puts "\tcompressed size: %d" % z_data.bytesize()
    puts "\tuncompressed size: %d" % data.bytesize()
  end
end
 

