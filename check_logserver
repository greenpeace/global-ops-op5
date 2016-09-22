#!/usr/bin/perl -w
use Nagios::Plugin;

my $np = Nagios::Plugin->new(shortname=>"LOGSERV", usage=>"Usage: %s [flags]", version=>"0.1");
$np->add_arg(spec=>"warning|w=s", help=>"-w, --warning=INTEGER:INTEGER\n   Provide a range for how many logs sent to the error directory should trigger a warning");
$np->add_arg(spec=>"critical|c=s", help=>"-c, --critical=INTEGER:INTEGER\n   Provide a range for how many logs sent to the error directory should trigger a critical report");
$np->getopts;
alarm $np->opts->timeout;
my $warningrange = "~:0";
if($np->opts->warning){$warningrange = $np->opts->warning;}
my $criticalrange = "5";
if($np->opts->critical){$criticalrange = $np->opts->critical;}
$np->set_thresholds(warning=>$warningrange, critical=>$criticalrange);
my $return = OK;
my $statusmsg = "";
if (`ps aux | grep '[l]oad-daemon.php' -c` eq "0\n")
{
  $statusmsg = "op5logserver-loader is stopped. ";
  $return = CRITICAL;
}
my $dir;
if (opendir($dir, '/var/log/oslogd/spool'))
{
  my $numfiles = 0;
  while(my $file = readdir($dir))
  {
    if(substr($file, 0, 1) eq '.'){next;}
    my @stats=stat('/var/log/oslogd/spool/'.$file);
    if(time - $stats[9] > 60){
      if($return == OK){$return = WARNING;}
      $statusmsg .= "Stale logs found in spool directory. ";
      last;
      }
    $numfiles++;
  }
  closedir($dir);

  if($numfiles > 2)
  {
    if($return == OK){$return = WARNING;}
    $statusmsg .= "More than 2 logfiles found in spool directory. ";
  }
}
else
{
  $statusmsg .= "Could not open spool directory. ";
  $return = CRITICAL;
}
my $numerrorfiles = 0;
if (opendir($dir, '/var/log/oslogd/error'))
{
  while(my $file=readdir($dir))
  {
    if(substr($file, 0, 1) eq '.'){next;}
    $numerrorfiles++;
  }
  if($numerrorfiles>0)
  {
    $returncode = $np->check_threshold(check=>$numerrorfiles);
    if($returncode > $return){$return = $returncode;}
    $statusmsg .= ' '.$numerrorfiles.' logfile'.($numerrorfiles > 1?'s':'').' in the error directory.';
  }
}
else
{
  $statusmsg .= "Could not open error directory. ";
}
$np->add_perfdata(label=>"'Logs in error directory'", value=>$numerrorfiles, threshold=>$np->threshold);
$np->nagios_exit($return, $statusmsg);
