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

class Node
  attr_accessor :children, :de_duped, :offset, :written

  def initialize(path)
    @children = {}
    @de_duped = false
    @offset = ran_char(2)
  end

  def has_key?(key)
    @children.has_key? key
  end

  def get_child(name)
    @children[name]
  end

  def de_duped=(val)
    @de_duped = val
    @children.each do |key, child|
      child.de_duped = true
    end
  end

  def signature
      sorted = @children.keys.sort do |a, b|
        a <=> b
      end
      "[" + sorted.collect { |key| key + @children[key].signature }.join("|") + "]"
   end

  def flatten()
    flat = [self]
    @children.each do |key, child|
      flat += child.flatten
    end
    flat
  end

  def to_json(*a)
    @children.to_json(*a)
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
    parent.children[segment] = mk_hash(sgmts, Node.new(segment))
  else
    mk_hash(sgmts, parent.get_child(segment))
#  else
#    hash[segment].update(mk_hash(sgmts, hash[segment]))
  end
  return parent
end

def compress_prefix(parent)
  parent.children.keys.each do |key|
    child = parent.children[key]
    compress_prefix(child)
    if child.children.length == 1
        puts "compressing #{key} and #{child.children.keys[0]}"
        new_key = key + "/" + child.children.keys[0]
        parent.children[new_key] =  child
        child.children = child.children.values[0].children
        parent.children.delete(key)
    end
  end
  return parent
end

def replace(tree, old, new)
  tree.flatten.uniq.each do |node|
    node.children.keys.each do |key|
      if node.children[key] == old
        node.children[key] = new
      end
    end
  end
end

# given a tree of nodes, try and find branches that match the children of node.
# if found, replace those branches with node's children
def de_dupe(tree, node)
  tree.flatten.uniq.each do |sub_tree|
    if sub_tree == node
      # nothing
    elsif node.signature == sub_tree.signature
      sub_tree.de_duped = true
      replace(tree, sub_tree, node)
      puts "Found dupe! " + node.signature unless node.signature == "[]"
    end
  end
end

def de_dupe_driver(tree)
  before = tree.flatten.length
  tree.flatten.each do |node|
    de_dupe(tree, node) unless node.de_duped
  end

  puts "Total nodes Before: #{before} After: #{tree.flatten.uniq.length}"
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
  if parent.written
    return
  end

  parent.children.each do |path, child|
#    puts "PATH: " + child.path
#    file.write(child.path)
#    file.write("\0")
    # index of path string
    file.write_bits(string_huff.encode(path))
    # offset to node
    # index of node, that is.
    file.write_bits(node_huff.encode(child))
  end
  # reserve null byte for end of node info
  # 3 0s are reserved in our name huffman table to denote end of node
  file.write_bits("000")
  parent.children.each do |path, child|
      binary_write(file, child, string_huff, node_huff)
      child.written = true
  end
end

def write_strings(file, strings)
  string_io = StringIO.new()
  strings.each_key do |string|
    string_io.write(string)
    string_io.write("\0")
  end
  zlib = Zlib::Deflate.new(Zlib::BEST_COMPRESSION, 15, Zlib::MAX_MEM_LEVEL)
  file.write zlib.deflate(string_io.string, Zlib::FINISH)
end

def collect_strings(parent)
  strings = {}
  parent.flatten.uniq.each do |node|
    node.children.each_key do |key|
      strings[key] ||= 0
      strings[key] += 1
    end
  end
  strings
end

def build_huffman_for_strings(parent)
    paths = []
    parent.flatten.uniq.each do |node|
      node.children.each_key {|key| paths << key}
    end
    HuffmanEncoding.new paths
end

def build_huffman_for_nodes(parent)
    nodes = parent.flatten.uniq
    refs = {}
    nodes.each do |node|
      node.children.each do |key, node|
        refs[node] ||= 0
        refs[node] += 1
      end
    end
    refs[parent] = 1
    expanded = []
    refs.each do |node, freq|
      freq.times {expanded << node}
    end
    table = HuffmanEncoding.new expanded
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
#      parent = compress_prefix(parent)

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
