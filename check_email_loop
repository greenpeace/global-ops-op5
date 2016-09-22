#!/usr/bin/perl 
#
# $Id: $
#
# Version 1.2             
# Last update: 2007-06-11
#
# (c)2000 Benjamin Schmid, blueshift@gmx.net (emergency use only ;-)
# Copyleft by GNU GPL
#
#
# check_email_loop Nagios Plugin
#
# This script sends a mail with a specific id in the subject via
# an given smtp-server to a given email-adress. When the script
# is run again, it checks for this Email (with its unique id) on
# a given pop3 account and send another mail.
# 
#
# Example: check_email_loop.pl -poph=mypop -popu=user -pa=password
# 	   -smtph=mailer -from=returnadress@yoursite.com
#	   -to=remaileradress@friend.com -pendc=2 -lostc=0
#
# This example will send each time this check is executed a new
# mail to remaileradress@friend.com using the SMTP-Host mailer.
# Then it looks for any back-forwarded mails in the POP3 host
# mypop. In this Configuration CRITICAL state will be reached if  
# more than 2 Mails are pending (meaning that they did not came 
# back till now) or if a mails got lost (meaning a mail, that was
# send later came back prior to another mail).
# 
# Michael Markstaller, mm@elabnet.de various changes/additions
# MM 021003: fixed some unquoted strings
# MM 021116: fixed/added pendwarn/lostwarn
# MM 030515: added deleting of orphaned check-emails 
#            changed to use "top" instead of get to minimize traffic
#            (required changing match-string from "Subject: Email-ping [" to "Email-Ping ["
# 2006-11-09: Allow multiple mail-servers (separate stats files via target server hash).
#
# Emmanuel Kedaj (Emmanuel.kedaj@gmail.com)
# Added some debug messages
# retrieving POP3 mails before sending actual test mail
# as mentionned by Dave Ewall <dave_at_email.domain.hidden> on 19 Jul 2005 on Nagios-users mailing list
# https://lists.sourceforge.net/lists/listinfo/nagios-users
#
#
# Jb007 (007_james_bond NO @ SPAM libero.it) Oct 2006
# ChangeLog:
# * Used Mail::POP3Client for SSL support
# * Added trashall param
# * Fixed lost mail stat file
# * Added forgetafter param
# Bugs:
# * Try to delete matched id already marked for deletion
# * No interval even if present in options
# Todo:
# Implement "interval" param
#
#
# James W., September 2008  (v.1.3.1)
# * sanity check for required Authen:SASL module
#
# Martin D Kamijo (mk@op5.com) Feb 2008
# ChangeLog:
# * Added support for IMAP and IMAPS (need to install  IMAP and IMAP_SSL support in perl.
#     In Ubuntu/Debian:
#     aptitude install libio-socket-ssl-perl libnet-imap-simple-perl libnet-imap-simple-ssl-perl libnet-ssleay-perl libemail-simple-perl
#     In CentOS 5:
#     rpm -Uvh ftp://ftp.sunet.se/pub/Linux/distributions/centos/5/extras/i386/RPMS/perl-Net-IMAP-Simple-1.17-1.el5.centos.noarch.rpm
#     rpm -Uvh ftp://ftp.sunet.se/pub/Linux/distributions/centos/5/extras/i386/RPMS/perl-Net-IMAP-Simple-SSL-1.3-1.el5.centos.noarch.rpm
#
# * Added auth mode for POP3
#
# * Removed the option statfile, this is not used any more.
#
# * Updated usage and described that you may use IP:port on the smtp-server.
#
# * Added smtpuser, smtppass and smtpauthtype. You need a couple of perl modules for this to work:
#   To be able to use the SMTP auth you'll need this perl module: Net::SMTP_auth
#
# * Added support for TLS during the SMTP session.
#   Customization of Net::SMTP::TLS was done to acomplish this.
#  
# * Added a bit clearer error handling to the smtp-session
#
# * Added attachfile option. MIMIE::Base64 is needed for this.
#   In the sub attachFile there is a string that tells the script where the
#   attachments is suposed to be located on the server.
#   

use lib "/opt/plugins";

use Mail::POP3Client;
use Net::SMTP;
use Net::SMTP::SSL;
use Net::IMAP::Simple;
use Net::IMAP::Simple::SSL;
use Email::Simple;
use MIME::Base64;
use strict;
use Getopt::Long;
use Digest::MD5;
&Getopt::Long::config('auto_abbrev');

# ----------------------------------------

my $TIMEOUT = 120;
my %ERRORS = ('OK' , '0',
              'WARNING', '1',
              'CRITICAL', '2',
              'UNKNOWN' , '3');

my $state = "UNKNOWN";
my ($sender,$receiver, $pophost, $popuser, $poppasswd, $smtphost, $smtpuser, $smtppass, $keeporphaned, $useimap, $attachfile);
my ($trashall,$usessl,$forgetafter, $help);
my ($smtpusessl);
my ($poptimeout,$smtptimeout,$pinginterval,$maxmsg)=(60,60,5,50);
my ($lostwarn, $lostcrit, $pendwarn, $pendcrit);
my ($smtpauth, $popauth, $debug) = ("PLAIN", "PASS", 0);

# Internal Vars
my ($pop,$msgcount,@msglines,$statinfo,@messageids,$newestid);
my (%smtp_opts, %other_smtp_opts);
my ($matchcount, $statfile) = (0,"/opt/monitor/var/email_loop/check_email_loop");

# <- Variables used to create delimiters for the mime parts
our $b = "="; #Mime part delimiter
our ($i,$n,@chrs);
foreach $n (48..57,65..90,97..122) { $chrs[$i++] = chr($n);}
foreach $n (0..20) {$b .= $chrs[rand($i)];}
# <- End of variables for mime parts...

# Subs declaration
sub mkdir_p;
sub usage;
sub messagematchs;
sub nsexit;
sub attachFile;
sub sendMail;

# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
     # Write list to id-Database
     foreach my $id (@messageids) {
         print STATF  "$id\n";
     }
     close STATF;
     print ("ERROR: $0 Time-Out $TIMEOUT s \n");
     exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);


# Evaluate Command Line Parameters
my $status = GetOptions(
		  "from=s",\$sender,
			"to=s",\$receiver,
      "debug", \$debug,
      "pophost=s",\$pophost,
      "popuser=s",\$popuser,
			"passwd=s",\$poppasswd,
			"poptimeout=i",\$poptimeout,
      "popauth=s",\$popauth,
			"smtphost=s",\$smtphost,
      "smtpuser=s",\$smtpuser,
      "smtppass=s",\$smtppass,
			"smtptimeout=i",\$smtptimeout,
      "smtpauth=s",\$smtpauth,
			"interval=i",\$pinginterval,
			"lostwarn=i",\$lostwarn,
			"lostcrit=i",\$lostcrit,
			"pendwarn=i",\$pendwarn,
			"pendcrit=i",\$pendcrit,
			"maxmsg=i",\$maxmsg,
			"forgetafter=i",\$forgetafter,
			"keeporphaned=s",\$keeporphaned,
			"trashall",\$trashall,
			"usessl",\$usessl,
      "smtpusessl",\$smtpusessl,
      "useimap",\$useimap,
      "attachfile=s",\$attachfile,
      "statfile=s",\$statfile,
      "help",\$help,
			);
usage() if ($status == 0 || ! ($pophost && $popuser && $poppasswd &&
	$smtphost && $receiver && $sender ) || defined($help));

# Make sure that the directory we're going to write the statfile to exists
mkdir_p(substr($statfile, 0, rindex($statfile, "/")));

my @required_module = ();
push @required_module, 'Net::SMTP::SSL' if $smtpusessl;
push @required_module, ('MIME::Base64','Authen::SASL') if $smtpusessl && $smtpuser;
push @required_module, 'Authen::SASL' if $smtpuser && !$smtpusessl;
#exit $ERRORS{"UNKNOWN"} unless load_modules(@required_module);

# Hash stat file
my $statfilehash = Digest::MD5->new;
$statfilehash->add($sender.$receiver.$pophost.$popuser.$poppasswd.$smtphost);
$statfile = $statfile."_".$statfilehash->hexdigest.".stat";

# Try to read the ids of the last send emails out of statfile
if (open STATF, "$statfile") {
  @messageids = <STATF>;
  chomp @messageids;
  close STATF;
}

# Try to open statfile for writing 
if (!open STATF, ">$statfile") {
  nsexit("Failed to open mail-ID database $statfile for writing",'CRITICAL');
} else {
  printd ("Opened $statfile for writing..");
}

# Forget old mail
if (defined $forgetafter) {
        my $timeis=time();
        printd ("----------------------------------------------------------------------\n");
        printd ("----------------------------------------------------------------------\n");
        printd ("-------------------- Purging Old Mails -------------------------------\n");
        printd ("-------------------- Time: $timeis -------------------------------\n");
        printd ("-------------------- Forget: $forgetafter ------------------------\n");
        printd ("----------------------------------------------------------------------\n");
        printd ("----------------------------------------------------------------------\n");
        for (my $i=0; $i < scalar @messageids; $i++) {
                my $msgtime = $messageids[$i];
                $msgtime =~ /\#(\d+)\#/;
                $msgtime = $1;
                my $diff=($timeis-$msgtime)/86400;
                if ($diff>$forgetafter) {
                        printd ("Purging mail $i with date $msgtime\n");
                        splice @messageids, $i, 1;
                                last;
                }
        }
}


# Let's start checking the POP3 or IMAP account for mails.
if (!$useimap) {
  printd ("----------------------------------------------------------------------\n");
  printd ("----------------------------------------------------------------------\n");
  printd ("-------------------- Checking POP3 Mails -----------------------------\n");
  printd ("----------------------------------------------------------------------\n");
  printd ("----------------------------------------------------------------------\n");
  if (defined $usessl) { printd ("Retrieving POP mails from $pophost using ssl and user: $popuser and password $poppasswd with AUTH_METHOD $popauth\n"); }
  else { printd ("Retrieving POP mails from $pophost using user: $popuser and password $poppasswd with AUTH_METHOD $popauth\n"); }

  # now the interesting part: let's see if they are receiving ;-)

  my $port=110;
  if(index($pophost, ':') > -1)
  {
    $port=substr($pophost, index($pophost, ':')+1, length($pophost));
    $pophost=substr($pophost, 0, index($pophost, ':'));
  }
  $pop = Mail::POP3Client->new( 
         USER => $popuser,
         PASSWORD => $poppasswd,
         HOST => $pophost,
         PORT => $port,
         TIMEOUT => $poptimeout,
         USESSL => $usessl ,
         AUTH_MODE => $popauth,
         DEBUG => $debug ) || nsexit("POP3 connect timeout (>$poptimeout s, host: $pophost)",'CRITICAL');

  $pop->Login()|| nsexit("POP3 login failed (user:$popuser)",'CRITICAL');
  $msgcount=$pop->Count();

  $statinfo="$msgcount mails on POP3";

  printd ("Found $statinfo\n");

  nsexit("POP3 login failed (user:$popuser)",'CRITICAL') if (!defined($msgcount));

  # Check if more than maxmsg mails in pop3-box
  nsexit(">$maxmsg Mails ($msgcount Mails on POP3); Please delete !",'WARNING') if ($msgcount > $maxmsg);

  my ($mid, $nid);
  # Count messages, that we are looking 4:
  while ($msgcount > 0) {
    my $msgtext = "";
    foreach ($pop->Head($msgcount)) {
      $msgtext= $msgtext . $_ . "\n";
      printd ("POP HEADER: " . $_ . "\n");
    }
    @msglines = $msgtext;
    for (my $i=0; $i < scalar @messageids; $i++) {
      if (messagematchsid(\@msglines,$messageids[$i])) { 
        $matchcount++;
        printd ("Messages are matching\n");
        # newest received mail than the others, ok remeber id.
        if (!defined $newestid) { 
          $newestid = $messageids[$i];
        } else {
	        $messageids[$i] =~ /\#(\d+)\#/;
          $mid = $1;
	        $newestid =~ /\#(\d+)\#/;
          $nid = $1;
          if ($mid > $nid) { 
            $newestid = $messageids[$i]; 
          }
        }
        printd ("Deleted retrieved mail $msgcount with messageid ".$messageids[$i]."\n");
        $pop->Delete($msgcount);  # remove E-Mail from POP3 server
        splice @messageids, $i, 1;# remove id from List
	      last;                     # stop looking in list
	    } 
    }
    # Messages Deleted before are marked for deletion here again
	  # we should try to avoid this.
	  # Delete orphaned Email-ping msg
	  my @msgsubject = grep /^Subject/, @msglines;
	  chomp @msgsubject;
        # Maybe we should delete all messages?
        if (defined $trashall) {
            $pop->Delete($msgcount);
            printd ("Deleted mail $msgcount\n");
	  # Scan Subject if email is an Email-Ping. In fact we match and delete also successfully retrieved messages here again.
	  } elsif (!defined $keeporphaned && $msgsubject[0] =~ /E-Mail Ping \[/) {
	    $pop->Delete($msgcount);  # remove E-Mail from POP3 server
            printd ("Deleted orphaned mail $msgcount with subject ".$msgsubject[0]."\n");
	  }

	  $msgcount--;
  }

  $pop->Close();  # necessary for pop3 deletion!

} elsif ($useimap) {
  printd ("----------------------------------------------------------------------\n");
  printd ("----------------------------------------------------------------------\n");
  printd ("-------------------- Checking IMAP Mails -----------------------------\n");
  printd ("----------------------------------------------------------------------\n");
  printd ("----------------------------------------------------------------------\n");

  my $imap;

  if (defined $usessl) {
    $imap = Net::IMAP::Simple::SSL->new($pophost) ||
            nsexit( "Unable to connect to IMAP: " . $Net::IMAP::Simple::errstr . "\n", 'CRITICAL');
    printd ("Retrieving IMAP mails from $pophost using ssl and user: $popuser and password $poppasswd\n");
  } else { 
    $imap = Net::IMAP::Simple->new($pophost) ||
            nsexit( "Unable to connect to IMAP: " . $Net::IMAP::Simple::errstr . "\n", 'CRITICAL');
    printd ("Retrieving IMAP mails from $pophost using user: $popuser and password $poppasswd\n");
  }

  

  # Log on
  if(!$imap->login($popuser,$poppasswd)){
    nsexit("Login failed: " . $imap->errstr . "\n", 'CRITICAL');
  }


  # Print the subject's of all the messages in the INBOX
  my $msgcount = $imap->select('INBOX');

  $statinfo="$msgcount mails on IMAP";

  printd ("Found $statinfo\n");

  nsexit("IMAP login failed (user:$popuser)",'CRITICAL') if (!defined($msgcount));


  my ($mid, $nid);
  # Count messages, that we are looking 4:
  while ($msgcount > 0) {
    my $msgtext = "";
    my $tmpmail = Email::Simple->new(join '', @{ $imap->top($msgcount) } );
    if (length($tmpmail->header('Subject')) > 0) {
      $msgtext = "Subject: " . $tmpmail->header('Subject') . "\n";
    }
  
    @msglines = $msgtext;
    for (my $ii=0; $ii < scalar @messageids; $ii++) {
      if (messagematchsid(\@msglines,$messageids[$ii])) { 
        $matchcount++;
        printd ("Messages are matching\n");
        # newest received mail than the others, ok remeber id.
        if (!defined $newestid) { 
          $newestid = $messageids[$ii];
        } else {
          $messageids[$ii] =~ /\#(\d+)\#/;
          $mid = $1;
          $newestid =~ /\#(\d+)\#/;
          $nid = $1;
          if ($mid > $nid) { 
            $newestid = $messageids[$ii]; 
          }
        }
        printd ("Deleted retrieved mail $msgcount with messageid ".$messageids[$ii]."\n");
        $imap->delete($msgcount);  # remove E-Mail from POP3 server
        splice @messageids, $ii, 1;# remove id from List
        last;                     # stop looking in list
      } 
    }
    # Messages Deleted before are marked for deletion here again
    # we should try to avoid this.
    # Delete orphaned Email-ping msg
    my @msgsubject = grep /^Subject/, @msglines;
    chomp @msgsubject;
        # Maybe we should delete all messages?
        if (defined $trashall) {
            $imap->delete($msgcount);
            printd ("Deleted mail $msgcount\n");
    # Scan Subject if email is an Email-Ping. In fact we match and delete also successfully retrieved messages here again.
    } elsif (!defined $keeporphaned && $msgsubject[0] =~ /E-Mail Ping \[/) {
      $imap->delete($msgcount);  # remove E-Mail from POP3 server
            printd ("Deleted orphaned mail $msgcount with subject ".$msgsubject[0]."\n");
    }

    $msgcount--;
  }


  $imap->expunge_mailbox('INBOX');
  $imap->quit;
}


# traverse through the message list and mark the lost mails
# that mean mails that are older than the last received mail.
if (defined $newestid) {
  $newestid =~ /\#(\d+)\#/;
  $newestid = $1;
  for (my $i=0; $i < scalar @messageids; $i++) {
    $messageids[$i] =~ /\#(\d+)\#/;
    my $akid = $1;
    if ($akid < $newestid) {
      $messageids[$i] =~ s/^ID/LI/; # mark lost
      printd ("MAIL $messageids[$i] MARKED AS LOST\n");
    }
  }
}

# Write list to id-Database
foreach my $id (@messageids) {
  print STATF  "$id\n";
}

# creating new serial id
my $timenow = time();  
my $serial = "ID#" . $timenow . "#$$";

# Ok - check if it's time to release another mail

# ...

if (defined $pinginterval) {
#    if (!defined $newestid) {
#        $newestid=$messageids[-1];
#    } elsif ($messageids[-1] > $newestid) {
#        $newestid = $messageids[-1];
#    }
#    $newestid =~ /\#(\d+)\#/;
#    $newestid = $1;
#
#    printd ("----------------------------------------------------------------------\n");
#    printd ("----------------------------------------------------------------------\n");
#    printd ("-------------------- INTERVAL: $pinginterval -----------------\n");
#    printd ("-------------------- TIME: $timenow --------------------------\n");
#    printd ("-------------------- LAST: $newestid -------------------------\n");
#    printd ("----------------------------------------------------------------------\n");
#    printd ("----------------------------------------------------------------------\n");
#
# FIXME ... TODO

}

# sending new ping email
sendMail($sender,
         $receiver,
         $serial,
         $debug,
         $smtphost,
         $smtpuser,
         $smtppass,
         $smtptimeout,
         $smtpauth,
         $smtpusessl,
         $attachfile
        );

print STATF "$serial\n";     # remember send mail of this session
close STATF;

# ok - count lost and pending mails;
my @tmp = grep /^ID/, @messageids;
my $pendingm = scalar @tmp;
@tmp = grep /^LI/, @messageids;
my $lostm = scalar @tmp; 

# Evaluate the Warnin/Crit-Levels
if (defined $pendwarn && $pendingm > $pendwarn) { $state = 'WARNING'; }
if (defined $lostwarn && $lostm > $lostwarn) { $state = 'WARNING'; }
if (defined $pendcrit && $pendingm > $pendcrit) { $state = 'CRITICAL'; }
if (defined $lostcrit && $lostm > $lostcrit) { $state = 'CRITICAL'; }

if ((defined $pendwarn || defined $pendcrit || defined $lostwarn 
     || defined $lostcrit) && ($state eq 'UNKNOWN')) {$state='OK';}

printd ("STATUS:\n");
printd ("Found    : $statinfo\n");
printd ("Matching : $matchcount\n");
printd ("Pending  : $pendingm\n");
printd ("Lost     : $lostm\n");
printd ("Mail $serial remembered as sent\n");
printd ("----------------------------------------------------------------------\n");
printd ("----------------------------------------------------------------------\n");
printd ("-------------------------- END DEBUG INFO ----------------------------\n");
printd ("----------------------------------------------------------------------\n");
printd ("----------------------------------------------------------------------\n");

# Append Status info
$statinfo = $statinfo . ", $matchcount mail(s) came back,".
            " $pendingm pending, $lostm lost.";

# Exit in a Nagios-compliant way
nsexit($statinfo);

# ----------------------------------------------------------------------

sub mkdir_p {
  my $path=shift;
  if(! -d $path)
  {
    if(! -d substr($path, 0, rindex($path, "/"))){mkdir_p(substr($path, 0, rindex($path, "/")));}
    mkdir $path;
  }
}

sub usage {
  print "check_email_loop 1.5 Nagios Plugin - Real check of a E-Mail system\n";
  if (!defined($help)) {
    print "=" x 75,"\nERROR: Missing or wrong arguments!\n","=" x 75,"\n";
  }
  print "This script sends a mail with a specific id in the subject via an given\n";
  print "smtp-server to a given email-adress. When the script is run again, it checks\n";
  print "for this Email (with its unique id) on a given pop3 or imap account and sends \n";
  print "another mail.\n\n";
  print "\nThe following options are available:\n";
  print	"   -from=text         email adress of send (for mail returnr on errors)\n";
  print	"   -to=text           email adress to which the mails should send to\n";
  print "   -pophost=text      IP or name of the POP3/IMAP-host to be checked\n";
  print "   -popuser=text      Username of the POP3/IMAP-account\n";
  print "   -popauth=text      Auth method to use: PASS (default), APOP or CRAM-MD5\n";
  print	"   -passwd=text       Password for the POP3/IMAP-user\n";
  print	"   -poptimeout=num    Timeout in seconds for the POP3/IMAP-server\n";
  print "   -smtphost=text     IP or name of the SMTP host. Use host:port to specify port\n";
  print "   -smtpuser=text     Username to use with SMTP Auth\n";
  print "   -smtppass=text     Password for smtpuser\n";
  print "                      The default port is 25.\n";
  print "   -smtptimeout=num   Timeout in seconds for the SMTP-server\n";
  print "                      Default: 60s\n";
  print "   -smtpauth=string   AUTH type used when using authentication in the SMTP sessino\n";
  print "                      Use one of: PLAIN, LOGIN, CRAM-MD5\n";
  print "   -interval=num      Time (in minutes) that must pass by before sending\n";
  print "                      another Ping-mail (give a new try);\n"; 
  print "   -lostwarn=num      WARNING-state if more than num lost emails\n";
  print "   -lostcrit=num      CRITICAL \n";
  print "   -pendwarn=num      WARNING-state if more than num pending emails\n";
  print "   -pendcrit=num      CRITICAL \n";
  print "   -maxmsg=num        WARNING if more than num emails on POP3 (default 50)\n";
  print "   -forgetafter=num   Forget Pending and Lost emails after num days\n";
  print "   -keeporphaned      Set this to NOT delete orphaned E-Mail Ping msg from POP3\n";
  print "   -trashall          Set this to DELETE all E-Mail msg on server\n";
  print "   -usessl            Set this to login with ssl enabled on server\n";
  print "   -smtpusessl        Set this to use SSL in your SMTP session\n";
  print "   -useimap           Use IMAP instead of POP3\n";
  print "   -attachfile        File to send with the mail, only the file name\n";
  print "                      The file must be placed in \$USER1\$/attachments/\n";
  print "   -debug             send SMTP tranaction info to stderr\n\n";
  print " Options may abbreviated!\n";
  print " LOST mails are mails, being sent before the last mail arrived back.\n";
  print " PENDING mails are those, which are not. (supposed to be on the way)\n";
  print "\nExample: \n";
  print " $0 -poph=host -pa=pw -popu=popts -smtph=host -from=root\@me.com\n ";
  print "      -to=remailer\@testxy.com -lostc=0 -pendc=2\n";
  print "\nCopyleft 19.10.2000, Benjamin Schmid / 2003 Michael Markstaller, mm\@elabnet.de\n";
  print "This script comes with ABSOLUTELY NO WARRANTY\n";
  print "This programm is licensed under the terms of the ";
  print "GNU General Public License\n\n";
  exit $ERRORS{"UNKNOWN"};
}

# ---------------------------------------------------------------------

sub printd {
  my ($msg) = @_;
  if ($debug == 1) {
    print $msg;
  }
}

# ---------------------------------------------------------------------

sub nsexit {
  my ($msg,$code) = @_;
  $code=$state if (!defined $code);
  print "$code: $msg\n" if (defined $msg);
  exit $ERRORS{$code};
}

# ---------------------------------------------------------------------

sub messagematchsid {
  my ($mailref,$id) = (@_);
  my (@tmp);
  my $match = 0;
 
  # ID
  $id =~ s/^LI/ID/;    # evtl. remove lost mail mark
  @tmp = grep /E-Mail Ping \[/, @$mailref;
  chomp @tmp;
  printd ("Comparing Mail content ".$tmp[0]." with Mail ID $id:\n");
  if ($tmp[0] && $id ne "" && $tmp[0] =~ /$id/)
    { $match = 1; }

  # Sender:
#  @tmp = grep /^From:\s+/, @$mailref;
#  if (@tmp && $sender ne "") 
#    { $match = $match && ($tmp[0]=~/$sender/); }

  # Receiver:
#  @tmp = grep /^To: /, @$mailref;
#  if (@tmp && $receiver ne "") 
#    { $match = $match && ($tmp[0]=~/$receiver/); }

  return $match;
}

# ---------------------------------------------------------------------

# Used to send an attachment along with the mail.
# Could take a list of files as an argument
# but that option is not shown to the user.
# 
sub attachFile {
    my $self = shift;

    chdir ("/opt/plugins/email_loop/attachments/");
    foreach my $file (@_) {
    unless (-f $file) {
        print 'Net::SMTP::Multipart:FileAttach: unable to find file $file';
        next;
      }
      my($bytesread,$buffer,$data,$total);
      open(FH,"$file") || print "sub attachFile: failed to open $file\n";
      binmode(FH);
      while ( ($bytesread=sysread(FH,$buffer, 1024))==1024 ){
        $total += $bytesread;
        # 500K Limit on Upload Images to prevent buffer overflow
        #if (($total/1024) > 500){
        #  printf "TooBig %s\n",$total/1024;
        #  $toobig = 1;
        #  last;
        #}
        $data .= $buffer;
      }
      if ($bytesread) {
        $data .= $buffer;
        $total += $bytesread ;
      }
      #print "File Size: $total bytes\n";
      close FH;

      if ($data){
        $self->datasend("--$b\n");
        $self->datasend("Content-Type: application/X; name=\"$file\"\n");
        $self->datasend("Content-Transfer-Encoding: base64\n");
        $self->datasend("Content-Disposition: attachment; =filename=\"$file\"\n\n");
        $self->datasend(encode_base64($data));
        $self->datasend("--$b\n");
      }
    }
}

# ---------------------------------------------------------------------

# Depending on the arguments this mail sub may use smtpauth and or TLS.
#
sub sendMail {
  my ($_sender, $_receiver, $_serial, $_debug, 
      $_smtphost, $_smtpuser, $_smtppass, $_smtptimeout,
      $_smtpauth, $_smtpusessl, $_attachfile
     ) = @_;

  # Building the hash used as options when starting the SMTP connection.
  # First some vars that is allways used.
  my $smtp;
  my %smtp_opts=();
     $smtp_opts{'Hello'}   = 'localhost.localdomain';
     $smtp_opts{'Timeout'} = $_smtptimeout;
     $smtp_opts{'Debug'}   = $_debug;
  
  # Checking to see if the user provided the hostname in this way:
  # hostname:port or ip:port
  my @hostport = split(/:/, $_smtphost);
  if (defined($hostport[1])) {
    $smtp_opts{'Port'} = $hostport[1];
    $_smtphost         = $hostport[0];
  } else {
    $smtp_opts{'Port'} = 25;
  }

  # Checking if we are about to use TLS or not
  if (defined($_smtpusessl)) {
    #TLS with AUTH?
    if (defined($_smtpuser) && defined($_smtppass)) {
      $smtp_opts{'User'}     = $_smtpuser;
      $smtp_opts{'Password'} = $_smtppass;
    }
  } else {
    #AUTH without TLS?
    $smtp_opts{'NoTLS'}     = 1;
    if (defined($_smtpuser) && defined($_smtppass)) {
      $smtp_opts{'User'}     = $_smtpuser;
      $smtp_opts{'Password'} = $_smtppass;
    }
  }

  printd("B:" . $b . "\n");
  
  # Start the SMTP session
  # Every $smtp - line below is actualy sending an
  # SMTP command directly to the SMTP server.
  if($smtpusessl)
  {
    $smtp = new Net::SMTP::SSL( $_smtphost, %smtp_opts)
          || nsexit("Error connecting to $_smtphost", 'CRITICAL');
  }else{
    $smtp = new Net::SMTP( $_smtphost, %smtp_opts)
          || nsexit("Error connecting to $_smtphost", 'CRITICAL');
  }
  if (defined($_smtpuser) && defined($_smtppass)) {
    if (lc($_smtpauth) eq "login")
    {
      $smtp->rawdatasend("AUTH LOGIN\r\n");
      $smtp->response();
      $smtp->rawdatasend(encode_base64($_smtpuser, ""));
      $smtp->rawdatasend("\r\n");
      $smtp->response();
      $smtp->rawdatasend(encode_base64($_smtppass, ""));
      $smtp->rawdatasend("\r\n");
      my $status=$smtp->response();
      if ($status != 2){ nsexit("Authentication failed",'CRITICAL'); }
    }elsif (lc($_smtpauth) eq "plain"){
      $smtp->rawdatasend("AUTH PLAIN ");
      $smtp->rawdatasend(encode_base64($_smtpuser."\0".$_smtpuser."\0".$_smtppass), "");
      $smtp->rawdatasend("\r\n");
      my $status=$smtp->response();
      if ($status != 2){ nsexit("Authentication failed",'CRITICAL'); }
    }else{
      $smtp->auth($_smtpuser, $_smtppass)
          || nsexit("Authentication failed",'CRITICAL');
    }
  }
 
  printd ("SMTP: " . $smtp . "\nSender: " . $_sender . "\n");

  $smtp->mail($_sender)
          || nsexit("Error executing MAIL FROM",'CRITICAL');
  $smtp->to($_receiver)
          || nsexit("Error executing RCPT TO",'CRITICAL');
  $smtp->data()
          || nsexit("Error executing DATA",'CRITICAL');;
  $smtp->datasend("To: $_receiver\nFrom: $_sender\nSubject: E-Mail Ping [$_serial]\n");
  $smtp->datasend("\n")
          || nsexit("Error delivering message",'CRITICAL');
    
  if (defined($_attachfile)) {
    $smtp->datasend("MIME-Version: 1.0\n");
    $smtp->datasend(sprintf "Content-Type: multipart/mixed; BOUNDARY=\"%s\"\n",$b);
    $smtp->datasend(sprintf "\n--%s\n",$b);
    $smtp->datasend("Content-Type: text/plain\n");
  }
  $smtp->datasend("This is an automatically sent E-Mail.\n".
                  "It is not intended for a human reader.\n\n".
                  "Serial No: $_serial\n");#  || nsexit("Error adding text part in SMTP session",'CRITICAL');
  if (defined($_attachfile)) {
    attachFile($smtp, $_attachfile);
  }
    
  $smtp->dataend();# || nsexit("delivering message",'CRITICAL');;
  $smtp->quit;# || nsexit("Error in exit from SMTP server",'CRITICAL');

} #END SENDING MAIL PING...

# ---------------------------------------------------------------------

