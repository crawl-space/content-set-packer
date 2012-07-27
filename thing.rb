#!/usr/bin/env ruby

require 'openssl'
require 'zlib'
require 'stringio'
require 'rubygems'
begin
  require 'json'
rescue
  abort('ERROR: plz2run #> gem install json')
end

require './huffman'

# usage: ./content_from_pem.rb 5286016419950084643.pem

class BitWriter

  def initialize(stream)
    @stream = stream
    @byte = 0x00
    @count = 8
  end

  def write(char)
    if char == '1'
      @byte |= 1 << @count
    end
    @count -= 1
    if @count == -1
      self.pad
    end
  end

  def write_bits(string)
    string.each_char do |c|
      self.write(c)
    end
  end

  def pad()
    @count = 8
    @stream.write(Array(@byte).pack('C'))
    @byte = 0x00
  end
end

class Children

   attr_accessor :children, :written

   def initialize()
     @children = []
     @written = false
   end

   def each()
     @children.each do |child|
       yield child
     end
   end

   def collect()
     @children.each do |child|
       yield child
     end
   end

  def length()
    @children.length
  end
  def [](i)
    @children[i]
  end

  def []=(i, val)
    @children[i] = val
  end

   def <<(other)
     @children << other
   end

   def join(str)
     @children.join(str)
   end

   def signature
      @children.sort! do |a, b|
        a.path <=> b.path
      end
      "[" + @children.collect { |x| x.path + x.signature }.join("|") + "]"
   end
end

class Node
  attr_accessor :path, :children, :de_duped, :offset

  def initialize(path)
    @path = path
    @children = Children.new
    @sig = nil
    @de_duped = false
    @offset = ran_char(2)
  end

  def has_key?(key)
    @children.each do |child|
      if child.path == key
        return true
      end
    end
    return false
  end

  def get_child(name)
    @children.each do |child|
      if child.path == name
        return child
      end
    end
    return nil
  end

  def de_duped=(val)
    @de_duped = val
    @children.each do |child|
      child.de_duped = true
    end
  end

  def signature()
    if @sig.nil?
      @sig = @children.signature
    end
    @sig
  end

  def flatten()
    flat = [self]
    @children.each do |child|
      flat += child.flatten
    end
    flat
  end

  def to_json(*a)
      {
          @path => @children
      }.to_json(*a)
  end
end

def akamai_hex_to_content_set(akamai_hex)
  gzipped_hex = akamai_hex.gsub(":","").chomp("00")
  gzipped_data = [gzipped_hex].pack("H*")
  gzipped_data_io = StringIO.new(gzipped_data)
  gz = Zlib::GzipReader.new(gzipped_data_io)
  content_sets = gz.read.split("|")
  begin
    gz.close
  rescue Zlib::GzipFile::NoFooter
  end
  return content_sets
end

def mk_hash(sgmts,  parent)
  segment = sgmts.shift
  return parent if segment.nil?
  unless parent.has_key?(segment)
    parent.children << mk_hash(sgmts, Node.new(segment))
  else
    mk_hash(sgmts, parent.get_child(segment))
#  else
#    hash[segment].update(mk_hash(sgmts, hash[segment]))
  end
  return parent
end

def compress_prefix(parent)
  parent.children.each do |child|
    compress_prefix(child)
  end
  if parent.children.length == 1
    puts "compressing #{parent.path} and #{parent.children[0].path}"
    parent.path += "/" + parent.children[0].path
    parent.children = parent.children[0].children
  end
  return parent
end

# given a tree of nodes, try and find branches that match the children of node.
# if found, replace those branches with node's children
def de_dupe(tree, node)
  tree.flatten.each do |sub_tree|
    if sub_tree.children == node.children
      # nothing
    elsif node.signature == sub_tree.signature
      sub_tree.de_duped = true
      sub_tree.children = node.children
      puts "Found dupe! " + node.signature unless node.signature == "[]"
    end
  end
end

def de_dupe_driver(tree)
  tree.flatten.each do |node|
    de_dupe(tree, node) unless node.de_duped
  end
end

# simulate random file offsets
def ran_char(val)
  val = (0..val - 1).map {rand(256).chr}.join
  return val
end

def binary_write(file, parent, string_huff, node_huff)
#  file.write(parent.path)
#  file.write("\0")
  #offset to child node indicies
   # not needed, can just go write to children indicies
  #file.write(ran_char)
  if parent.children.written
    puts "not writing children of #{parent.path}"
    return
  end

  # number of paths
  length = parent.children.length.to_s
#  path_count = (3 - length.length).times.collect { |i| "0" }.join + length
#  file.write(path_count)
#  puts "CHILD COUNT: " + parent.children.length.to_s
  parent.children.each do |child|
#    puts "PATH: " + child.path
#    file.write(child.path)
#    file.write("\0")
    # index of path string
    file.write_bits(string_huff.encode(child.path))
    # offset to node
    # index of node, that is.
    file.write_bits(node_huff.encode(child))
  end
  # reserve null byte for end of node info
  # 3 0s are reserved in our name huffman table to denote end of node
  file.write_bits("000")
  parent.children.each do |child|
      binary_write(file, child, string_huff, node_huff)
      child.children.written = true
  end
end

def write_strings(file, strings)
  string_io = StringIO.new()
  strings.each_key do |string|
    puts "STRING: " + string
    string_io.write(string)
    string_io.write("\0")
  end
  zlib = Zlib::Deflate.new(Zlib::BEST_COMPRESSION, 15, Zlib::MAX_MEM_LEVEL)
  file.write zlib.deflate(string_io.string, Zlib::FINISH)
end

def collect_strings(parent)
  strings = {}
  parent.flatten.each do |node|
    strings[node.path] = [0, ran_char(1)] unless strings.has_key? node.path
    strings[node.path][0] += 1
  end
  strings
end

def build_huffman_for_strings(parent)
    nodes = parent.flatten.uniq
    paths = nodes.collect {|node| node.path}
    table = HuffmanEncoding.new paths
end

def build_huffman_for_nodes(parent)
    nodes = parent.flatten
    table = HuffmanEncoding.new nodes
end

if $0 == __FILE__
  if ARGV.length == 0
    cert_data = STDIN.read

    cert = OpenSSL::X509::Certificate.new(cert_data)
    content_hex = cert.extensions.detect {|ext| ext.oid == 'subjectKeyIdentifier' }
    abort('ERROR: no X509v3 extension for subjectKeyIdentifier') unless content_hex
  
    puts akamai_hex_to_content_set(content_hex.value).join("|")
  end

  ARGV.each do |arg|
    next unless FileTest.file?(arg)
    cert_data = File.read(arg)

    cert = OpenSSL::X509::Certificate.new(cert_data)
    content_hex = cert.extensions.detect {|ext| ext.oid == 'subjectKeyIdentifier' }
    abort('ERROR: no X509v3 extension for subjectKeyIdentifier') unless content_hex
  
    ext = File.extname(arg)
    txt_name = File.basename(arg, ext) + ".txt"
    json_name = File.basename(arg, ext) + ".json"
    binary = File.open(File.basename(arg, ext) + ".bin", "w")
    
    sets = akamai_hex_to_content_set(content_hex.value)

    File.open(txt_name, "w+") do |file|
      file.write(sets)
    end
    File.open(json_name, "w+") do |file|
      parent = Node.new("")
      sets.each do |set|
        line = set.start_with?("/") ? set[1..-1] : set
      
        # => ["content", "beta", "rhel", "server", "6", "$releasever", "$basearch", "scalablefilesystem", "debug"]
        chunks = line.split("/")
        parent = mk_hash(chunks, parent)
      end
      # prime the signatures
      parent.signature
      de_dupe_driver(parent)
      parent = compress_prefix(parent)

      string_huff = build_huffman_for_strings(parent)
      node_huff = build_huffman_for_nodes(parent)
      
      strings = collect_strings(parent)
      write_strings(binary, strings)
      bit_file = BitWriter.new binary
      binary_write(bit_file, parent, string_huff, node_huff)
      bit_file.pad
      file.write(parent.to_json)

    end
    puts "Wrote:\n [%d] %s\n [%d] %s" % [File.size(txt_name), txt_name, File.size(json_name), json_name]

  end
end
