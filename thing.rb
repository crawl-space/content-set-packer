#!/usr/bin/env ruby
=begin
 usage: ruby ./thing.rb <dpc> 5286016419950084643.{pem,txt}
=end

# stdlib
require 'openssl'
require 'zlib'
require 'stringio'
require 'logger'
require 'pp'

# gems
require 'rubygems'
begin
  require 'json'
rescue
  abort('ERROR: plz2run #> gem install json')
end

# local
require './huffman'

$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG
#$log.level = Logger::FATAL

$sentinal = "SENTINAL"

class BitWriter

  def initialize(stream)
    @stream = stream
    @byte = 0x00
    @count = 7
  end

  def write(char)
    if char == '1'
      @byte |= 0x01 << @count
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
    @stream.write(Array(@byte).pack('c'))
    @count = 7
    @byte = 0x00
  end
end

class Node
  attr_accessor :children, :de_duped, :offset, :written

  def initialize(path)
    @children = {}
    @de_duped = false
    @offset = ran_char(2)
    @sig = nil
  end

  def has_key?(key)
    @children.has_key? key
  end

  def [](name)
    @children[name]
  end

  def de_duped=(val)
    @de_duped = val
    @children.each do |key, child|
      child.de_duped = true
    end
  end

  def signature
      return @sig unless @sig.nil?
      sorted = @children.keys.sort do |a, b|
        a <=> b
      end
      @sig = "[" + sorted.collect { |key| key + @children[key].signature }.join("|") + "]"
      return @sig
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

  def to_h
    Hash[@children.map {|k, v| [k, v.to_h] }]
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
    mk_hash(sgmts, parent[segment])
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

def replace(list, old, new)
  puts "replace"
  length = list.length
  list.each do |node|
    node.children.keys.each do |key|
      if node.children[key] == old
        node.children[key] = new
      end
    end
  end
end

# given a list of nodes, try and find branches that match the children of node.
# if found, replace those branches with node's children
def de_dupe(list, node)
  list.each do |sub_tree|
    if sub_tree == node or sub_tree.de_duped
      next
    end
      # nothing
    sub_tree.children.keys.each do |key|
      next if sub_tree.children[key] == node
      next if sub_tree.children[key].de_duped
      if sub_tree.children[key].signature == node.signature
        sub_tree.children[key].de_duped = true
        sub_tree.children[key] = node
        $log.info("Found dupe!" ) { node.signature unless node.signature == "[]" }
      end
    end
  end
end

def de_dupe_driver(tree)
  list = tree.flatten
  before = list.length
  i = 1
  list.each do |node|
    $log.info('de_dupe_driver') { "de dupe #{i} / #{before}" }
    i += 1
    de_dupe(list, node) unless node.de_duped
  end

  puts "Total nodes Before: #{before} After: #{tree.flatten.uniq.length}"
end

# simulate random file offsets
def ran_char(val)
  val = (0..val - 1).map {rand(256).chr}.join
  return val
end

def binary_write(file, node_list, string_huff, node_huff)
  node_list.each do |node|
    $log.debug('binary_write') { "begin node: " + node_huff.encode(node) }
    node.children.each do |path, child|
      # index of path string
      $log.debug('binary_write') { "\tpath: " + path.inspect + "; encoded: " + string_huff.encode(path).inspect }
      file.write_bits(string_huff.encode(path))
      # offset to node
      # index of node, that is.
      file.write_bits(node_huff.encode(child))
      $log.debug('binary_write') { "\tnode encoded: " + node_huff.encode(child) }
    end
    # end of node is indicated by the special sentinal huffman coding of \0
    file.write_bits(string_huff.encode($sentinal))
  end
end

def list_from_file(path)
  paths = File.read(path)
  paths.split("\n")
end

def tree_from_list(sets)
  parent = Node.new("")
  sets.each do |set|
    line = set.start_with?("/") ? set[1..-1] : set

    # => ["content", "beta", "rhel", "server", "6", "$releasever", "$basearch", "scalablefilesystem", "debug"]
    chunks = line.split("/")
    parent = mk_hash(chunks, parent)
  end
  parent
end

def write_strings(file, strings)
  string_io = StringIO.new()

  strings.each do |string|
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

  list = []
  strings.sort { |l, r| l[1] <=> r[1] }.each do |string, weight|
    list << string
  end

  list
end

def build_huffman_for_strings(strings)
    paths = []
    i = 1
    strings.each do |string|
      i.times { paths << string }
      i += 1
    end
    # add on sentinal string
    i.times { paths << $sentinal }
    puts paths
    HuffmanEncoding.new paths
end

def build_node_frequencies(parent)
  nodes = parent.flatten.uniq
  refs = {}
  nodes.each do |node|
    node.children.each do |key, child|
      refs[child] ||= 0
      refs[child] += 1
    end
  end

  list = []
  refs.sort { |l, r| l[1] <=> r[1] }.each do |node, weight|
    list << node
  end

  list
end


def build_huffman_for_nodes(list)
    # parent doesn't have to go into the table
    i = 1
    expanded = []
    list.each do |node|
      i.times {expanded << node}
      i += 1
    end
    table = HuffmanEncoding.new expanded
end

if $0 == __FILE__
  if ARGV.include?("-v")
    $log.level = Logger::DEBUG
    ARGV.delete("-v")
  end
  if ARGV.length != 2
    puts "usage: thing.rb <d|c> <file>"
    puts "please specify one of d or c"
    puts "d - dump an x509 cert into a newline delimited output"
    puts "p - pretty print the newline delimited list, as a tree"
    puts "c - compress the newline delimited input list of paths"
    exit()
  end
  
  case ARGV[0]
  when 'd'
    cert_data = File.read(ARGV[1])

    cert = OpenSSL::X509::Certificate.new(cert_data)
    content_hex = cert.extensions.detect {|ext| ext.oid == 'subjectKeyIdentifier' }
    abort('ERROR: no X509v3 extension for subjectKeyIdentifier') unless content_hex
    ext = File.extname(ARGV[1])
    txt_name = File.basename(ARGV[1], ext) + ".txt"
 
    File.open(txt_name, "w+") do |file|
      file.write(akamai_hex_to_content_set(content_hex.value).join("\n"))
      file.write("\n")
    end

  when 'p'
    sets = list_from_file(ARGV[1])
    parent = tree_from_list(sets)

    de_dupe_driver(parent)
    pp parent.to_h
  when 'c'

    paths = File.read(ARGV[1])
    sets = paths.split("\n")
    ext = File.extname(ARGV[1])
    binary = File.basename(ARGV[1], ext) + ".bin"

    File.open(binary, "w+") do |file|
      parent = Node.new("")
      sets.each do |set|
        line = set.start_with?("/") ? set[1..-1] : set
      
        # => ["content", "beta", "rhel", "server", "6", "$releasever", "$basearch", "scalablefilesystem", "debug"]
        chunks = line.split("/")
        parent = mk_hash(chunks, parent)
      end
      puts "priming node signatures"
      parent.signature
      puts "removing duplicates"
      de_dupe_driver(parent)
    #      parent = compress_prefix(parent)

      puts "building huffman table for nodes"
      node_list = build_node_frequencies(parent)
      node_huff = build_huffman_for_nodes(node_list)

      # XXX add sentinal value to strings to indicate end of node.
      # should be most frequent one. the string itself doesn't have to
      # be stored, since we just care about the bitstring.
      
      strings = collect_strings(parent)
    
      puts "building huffman table for strings"
      string_huff = build_huffman_for_strings(strings)
 
      puts "writing"
      write_strings(file, strings)

      # write out the number of unique path nodes into 1 or more bytes.  if <
      # 128 nodes, write in a single byte. if > 128 nodes, the first byte will
      # begin with a '1' to indicate as such. the following bits in the byte
      # indicate how many bytes following the first byte are used to store the
      # size.

      node_count = node_list.count + 1
      puts node_count
      file.write([node_count].pack("c"))

      bit_file = BitWriter.new file
      binary_write(bit_file, [parent] + node_list, string_huff, node_huff)
      bit_file.pad
    end

  end # esac
end
