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

# usage: ./content_from_pem.rb 5286016419950084643.pem

class Node
  attr_accessor :path, :children

  def initialize(path)
    @path = path
    @children = []
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
    parent.path += "/" + parent.children[0].path
    parent.children = parent.children[0].children
  end
  return parent
end

def binary_write(file, hash)
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
      h = compress_prefix(parent)
#      binary_write(file, parent)
      file.write(parent.to_json)
    end
    puts "Wrote:\n [%d] %s\n [%d] %s" % [File.size(txt_name), txt_name, File.size(json_name), json_name]

  end
end
