#!/usr/bin/ruby
#--
# Nagios API Ruby library
#
# Ruby Gem Name::  secludit-nagios
# Author:: $Author: $ 
# Copyright:: 
# License::   Distributes under the same terms as Ruby
# Home:: $Id: check_ec2_status.rb 1044 2011-03-04 12:51:53Z  $
#++

%w[ getoptlong rubygems AWS pp base64 openssl].each { |f| require f }


# define static values
EC2_STATUS_CODE_PENDING	= 0
EC2_STATUS_CODE_RUNNING	= 16
EC2_STATUS_CODE_STOPPING = 64
EC2_STATUS_CODE_STOPPED	= 80

EC2_STATUS_NAME_PENDING	= "pending"
EC2_STATUS_NAME_RUNNING	= "running"
EC2_STATUS_NAME_STOPPING = "stopping"
EC2_STATUS_NAME_STOPPED = "stopped"

NAGIOS_CODE_OK = 0		# UP
NAGIOS_CODE_WARNING = 1		# UP or DOWN/UNREACHABLE*
NAGIOS_CODE_CRITICAL = 2	# DOWN/UNREACHABLE
NAGIOS_CODE_UNKNOWN = 3		# DOWN/UNREACHABLE
NAGIOS_OUTPUT_SEPARATOR = "|"

# specify the options we accept and initialize and the option parser
verbose = 0
#owner_id = ''
instance_id = ''
credential_file = ''
server = ''
address = ''
ret = NAGIOS_CODE_UNKNOWN 
use_rsa = false


  def display_menu
    puts "Usage: #{$0} [-v] -s <server> -h <host> -c <credentials>"
    puts "  --help, -h:            This Help"
    puts "  --verbose, -v:         Enable verbose mode"
    puts "  --server, -s:          Amazon Server URL"
    puts "  --address, -a:         Amazon Instance Address"
    puts "  --instance_id, -i:     Amazon Instance ID"
    puts "  --credential_file, -f: Path to a File containing the Amazon EC2 Credentials"
    exit
  end


opts = GetoptLong.new


# add options
opts.set_options(
        [ "--help", "-h", GetoptLong::OPTIONAL_ARGUMENT ], \
        [ "--verbose", "-v", GetoptLong::OPTIONAL_ARGUMENT ], \
        [ "--server", "-s", GetoptLong::OPTIONAL_ARGUMENT ], \
        [ "--address", "-a", GetoptLong::OPTIONAL_ARGUMENT ], \
        [ "--instance_id", "-i", GetoptLong::OPTIONAL_ARGUMENT ], \
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
    when '--server'
      server = arg
    when '--address'
      address = arg
      #server = URI.parse( "http://" + address.gsub(/^.*?\.(.+)$/, "\\1") ).host
      case address
        when /us-east/
          server = "ec2.us-east-1.amazonaws.com"
        when /us-west/
          server = "ec2.us-west-1.amazonaws.com"
        when /eu-west/
          server = "ec2.eu-west-1.amazonaws.com"
        when /ap-southeast/
          server = "ec2.ap-southeast-1.amazonaws.com"
        when /ap-northeast/
          server = "ec2.ap-northeast-1.amazonaws.com"
        else
          server = "ec2.us-east-1.amazonaws.com"
      end 
    when '--instance_id'
      instance_id = arg
    when '--credential_file'
      credential_file = arg
  end
}

begin
  content = File.read(credential_file)
  #access_key_id = content.match(/^\sec2_access_id\s.*$/).to_s.gsub(/^\sec2_access_id\s/,"")
  #secret_access_key = content.match(/^\sec2_access_key\s.*$/).to_s.gsub(/^\sec2_access_key\s/,"")
  key_file = "/opt/plugins/check_aws/check_aws.pem" #TODO: make configurable?
  encrypted_access_key_id = content.match(/^\sec2_access_id.*ec2_access_key/m).to_s.gsub("ec2_access_id","").gsub("ec2_access_key","").strip
  encrypted_secret_access_key = content.match(/^\sec2_access_key.*/m).to_s.gsub("ec2_access_key","").strip
  if use_rsa
    decrypt_key = OpenSSL::PKey::RSA.new(File.read(key_file))
  
    access_key_id = decrypt_key.private_decrypt(Base64.decode64(encrypted_access_key_id))
    secret_access_key = decrypt_key.private_decrypt(Base64.decode64(encrypted_secret_access_key))
  else
    cipher = OpenSSL::Cipher::Cipher.new('bf-cbc')

    cipher.decrypt
    cipher.key = Digest::SHA256.digest(File.read(key_file))
    access_key_id = cipher.update(Base64.decode64(encrypted_access_key_id))
    access_key_id << cipher.final

    cipher.decrypt
    cipher.key = Digest::SHA256.digest(File.read(key_file))
    secret_access_key = cipher.update(Base64.decode64(encrypted_secret_access_key))
    secret_access_key << cipher.final
  end
rescue Exception => e
  puts "Error occured while retrieving and decrypting credentials for instance #{instance_id} on Amazon Server: $#{server}: #{e}"
  exit NAGIOS_CODE_CRITICAL
end

if verbose == 1
  puts "** Launching EC2 status retrieval on instance ID: #{instance_id} on Amazon Server: $#{server}"
  #puts "Amazon Server: #{URI.parse(server).host}"
  puts "Amazon Server: #{server}"
end

#puts "Instance Address: #{address}, Amazon server: #{server}"

# Real job
begin
  #ec2 = AWS::EC2::Base.new( :access_key_id => access_key_id, :secret_access_key => secret_access_key, :server => URI.parse(server).host)
  ec2 = AWS::EC2::Base.new( :access_key_id => access_key_id, :secret_access_key => secret_access_key, 
                            :use_ssl => true, :server => server )
rescue Exception => e
  puts "Error occured while trying to connect to EC2 server: #{server}\n" + e
  exit NAGIOS_CODE_CRITICAL
end

begin
  ec2_instance = ec2.describe_instances( :instance_id => instance_id )
rescue Exception => e
  puts "Error occured while trying to retrieve EC2 instance: #{instance_id}\n" + e
  exit NAGIOS_CODE_CRITICAL
end

# interesting debug
#pp ec2_instance

ec2_instance_nb = ec2_instance.reservationSet.item.length
# check whether we get the correct instance
if (ec2_instance_nb == 0)
  puts "Error occured while retrieving EC2 instance: No instance found for instance ID #{instance_id}"
  exit NAGIOS_CODE_CRITICAL
elsif (ec2_instance_nb > 1)
  puts "Error occured while retrieving EC2 instance: More than one instance found for instance ID #{instance_id}"
  exit NAGIOS_CODE_CRITICAL
end

#puts "Number of instance: #{ec2_instance.reservationSet.item.length}"
#puts "Owner ID: #{ec2_instance.ownerId}"
ec2_state_name = ec2_instance.reservationSet.item[0].instancesSet.item[0].instanceState.name
ec2_state_code = ec2_instance.reservationSet.item[0].instancesSet.item[0].instanceState.code

nagios_perf_state = 0
case ec2_state_name
  when EC2_STATUS_NAME_PENDING
    ret = NAGIOS_CODE_WARNING
    nagios_state_name = "WARNING"
  when EC2_STATUS_NAME_RUNNING
    ret = NAGIOS_CODE_OK
    nagios_state_name = "OK"
    nagios_perf_state = 1
  when EC2_STATUS_NAME_STOPPING
    ret = NAGIOS_CODE_WARNING
    nagios_state_name = "WARNING"
  when EC2_STATUS_NAME_STOPPED
    ret = NAGIOS_CODE_CRITICAL
    nagios_state_name = "CRITICAL"
end

# print SERVICEOUTPUT
#puts "EC2 Status Check: #{nagios_state_name} - State Name: #{ec2_state_name}, State Code: #{ec2_state_code}"
service_output="EC2 Status Check: #{nagios_state_name} - State Name: #{ec2_state_name}, State Code: #{ec2_state_code}"

# print SERVICEPERFDATA
#puts ""
service_perfdata="running=#{nagios_perf_state}"

# print LONGSERVICEOUTPUT
#puts ""

# output
puts "#{service_output}|#{service_perfdata}"

exit ret
