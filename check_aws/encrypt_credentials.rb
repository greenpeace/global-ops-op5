#!/usr/bin/ruby
#--
# Nagios API Ruby library
#
# Ruby Gem Name::  secludit-nagios
# Author:: $Author: $ 
# Copyright:: 
# License::   Distributes under the same terms as Ruby
# Home:: $Id: encrypt_credentials.rb 1044 2011-03-04 12:51:53Z  $
#++

%w[ getoptlong pp base64 openssl].each { |f| require f }


RETURN_CODE_OK = 0
RETURN_CODE_NOK = 1


# specify the options we accept and initialize and the option parser
verbose = 0
credential_file = ''
ret = RETURN_CODE_NOK
use_rsa = false
aws_access_key_id = ''
aws_secret_access_key = ''
enc_aws_access_key_id = ''
enc_aws_secret_access_key = ''


  def display_menu
    puts "Usage: #{$0} [-v] -s <server> -h <host> -c <credentials>"
    puts "  --help, -h:              This Help"
    puts "  --verbose, -v:           Enable verbose mode"
    puts "  --access_key_id, -A:     Amazon Access Key ID"
    puts "  --secret_access_key, -S: Amazon Secret Access Key"
    puts "  --credential_file, -f:   Path to a File containing the Amazon EC2 Credentials"
    exit
  end


opts = GetoptLong.new


# add options
opts.set_options(
        [ "--help", "-h", GetoptLong::OPTIONAL_ARGUMENT ], \
        [ "--verbose", "-v", GetoptLong::OPTIONAL_ARGUMENT ], \
        [ "--access_key_id", "-A", GetoptLong::OPTIONAL_ARGUMENT ], \
        [ "--secret_access_key", "-S", GetoptLong::OPTIONAL_ARGUMENT ], \
        [ "--credential_file", "-f", GetoptLong::OPTIONAL_ARGUMENT ]
      )

# test usage
unless ARGV.length >= 4
  display_menu
end

# parse options
opts.each { |opt, arg|
  case opt
    when '--help'
      display_menu
    when '--verbose'
      verbose = 1
    when '--access_key_id'
      aws_access_key_id = arg
    when '--secret_access_key'
      aws_secret_access_key = arg
    when '--credential_file'
      credential_file = arg
  end
}

if verbose == 1
  puts "** Encrypting AWS Credentials: access_key_id: #{aws_access_key_id}, secret_access_key: #{aws_secret_access_key}"
end

begin
  key_file = "/opt/plugins/check_aws/check_aws.pem" #TODO: make configurable?
  if use_rsa
    rsa_pubkey = OpenSSL::PKey::RSA.new(File.read(key_file))

    enc_aws_access_key_id = rsa_pubkey.public_encrypt(Base64.encoode(aws_access_key_id))
    enc_aws_secret_access_key = rsa_pubkey.public_encrypt(Base64.encoode(aws_secret_access_key))
  else
    cipher = OpenSSL::Cipher::Cipher.new('bf-cbc')

    tmp_data = ''
    cipher.encrypt
    cipher.key = Digest::SHA256.digest(File.read(key_file))
    tmp_data = cipher.update(aws_access_key_id)
    tmp_data << cipher.final
    enc_aws_access_key_id = Base64.encode64(tmp_data)

    tmp_data = ''
    cipher.encrypt
    cipher.key = Digest::SHA256.digest(File.read(key_file))
    tmp_data = cipher.update(aws_secret_access_key)
    tmp_data << cipher.final
    enc_aws_secret_access_key = Base64.encode64(tmp_data)
  end
  fd = File.open(credential_file, "w")
  fd.syswrite(" ec2_access_id #{enc_aws_access_key_id}")
  fd.syswrite(" ec2_access_key #{enc_aws_secret_access_key}")
  fd.close
  ret = RETURN_CODE_OK
rescue Exception => e
  puts "Error occured while encrypting AWS credentials: #{e}"
  exit RETURN_CODE_NOK
end

if verbose == 1
  puts "==> Encrypted AWS Credentials: access_key_id: #{enc_aws_access_key_id}, secret_access_key: #{enc_aws_secret_access_key}"
end

exit ret
