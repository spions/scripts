#!/usr/bin/ruby

require 'yaml'
require 'uri'
require 'net/http'

# Fetch facts from puppet master
URL     = "https://localhost:8140/production/facts/"
CA_PATH = "/var/lib/puppet/ssl/ca/ca_crt.pem"

NODE    = ARGV.first

ca_path = ENV[ 'PUPPET_CA_PATH' ] || CA_PATH
url     = ENV[ 'PUPPET_URL' ] || URL

uri = URI.parse( "#{url}#{NODE}" )
require 'net/https' if uri.scheme == 'https'
request = Net::HTTP::Get.new( uri.to_s, initheader = { 'Accept' => 'yaml' } )
http = Net::HTTP.new( uri.host, uri.port )
if uri.scheme == 'https'
  http.use_ssl = true
  http.ca_file = ca_path
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
end
res = http.start { |http| http.request( request ) }

node = YAML::parse( res.body )
facts = node.select( "values" )[0]
