#!/usr/bin/python
""" Used to monitor the number of used op5 LogServer hosts
    Either give a warning and critical level to monitor
    or let the plugin return critical when you have reached
    the number of licensed file according to the license file
"""

import os
import subprocess
from sys import argv
from xml.etree import ElementTree
from optparse import OptionParser

license_file = '/etc/op5license/op5license.xml'
num_used_hosts_file = '/tmp/logserver-license.dat'
state_msg = "UNKNOWN"
exit_code = 3

command_args = []
command_args = argv

parser = OptionParser()
parser.add_option('-w', '--warning',
	dest='warn',
	action='store',
	type='int',
	default=0,
	help='Warning threshold')

parser.add_option('-c', '--critical',
	dest='crit',
	action='store',
	type='int',
	default=0,
	help='Critical threshold')

	
(options, args) = parser.parse_args(command_args)

warn = options.warn
crit = options.crit

def logserver_dat_file_exists():
	""" Returns true if the cron generated data file exists"""
	return os.path.isfile(num_used_hosts_file)

def license_file_exists():
	""" Return true if a license file exists """
	return os.path.isfile(license_file)

def check_license_file():
	""" Checking the license file
	    Returns true if it is ok
	"""
	fh = open('/dev/null', 'w')
	check_cmd = ['/opt/op5sys/bin/op5license-verify', license_file]
	check_output = subprocess.call(check_cmd, stdout=fh, stderr=fh)
	fh.close()

	return check_output

def get_num_used_hosts():
	""" Return the number of hosts used in op5 LogServer """
	fh = open(num_used_hosts_file, 'r')
	hosts = fh.read()
	fh.close()

	return len(hosts.split(':'))

def get_num_licensed_hosts():
	""" Get the number of licensed hosts from the license file """
	""" If license type is Site 'Unlimited' is returned """
	lf = ElementTree.parse(license_file)

	lic_type = ""
	lic_num  = ""
	for lic_stuff in lf.findall('item'):
		if lic_stuff.attrib['name'] == "LogserverLicenseType":
			
			lic_type = lic_stuff.attrib['value']
		if lic_stuff.attrib['name'] == "LogserverHosts":
			lic_num = lic_stuff.attrib['value']

	if lic_type == "Site":
		return "Unlimited"
	else:
		return lic_num

# Make sure the dat file updated by the logserver
# count_host.sh cron job exists.
if logserver_dat_file_exists() == False:
	print "CRITICAL: The license check cronjob (update_hosts.sh) has not been executed yet"
	exit(2)

# Check for license file
if license_file_exists() == False:
	print "CRITIAL: License file does not exists"
	exit(2)

# Check if license file is valid
if check_license_file() != 0:
	print "CRITICAL: You are using a invalid license file"
	exit(2)

used_hosts = get_num_used_hosts()
lic_hosts = get_num_licensed_hosts()
# If crit is set to 0 then set it to
# the number of licenses defined in the op5licsense.xml file
if crit == 0:
	crit = lic_hosts

# If warn is set to 0 then set it to
# the number of licenses defined in the op5licsense.xml file
if warn == 0:
	warn = lic_hosts

if used_hosts >= crit:
	state_msg = "CRITICAL"
	exit_code = 2
elif used_hosts >= warn:
	state_msg = "WARNING"
	exit_code = 1
else:
	state_msg = "OK"
	exit_code = 0

if lic_hosts == "Unlimited":
	print "%s: You are using %s of %s hosts in your op5 LogServer|used_hosts=%s;;;" % (state_msg, used_hosts, lic_hosts, used_hosts)
	exit(0)

print "%s: You are using %s of %s hosts in your op5 LogServer|used_hosts=%s;%s;%s; license=%s" % (state_msg, used_hosts, lic_hosts, used_hosts, warn, crit, lic_hosts)
exit(exit_code)
