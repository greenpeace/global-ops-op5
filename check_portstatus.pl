#!/usr/bin/perl
#
# License: GPL v3
# Copyright (C) 2009 op5 AB
# Author: Henrik Nilsson <henrik30000@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Config:
my $spooldir="/var/spool/check_portstatus";
my @skip_interface_types=(53, 28, 24);
my $unused_port_dormant_time=600; # Seconds

use Net::SNMP;
use Getopt::Long;
use Nagios::Plugin::Range;

my %STATUS=("OK"=>0, "WARNING"=>1, "ERROR"=>2, "UNKNOWN"=>3);
if(!-d $spooldir){mkdir($spooldir);}

sub status_exit {
  my ($state, $message) = @_;
  print("$state: $message\n");
  exit $STATUS{$state};
};

$SIG{'ALRM'}=sub {
  print("Timeout\n");
  exit $STATUS{"UNKNOWN"};
};

sub in_array
{
  my $key=$_[0];
  my @array=@{$_[1]};
  foreach $arrvalue (@array)
  {
    if($key eq $arrvalue){return 1;}
  }
  return 0;
}

sub timestrtonum
{
  my @str=split(/,/, $_[0]);
  my ($count, $units) = ($str[0] =~ /(\d+) (.*)/);
  my $num = 0;

  if($units eq "minute"||$units eq "minutes"){$num = $count * 60;}
  if($units eq "hour"||$units eq "hours"){$num = $count * 3600;}
  if($units eq "day"||$units eq "days"){$num = $count * 86400; shift(@str);}

  ($hour, $min, $sec) = ($str[0] =~ /(\d+):(\d+):(\d+)/);
  if (defined($hour)) {
    $num += $hour * 3600 + $min * 60 + $sec;
  }

  return $num;
}

my @typenames;
$typenames[1]='other';
$typenames[2]='regular1822';
$typenames[3]='hdh1822';
$typenames[4]='ddnX25';
$typenames[5]='rfc877x25';
$typenames[6]='ethernetCsmacd';
$typenames[7]='iso88023Csmacd';
$typenames[8]='iso88024TokenBus';
$typenames[9]='iso88025TokenRing';
$typenames[10]='iso88026Man';
$typenames[11]='starLan';
$typenames[12]='proteon10Mbit';
$typenames[13]='proteon80Mbit';
$typenames[14]='hyperchannel';
$typenames[15]='fddi';
$typenames[16]='lapb';
$typenames[17]='sdlc';
$typenames[18]='ds1';
$typenames[19]='e1';
$typenames[20]='basicISDN';
$typenames[21]='primaryISDN';
$typenames[22]='propPointToPointSerial';
$typenames[23]='ppp';
$typenames[24]='softwareLoopback';
$typenames[25]='eon';
$typenames[26]='ethernet3Mbit';
$typenames[27]='nsip';
$typenames[28]='slip';
$typenames[29]='ultra';
$typenames[30]='ds3';
$typenames[31]='sip';
$typenames[32]='frameRelay';
$typenames[33]='rs232';
$typenames[34]='para';
$typenames[35]='arcnet';
$typenames[36]='arcnetPlus';
$typenames[37]='atm';
$typenames[38]='miox25';
$typenames[39]='sonet';
$typenames[40]='x25ple';
$typenames[41]='iso88022llc';
$typenames[42]='localTalk';
$typenames[43]='smdsDxi';
$typenames[44]='frameRelayService';
$typenames[45]='v35';
$typenames[46]='hssi';
$typenames[47]='hippi';
$typenames[48]='modem';
$typenames[49]='aal5';
$typenames[50]='sonetPath';
$typenames[51]='sonetVT';
$typenames[52]='smdsIcip';
$typenames[53]='propVirtual';
$typenames[54]='propMultiplexor';
$typenames[55]='ieee80212';
$typenames[56]='fibreChannel';
$typenames[57]='hippiInterface';
$typenames[58]='frameRelayInterconnect';
$typenames[59]='aflane8023';
$typenames[60]='aflane8025';
$typenames[61]='cctEmul';
$typenames[62]='fastEther';
$typenames[63]='isdn';
$typenames[64]='v11';
$typenames[65]='v36';
$typenames[66]='g703at64k';
$typenames[67]='g703at2mb';
$typenames[68]='qllc';
$typenames[69]='fastEtherFX';
$typenames[70]='channel';
$typenames[71]='ieee80211';
$typenames[72]='ibm370parChan';
$typenames[73]='escon';
$typenames[74]='dlsw';
$typenames[75]='isdns';
$typenames[76]='isdnu';
$typenames[77]='lapd';
$typenames[78]='ipSwitch';
$typenames[79]='rsrb';
$typenames[80]='atmLogical';
$typenames[81]='ds0';
$typenames[82]='ds0Bundle';
$typenames[83]='bsc';
$typenames[84]='async';
$typenames[85]='cnr';
$typenames[86]='iso88025Dtr';
$typenames[87]='eplrs';
$typenames[88]='arap';
$typenames[89]='propCnls';
$typenames[90]='hostPad';
$typenames[91]='termPad';
$typenames[92]='frameRelayMPI';
$typenames[93]='x213';
$typenames[94]='adsl';
$typenames[95]='radsl';
$typenames[96]='sdsl';
$typenames[97]='vdsl';
$typenames[98]='iso88025CRFPInt';
$typenames[99]='myrinet';
$typenames[100]='voiceEM';
$typenames[101]='voiceFXO';
$typenames[102]='voiceFXS';
$typenames[103]='voiceEncap';
$typenames[104]='voiceOverIp';
$typenames[105]='atmDxi';
$typenames[106]='atmFuni';
$typenames[107]='atmIma';
$typenames[108]='pppMultilinkBundle';
$typenames[109]='ipOverCdlc';
$typenames[110]='ipOverClaw';
$typenames[111]='stackToStack';
$typenames[112]='virtualIpAddress';
$typenames[113]='mpc';
$typenames[114]='ipOverAtm';
$typenames[115]='iso88025Fiber';
$typenames[116]='tdlc';
$typenames[117]='gigabitEthernet';
$typenames[118]='hdlc';
$typenames[119]='lapf';
$typenames[120]='v37';
$typenames[121]='x25mlp';
$typenames[122]='x25huntGroup';
$typenames[123]='trasnpHdlc';
$typenames[124]='interleave';
$typenames[125]='fast';
$typenames[126]='ip';
$typenames[127]='docsCableMaclayer';
$typenames[128]='docsCableDownstream';
$typenames[129]='docsCableUpstream';
$typenames[130]='a12MppSwitch';
$typenames[131]='tunnel';
$typenames[132]='coffee';
$typenames[133]='ces';
$typenames[134]='atmSubInterface';
$typenames[135]='l2vlan';
$typenames[136]='l3ipvlan';
$typenames[137]='l3ipxvlan';
$typenames[138]='digitalPowerline';
$typenames[139]='mediaMailOverIp';
$typenames[140]='dtm';
$typenames[141]='dcn';
$typenames[142]='ipForward';
$typenames[143]='msdsl';
$typenames[144]='ieee1394';
$typenames[145]='if-gsn';
$typenames[146]='dvbRccMacLayer';
$typenames[147]='dvbRccDownstream';
$typenames[148]='dvbRccUpstream';
$typenames[149]='atmVirtual';
$typenames[150]='mplsTunnel';
$typenames[151]='srp';
$typenames[152]='voiceOverAtm';
$typenames[153]='voiceOverFrameRelay';
$typenames[154]='idsl';
$typenames[155]='compositeLink';
$typenames[156]='ss7SigLink';
$typenames[157]='propWirelessP2P';
$typenames[158]='frForward';
$typenames[159]='rfc1483';
$typenames[160]='usb';
$typenames[161]='ieee8023adLag';
$typenames[162]='bgppolicyaccounting';
$typenames[163]='frf16MfrBundle';
$typenames[164]='h323Gatekeeper';
$typenames[165]='h323Proxy';
$typenames[166]='mpls';
$typenames[167]='mfSigLink';
$typenames[168]='hdsl2';
$typenames[169]='shdsl';
$typenames[170]='ds1FDL';
$typenames[171]='pos';
$typenames[172]='dvbAsiIn';
$typenames[173]='dvbAsiOut';
$typenames[174]='plc';
$typenames[175]='nfas';
$typenames[176]='tr008';
$typenames[177]='gr303RDT';
$typenames[178]='gr303IDT';
$typenames[179]='isup';
$typenames[180]='propDocsWirelessMaclayer';
$typenames[181]='propDocsWirelessDownstream';
$typenames[182]='propDocsWirelessUpstream';
$typenames[183]='hiperlan2';
$typenames[184]='propBWAp2Mp';
$typenames[185]='sonetOverheadChannel';
$typenames[186]='digitalWrapperOverheadChannel';
$typenames[187]='aal2';
$typenames[188]='radioMAC';
$typenames[189]='atmRadio';
$typenames[190]='imt';
$typenames[191]='mvl';
$typenames[192]='reachDSL';
$typenames[193]='frDlciEndPt';
$typenames[194]='atmVciEndPt';
$typenames[195]='opticalChannel';
$typenames[196]='opticalTransport';
$typenames[197]='propAtm';
$typenames[198]='voiceOverCable';
$typenames[199]='infiniband';
$typenames[200]='teLink';
$typenames[201]='q2931';
$typenames[202]='virtualTg';
$typenames[203]='sipTg';
$typenames[204]='sipSig';
$typenames[205]='docsCableUpstreamChannel';
$typenames[206]='econet';
$typenames[207]='pon155';
$typenames[208]='pon622';
$typenames[209]='bridge';
$typenames[210]='linegroup';
$typenames[211]='voiceEMFGD';
$typenames[212]='voiceFGDEANA';
$typenames[213]='voiceDID';
$typenames[214]='mpegTransport';
$typenames[215]='sixToFour';
$typenames[216]='gtp';
$typenames[217]='pdnEtherLoop1';
$typenames[218]='pdnEtherLoop2';
$typenames[219]='opticalChannelGroup';
$typenames[220]='homepna';
$typenames[221]='gfp';
$typenames[222]='ciscoISLvlan';
$typenames[223]='actelisMetaLOOP';
$typenames[224]='fcipLink';
$typenames[225]='rpr';
$typenames[226]='qam';

# Default values
my $port=161;
my $snmp_version="1";
my $community="public";
my $timeout=30;
my $limit=1;
my $warning="i";
my $admindown="i";
my $options=GetOptions("hostname=s"     => \$hostnames,    "H=s" => \$hostnames,
                       "community=s"    => \$community,    "C=s" => \$community,
                       "port=i"         => \$port,         "p=i" => \$port,
                       "snmp_version=s" => \$snmp_version, "v=s" => \$snmp_version,
                       "timeout=i"      => \$timeout,      "t=i" => \$timeout,
                       "dormant-time=i" => \$unused_port_dormant_time, "i=i" => \$unused_port_dormant_time,
                       "warn=s"         => \$warning,      "w=s" => \$warning,
                       "admin-down=s"   => \$admindown,    "D=s" => \$admindown,
                       "limit=s"        => \$limit,        "l=s" => \$limit,
                       "version"        => \$plugversion,
                       "help"           => \$help,
                       "skip-interfaces=s" => \$skipinterfaces,
                       "maxmsgsize=i"   => \$maxmsgsize);

my $range=Nagios::Plugin::Range->parse_range_string($limit);

if(defined($skipinterfaces)){@skip_interface_types=split(",", $skipinterfaces);}

if(defined($plugversion)){print("Version: 0.11\n");exit(0);}

if(!$options||defined($help))
{
  print("Usage: ./check_portstatus.pl <options>\n");
  print("-H (--hostname)     Hostname of host to query\n");
  print("-C (--community)    SNMP community (default public)\n");
  print("-p (--port)         Which port to use for SNMP connections (default 161)\n");
  print("-v (--snmp_version) SNMP version (1 or 2c, default 1)\n");
  print("-i (--dormant-time) How many seconds a port can be operational idle\n");
  print("                     before being considered dormant\n");
  print("-w (--warn)         Status to return for dormant ports\n");
  print("                     (i=ignore, w=warn, c=critical, ignore is the default)\n");
  print("-D (--admin-down)   Status for administratively down ports\n");
  print("                     (i=ignore, w=warn, c=critical, ignore is the default)\n");
  print("-l (--limit)        Minimum number of ports to be dormant/\n");
  print("                     administratively down to trigger status messages\n");
  print("-t (--timeout)      Timeout in seconds\n");
  print("--skip-interfaces   Comma separated list of interface types to consider\n");
  print("                     virtual and skip.");
  print("--version           Print the version of the plugin and exit\n");
  print("--maxmsgsize        Maximum SNMP message size\n");
  print("--help              Print this help text\n");
  if(!$options)
  {
    exit($STATUS{"UNKNOWN"});
  }else{
    exit($STATUS{"OK"});
  }
}

# OID numbers, to save time from look-ups
my $snmpIfIndex='1.3.6.1.2.1.2.2.1.1';
my $snmpIfAdminStatus='1.3.6.1.2.1.2.2.1.7';
my $snmpIfDescr='1.3.6.1.2.1.2.2.1.2';
my $snmpIfOperStatus='1.3.6.1.2.1.2.2.1.8';
my $snmpIfName='1.3.6.1.2.1.31.1.1.1.1';
my $snmpIfAlias='1.3.6.1.2.1.31.1.1.1.18';
my $snmpLocIfDescr='1.3.6.1.4.1.9.2.2.1.1.28';
my $snmpIfType='1.3.6.1.2.1.2.2.1.3';
my $snmpIfLastChange='1.3.6.1.2.1.2.2.1.9';
my $snmpIfSpeed='1.3.6.1.2.1.2.2.1.5';
my $snmpUptime='1.3.6.1.2.1.1.3';

my $session;
my $error;
if($timeout!=0){alarm($timeout);}
if(!defined($hostnames)){print("No hostnames defined!\n"); exit $STATUS{"ERROR"};}

my $result;
my @hostnamelist=split(",", $hostnames);
my %ports;
my %hostuptimes;
my $available=0;
my $in_use=0;
my $admindowncount=0;
my $invalid=0; # For voids between key intervals and virtual interfaces (to make the calculations correct)
my $extramsg=""; # Additional status info
# Loop through each host and get their port information
foreach my $hostname (@hostnamelist)
{
  # Set up the session
  if(!defined($hostname)){print("No hostname defined!\n"); exit $STATUS{"ERROR"};}
  ($session, $error) = Net::SNMP->session(-hostname    => $hostname,
                                          -community   => $community,
                                          -port        => $port,
                                          -version     => $snmp_version);
  if(!defined($session)){$extramsg.=" Failed to connect to ".$hostname.": ".$error."."; next;}
  $result=$session->get_table($snmpUptime);
  my @keys=keys %{$result};
  $hostuptimes{$hostname}=timestrtonum(${$result}{$keys[0]});
  if(defined($maxmsgsize)){$session->max_msg_size($maxmsgsize);}
  my %currentports=();
  #############
  $result=$session->get_table($snmpIfIndex);
  @keys=keys %{$result};
  foreach $index (0..@keys-1)
  {
    my $key=$keys[$index];
    $key=~s/.*\.//;
    if(!defined($currentports{$key})){my %port=("host"=>$hostname);$currentports{$key}=\%port;}
    $currentports{$key}{"index"}=${$result}{$keys[$index]};
  }
  #############
  $result=$session->get_table($snmpIfAdminStatus);
  @keys=keys %{$result};
  foreach $index (0..@keys-1)
  {
    my $key=$keys[$index];
    $key=~s/.*\.//;
    if(!defined($currentports{$key})){my %port=("host"=>$hostname);$currentports{$key}=\%port;}
    $currentports{$key}{"adminstatus"}=${$result}{$keys[$index]};
  }
  #############
  $result=$session->get_table($snmpIfDescr);
  @keys=keys %{$result};
  foreach $index (0..@keys-1)
  {
    my $key=$keys[$index];
    $key=~s/.*\.//;
    if(!defined($currentports{$key})){my %port=("host"=>$hostname);$currentports{$key}=\%port;}
    $currentports{$key}{"descr"}=${$result}{$keys[$index]};
  }
  #############
  $result=$session->get_table($snmpIfOperStatus);
  @keys=keys %{$result};
  foreach $index (0..@keys-1)
  {
    my $key=$keys[$index];
    $key=~s/.*\.//;
    if(!defined($currentports{$key})){my %port=("host"=>$hostname);$currentports{$key}=\%port;}
    $currentports{$key}{"operstatus"}=${$result}{$keys[$index]};
  }
  #############
  $result=$session->get_table($snmpIfName);
  @keys=keys %{$result};
  foreach $index (0..@keys-1)
  {
    my $key=$keys[$index];
    $key=~s/.*\.//;
    if($currentports{$key}==NULL){my %port=("host"=>$hostname);$currentports{$key}=\%port;}
    $currentports{$key}{"name"}=${$result}{$keys[$index]};
  }
  #############
  $result=$session->get_table($snmpIfAlias);
  @keys=keys %{$result};
  foreach $index (0..@keys-1)
  {
    my $key=$keys[$index];
    $key=~s/.*\.//;
    if($currentports{$key}==NULL){my %port=("host"=>$hostname);$currentports{$key}=\%port;}
    $currentports{$key}{"alias"}=${$result}{$keys[$index]};
  }
  #############
  $result=$session->get_table($snmpLocIfDescr);
  @keys=keys %{$result};
  foreach $index (0..@keys-1)
  {
    my $key=$keys[$index];
    $key=~s/.*\.//;
    if(!defined($currentports{$key})){my %port=("host"=>$hostname);$currentports{$key}=\%port;}
    $currentports{$key}{"locdescr"}=${$result}{$keys[$index]};
  }
  #############
  $result=$session->get_table($snmpIfType);
  @keys=keys %{$result};
  foreach $index (0..@keys-1)
  {
    my $key=$keys[$index];
    $key=~s/.*\.//;
    if(!defined($currentports{$key})){my %port=("host"=>$hostname);$currentports{$key}=\%port;}
    $currentports{$key}{"type"}=${$result}{$keys[$index]};
  }
  #############
  $result=$session->get_table($snmpIfLastChange);
  @keys=keys %{$result};
  foreach $index (0..@keys-1)
  {
    my $key=$keys[$index];
    $key=~s/.*\.//;
    if(!defined($currentports{$key})){my %port=("host"=>$hostname);$currentports{$key}=\%port;}
    $currentports{$key}{"lastchange"}=timestrtonum(${$result}{$keys[$index]});
    if($currentports{$key}{"lastchange"}>$hostuptimes{$hostname}){$currentports{$key}{"lastchange"}=0;}
  }
  #############
  $result=$session->get_table($snmpIfSpeed);
  @keys=keys %{$result};
  foreach $index (0..@keys-1)
  {
    my $key=$keys[$index];
    $key=~s/.*\.//;
    if(!defined($currentports{$key})){my %port=("host"=>$hostname);$currentports{$key}=\%port;}
    $currentports{$key}{"speed"}=${$result}{$keys[$index]};
  }
  #############
  $session->close;
  %ports = (%ports, %currentports);
}
# Write port information to a csv file (Comma Separated Values)
$csv="";
foreach my $hashkey (keys %ports)
{
  if(!defined($ports{$hashkey})){$invalid++;next;}

  my %hash=%{$ports{$hashkey}};

  if(in_array($hash{"type"}, \@skip_interface_types)){$invalid++;next;}
  if(in_array($typenames[$hash{"type"}], \@skip_interface_types)){$invalid++;next;}
  if($hash{"adminstatus"}==1)
  {
    if($hash{"lastchange"}==0 or $hash{"lastchange"}>$hostuptimes{$hash{"host"}})
    {
      # Load the old spooldata and find the same port there, adding to the current last-change time if the statuses match (if they don't, there has obviously been a change)
      open(OLDSPOOL, "<".$spooldir."/status".$hostnames);
      my $line;
      while($line=<OLDSPOOL>)
      {
        my @data=split(",", $line);
        if($hash{"index"} eq $data[0]&&$hash{"host"} eq $data[1]&&$hash{"adminstatus"} eq $data[2]&&$hash{"operstatus"} eq $data[4])
        {
          $hash{"lastchange"}=$hostuptimes{$hash{"host"}}-$data[9];
        }
      }
      close(OLDSPOOL);
    }
    if($hash{"operstatus"}!=1&&$hostuptimes{$hash{"host"}}-$hash{"lastchange"}>=$unused_port_dormant_time*100)
    {
      $available++;
    }else{
      $in_use++;
    }
  }
  $csv.=$hash{"index"}.",";
  $csv.=$hash{"host"}.",";
  $csv.=$hash{"adminstatus"}.",";
  $csv.=$hash{"descr"}.",";
  $csv.=$hash{"operstatus"}.",";
  $csv.=$hash{"name"}.",";
  $csv.=$hash{"alias"}.",";
  $csv.=$hash{"locdescr"}.",";
  $csv.=$hash{"type"}.",";
  $csv.=$hostuptimes{$hash{"host"}}-$hash{"lastchange"}.",";
  $csv.=$hash{"speed"}.",\n";
  if($hash{"adminstatus"}==2){$admindowncount++;}
}
open(SPOOL, ">".$spooldir."/newstatus".$hostnames) or status_exit("UNKNOWN", "Can not create file ".$spooldir."/newstatus".$hostnames.". Please check permissions, disk space and mount point availability.");
print SPOOL $unused_port_dormant_time."\n";
print SPOOL ((keys %ports)-$invalid)."\n";
print SPOOL $csv;
close(SPOOL);
rename($spooldir."/newstatus".$hostnames, $spooldir."/status".$hostnames) or status_exit("UNKNOWN", "Can not rename file ".$spooldir."/newstatus".$hostnames." to ".$spooldir."/status".$hostnames.". Please check permissions and mount point availability.");
$status="OK";
if($range->check_range($admindowncount))
{
  if($admindown eq "w"){$status="WARNING";}
  if($admindown eq "c"){$status="ERROR";}
}
if($range->check_range($available))
{
  if($warning eq "w"&&$status eq "OK"){$status="WARNING";}
  if($warning eq "c"){$status="ERROR";}
}
print($status.": ".$available." of ".((keys %ports)-$invalid)." ports available, ".((keys %ports)-$available-$in_use-$invalid)." down, <a href=\"/monitor/index.php/portstatus?address=".$hostnames."\">click here to view the report</a>.".$extramsg."\n");
exit $STATUS{$status};
