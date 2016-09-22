#!/usr/bin/perl
#
# License: GPL v.3+
# Copyright (c) 2009 op5 AB
# Author: Henrik Nilsson <henrik30000@gmail.com>
#
# For direct contact with any of the op5 developers send a mail to
# op5-users@lists.op5.com
# Discussions are directed to the mailing list op5-users@op5.com,
# see http://lists.op5.com/mailman/listinfo/op5-users
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3 or,
# at your option, any later version, as published by the Free Software
# Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

use DBI;
use Nagios::Plugin;
my $return_code=0;
my $return_msg;
my $p=Nagios::Plugin->new(usage=>"Usage %s: -U user -P password (-H server|-S servername)\n");

$p->add_arg(spec=>'username|U=s', help=>'User name', required=>1);
$p->add_arg(spec=>'password|P=s', help=>'Password', required=>1);
$p->add_arg(spec=>'host|H=s', help=>'BizTalk server to check (hostname/IP)', required=>0);
$p->add_arg(spec=>'server|S=s', help=>'BizTalk server to check (by sybase configuration)', required=>0);
$p->add_arg(spec=>'port|p=i', help=>'Port for the MSSQL server that BizTalk uses', required=>0);
$p->add_arg(spec=>'warning|w=s', help=>'Warning-range for receive/send ports', required=>0);
$p->add_arg(spec=>'critical|c=s', help=>'Critical-range for receive/send ports', required=>0);
$p->add_arg(spec=>'queuewarning|W=s', help=>'Warning-range for queues', required=>0);
$p->add_arg(spec=>'queuecritical|C=s', help=>'Critical-range for queues', required=>0);
$p->add_arg(spec=>'orchestrationwarning|o=s', help=>'Warning-range for orchestrations', required=>0);
$p->add_arg(spec=>'orchestrationcritical|O=s', help=>'Critical-range for orchestrations', required=>0);
$p->add_arg(spec=>'sendportwarning|d=s', help=>'Warning-range for sendports', required=>0);
$p->add_arg(spec=>'sendportcritical|D=s', help=>'Critical-range for sendports', required=>0);
$p->add_arg(spec=>'receivelocations|l=s', help=>'Specific receivelocation(s) to check, comma-separated', required=>0);
$p->getopts;

if(!defined($p->opts->host)&&!defined($p->opts->server)){$p->nagios_die("You must provide either host or server name");}

# Set up timeout
if(defined($p->opts->timeout))
{
  $SIG{'ALRM'} = sub{$p->nagios_die("UNKNOWN", "Plugin timed out.");};
  alarm($p->opts->timeout);
}

if (defined($p->opts->port)) {
  $ENV{TDSPORT} = $p->opts->port;
}

# Connect to the database
my $db;
if(defined($p->opts->host))
{
  $db=DBI->connect("dbi:Sybase:server=".$p->opts->host.";port=".(defined($p->opts->port)?$p->opts->port:1433), $p->opts->username, $p->opts->password) or $p->nagios_die("Could not connect to the BizTalk database", CRITICAL);
}else{
  $db=DBI->connect("dbi:Sybase:".$p->opts->server, $p->opts->username, $p->opts->password) or $p->nagios_die("Could not connect to the BizTalk database", CRITICAL);
}
$db->prepare("use BizTalkMgmtDb")->execute();

# Check receive locations
my $q=$db->prepare("select Name, Disabled from adm_ReceiveLocation;");
$q->execute();
my $name, $disabled;
my $count=0;
my $msg="";
$q->bind_columns(\$name, \$disabled);
if(defined($p->opts->receivelocations))
{
  $msg='';
  my @list=split(",", $p->opts->receivelocations);
  while($q->fetch)
  {
    if($disabled and grep {$_ eq $name} @list)
    {
      $msg.=$name.", ";
      $count++;
    }
  }
  $return_code=$p->check_threshold(check=>$count, warning=>$p->opts->warning, critical=>$p->opts->critical);
  $p->nagios_exit($return_code, $count." of ".@list." receive location".(@list!=1?'s':'')." disabled: ".$msg);
}else{
  while($q->fetch)
  {
    if($disabled)
    {
      $msg.=$name.", ";
      $count++;
    }
  }
}
$code=$p->check_threshold(check=>$count, warning=>$p->opts->warning, critical=>$p->opts->critical);
if($code>$return_code)
{
  $return_code=$code;
  $return_msg=$count." receive location".($count!=1?"s":"")." disabled: ".$msg;
}elsif($return_code==0){
  $return_msg.=$count." receive location".($count!=1?"s":"")." disabled. ";
}

# Check message queue
# Getting the messagequeue, in which we check if nState is 4 or 32 (both mean suspended, 4 for resumable, 32 for non-resumable)
$db->prepare("use BizTalkMsgBoxDb")->execute();
$q=$db->prepare("select nState, nvcErrorDescription from InstancesSuspended where nState=4 or nState=32;");
$q->execute();
my $state, $error;
$count=0;
$msg="";
$q->bind_columns(\$state, \$error);
while($q->fetch)
{
  if($state==32)
  {
    $msg.="Non-resumable: ".$error;
  }else{
    $msg.="Resumable: ".$error;
  }
  $count++;
}
$code=$p->check_threshold(check=>$count, warning=>$p->opts->warning, critical=>$p->opts->critical);
if($code>$return_code)
{
  $return_code=$code;
  $return_msg=$count." suspended messages: ".$msg;
}elsif($return_code==0){
  $return_msg.=$count." suspended messages. ";
}

# Check the total length of the queue
$q=$db->prepare("select count(nState) from InstancesSuspended;");
$q->execute();
my @line=$q->fetchrow_array;
$code=$p->check_threshold(check=>$line[0], warning=>$p->opts->queuewarning, critical=>$p->opts->queuecritical);
if($code>$return_code)
{
  $return_code=$code;
  $return_msg=$line[0]." messages in queue.";
}elsif($return_code==0){
  $return_msg.=$line[0]." messages in queue. ";
}

# Check SendPorts
$q=$db->prepare("SELECT nvcName AS SendPortName, nPortStatus as PortStatus FROM [BizTalkMgmtDb].[dbo].[bts_sendport] WHERE nPortStatus != 3");
$q->execute();
$q->bind_columns(\$SendPortName, \$PortStatus);

$count=0;
my $portline;
while($q->fetch) {
    $portline .= $SendPortName . ": " . $PortStatus . " ";
    $count++;
}
    $return_msg .= $count . " lines matching SendPortStatus <> 3. ";

$code=$p->check_threshold(check=>$count,warning=>$p->opts->sendportwarning,critical=>$p->opts->sendportcritical);

if ( $code > 0 ) {
    $return_code = $code;
    $return_msg =" SendPort: " . $portline
}


# Check Orchesrations
$q=$db->prepare("SELECT nvcFullName AS OrchestrationName,nOrchestrationStatus as PortStatus FROM [BizTalkMgmtDb].[dbo].[bts_orchestration] WHERE (nOrchestrationStatus != 3)");
$q->execute();
$q->bind_columns(\$OrchestrationName, \$PortStatus);

$count=0;
my $orchline;
while($q->fetch) {
    $orchline .= $OrchestrationName . ": " . $PortStatus . " ";
    $count++;
}
    $return_msg .= $count . " lines matching OrchestrationStatus <> 3. ";

$code=$p->check_threshold(check=>$count,warning=>$p->opts->orchestrationwarning,critical=>$p->opts->orchestrationcritical);

if ( $code > 0 ) {
    $return_code = $code;
    $return_msg =" Orchestration: " . $orchline
}

$p->nagios_exit($return_code, $return_msg);
