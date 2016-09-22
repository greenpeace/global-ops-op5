#!/usr/bin/perl -w

# check_em1.pl - checks the em1 sensor box for NAGIOS.
# Copyright (C) 2005 NETWAYS GmbH
# $Id: check_em1.pl 1566 2007-03-16 11:28:13Z gmueller $
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
# $Id: check_em1.pl 1566 2007-03-16 11:28:13Z gmueller $

use strict;
use LWP::UserAgent;
use Getopt::Long;
use File::Basename;
use Data::Dumper;
use Pod::Usage;
use subs qw(print_help);
use vars qw(
    $progname
    $VERSION
    %states
    %state_names
    %queries
    %units
    
    $opt_help
    $opt_usage
    $opt_host
    $opt_port
    $opt_group
    $opt_path
    $opt_query
    $opt_warning
    $opt_critical
    
    $ua
    $response
    @values
    @tmp
    @groups
    
    $value
    $state
    $out
);

$progname = basename($0);
$VERSION = '1.0';

%states = (OK       =>  0,
           WARNING  =>  1,
           CRITICAL =>  2,
           UNKNOWN  =>  3);

%state_names = (0   =>  "OK",
                1   =>  "WARNING",
                2   =>  "CRITICAL",
                3   =>  "UNKNOWN");

%queries = ("t" =>  0,
            "h" =>  1,
            "w" =>  2);

%units = ("t" => "k",
          "h" => "%",
          "w" => "n");

$opt_port = 80;
$opt_path = '/data';
$opt_warning = 25;
$opt_critical = 30;
$state = $states{UNKNOWN};

Getopt::Long::Configure('bundling');
GetOptions ("h"     =>  \$opt_help,
            "U"     =>  \$opt_usage,
            "H=s"   =>  \$opt_host,
            "p=i"   =>  \$opt_port,
            "u=i"   =>  \$opt_group,
            "q=s"   =>  \$opt_query,
            "P=s"   =>  \$opt_path,
            "c=s"   =>  \$opt_critical,
            "w=s"   =>  \$opt_warning)
    || die ("Please check your options.\n");

print_help(1) if ($opt_usage);
print_help(99) if ($opt_help);

unless ($opt_host && $opt_port && $opt_path && $opt_group && $opt_query) {
    print "Too few arguments!\n";
    print_help(1);
}
else {
    $opt_group--;
    $ua = LWP::UserAgent->new;
    $ua->agent($progname. '-checkbot/'. $VERSION);
    $ua->timeout(10);
    $response = $ua->get('http://'. $opt_host. ':'. $opt_port. $opt_path. '/');
    if ($response->is_success) {
        @values = split(/\|/, $response->content);
        
        $units{t} = $values[0];
        
        shift (@values);
        
        my $i = 0;
        foreach (@values) {
            $i++;
            push @tmp, $_ if ($i <=3);
            if ($i >= 3) {
                push @groups, [@tmp];
                @tmp = ();
                $i=0;
            }
        }
        
        if (exists($groups[$opt_group]) && exists($queries{$opt_query})) {
            $value = $groups[$opt_group][$queries{$opt_query}];
            
            
			# get left/right of warning/critical
			my ( $opt_warning_left, $opt_warning_right ) = split( /:/, $opt_warning );
			if($opt_warning !~ m /:/  ) {
				$opt_warning_right = $opt_warning_left;
				$opt_warning_left = "";
			}

			my ( $opt_critical_left, $opt_critical_right ) = split( /:/, $opt_critical );
			if($opt_critical !~ m /:/  ) {
				$opt_critical_right = $opt_critical_left;
				$opt_critical_left = "";
			}

			# test borders
			if ( check_value( $value, $opt_critical_left, $opt_critical_right ) ) {
                $state = $states{CRITICAL};
            }
			elsif ( check_value( $value, $opt_warning_left, $opt_warning_right ) ) {
                $state = $states{WARNING};
            }
            else {
                $state = $states{OK}
            }
            $out = "$progname: ". $state_names{$state}. ' ('. $opt_query. '='. $value. ' '. $units{$opt_query}. ')|'. $opt_query. '='. $value. ";$opt_warning;$opt_critical;\n";
			if ($value <= -999) {
				my $probe_num = $opt_group+1;
				$out = "Error: Probe #" . $probe_num . " appears to be disconnected\n";
				$state = $states{CRITICAL};
			}
            print $out;
        }
        else {
            print "ERROR: no groups or queries exists ...\n";
        }
    }
    else {
	if($response->code == 404) { 
	    print "ERROR: Sensor data not found, is this really a Sensatronics em1?\n";
	} else {
	    print "ERROR: ". $response->status_line. "\n";
	}
    }
}

exit ($state);

sub print_help {
    my ($level) = @_;
    pod2usage(-verbose=>$level);
    exit ($states{UNKNOWN});
}

sub check_value {
	my $rw = 0;

	my ( $value, $left, $right ) = @_;

	$left  = "" if ( !$left );
	$right = "" if ( !$right );

	if ( $right ne "" && $left ne "" ) {

		# outside 
		if( $right <= $left) {
		
			$rw=1 if($value < $right || $value > $left)
		
		# inside
		} else {

			$rw=1 if($value >= $right || $value <= $left)
		}
		
	}
	elsif ( $right eq "" ) {
		$rw = 1 if ( $value <= $left );
	}
	elsif ( $left eq "" ) {
		$rw = 1 if ( $value >= $right );
	}

	return $rw;
}


__END__

=head1 NAME

check_em1.pl - checks the em1 sensor for nagios.

version 1.0, Copyright (C) 2005  NETWAYS GmbH

check_em1.pl comes with ABSOLUTELY NO WARRANTY. This is free software, and you are welcome to redistribute it under certain conditions. 

$Id: check_em1.pl 1566 2007-03-16 11:28:13Z gmueller $

=head1 SYNOPSIS

check_em1.pl -H host -u sensor_unit -q t|h|w [ -p port ] [ -P web_path ] [ -w warn ] [ -c crit  ]

=head1 OPTIONS

=over 8

=item B<-H>

The ip or hostname of the SnesorTronics EM1 box.

=item B<-p>

The port of the webservice running on the EM1, default is 80.

=item B<-P>

The webpath for the servicedata, normally '/data'.

=item B<-u>

The sensorunit (1-4)

=item B<-q>

Which sensor to query (t=temperature, h=humidity, w=wetness)

=item B<-w>

The warning threshold.

=item B<-c>

The critical threshold.

=item B<-h>

Display's this screen here...

=item B<-U>

Display's a little usage.

=back

=head1 DESCRIPTION

B<check_em1.pl> queries the webservice of the EM1 sensor box, and compare the values
with the critical and warning thresholds for the NAGIOS status.

=head1 THRESHOLD FORMATS

B<1.> start <= end

The startvalue have to be less than the endvalue

B<2.> start and ':' is not required if start is infinity>

If you set a threshold of '12' it's the same like ':12'

B<3.> if range is of format "start:" and end is not specified, assume end is infinity

B<4.> alert is raised if metric is outside start and end range (inclusive of endpoints)

B<5.> if range starts is lower than end then alert is inside this range 
(inclusive of endpoints)

=head1 PERFDATA

The plugin supports the perfparse functions of NAGIOS.

=head1 AUTHOR

Marius Hein <mhein@netways.de>

