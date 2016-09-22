#!/usr/bin/env python

import urllib2
import json
import sys
import traceback
from optparse import OptionParser

def check_error(error_txt):
	print "UNKNOWN: %s" % error_txt
	sys.exit(3)

def query_api_wpm(options):
	query_url = "https://api-wpm.apicasystem.com:443/v3/Checks/%s/results?mostRecent=1&detail_level=1" % options.checkid

	if options.verbose > 0:
		print "VERBOSE: query_url: %s " % query_url

	passman = urllib2.HTTPPasswordMgrWithDefaultRealm()
	passman.add_password(None, query_url, options.username, options.password)
	authhandler = urllib2.HTTPBasicAuthHandler(passman)
	opener = urllib2.build_opener(authhandler)
	urllib2.install_opener(opener)

	try:
		data = urllib2.urlopen(query_url, timeout=options.timeout)
	except urllib2.HTTPError as he:
		error_txt = "Can not connect to url: %s" % he

		if options.verbose > 0 and hasattr(he, 'read'):
			error_txt = "VERBOSE: %s, MESSAGE: %s" % (query_url, he.read())

		raise check_error(error_txt)
	except urllib2.URLError as ue:
		raise check_error(
			"URL Error: %s" % ue)
	except:
		raise check_error(
			"Unexpected error: ".format(sys.exc_info()[0]))

	return json.loads(data.read())

	return ret_val

def get_credentials_from_file(authfile):
	file = open(authfile, 'r')
	usr_name = None
	passwd   = None
	
	for line in file.read().strip().split('\n'):
		up = line.partition('=')
		if up[0].strip() == "username":
			usr_name = up[2].strip()
		elif up[0].strip() == "password":
			passwd = up[2].strip()

	return (usr_name, passwd)

def get_exec_args():
	usage = "Usage: %prog [-U USER -P PASSWORD|-a AUTH_FILE] -i CHECKID [-t SECONDS] [-v]"

	description = "Fetch the latest value of a check from Apica WebPerformance Monitor API."

	parser = OptionParser(usage=usage, description=description)

	parser.add_option("-i", "--checkid", dest="checkid", action="store",
				help="Your WPM Check ID")

	parser.add_option("-U", "--username", dest="username", action="store",
				help="User to access op5 Monitor REST API with")

	parser.add_option("-P", "--password", dest="password", action="store",
				help="Password for the op5 Monitor REST API user")

	parser.add_option("-a", "--authfile", dest="authfile", action="store",
				help="""Authentication file with login and password. File syntax:
						username=<login>
						password=<password>""")

	parser.add_option("-v", "--verbose", dest="verbose", action="count", default=0,
				help="Increase the level of information in the output. Mainly for debugging.")

	parser.add_option("-t", "--timeout", dest="timeout", action="store", default=10,
				help="Set timeout limit for the connection to the Apica WP-server. Default: 10s")

	(opt, args) = parser.parse_args()

	args_error_state = 0
	args_error_msg   = ""

	if not opt.authfile:
		if not opt.username:
			args_error_msg += "-U, --username is missing.\n"
			args_error_state = 1

		if not opt.password:
			args_error_msg += "-P, --password is missing.\n"
			args_error_state = 1
	elif opt.authfile:
		try:
			(opt.username, opt.password) = get_credentials_from_file(opt.authfile)
		except IOError as e:
			args_error_msg += "Problem while reading the auth file - %s" % e
			args_error_state = 1

	if not opt.checkid:
		args_error_msg += "-i, --checkid is missing.\n"
		args_error_state = 1

	if args_error_state == 1:
		print "ERROR:\n%s" % args_error_msg
		parser.print_usage()
		sys.exit(3)

	return (opt, args)

def resolve_severity(in_severity):
	if in_severity == "I":
		severity = 0
	elif in_severity == "W":
		severity = 1
	elif in_severity == "E":
		severity = 2
	elif in_severity == "F":
		severity = 2
	else:
		severity = 3

	return(severity)

def main():
	(options, args) = get_exec_args()

	query_res = query_api_wpm(options)

	if options.verbose > 0:
		print "VERBOSE: query_res: %s" % str(query_res)

	# Checks that results exist for provided check ID
	if not len(query_res):
		print 'No results exist for check ID "%s"' % options.checkid
		sys.exit(3)

	response_time = ''
	if not query_res[0]["value"] == None:
		response_time = query_res[0]["value"]

	status_str = "Severity: %s - Response time: %s - Message=" % (
				query_res[0]["severity"],
				response_time)

	if "message" in query_res[0].keys():
		status_str += query_res[0]["message"]

	perf_data = "response_time=%s%s" % (response_time,
										query_res[0]["unit"])

	print "%s|%s" % (status_str, perf_data)
	sys.exit(resolve_severity(query_res[0]["severity"]))


if __name__ == '__main__':
	try:
		main()
	except Exception as e:
		print("UNKNOWN: An unhandled exception occurred: %s" % e)
		traceback.print_exc(e, sys.stdout)
		sys.exit(3)
