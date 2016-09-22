#!/usr/bin/env python

import nagiosplugin
import urllib
import urllib2
import json
import sys
from optparse import OptionParser

class Apiquery(nagiosplugin.Resource):
    def __init__(self, options):
        self.options = options

    def __create_filter_url(self, column=0):
        filter_str = urllib.urlencode({'query':self.options.filter})
        filter_url = ""
        if column == 1:
            # Set --sort mtime, to use this with log server filter
            filter_url = "https://%s:%s/api/filter/query?%s&sort=%s+desc&limit=1&columns=%s&format=json" % (
                        self.options.host,self.options.port, filter_str, self.options.sort, self.options.column)
        else:
            filter_url = "https://%s:%s/api/filter/count?%s&format=json" % (
                        self.options.host,self.options.port, filter_str)

        if self.options.verbose > 1:
            print "Filter URL: %s" % filter_url

        return filter_url

    def do_query(self, column=0):
        filter_url = self.__create_filter_url(column)

        passman = urllib2.HTTPPasswordMgrWithDefaultRealm()
        passman.add_password(None, filter_url, self.options.username, self.options.password)
        authhandler = urllib2.HTTPBasicAuthHandler(passman)
        opener = urllib2.build_opener(authhandler)
        urllib2.install_opener(opener)

        try:
            data = urllib2.urlopen(filter_url)
        except urllib2.HTTPError as he:
            error_txt = "Invalid answer from server: %s. (Execute the plugin with -v for more info.)" % he

            if self.options.verbose > 0 and hasattr(he, 'read'):
                error_txt = "URL: %s, MESSAGE: %s" % (filter_url, he.read())

            print "UNKNOWN: %s" % error_txt
            sys.exit(3)

        except urllib2.URLError as ue:
            raise nagiosplugin.CheckError(
                "URL Error: %s" % ue)
        except:
            raise nagiosplugin.CheckError(
                "Unexpected error: ".format(sys.exc_info()[0]))

        res = json.loads(data.read())
        return res

class Filter(nagiosplugin.Resource):
    def __init__(self, options):
        self.options = options

    def query_filter(self, column=0):
        api_q = Apiquery(self.options)
        res = api_q.do_query(column)

        if 'error' in res:
            print "ERROR: " + res['error']
            sys.exit(3)

        if self.options.verbose > 2:
            print(json.dumps(res, sort_keys=True, indent=4))

        return res

    def probe(self):
        filter_res = self.query_filter()

        return [nagiosplugin.Metric(self.options.label,
                filter_res["count"],
                min=0,
                context=self.options.label)]

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

class MessageSummary(nagiosplugin.Summary):
    def __init__(self, label, message):
        self.label = label
        self.message = message

    def ok(self, results):
        super(MessageSummary, self).ok(results)
        return (str(results[self.label]) + " " + self.message)

    def problem(self, results):
        super(MessageSummary, self).problem(results)
        return (str(results[self.label]) + " " + self.message)

    def verbose(self, results):
        super(MessageSummary, self).verbose(results)
        return ("Results: " + str(results[self.label]))

def get_exec_args():
    usage = """Usage: %prog -H HOST [-U USER -P PASSWORD|-a AUTH_FILE] -f 'FILTER'
       [-s 'STATUS TEXT'] [-l LABEL] [-w WARNING] [-c CRITICAL]"""

    description = """check_op5_filter is a monitoring plugin designed to check op5 Monitor list view filters.
It will get the hit counts via op5 Monitor's HTTP API.
You may set a custom status output as well as perf data label to have the result showing
what you are monitoring. Use the filter editor in the op5 Monitor list views to get the exact filter you like to monitor."""

    parser = OptionParser(usage=usage, description=description)

    parser.add_option("-f", "--filter", dest="filter", action="store",
                help="Filter to query")

    parser.add_option("-H", "--host", dest="host", action="store",
                help="op5 Monitor host to query against")

    parser.add_option("-p", "--port", dest="port", action="store", default="443",
                help="TCP port to use when connecting to the op5 Monitor host. Default: 443")

    parser.add_option("-U", "--username", dest="username", action="store",
                help="User to access op5 Monitor REST API with")

    parser.add_option("-P", "--password", dest="password", action="store",
                help="Password for the op5 Monitor REST API user")

    parser.add_option("-a", "--authfile", dest="authfile", action="store",
                help="""Authentication file with login and password. File syntax:
username=<login>
password=<password>""")

    parser.add_option("-l", "--label", dest="label", action="store", default="count",
                help="Custom label on your performance data. Default is 'count'")

    parser.add_option("-s", "--statustext", dest="statustext", action="store", default="Filter count: {value}",
                help="""Custom text in your status output.
Default is 'Filter count: {value}'
You may include the number of hits in your own
custom status text just by adding the placeholder {value} where
you would like the number to show up, e.g.:
-s 'Network contains {value} outages'""")

    parser.add_option("-w", "--warning", dest="warning", action="store",
                help="Set warning threshold. Supports nagios ranges")

    parser.add_option("-c", "--critical", dest="critical", action="store",
                help="Set critical threshold. Supports nagios ranges")

    parser.add_option("-t", "--timeout", dest="timeout", action="store", type="int", default=10,
                help="Set plugin execution timeout, in seconds. Default: 10")

    parser.add_option("-v", "--verbose", dest="verbose", action="count", default=0,
                help="Increase the level of information in the output. Mainly for debugging.")

    parser.add_option("-C", "--column", dest="column", action="store",
                help="""Set the name of the column you would like to
show as status output.
This is mainly supposed to be used when you are
monitoring logger filters. You will most likely
use 'msg' as the column to show.""")

    parser.add_option("-S", "--sort", dest="sort", action="store",
                help="""Set the column name you like to sort
on when using -C|--column.
The two most likely to use for logger filters are:
'mtime' or 'rtime'""")

    (opt, args) = parser.parse_args()

    args_error_state = 0
    args_error_msg   = ""
    if not opt.host:
        args_error_msg += "-H, --host is missing.\n"
        args_error = 'true'

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

    if not opt.filter:
        args_error_msg += "-f, --filter is missing.\n"
        args_error_state = 1

    if opt.column and not opt.sort:
        args_error_msg += "You must set -S|--sort if you are using -C|--column\n"
        args_error_state = 1
    elif opt.sort and not opt.column:
        args_error_msg += "You must set -C|--column if you are using -S|--sort\n"
        args_error_state = 1
    elif opt.column and opt.column.count(',') > 0:
        args_error_msg += "You can only specify one column with -C|--column\n"
        args_error_state = 1
    elif opt.sort and opt.sort.count(',') > 0:
        args_error_msg += "You can only specify one column with -S|--sort\n"
        args_error_state = 1

    try:
        nsc = nagiosplugin.ScalarContext(opt.label, opt.warning, opt.critical, fmt_metric=opt.statustext)
    except ValueError as ve:
        args_error_msg += "Wrong thresholds usage - %s" % ve
        args_error_state = 1

    if args_error_state == 1:
        print "ERROR:\n%s" % args_error_msg
        parser.print_usage()
        sys.exit(3)

    return (opt, args, nsc)



@nagiosplugin.guarded
def main():
    (options, args, nagios_scalar) = get_exec_args()

    if options.column:
        api_q = Apiquery(options)
        resq = api_q.do_query(1)
        resq_str = ""

        if len(resq) > 0:
            resq_str = str(resq[0][options.column])

        if options.verbose > 2:
            print(json.dumps(resq, sort_keys=True, indent=4))

        if 'error' in resq:
            print "ERROR: " + resq['error']
            sys.exit(3)

        check = nagiosplugin.Check(
                Filter(options),
                nagios_scalar,
                MessageSummary(options.label, resq_str)
                )
    else:
        check = nagiosplugin.Check(
                Filter(options),
                nagios_scalar,
                )

    check.main(verbose=options.verbose, timeout=options.timeout)

if __name__ == '__main__':
    main()
