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

def mk_hash(sgmts, hash = nil)
  hash = {} unless hash.kind_of? Hash
  segment = sgmts.shift
  return hash if segment.nil?
  unless hash.has_key?(segment)
    hash[segment] = mk_hash(sgmts, {})
  else
    hash[segment].update(mk_hash(sgmts, hash[segment]))
  end
  return hash
end

def compress_prefix(hash)
  hash.keys.each do |key|
    hash[key] = compress_prefix(hash[key])
    if hash[key].length == 1
      new_key = key + "/" + hash[key].keys[0]
      hash[new_key] = hash[key].values[0]
      hash.delete(key)
    end
  end
  return hash
end

if $0 == __FILE__
  if ARGV.length == 0
    cert_data = STDIN.read

    cert = OpenSSL::X509::Certificate.new(cert_data)
    content_hex = cert.extensions.detect {|ext| ext.oid == 'subjectKeyIdentifier' }
    abort('ERROR: no X509v3 extension for subjectKeyIdentifier') unless content_hex
  
    puts akamai_hex_to_content_set(content_hex.value)
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
      h = {}
      sets.each do |set|
        line = set.start_with?("/") ? set[1..-1] : set
      
        # => ["content", "beta", "rhel", "server", "6", "$releasever", "$basearch", "scalablefilesystem", "debug"]
        chunks = line.split("/")
        h = mk_hash(chunks, h)
      end
      h = compress_prefix(h)
      file.write(h.to_json)
    end
    puts "Wrote:\n [%d] %s\n [%d] %s" % [File.size(txt_name), txt_name, File.size(json_name), json_name]

  end
end
