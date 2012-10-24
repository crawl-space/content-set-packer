#!/usr/bin/ruby

require 'openssl'

def extension_from_cert(cert, extension_id)
    x509 = OpenSSL::X509::Certificate.new(cert)
    extensions_hash = Hash[x509.extensions.collect { |ext| [ext.oid, ext.to_der()] }]
    asn1_body = nil
    if extensions_hash[extension_id]
      asn1 = OpenSSL::ASN1.decode(extensions_hash[extension_id])
      OpenSSL::ASN1.traverse(asn1.value[1]) do| depth, offset, header_len, length, constructed, tag_class, tag|
        asn1_body = asn1.value[1].value[header_len, length]
      end
    end
    asn1_body
  end


cert = File.open(ARGV[0], "rb").read

puts extension_from_cert cert, "1.3.6.1.4.1.2312.9.7"
