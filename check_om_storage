#!/usr/bin/perl -wT
#
# Nagios Plugin to check storage devices ( e.g. raid controller )
# in Dell server systems using "omreport" from Dell OpenManage.
#
# (C) 2005 - 2007 Riege Software International GmbH
# Mollsfeld 10
# 40670 Meerbusch
# Germany
#
# Published under the Genral Public License, Version 3.
# 
# Author: Gunther Schlegel <schlegel@riege.com>
#
# V0.0.1  20050801 gs	new script
# V0.1.0  20050818 gs	initial release, checks controllers, disks,
#						virtual disks, batteries.
# V0.2.0  20050819 gs	detect regenerating virtual disks and report  
#						warning instead of critical.
# V0.3.0  20050822 gs	detect noncritical degraded controllers and report 
# 						warning instead of critical
# V0.4.0  20051102 gs	detect noncritical degraded hard disk and report 
#						warning instead of critical
# V0.5.0  20051103 gs	detect noncritical rebuilding-message and report 
#						warning instead of critical
# V0.5.1  20060516 gs	add /usr/lib/nagios/plugins to default module search path
# V0.5.2  20060609 gs	fix option inconsistency
# V0.6.0  20060609 gs	add OpenManage 5.0.0 compatibility
# V0.6.1  20060712 gs	fix: detect OM5 Non-Critical messages correctly
# V0.7.0  20061019 gs	add OpenManage 5.1.0 / PERC 5 / SAS compatibility
# V0.7.1  20061024 gs	fix: battery matching
#						enh: use different omreport output format -- it is way faster
# V0.7.2  20070824 gs	fix: OM5.1 reports "Resynching" instead of Rebuilding. 
# 						Credits to Heinz Terwort.
# V0.7.3  20070824 gs	fix: OM "Non-Critical" messages where not reported, as the -
# 						was missing in a regular expression. 
# 						Credits to: Sam Soffa and Geoff Hibble.
# V0.8.0  20070928 gs	added a scan mode to create sample output from systems I 
#						have no access to.
# V0.8.1  20070928 gs	fix: do not skip disks in Enclosures with more than 10 disks
#						fix: battery max recharge count regexp was too greedy
# 						enh: finetune debug output
#						Credits to: Jeff Potter
# V0.8.2  20071001 gs	enh: improved scan mode output, renamed to analyze
#						enh: added sudo support
#						enh: improved usage display
#						fix: detect virtual disk state "Background Initialization"
# 						fix: detect charging batteries
#						Credits to: Jeff Potter


# Modules
use strict;
use Getopt::Long;
use File::Basename;
use lib qw(/usr/local/nagios/libexec /usr/lib/nagios/plugins /opt/plugins);
use utils qw (%ERRORS);

# untaint Environment
$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';
$ENV{'PATH'}='/bin:/usr/bin';

# variables
my ($debug,$help,$analyze,$sudo)='0';
my $om='/usr/bin/omreport';
my $omcmd="$om storage";
my $omfmt='-fmt ssv';
my $result=$ERRORS{'UNKNOWN'};

my @controllers;
my %controller;
my $I;
my $J;
my @disks;
my %disk;
my @messages;
my @batteries;
my %battery;
my $omversion;
my $dummy;
my @dummy;
my $match;

# Process command line
GetOptions ('VERBOSE+' => \$debug,'HELP|?' => \$help,'ANALYZE' => \$analyze, 'SUDO' => \$sudo);
$help and usage();
$analyze and $debug=2;
$sudo and $omcmd="/usr/bin/sudo $omcmd";

# Main
if ( -x $om ) {
	$analyze && print "Running in ANALYZE mode. Please send Output to schlegel\@riege.com.\n\n";
	
	@dummy=`$om about -fmt cdv`;
	if ( $analyze ) {
		print "--CMD1--: $om about -fmt cdv\n";
		print @dummy; 
		print "--CMD1 parsed output:\n";
	}
	chomp @dummy;
	
	($omversion)=($dummy[2] =~ /.*?;(\d+\.\d+\.\d+)?;/);
	print "OpenManage version: $1\n" if $debug;

	
	@controllers=`$omcmd controller $omfmt`;
	if ( $analyze ) {
		print "\n--CMD2--: $omcmd controller $omfmt\n";
		print @controllers;
		print "--CMD2 results:\n";
	}	

	print "Got $#controllers controller lines\n" if $debug > 1;
	print @controllers if $debug > 2;
	chomp @controllers;

	foreach $I (@controllers) {
		undef (%controller);
		if (($controller{'id'},$controller{'status'},$controller{'type'},$controller{'state'}) = ($I =~ /^(\d+?);(.*?);(.*?);.*?;(.*?);/)) {
			print "\nChecking Controller No. $controller{'id'}: $controller{'type'}\n" if $debug;

			if ( $controller{'status'} ne 'Ok' ) {
				if ( $controller{'status'} eq 'Noncritical' or $controller{'status'} eq 'Non-Critical' ) {
					$result=addresult($result,$ERRORS{'WARNING'});
				} else {
					$result=addresult($result,$ERRORS{'CRITICAL'});
				}	
				push @messages, "Ctrl $controller{'id'} ($controller{'type'} is $controller{'status'}($controller{'state'}))";
			} else {
				$result=addresult($result,$ERRORS{'OK'});
			}

			undef @disks;
			@disks=`$omcmd adisk controller=$controller{'id'} $omfmt`;
			if ( $analyze ) {
				print "\n--CMD3--: $omcmd adisk controller=$controller{'id'} $omfmt\n";
				print @disks;
				print "--CMD3 results:\n";
			}	

			$dummy=$#disks;
			print "Got $dummy physical disk lines on controller $controller{'id'}\n" if $debug > 1;
			# no need to check virtual disks if there are no harddisks
			if ( grep /^(\d+:){1,2}\d+;.*/, @disks ) {
				push (@disks,`$omcmd vdisk controller=$controller{'id'} $omfmt`); 
				if ( $analyze ) {
					print "\n--CMD4--: $omcmd vdisk controller=$controller{'id'} $omfmt\n";
					$J=$#disks-($#disks-$dummy);
					while ( $J <= $#disks ) {
						print "$disks[$J]";
						$J++; }	
					print "--CMD4 results:\n";
				}	
				print 'Got '.($#disks-$dummy)." logical disk lines on controller $controller{'id'}\n" if $debug > 1;
			}

			print @disks if $debug > 2;
			chomp @disks;	
			
			foreach $J (@disks) {
				undef (%disk);

				$match=0;
				if ( $omversion =~ /^4\./ ) {
					(($disk{'id'},$disk{'status'},$disk{'state'},$disk{'progress'}) = ($J =~  /^([\d:]+?);([\w-]+?);.+?;(\w+?);(.*?);/)) && ($match=1);
					$disk{'predicted'}='n/a';
				} elsif ( $omversion =~ /^5\./ ) {	
					(($disk{'id'},$disk{'status'},$disk{'state'},$disk{'predicted'},$disk{'progress'}) = ($J =~  /^([\d:]+?);([\w-]+?);.+?;(.+?);(.*?);(.*?);/)) && ($match=1)
				} 
				
				if ($match) {
					if ( $disk{'id'} =~ /:/ ) {
						$disk{'type'}='physical';

						print "Status of $disk{'type'} disk $disk{'id'}: $disk{'status'}, state: $disk{'state'}, predicted: $disk{'predicted'}, progess: $disk{'progress'}\n" if $debug; 
					} else {	
						$disk{'type'}='virtual';
						$dummy=$disk{'progress'};
						$disk{'progress'}=$disk{'predicted'};
						$disk{'predicted'}=$dummy;
						
						print "Status of $disk{'type'} disk $disk{'id'}: $disk{'status'}, state: $disk{'state'}, progress: $disk{'progress'}, type: $disk{'predicted'}\n" if $debug; 
					}	
					
					if ( ($disk{'status'} ne 'Ok') or ($disk{'state'} ne 'Online' and $disk{'state'} ne 'Ready') ) {
						if ( $disk{'status'} =~ /Noncritical|Ok/ and $disk{'state'} =~ /Regenerating|Rebuilding|Resynching|Resyncing|Background\sInitialization/ ) {
							push @messages,"Ctrl $controller{'id'} Disk $disk{'id'} is $disk{'status'}($disk{'state'}, $disk{'progress'})";
							$result=addresult($result,$ERRORS{'WARNING'});
						} elsif ( $disk{'status'} eq 'Noncritical' and $disk{'state'} eq 'Degraded' ) {
							push @messages,"Ctrl $controller{'id'} Disk $disk{'id'} is $disk{'status'}($disk{'state'})";
							$result=addresult($result,$ERRORS{'WARNING'});
						} else {							
							push @messages,"Ctrl $controller{'id'} Disk $disk{'id'} is $disk{'status'}($disk{'state'})";
							$result=addresult($result,$ERRORS{'CRITICAL'});
						}	
					}	

					if ($disk{'predicted'} eq 'Yes') {
						push @messages,"Predicted fail on Ctrl $controller{'id'} Disk $disk{'id'}";
						$result=addresult($result,$ERRORS{'WARNING'});
					}	
				}

			}

			print "\nChecking Batteries on Controller $controller{'id'}:\n" if $debug;
			undef @batteries;
			@batteries=`$omcmd battery controller=$controller{'id'} $omfmt`;
			if ( $analyze ) {
				print "\n--CMD5--: $omcmd battery controller=$controller{'id'} $omfmt\n";
				print @batteries;
				print "--CMD5 results:\n";
			}

			print "Got $#batteries battery lines\n" if $debug > 1;
			print @batteries if $debug > 2;
			chomp @batteries;

			foreach $J (@batteries) {
				undef (%battery);
				if (($battery{'id'},$battery{'status'},$battery{'name'},$battery{'state'},$battery{'chargecount'},$battery{'chargemax'}) = ($J =~ /^(\d+?);(.+?);(.+?);(\w+?);(.*?);(.*?);/)) {
					print "Status of battery $battery{'id'}: $battery{'status'}, state: $battery{'state'}\n" if $debug;

					if ( $battery{'status'} ne 'Ok' or $battery{'state'} ne 'Ready' ) { 
						if ( $battery{'status'} eq 'Non-Critical' ) {
							$result=addresult($result,$ERRORS{'WARNING'});
						} else {	
							$result=addresult($result,$ERRORS{'CRITICAL'});
						}	
						push @messages,"Ctrl $controller{'id'} Batt $battery{'id'} is $battery{'status'}($battery{'state'})";
					}

					if ( $battery{'chargecount'} =~ /^\d+$/ and $battery{'chargemax'} =~ /^\d+$/ ) {
						if ( $battery{'chargecount'} >= $battery{'chargemax'} ) {
							push @messages,"Ctrl $controller{'id'} Batt $battery{'id'} charge max reached";
							$result=addresult($result,$ERRORS{'WARNING'});
						}
					}	
				}
			}	
		}
	}
} else {
	push @messages,"Error: $om not found\n\n";
	usage();
}


# Script end
print "\nResult: $result\n" if $debug;
writemessages(@messages);
exit $result;

# Subs

sub addresult {
	my $oldresult=shift @_;
	my $newresult=shift @_;

	if ( $oldresult eq $ERRORS{'UNKNOWN'} or $newresult gt $oldresult ) {
		return $newresult;
	}

	return $oldresult;
}	

sub writemessages {
	my @messages = @_;

	unshift @messages, '[' if $#messages >= 0;

	foreach (keys %ERRORS) {
		unshift @messages, "$_" if $ERRORS{$_} == $result;
	}	

	push @messages, ']' if $#messages > 0;

	print 'STORAGE: ',substr ((join " ",@messages),0,71),"\n";
}

sub usage {
	writemessages(@messages);
	print (basename $0." (C) 2005 - 2007 Riege Software International GmbH\n\n");
	print "This script analyzes the state of DELL storage using the omreport command\nfrom the DELL OpenManage 4.3 or later distribution. As omreport requires root\nprivileges, please add the following line to /etc/sudoers (\"nagios\" is the user\nrunning the script and may be a different user on your system depending on your\nNagios Plugins and nrpe setup):\n\nnagios 	ALL= NOPASSWD: /usr/bin/omreport *\n\nUsage:\n";  
	print (basename $0." [--analyze] [--help] [--sudo] [--verbose]\n");
	print "  --analyze: Scan Storage System and display OpenManage Output and script\n";
	print "             results. Use this if your storage system is not properly checked\n";
	print "             and send the output to schlegel\@riege.com .\n";
	print "  --help:    Display exactly this text.\n";
	print "  --sudo:    Use sudo to run omreport.\n";
	print "  --verbose: run script in debug mode.\n";
	exit $ERRORS{'UNKNOWN'};
}
	
sub exitmessage {
	my $result=shift @_;

	print join ' ',@messages."\n";
	exit $result; 
}	

# vim: autoindent number ts=4
