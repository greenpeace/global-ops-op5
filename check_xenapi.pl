#!/usr/bin/perl
#
# Nagios plugin to monitor Xen Hypervisor via XenAPI. Supports Citrix Xen solutions.
#
# License: Creative Commons
# Copyright (c) 2011 op5 AB
# Author: Kostyantyn Hushchyn <op5-users@lists.op5.com>
#
# For direct contact with any of the op5 developers send a mail to
# op5-users@lists.op5.com
# Discussions are directed to the mailing list op5-users@op5.com,
# see http://lists.op5.com/mailman/listinfo/op5-users
#
# This work is licensed under the Creative Commons
# Attribution-NonCommercial-ShareAlike 3.0 Unported License. To view a copy
# of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/
# or send a letter to Creative Commons, 444 Castro Street, Suite 900,
# Mountain View, California, 94041, USA.

use lib "/opt/plugins/xen";
use strict;
use warnings;
use vars qw($PROGNAME $VERSION $output $result $debug_timeshift);
use Nagios::Plugin;
use File::Basename;
use Time::Local;
use XenAPI::Session;
use XenAPI::RRD;
use Data::Dumper;

$PROGNAME = basename($0);
$VERSION = '0.1.0';

my $np = Nagios::Plugin->new(
  usage => "Usage: %s -S <sessionurl> [ -H <hostname> ] [ -N <vmname> ]\n"
    . "    -u <user> -p <pass>\n"
    . "    -l <command> [ -s <subcommand>] [ -r <rolltype> ] [-a <apiversion>]\n"
    . "    [-t <timeout> ] [ -w <warn_range> ] [ -c <crit_range> ]\n"
    . '    [ -V ] [ -h ]',
  version => $VERSION,
  plugin  => $PROGNAME,
  shortname => uc($PROGNAME),
  blurb => 'Citrix XEN monitoring plugin',
  extra => "\n"
      . "This plugin checks Xen Hypervisor via Xen API.\n"
      . "Every check requires session to Xen Hypervisor. To establish connection provide -S option\n"
      . "with appropreate URL. To check particular Host or VM use either -H <name> or -N <name>\n"
      . " acordingly. <name> can be specified as Label or UUID of an object, depending on -U flag.\n"
      . "\n"
      . "Supported commands(^ means blank or not specified parameter) :\n"
      . "    Session specific :\n"
      . "        * listhost - list attached Hosts\n"
      . "        * listpool - list available Pools\n"
      . "        * list - list available VM's\n"
      . "\n"
      . "    Host specific :\n"
      . "        * cpu - shows cpu info\n"
      . "            + usage - overall CPU usage as percentage\n"
      . "            + loadavg - CPU load average \n"
      . "            + <number> - CPU core usage \n"
      . "            ^ all cpu info\n"
      . "        * mem - shows memory info\n"
      . "            + usage - memory usage in MB\n"
      . "            + free - free memory in MB\n"
      . "            + xapiusage - memory used by xapi daemon's in MB\n"
      . "            + xapifree - free memory available to xapi daemon's in MB\n"
      . "            + xapilive - live memory used by xapi daemon's in MB\n"
      . "            + xapiallocation - memory allocation done by xapi daemon's MB\n"
      . "            ^ all mem info\n"
      . "        * net - shows network info\n"
      . "            + usage - overall usage of network(send + receive) in KB/s\n"
      . "            + errors - overall network errors(txerrs + rxerrs)\n"
      . "            + send - overall transmit in KB/s\n"
      . "            + receive - overall receive in KB/s\n"
      . "            + txerrs - overall transmit errors per second/s\n"
      . "            + rxerrs - overall receive errors per second/s\n"
      . "            ^ all net info\n"
      . "        * io - shows disk I/O info\n"
      . "            + cachesize - cache size of the IntelliCache in B\n"
      . "            + cachemisses - misses per second of the IntelliCache\n"
      . "            + cachehits - hits per second of the IntelliCache\n"
      . "            ^ all io info\n"
      . "        * time - shows time difference info\n"
      . "            + time - time difference of Citrix and check_xenpai hosts\n"
      . "            + localtime - time difference of Citrix(time in local timezone) and check_xenpai hosts\n"
      . "            + <number> - time difference of Citrix host and custom value\n"
      . "            ^ all time info\n"
      . "        * list - list available VM's\n"
      . "\n"
      . "    VM specific :\n"
      . "        * cpu - shows cpu info\n"
      . "            + <number> - CPU core usage \n"
      . "            ^ all cpu info\n"
      . "        * mem - shows memory info\n"
      . "            + allocated - allocated memory for VM in MB\n"
      . "            + ballooned - target memory for VM balloon driver in MB\n"
      . "            + internal - memory usage as reported by guest OS in MB\n"
      . "            ^ all mem info\n"
      . "        * net - shows network info\n"
      . "            + usage - overall usage of network(send + receive) in KB/s\n"
      . "            + errors - overall network errors(txerrs + rxerrs)\n"
      . "            + send - overall transmit in KB/s\n"
      . "            + receive - overall receive in KB/s\n"
      . "            + txerrs - overall transmit errors per second/s\n"
      . "            + rxerrs - overall receive errors per second/s\n"
      . "            ^ all net info\n"
      . "        * io - shows disk I/O info\n"
      . "            + usage - overall disk usage in MB/s\n"
      . "            + latency - overall latency in ms\n"
      . "            + read - overall disk read in MB/s\n"
      . "            + write - overall disk write in MB/s\n"
      . "            + read_latency - overall disk read latency in ms\n"
      . "            + write_latency - overall disk write latency in ms\n"
      . "            ^ all io info\n"
      . "",
  timeout => 30,
);

$np->add_arg(
  spec => 'session|S=s',
  help => "-S, --session=<sessionurl>\n"
    . '   Citrix Xen session address.',
  required => 1,
);

$np->add_arg(
  spec => 'host|H=s',
  help => "-H, --host=<hostname>\n"
    . '   Citrix Xen host name',
  required => 0,
);

$np->add_arg(
  spec => 'name|N=s',
  help => "-N, --name=<vmname>\n"
    . '   Virtual machine name.',
  required => 0,
);

$np->add_arg(
  spec => 'uuid|U!',
  help => "-U, --uuid\n"
    . '   Switch between Label and UUID object identefication.(default: Label)',
  required => 0,
);

$np->add_arg(
  spec => 'username|u=s',
  help => "-u, --username=<username>\n"
    . '   Username to connect with.',
  required => 1,
);

$np->add_arg(
  spec => 'password|p=s',
  help => "-p, --password=<password>\n"
    . '   Password to use with the username.',
  required => 1,
);

$np->add_arg(
  spec => 'warning|w=s',
  help => "-w, --warning=THRESHOLD\n"
    . "   Warning threshold. See\n"
    . "   http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT\n"
    . '   for the threshold format.',
  required => 0,
);

$np->add_arg(
  spec => 'critical|c=s',
  help => "-c, --critical=THRESHOLD\n"
    . "   Critical threshold. See\n"
    . "   http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT\n"
    . '   for the threshold format.',
  required => 0,
);

$np->add_arg(
  spec => 'command|l=s',
  help => "-l, --command=COMMAND\n"
    . '   Specify command type (CPU, MEM, NET, IO, LIST, ...)',
  required => 1,
);

$np->add_arg(
  spec => 'rolluptype|r=s',
  help => "-r, --rolluptype=rolltype\n"
    . '   Counters rollup type(AVERAGE, MIN, MAX)',
  required => 0,
);

$np->add_arg(
  spec => 'api|a=s',
  help => "-a, --api=apiversion\n"
    . '   Client API version(default: 1.7)',
  required => 0,
);

$np->add_arg(
  spec => 'subcommand|s=s',
  help => "-s, --subcommand=SUBCOMMAND\n"
    . '   Specify subcommand',
  required => 0,
);

$np->getopts;

my $session = $np->opts->session;
my $hostname = $np->opts->host;
my $vmname = $np->opts->name;
my $username = $np->opts->username;
my $password = $np->opts->password;
my $warning = $np->opts->warning;
my $critical = $np->opts->critical;
my $command = $np->opts->command;
my $subcommand = $np->opts->subcommand;
my $rolluptype = $np->opts->rolluptype;
my $api = $np->opts->api;
my $uuid = $np->opts->uuid;

$output = "Unknown ERROR!";
$result = 'CRITICAL';
$debug_timeshift = 10;

$critical = undef if (!$critical);
$warning = undef if (!$warning);

$rolluptype = 'AVERAGE' if (!$rolluptype);
$api = '1.7' if (!$api);

CONNECT:
eval {
    die "Provide either host or vm.\n" if ($hostname && $vmname);
    $np->set_thresholds(critical => $critical, warning => $warning);
    my $xen = new XenAPI::Session;
    $xen->connect("https://" . $session, $username, $password, $api);
    if ($hostname) {
        $command = uc($command);
        if ($command eq 'LIST') {
            ($result, $output) = session_list_vms($xen, $uuid, $hostname, $np);
        } elsif ($command eq 'CPU') {
            ($result, $output) = host_cpu_info($xen, $uuid, $hostname, $np, $subcommand);
        } elsif ($command eq 'MEM') {
            ($result, $output) = host_mem_info($xen, $uuid, $hostname, $np, $subcommand);
        } elsif ($command eq 'NET') {
            ($result, $output) = host_net_info($xen, $uuid, $hostname, $np, $subcommand);
        } elsif ($command eq 'IO') {
            ($result, $output) = host_io_info($xen, $uuid, $hostname, $np, $subcommand);
        } elsif ($command eq 'TIME') {
            ($result, $output) = host_time_info($xen, $uuid, $hostname, $np, $subcommand);
        } else {
            $output = "Unknown command '$command'";
        }
    } elsif ($vmname) {
        $command = uc($command);
        if ($command eq 'CPU') {
            ($result, $output) = vm_cpu_info($xen, $uuid, $vmname, $np, $subcommand);
        } elsif ($command eq 'MEM') {
            ($result, $output) = vm_mem_info($xen, $uuid, $vmname, $np, $subcommand);
        } elsif ($command eq 'NET') {
            ($result, $output) = vm_net_info($xen, $uuid, $vmname, $np, $subcommand);
        } elsif ($command eq 'IO') {
            ($result, $output) = vm_io_info($xen, $uuid, $vmname, $np, $subcommand);
        } else {
            $output = "Unknown command '$command'";
        }
    } else {
        $command = uc($command);
        if ($command eq 'LISTHOST') {
            ($result, $output) = session_list_hosts($xen, $np);
        } elsif ($command eq 'LISTPOOL') {
            ($result, $output) = session_list_pools($xen, $np);
        } elsif ($command eq 'LIST') {
            ($result, $output) = session_list_vms($xen, undef, undef, $np);
        } else {
            $output = "Unknown command '$command'";
        }
    }
    $xen->disconnect();
};

if ($@) {
    if ((ref($@) eq 'ARRAY') && (defined(${$@}[0])) && (${$@}[0] eq 'HOST_IS_SLAVE')) {
        # Try to reconnect to the pool master
        if (defined(${$@}[1])) {
            $hostname = $session if (!defined($hostname));
            $session = ${$@}[1];
            goto CONNECT;
        }
        $@ = "Pool master not defined\n";
    }
    $output = uc(ref($@)) eq "ARRAY" ? $@->[-1] : $@ . '';
    $result = CRITICAL;
}

$np->nagios_exit($result, $output);

sub perfvalue {
    my $val = shift;
    return $val eq 'nan' ? 0 : $val;
}

sub simplify_number {
    my ($number, $cnt) = (@_, 2);
    return sprintf("%.${cnt}f", "$number");
}

sub parse_datetime_iso8601 {
    my $datetime = shift;
    return undef if (!($datetime =~ m/(.+)T(.+)/));
    my $date = $1;
    my $time = $2;
    $date =~ m/(....)(..)(..)/ if (!($date =~ m/(....)-(..)-(..)/));
    my ($year, $mon, $mday) = ($1, $2, $3);
    $time =~ m/(..)(..)(..)/ if (!($time =~ m/(..):(..):(..)/));
    my ($hour, $min, $sec) = ($1, $2, $3);
    return timegm($sec, $min, $hour, $mday, $mon - 1, $year);
}

sub raise_multiobject_exception {
    my ($objects, $type) = @_;
    my $msg = "Unsupported. If you still want to monitor this $type, use their uuids instead: ";
    foreach my $obj (@{$objects}) {
        $msg .= $obj->get_uuid() . ", ";
    }
    chop($msg);
    chop($msg);
    die $msg ."\n";
}

sub get_latest_perfdata {
    my ($obj, $timestamp) = @_;
    my $rrd = $obj->get_rrd_update($timestamp);
    my $perf = {};
    my $time = 0;
    # get newest perf data
    foreach my $row (@{$rrd}) {
        if ($time < $row->{timestamp}) {
            $time = $row->{timestamp};
            $perf = $row->{data};
        }
    }
    return $perf;
}

sub get_latest_host_by_name_perfdata {
    my ($xen, $hostname) = @_;
    my $hosts = $xen->get_host_by_name($hostname);
    die "Can't find Hosts matching '$hostname'\n" if (!$hosts);
    raise_multiobject_exception($hosts, "Hosts") if (@{$hosts} > 1);
    my $host = shift(@{$hosts});
    my $state = $host->get_enabled();
    die "Host \"$hostname\" is disabled\n" if (!$state);
    my $timestamp = parse_datetime_iso8601($host->get_servertime()) - $debug_timeshift;
    return get_latest_perfdata($host, $timestamp);
}

sub get_latest_vm_by_name_perfdata {
    my ($xen, $vmname) = @_;
    my $vms = $xen->get_vm_by_name($vmname);
    die "Can't find VM's matching '$vmname'\n" if (!$vms);
    raise_multiobject_exception($vms, "VM's") if (@{$vms} > 1);
    my $vm = shift(@{$vms});
    my $host = $vm->get_resident_on();
    my $state = $vm->get_power_state();
    die "VM '$vmname' is not running. Current state is '$state'\n" if ($state ne "Running");
    my $timestamp = parse_datetime_iso8601($host->get_servertime()) - $debug_timeshift;
    return get_latest_perfdata($vm, $timestamp);
}

sub get_latest_host_by_uuid_perfdata {
    my ($xen, $uuid) = @_;
    my $host = $xen->get_host_by_uuid($uuid);
    die "Can't find Host matching '$hostname'\n" if (!$host);
    my $state = $host->get_enabled();
    die "Host \"$hostname\" is disabled\n" if (!$state);
    my $timestamp = parse_datetime_iso8601($host->get_servertime()) - $debug_timeshift;
    return get_latest_perfdata($host, $timestamp);
}

sub get_latest_vm_by_uuid_perfdata {
    my ($xen, $uuid) = @_;
    my $vm = $xen->get_vm_by_uuid($uuid);
    die "Can't find VM matching '$uuid'\n" if (!$vm);
    my $host = $vm->get_resident_on();
    my $state = $vm->get_power_state();
    die "VM '$uuid' is not running. Current state is '$state'\n" if ($state ne "Running");
    my $timestamp = parse_datetime_iso8601($host->get_servertime()) - $debug_timeshift;
    return get_latest_perfdata($vm, $timestamp);
}

sub session_list_hosts {
    my ($xen, $np) = @_;
    my $hosts = $xen->get_hosts();
    my $cnt = 0;
    my $output = '';
    my $res = CRITICAL;
    foreach my $host (@$hosts) {
        my $state = $host->get_enabled();
        $output .= $host->get_name() . '(' . ($state ? 'ENABLED' : 'DISABLED') . '), ';
        $cnt++ if ($state);
    }
    chop($output);
    chop($output);
    $output = $cnt . "/" . @$hosts  . " are enabled: " . $output;
    $np->add_perfdata(label => "hostcount", value => $cnt, uom => 'units', threshold => $np->threshold);
    $res = $np->check_threshold(check => $cnt);
    return ($res, $output);
}

sub session_list_vms {
    my ($xen, $uuid, $hostname, $np) = @_;
    my $cnt = 0;
    my $all = 0;
    my $host;
    if ($hostname) {
        if ($uuid) {
            $host = $xen->get_host_by_uuid($hostname);
        } else {
            my $hosts = $xen->get_host_by_name($hostname);
            die "Can't find Hosts matching '$hostname'\n" if (!$hosts);
            raise_multiobject_exception($hosts, "Hosts") if (@{$hosts} > 1);
            $host = shift(@{$hosts});
            my $state = $host->get_enabled();
            die "Host \"$hostname\" is disabled\n" if (!$state);
        }
    }
    my $vms = $host ? $host->get_resident_vms() : $xen->get_vms();
    my $output = '';
    my $res = CRITICAL;
    foreach my $vm (@$vms) {
        next if ($vm->is_template() || $vm->is_control_domain());
        $all++;
        my $state = $vm->get_power_state();
        $output .= $vm->get_name() . '(' . $state . '), ';
        $cnt++ if ($state eq 'Running');
    }
    chop($output);
    chop($output);
    $output = $cnt . "/" . $all  . " are Running: " . $output;
    $np->add_perfdata(label => "vmcount", value => $cnt, uom => 'units', threshold => $np->threshold);
    $res = $np->check_threshold(check => $cnt);
    return ($res, $output);
}

sub session_list_pools {
    my ($xen, $np) = @_;
    my $pools = $xen->get_pools();
    my $cnt = 0;
    my $output = '';
    my $res = CRITICAL;
    foreach my $pool (@$pools) {
        my $state = $pool->get_ha_overcommitted();
        $output .= $pool->get_uuid() . '(' . ($state ? 'OVERCOMMITTED' : 'NORMAL') . '), ';
        $cnt++ if ($state);
    }
    chop($output);
    chop($output);
    $output = $cnt . "/" . @$pools  . " are overcommited: " . $output;
    $np->add_perfdata(label => "overcommitted", value => $cnt, uom => 'units', threshold => $np->threshold);
    $res = $np->check_threshold(check => $cnt);
    return ($res, $output);
}

sub host_cpu_info {
    my ($xen, $uuid, $hostname, $np, $subcommand) = @_;
    my $perf = $uuid ? get_latest_host_by_uuid_perfdata($xen, $hostname) : get_latest_host_by_name_perfdata($xen, $hostname);
    my $usage = 0;
    my $loadavg = 'nan';
    my $i = 0;
    my $output = '';
    my $res = CRITICAL;

    if (defined($subcommand)) {
        if (uc($subcommand) eq "USAGE") {
            # get all cpu values with keys: cpu0, cpu1, ..., cpu7, ...
            while (my $val = $perf->{"cpu$i"}) {
                $usage += $val->{$rolluptype};
                $i++;
            }
            $usage = simplify_number($usage / $i * 100) if ($i > 0);
            $output = "cpu: usage = " . $usage . " %";
            $np->add_perfdata(label => "cpu_usage", value => $usage, uom => '%', threshold => $np->threshold);
            $res = $np->check_threshold(check => $usage);
        } elsif (uc($subcommand) eq "LOADAVG") {
            $loadavg = $perf->{loadavg}->{$rolluptype} if (exists($perf->{loadavg}->{$rolluptype}));
            $output = "cpu: loadavg = " . $loadavg;
            $np->add_perfdata(label => "loadavg", value => perfvalue($loadavg), threshold => $np->threshold);
            $res = $np->check_threshold(check => $loadavg);
        } else {
            die "Please, provide eiser usage, loadavg command or cpu number(0, 1, ...) instead of string '$subcommand'\n" if (!($subcommand =~ /^[0-9]+$/));
            die "Can't find cpu" . $subcommand . "\n" if (!exists($perf->{"cpu${subcommand}"}));
            $usage = simplify_number($perf->{"cpu${subcommand}"}->{$rolluptype} * 100);
            $output = "cpu" . $subcommand . ": usage = " . $usage . " %";
            $np->add_perfdata(label => ("cpu" . $subcommand . "_usage"), value => $usage, uom => '%', threshold => $np->threshold);
            $res = $np->check_threshold(check => $usage);
        }
    } else {
        $res = OK;
        # get all cpu values with keys: cpu0, cpu1, ..., cpu7, ...
        while (my $val = $perf->{"cpu$i"}) {
            $usage += $val->{$rolluptype};
            $i++;
        }
        $usage = simplify_number($usage / $i * 100) if ($i > 0);
        $loadavg = $perf->{loadavg}->{$rolluptype} if (exists($perf->{loadavg}->{$rolluptype}));
        $output = "cpu: usage = " . $usage . " %, loadavg = " . $loadavg;
        $np->add_perfdata(label => "cpu_usage", value => $usage, uom => '%', threshold => $np->threshold);
        $np->add_perfdata(label => "loadavg", value => perfvalue($loadavg), threshold => $np->threshold);
    }
    return ($res, $output);
}

sub host_mem_info {
    my ($xen, $uuid, $hostname, $np, $subcommand) = @_;
    my $perf = $uuid ? get_latest_host_by_uuid_perfdata($xen, $hostname) : get_latest_host_by_name_perfdata($xen, $hostname);
    my $usage = 'nan';
    my $free = 'nan';
    my $xapi_usage = 'nan';
    my $xapi_free = 'nan';
    my $xapi_live = 'nan';
    my $xapi_alloc = 'nan';
    my $output = '';
    my $res = CRITICAL;

    if (defined($subcommand)) {
        if (uc($subcommand) eq "USAGE") {
            $usage = simplify_number($perf->{memory_total_kib}->{$rolluptype} / 1024) if (exists($perf->{memory_total_kib}));
            $output = "mem: usage = " . $usage . " MB";
            $np->add_perfdata(label => "used", value => perfvalue($usage), uom => 'MB', threshold => $np->threshold);
            $res = $np->check_threshold(check => $usage);
        } elsif (uc($subcommand) eq "FREE") {
            $free = simplify_number($perf->{memory_free_kib}->{$rolluptype} / 1024) if (exists($perf->{memory_free_kib}));
            $output = "mem: free = " . $free . " MB";
            $np->add_perfdata(label => "free", value => perfvalue($free), uom => 'MB', threshold => $np->threshold);
            $res = $np->check_threshold(check => $free);
        } elsif (uc($subcommand) eq "XAPIUSAGE") {
            $xapi_usage = simplify_number($perf->{xapi_memory_usage_kib}->{$rolluptype} / 1024) if (exists($perf->{xapi_memory_usage_kib}));
            $output = "mem: xapi usage = " . $xapi_usage . " MB";
            $np->add_perfdata(label => "xapi_usage", value => perfvalue($xapi_usage), uom => 'MB', threshold => $np->threshold);
            $res = $np->check_threshold(check => $xapi_usage);
        } elsif (uc($subcommand) eq "XAPIFREE") {
            $xapi_free = simplify_number($perf->{memory_free_kib}->{$rolluptype} / 1024) if (exists($perf->{memory_free_kib}));
            $output = "mem: xapi free = " . $xapi_free . " MB";
            $np->add_perfdata(label => "xapi_free", value => perfvalue($xapi_free), uom => 'MB', threshold => $np->threshold);
            $res = $np->check_threshold(check => $xapi_free);
        } elsif (uc($subcommand) eq "XAPILIVE") {
            $xapi_live = simplify_number($perf->{xapi_live_memory_kib}->{$rolluptype} / 1024) if (exists($perf->{xapi_live_memory_kib}));
            $output = "mem: xapi live = " . $xapi_live . " MB";
            $np->add_perfdata(label => "xapi_live", value => perfvalue($xapi_live), uom => 'MB', threshold => $np->threshold);
            $res = $np->check_threshold(check => $xapi_live);
        } elsif (uc($subcommand) eq "XAPIALLOCATION") {
            $xapi_alloc = simplify_number($perf->{xapi_allocation_kib}->{$rolluptype} / 1024) if (exists($perf->{xapi_allocation_kib}));
            $output = "mem: xapi allocation = " . $xapi_alloc . " MB";
            $np->add_perfdata(label => "xapi_allocation", value => perfvalue($xapi_alloc), uom => 'MB', threshold => $np->threshold);
            $res = $np->check_threshold(check => $xapi_alloc);
        } else {
            $output = "VM MEM - unknown subcommand\n" . $np->opts->_help;
        }
    } else {
        $res = OK;
        $usage = simplify_number($perf->{memory_total_kib}->{$rolluptype} / 1024) if (exists($perf->{memory_total_kib}));
        $free = simplify_number($perf->{memory_free_kib}->{$rolluptype} / 1024) if (exists($perf->{memory_free_kib}));
        $xapi_usage = simplify_number($perf->{xapi_memory_usage_kib}->{$rolluptype} / 1024) if (exists($perf->{xapi_memory_usage_kib}));
        $xapi_free = simplify_number($perf->{memory_free_kib}->{$rolluptype} / 1024) if (exists($perf->{memory_free_kib}));
        $xapi_live = simplify_number($perf->{xapi_live_memory_kib}->{$rolluptype} / 1024) if (exists($perf->{xapi_live_memory_kib}));
        $xapi_alloc = simplify_number($perf->{xapi_allocation_kib}->{$rolluptype} / 1024) if (exists($perf->{xapi_allocation_kib}));
        $output = "mem: usage = " . $usage . " MB, free = " . $free . " MB, xapi usage = " . $xapi_usage . " MB, xapi free = " . $xapi_free . " MB, xapi live = " . $xapi_live . "MB, xapi allocation = " . $xapi_alloc . " MB";
        $np->add_perfdata(label => "used", value => perfvalue($usage), uom => 'MB', threshold => $np->threshold);
        $np->add_perfdata(label => "free", value => perfvalue($free), uom => 'MB', threshold => $np->threshold);
        $np->add_perfdata(label => "xapi_usage", value => perfvalue($xapi_usage), uom => 'MB', threshold => $np->threshold);
        $np->add_perfdata(label => "xapi_free", value => perfvalue($xapi_free), uom => 'MB', threshold => $np->threshold);
        $np->add_perfdata(label => "xapi_live", value => perfvalue($xapi_live), uom => 'MB', threshold => $np->threshold);
        $np->add_perfdata(label => "xapi_allocation", value => perfvalue($xapi_alloc), uom => 'MB', threshold => $np->threshold);
    }
    return ($res, $output);
}

sub host_net_info {
    my ($xen, $uuid, $hostname, $np, $subcommand) = @_;
    my $perf = $uuid ? get_latest_host_by_uuid_perfdata($xen, $hostname) : get_latest_host_by_name_perfdata($xen, $hostname);
    my $list = {};
    my $send = 0;
    my $receive = 0;
    my $tx_errors = 0;
    my $rx_errors = 0;
    my $output = '';
    my $res = CRITICAL;

    while (my ($name, $value) = each(%{$perf})) {
        if ($name =~ /^(pif_[^_]+)_(.*)/) {
            $list->{$1} = {} if (!exists($list->{$1}));
            $list->{$1}->{$2} = $value->{$rolluptype};
        }
    }
    while (my ($name, $value) = each(%{$list})) {
        $send += $value->{tx} / 1024 if (exists($value->{tx}));
        $receive += $value->{rx} / 1024 if (exists($value->{rx}));
        $rx_errors += $value->{tx_errors} if (exists($value->{tx_errors}));
        $tx_errors += $value->{rx_errors} if (exists($value->{rx_errors}));
    }
    $send = simplify_number($send);
    $receive = simplify_number($receive);

    if (defined($subcommand)) {
        if (uc($subcommand) eq "USAGE") {
            my $usage = $send + $receive;
            $output = "net: usage = " . $usage . " KBps";
            $np->add_perfdata(label => "usage", value => $usage, uom => 'KBps', threshold => $np->threshold);
            $res = $np->check_threshold(check => $usage);
        } elsif (uc($subcommand) eq "ERRORS") {
            my $errors = $tx_errors + $rx_errors;
            $output = "net: errors = " . $errors . " KBps";
            $np->add_perfdata(label => "errors", value => $errors, uom => 'KBps', threshold => $np->threshold);
            $res = $np->check_threshold(check => $errors);
        } elsif (uc($subcommand) eq "SEND") {
            $output = "net: send = " . $send . " KBps";
            $np->add_perfdata(label => "send", value => $send, uom => 'KBps', threshold => $np->threshold);
            $res = $np->check_threshold(check => $send);
        } elsif (uc($subcommand) eq "RECEIVE") {
            $output = "net: receive = " . $receive . " KBps";
            $np->add_perfdata(label => "receive", value => $receive, uom => 'KBps', threshold => $np->threshold);
            $res = $np->check_threshold(check => $receive);
        } elsif (uc($subcommand) eq "TXERRS") {
            $output = "net: send errors = "  . $tx_errors;
            $np->add_perfdata(label => "send_errors", value => $tx_errors, threshold => $np->threshold);
            $res = $np->check_threshold(check => $tx_errors);
        } elsif (uc($subcommand) eq "RXERRS") {
            $output = "net: receive errors = " . $rx_errors;
            $np->add_perfdata(label => "receive_errors", value => $rx_errors, threshold => $np->threshold);
            $res = $np->check_threshold(check => $rx_errors);
        } else {
            $output = "VM NET - unknown subcommand\n" . $np->opts->_help;
        }
    } else {
        $res = OK;
        $output = "net: send = " . $send . " KBps, receive = " . $receive . " KBps, send errors = "  . $tx_errors . ", receive errors = " . $rx_errors;
        $np->add_perfdata(label => "send", value => $send, uom => 'KBps', threshold => $np->threshold);
        $np->add_perfdata(label => "receive", value => $receive, uom => 'KBps', threshold => $np->threshold);
        $np->add_perfdata(label => "send_errors", value => $tx_errors, threshold => $np->threshold);
        $np->add_perfdata(label => "receive_errors", value => $rx_errors, threshold => $np->threshold);
    }
    return ($res, $output);
}

sub host_io_info {
    my ($xen, $uuid, $hostname, $np, $subcommand) = @_;
    my $perf = $uuid ? get_latest_host_by_uuid_perfdata($xen, $hostname) : get_latest_host_by_name_perfdata($xen, $hostname);
    my $usage = 0;
    my $list = {};
    my $cache_size = 0;
    my $cache_misses = 0;
    my $cache_hits = 0;
    my $output = '';
    my $res = CRITICAL;

    while (my ($name, $value) = each(%{$perf})) {
        if ($name =~ /^sr_([^_]+)_(.*)/) {
            my $sr = $xen->get_sr_by_uuid($1);
            my $sr_name = $sr->get_name();
            $list->{$sr_name} = {} if (!exists($list->{$sr_name}));
            $list->{$sr_name}->{$2} = $value->{$rolluptype};
        }
    }
    while (my ($name, $value) = each(%{$list})) {
        $cache_size += $value->{cache_size} if (exists($value->{cache_size}));
        $cache_misses += $value->{cache_misses} if (exists($value->{cache_misses}));
        $cache_hits += $value->{cache_hits} if (exists($value->{cache_hits}));
    }

    if (defined($subcommand)) {
        if (uc($subcommand) eq "CACHESIZE") {
            $output = "disk io: cache size = " . $cache_size . " B";
            $np->add_perfdata(label => "cache_size", value => $cache_size, uom => 'B', threshold => $np->threshold);
            $res = $np->check_threshold(check => $cache_size);
        } elsif (uc($subcommand) eq "CACHEMISSES") {
            $output = "disk io: cache misses = " . $cache_misses;
            $np->add_perfdata(label => "cache_misses", value => $cache_misses, threshold => $np->threshold);
            $res = $np->check_threshold(check => $cache_misses);
        } elsif (uc($subcommand) eq "CACHEHITS") {
            $output = "disk io: cache hits = " . $cache_hits;
            $np->add_perfdata(label => "cache_hits", value => $cache_hits, threshold => $np->threshold);
            $res = $np->check_threshold(check => $cache_hits);
        } else {
            $output = "VM NET - unknown subcommand\n" . $np->opts->_help;
        }
    } else {
        $res = OK;
        $output = "disk io: cache size = " . $cache_size . " B, cache misses = " . $cache_misses . ", cache hits = "  . $cache_hits;
        $np->add_perfdata(label => "cache_size", value => $cache_size, uom => 'B', threshold => $np->threshold);
        $np->add_perfdata(label => "cache_misses", value => $cache_misses, threshold => $np->threshold);
        $np->add_perfdata(label => "cache_hits", value => $cache_hits, threshold => $np->threshold);
    }
    return ($res, $output);
}

sub host_time_info {
    my ($xen, $uuid, $hostname, $np, $subcommand) = @_;
    my $host = $uuid ? $xen->get_host_by_uuid($hostname) : $xen->get_host_by_name($hostname);
    die "Can't find Hosts matching '$hostname'\n" if (!$host);
    if (ref($host) eq 'ARRAY') {
        raise_multiobject_exception($host, "Hosts") if (@{$host} > 1);
        $host = shift(@{$host});
    }
    my $time_diff = 0;
    my $localtime_diff = 0;
    my $output = '';
    my $res = CRITICAL;

    if (defined($subcommand)) {
        if (uc($subcommand) eq "TIME") {
            $time_diff = time() - parse_datetime_iso8601($host->get_servertime());
            $output = "time difference = $time_diff";
            $np->add_perfdata(label => "time_diff", value => $time_diff, uom => 's', threshold => $np->threshold);
            $res = $np->check_threshold(check => $time_diff);
        } elsif (uc($subcommand) eq "LOCALTIME") {
            $localtime_diff = time() - parse_datetime_iso8601($host->get_server_localtime());
            $output = "localtime difference = $localtime_diff";
            $np->add_perfdata(label => "localtime_diff", value => $localtime_diff, uom => 's', threshold => $np->threshold);
            $res = $np->check_threshold(check => $localtime_diff);
        } elsif ($subcommand =~ m/^\d+$/) {
            $time_diff = $subcommand - parse_datetime_iso8601($host->get_servertime());
            $output = "custom time difference = $time_diff";
            $np->add_perfdata(label => "customtime_diff", value => $time_diff, uom => 's', threshold => $np->threshold);
            $res = $np->check_threshold(check => $time_diff);
        } else {
            $output = "VM TIME - unknown subcommand\n" . $np->opts->_help;
        }
    } else {
        $time_diff = time() - parse_datetime_iso8601($host->get_servertime());
        $localtime_diff = time() - parse_datetime_iso8601($host->get_server_localtime());
        $output = "time difference = $time_diff, localtime difference = $localtime_diff";
        $res = $np->check_threshold(check => $time_diff);
        $np->add_perfdata(label => "time_diff", value => $time_diff, uom => 's', threshold => $np->threshold);
        $np->add_perfdata(label => "localtime_diff", value => $localtime_diff, uom => 's', threshold => $np->threshold);
    }

    return ($res, $output);
}

sub vm_cpu_info {
    my ($xen, $uuid, $vmname, $np, $subcommand) = @_;
    my $perf = $uuid ? get_latest_vm_by_uuid_perfdata($xen, $vmname) : get_latest_vm_by_name_perfdata($xen, $vmname);
    my $usage = 0;
    my $i = 0;
    my $output = 'VM CPU Unknown error';
    my $res = CRITICAL;

    if (defined($subcommand)) {
        die "Please, provide cpu number(0, 1, ...) instead of string '$subcommand'\n" if (!($subcommand =~ /^[0-9]+$/));
        die "Can't find cpu" . $subcommand . "\n" if (!exists($perf->{"cpu${subcommand}"}));
        $usage = simplify_number($perf->{"cpu${subcommand}"}->{$rolluptype} * 100);
        $output = "VM '" . $vmname . "' cpu" . $subcommand . ": usage = " . $usage . " %";
        $np->add_perfdata(label => "cpu" . $subcommand . "_usage", value => $usage, uom => '%', threshold => $np->threshold);
    } else {
        # get all cpu values with keys: cpu0, cpu1, ..., cpu7, ...
        while (my $val = $perf->{"cpu$i"}) {
            $usage += $val->{$rolluptype};
            $i++;
        }
        $usage = simplify_number($usage / $i * 100) if ($i > 0);

        $output = "VM '" . $vmname . "' cpu: usage = " . $usage . " %";
        $np->add_perfdata(label => "cpu_usage", value => $usage, uom => '%', threshold => $np->threshold);
    }
    $res = $np->check_threshold(check => $usage);
    return ($res, $output);
}

sub vm_mem_info {
    my ($xen, $uuid, $vmname, $np, $subcommand) = @_;
    my $perf = $uuid ? get_latest_vm_by_uuid_perfdata($xen, $vmname) : get_latest_vm_by_name_perfdata($xen, $vmname);
    my $alloc = 'nan';
    my $target = 'nan';
    my $internal = 'nan';
    my $output = 'VM MEM Unknown error';
    my $res = CRITICAL;

    if (defined($subcommand)) {
        $output = "VM '" . $vmname . "' mem: ";
        if (uc($subcommand) eq "ALLOCATED") {
            $alloc = simplify_number($perf->{memory}->{$rolluptype} / 1024 / 1024) if (exists($perf->{memory}));
            $output .= "allocated = " . $alloc . " MB";
            $np->add_perfdata(label => "allocated", value => perfvalue($alloc), uom => 'MB', threshold => $np->threshold);
            $res = $np->check_threshold(check => $alloc);
        } elsif (uc($subcommand) eq "BALLOONED") {
            $target = simplify_number($perf->{memory_target}->{$rolluptype} / 1024 / 1024) if (exists($perf->{memory_target}));
            $output .= "ballooned = " . $target . " MB";
            $np->add_perfdata(label => "ballooned", value => perfvalue($target), uom => 'MB', threshold => $np->threshold);
            $res = $np->check_threshold(check => $target);
        } elsif (uc($subcommand) eq "INTERNAL") {
            $internal = simplify_number($perf->{memory_internal_free}->{$rolluptype} / 1024) if (exists($perf->{memory_internal_free}));
            $output .= "internal = " . $internal . " MB";
            $np->add_perfdata(label => "internal", value => perfvalue($internal), uom => 'MB', threshold => $np->threshold);
            $res = $np->check_threshold(check => $internal);
        } else {
            $output = "VM MEM - unknown subcommand\n" . $np->opts->_help;
        }
    } else {
        $res = OK;
        $alloc = simplify_number($perf->{memory}->{$rolluptype} / 1024 / 1024) if (exists($perf->{memory}));
        $target = simplify_number($perf->{memory_target}->{$rolluptype} / 1024 / 1024) if (exists($perf->{memory_target}));
        $internal = simplify_number($perf->{memory_internal_free}->{$rolluptype} / 1024) if (exists($perf->{memory_internal_free}));
        $output = "VM '" . $vmname . "' mem: allocated = " . $alloc . " MB, ballooned = " . $target . " MB, internal = " . $internal . " MB";
        $np->add_perfdata(label => "allocated", value => perfvalue($alloc), uom => 'MB', threshold => $np->threshold);
        $np->add_perfdata(label => "ballooned", value => perfvalue($target), uom => 'MB', threshold => $np->threshold);
        $np->add_perfdata(label => "internal", value => perfvalue($internal), uom => 'MB', threshold => $np->threshold);
    }
    return ($res, $output);
}

sub vm_net_info {
    my ($xen, $uuid, $vmname, $np, $subcommand) = @_;
    my $perf = $uuid ? get_latest_vm_by_uuid_perfdata($xen, $vmname) : get_latest_vm_by_name_perfdata($xen, $vmname);
    my $list = {};
    my $send = 0;
    my $receive = 0;
    my $tx_errors = 0;
    my $rx_errors = 0;
    my $output = '';
    my $res = CRITICAL;

    while (my ($name, $value) = each(%{$perf})) {
        if ($name =~ /^(vif_[^_]+)_(.*)/) {
            $list->{$1} = {} if (!exists($list->{$1}));
            $list->{$1}->{$2} = $value->{$rolluptype};
        }
    }
    while (my ($name, $value) = each(%{$list})) {
        $send += $value->{tx} / 1024 if (exists($value->{tx}));
        $receive += $value->{rx} / 1024 if (exists($value->{rx}));
        $rx_errors += $value->{tx_errors} if (exists($value->{tx_errors}));
        $tx_errors += $value->{rx_errors} if (exists($value->{rx_errors}));
    }
    $send = simplify_number($send);
    $receive = simplify_number($receive);

    if (defined($subcommand)) {
        $output = "VM '" . $vmname . "' net: ";
        if (uc($subcommand) eq "USAGE") {
            my $usage = $send + $receive;
            $output .= "usage = " . $usage . " KBps";
            $np->add_perfdata(label => "usage", value => $usage, uom => 'KBps', threshold => $np->threshold);
            $res = $np->check_threshold(check => $usage);
        } elsif (uc($subcommand) eq "ERRORS") {
            my $errors = $tx_errors + $rx_errors;
            $output .= "errors = " . $errors . " KBps";
            $np->add_perfdata(label => "errors", value => $errors, uom => 'KBps', threshold => $np->threshold);
            $res = $np->check_threshold(check => $errors);
        } elsif (uc($subcommand) eq "SEND") {
            $output .= "send = " . $send . " KBps";
            $np->add_perfdata(label => "send", value => $send, uom => 'KBps', threshold => $np->threshold);
            $res = $np->check_threshold(check => $send);
        } elsif (uc($subcommand) eq "RECEIVE") {
            $output .= "receive = " . $receive . " KBps";
            $np->add_perfdata(label => "receive", value => $receive, uom => 'KBps', threshold => $np->threshold);
            $res = $np->check_threshold(check => $receive);
        } elsif (uc($subcommand) eq "TXERRS") {
            $output .= "send errors = "  . $tx_errors;
            $np->add_perfdata(label => "send_errors", value => $tx_errors, threshold => $np->threshold);
            $res = $np->check_threshold(check => $tx_errors);
        } elsif (uc($subcommand) eq "RXERRS") {
            $output .= "receive errors = " . $rx_errors;
            $np->add_perfdata(label => "receive_errors", value => $rx_errors, threshold => $np->threshold);
            $res = $np->check_threshold(check => $rx_errors);
        } else {
            $output = "VM NET - unknown subcommand\n" . $np->opts->_help;
        }
    } else {
        $res = OK;
        $output = "VM '" . $vmname . "' net: send = " . $send . " KBps, receive = " . $receive . " KBps, send errors = "  . $tx_errors . ", receive errors = " . $rx_errors;
        $np->add_perfdata(label => "send", value => $send, uom => 'KBps', threshold => $np->threshold);
        $np->add_perfdata(label => "receive", value => $receive, uom => 'KBps', threshold => $np->threshold);
        $np->add_perfdata(label => "send_errors", value => $tx_errors, threshold => $np->threshold);
        $np->add_perfdata(label => "receive_errors", value => $rx_errors, threshold => $np->threshold);
    }
    return ($res, $output);
}

sub vm_io_info {
    my ($xen, $uuid, $vmname, $np, $subcommand) = @_;
    my $perf = $uuid ? get_latest_vm_by_uuid_perfdata($xen, $vmname) : get_latest_vm_by_name_perfdata($xen, $vmname);
    my $list = {};
    my $read = 0;
    my $write = 0;
    my $read_latency = 0;
    my $write_latency = 0;
    my $output = '';
    my $res = CRITICAL;

    while (my ($name, $value) = each(%{$perf})) {
        if ($name =~ /^vbd_([^_]+)_(.*)/) {
            $list->{$1} = {} if (!exists($list->{$1}));
            $list->{$1}->{$2} = $value->{$rolluptype};
        }
    }
    while (my ($name, $value) = each(%{$list})) {
        $read += $value->{read} / 1024 / 1024 if (exists($value->{read}));
        $write += $value->{write} / 1024 / 1024 if (exists($value->{write}));
        $read_latency += $value->{read_latency} if (exists($value->{read_latency}));
        $write_latency += $value->{write_latency} if (exists($value->{write_latency}));
    }
    $read = simplify_number($read);
    $write = simplify_number($write);

    if (defined($subcommand)) {
        $output = "VM '" . $vmname . "' disk io: ";
        if (uc($subcommand) eq "USAGE") {
            my $usage = $read + $write;
            $output .= "usage = " . $usage . " MBps";
            $np->add_perfdata(label => "usage", value => $usage, uom => 'MBps', threshold => $np->threshold);
            $res = $np->check_threshold(check => $read);
        } elsif (uc($subcommand) eq "LATENCY") {
            my $latency = $read_latency + $write_latency;
            $output .= "latency = " . $latency . " ms";
            $np->add_perfdata(label => "latency", value => $latency, uom => 'ms', threshold => $np->threshold);
            $res = $np->check_threshold(check => $latency);
        } elsif (uc($subcommand) eq "READ") {
            $output .= "read = " . $read . " MBps";
            $np->add_perfdata(label => "read", value => $read, uom => 'MBps', threshold => $np->threshold);
            $res = $np->check_threshold(check => $read);
        } elsif (uc($subcommand) eq "WRITE") {
            $output .= "write = " . $write . " MBps";
            $np->add_perfdata(label => "write", value => $write, uom => 'MBps', threshold => $np->threshold);
            $res = $np->check_threshold(check => $write);
        } elsif (uc($subcommand) eq "READLATENCY") {
            $output .= "read latency = "  . $read_latency . " ms";
            $np->add_perfdata(label => "read_latency", value => $read_latency, uom => 'ms', threshold => $np->threshold);
            $res = $np->check_threshold(check => $read_latency);
        } elsif (uc($subcommand) eq "WRITELATENCY") {
            $output .= "write latency = " . $write_latency . " ms";
            $np->add_perfdata(label => "write_latency", value => $write_latency, uom => 'ms', threshold => $np->threshold);
            $res = $np->check_threshold(check => $write_latency);
        } else {
            $output = "VM NET - unknown subcommand\n" . $np->opts->_help;
        }
    } else {
        $res = OK;
        $output = "VM '" . $vmname . "' disk io: read = " . $read . " MBps, write = " . $write . " MBps, read latency = "  . $read_latency . " ms, write latency = " . $write_latency . " ms";
        $np->add_perfdata(label => "read", value => $read, uom => 'MBps', threshold => $np->threshold);
        $np->add_perfdata(label => "write", value => $write, uom => 'MBps', threshold => $np->threshold);
        $np->add_perfdata(label => "read_latency", value => $read_latency, uom => 'ms', threshold => $np->threshold);
        $np->add_perfdata(label => "write_latency", value => $write_latency, uom => 'ms', threshold => $np->threshold);
    }
    return ($res, $output);
}
