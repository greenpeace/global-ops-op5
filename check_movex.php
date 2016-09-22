#!/usr/bin/php -q
<?php
# License: GPL
# Copyright (c) 2006-2007 op5 AB
# Author: Andreas Ericsson <ae@op5.com>
#         Peter Ostlin <peter@op5.com
#
# For direct contact with any of the op5 developers send a mail to
# op5-users@lists.op5.com
# Discussions are directed to the mailing list op5-users@op5.com,
# see http://lists.op5.com/mailman/listinfo/op5-users
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# 1.1 Kolla serverView job (check_num_jobs)
# check_movex.php --host m3tst --port 16666 --check subsys_jobs --id Sub:I:MFICONF --warn 45:45 --crit 45:45
# 1.2 Kolla serverView status check_status)
# check_movex.php --host m3tst --port 16666 --check subsys_status --id Sub:I:MFICONF --expect Up
# --expect Up som default?
# 1.7 Events and Warnings
# check_movex.php --host m3tst --port 16666 --check current_events --severity 0:2 -w 2
# 1.8 Find job
# check_movex.php --host m3tst --port 16666 --check job_status --severity 1 -w 1 -c 7
function ok($msg)
{
	echo "$msg\n";
    exit(0);
}

function warning($msg)
{
	echo "$msg\n";
	exit(1);
}

function critical($msg)
{
	echo "$msg\n";
	exit(2);
}

function unknown($msg)
{
	echo "$msg\n";
	exit(3);
}

function usage($msg)
{
#    for($i=0; $i<80; $i++){
#	echo "-";
#    }
#    echo "\n";
    echo "Check_movex.php. Copyright (c) 2007 op5 AB. <support.op5.se>\n";
    echo "\nThis plugin check various Movex/M3 related system information. It does so by\n";
    echo "connecting to the M3 webserver and fetching relevant url's.\n\n";
    echo "Usage: check_movex.php -H <host> -p <port> [--check <command>] [-w <warning>]\n";
    echo "   [-c <critical>] [-e <expect-string>] [-u <path>] [-i <job/subsystem id>]\n";
    echo "   [-s <severity>] [-f <state-info-file>] [-U <user>] [-P <password>]\n";
    echo "   [-t <timeout>]\n";
    echo "Where:\n";
    echo "  -H, --host ADDRESS\n";
    echo "    The address of the m3 server.\n";
    echo "  -p, --port INTEGER\n";
    echo "    The port to use. Default 6666.\n";
    echo "  --command STRING\n";
    echo "    The command to perform. Should be one of: subsys_jobs, subsys_status,\n";
    echo "    current_events, job_status, mecs_messages or mecs_status. \n";
    echo "    The commands are explained in more detail below.\n";
    echo "  -w, --warning INTEGER-RANGE\n";
    echo "  -c, --critical INTEGER-RANGE\n";
    echo "    The numeric range that do _not_ result in a warning/critical state.\n";
    echo "    I.E. '--warning 0:5' returns warning if value exceeds 5. '--warning 5' is\n";
    echo "    also interpreted as the range 0:5, i.e. warn if vaulue exceed 5.\n";
    echo "  -e, --expect-string STRING\n";
    echo "    String to expect, default: 'Up'. Only used with command 'subsys_status'\n";
    echo "  -u, --url-path STRING\n";
    echo "    Path to add to hostname when performing the checks. Example: '/index.html'\n";
    echo "    NOTE: Most commands have a default url-path, only use this to override.\n";
    echo "    See command details below for each command's default url-path.\n";
    echo "  -i, --id STRING\n";
    echo "    String identifying a specifik job os subsystem id.\n";
    echo "    Only valid with command: subsys_jobs, subsys_status and job_status.\n";
    echo "  -s, --severity INTEGER-RANGE\n";
    echo "    The severity range to look for. I.E. 0:2 means severity 0, 1 and 2.\n";
    echo "    Only valid with command: current_events and job_status.\n";
    echo "  -f, --state-file PATH\n";
    echo "    Path to file storing info regarding previous states.\n";
    echo "    Only valid with command job_status.\n";
    echo "  -U, --user STRING\n";
    echo "    Username to use when authenticating towards the webserver.\n";
    echo "  -P, --password STRING\n";
    echo "    Password to use when authenticating towards the webserver.\n";
    echo "  -t, --timeout INTEGER\n";
    echo "    Timeout for the script to execute.\n";
    echo "\n Examples:\n";
    echo " To check the ServerView page for the number of jobs for subsystem 'Sub:A:PROD'\n";
    echo " and return a warning if it is not exactly 45:\n";
    echo " > check_movex.php -H myHost -p 1234 --check subsys_jobs -i Sub:A:PROD -w 45:45\n";
    echo "\n";
    echo " To check the ServerView page for the status of subsystem 'Supervisor' and \n";
    echo " return critical status is anything other then 'Up'.\n";
    echo " > check_movex.php -H myHost -p 1234 --check subsys_status -i Supervisor -e Up\n";
    echo "\n";
    echo " To check the news page for jobs that have a severity in the range 0 to 2.\n";
    echo " Return warning if more then 2 and critical if more then 4.\n";
    echo " > check_movex.php -H myHost -p 1234 --check current_events -s 0:2 -w 2 -c 4\n";
    echo "\n";
    echo " To check for Autojobs that have had a value in the 'change' column larger then\n";
    echo " 300. Return warning if one or more jobs have been in this state for more then \n";
    echo " 10 minutes. Return critical if one or more have been in this state for more \n";
    echo " then 15 min.\n";
    echo " > check_movex.php -H myHost -p 1234 --check job_status -s 300 -w 10 -c 15 \n";
    echo "                   -f mystate.state -i Job:A\n";
    echo "\n";
    echo " To check the mecs messages page for messages that do not have state='Finished'.\n";
    echo " return warning if more then 5 and critical if more then 8.\n";
    echo " > check_movex.php -H myHost -p 1234 --check mecs_messages -e Finished -w 5 -c 8\n";
    echo "\n";
    echo " Check the MEC Channel Control page for channels where 'Channel State' is _not_ \n";
    echo " 'STARTED'. Return critical if any channel has a different state.\n";
    echo " > check_movex.php -H myHost -p 1234 --check mecs_channel_status -e STARTED\n";
    echo "\n";
    echo " Find and check the batch job logfile. Use -e <search> to locate the logfile to\n";
	echo " look at.\n";
    echo " > check_movex.php -H myHost -p 1234 --check log_file -e CRCHK001\n";
#    echo "  --check subsys_status --id <subsys-name>\n";
#    echo "  --check subsys_jobs [--id <subsys-name>]\n";
#    echo "  --check [subsys_jobs ,[heap|jobs] | counter]\n";
#    echo "  --id=<subsys-name|counter-name>\n";
#    echo " subsys_jobs";
#    echo "\n";
    unknown($msg);
}


# Turn a random html-page into a data-array
function de_tabulate_html($buf)
{
	$ary = array();
    # insert extra linebreak before each <tr> tag just in case it's missing
    # (peter's addition, might break somehing...)
	$buf = str_replace("<tr", "\n<tr", $buf);
    # For MECS messages. Needs testing so it do not break anything
	$buf = str_replace("\n<TD", "<TD", $buf);

	# Lawson
	# We need to only do the below in case of a log_file check, so hide it otherwise
	Global $check_params;
	if(isset($check_params) && $check_params === "log_file" ) {
		$buf = ereg_replace("[[:alpha:]]+://[^<>[:space:]]+[[:alnum:]/]", "<p>\\0</p>", $buf);
	}
	# first replace all HTML tags with tabs
	$buf = preg_replace("/<[^>]*>/", "\t", $buf);

	# Next we replace all double-tabs with single-tab.
	# We need to do this to keep array-field indexing consistent
	# with web output.
	$buf = preg_replace("/[\t ][\t ]/", "\t", $buf);
	$buf = preg_replace("/\t\t/", "\t", $buf);

	# turn it into an array with one line per array-entry
	$lines = explode("\n", $buf);
	$i = 0;

	# turn our 2d array into a 3d one by walking the lines
	# and splitting them at each tab
	foreach($lines as $line) {
		# trim whitespace from start end end of lines
		$line = trim($line);

		# skip empty lines
		if (!strlen($line))
		  continue;

		$sep = explode("\t", $line);
		$ary[$i++] = $sep;
	}

	return($ary);
}

function verify_data($buf, $verify_string){
    $ret = stristr($buf, $verify_string);
    if($ret){
	return true;
    } else {
	return false;
    }
}

function fetch_data($url) {
	# PHP's "file_get_contents()" supports opening files over http,
	# so we use that to get the webpage from the url.

    # Use @ before file_get_contents to suppress warnings if url can not be opened
	$buf = @file_get_contents($url);
	if ($buf === false)
	  critical("Failed to fetch movex url $url");

	return($buf);
}


function thresh_to_string($ary){
    $res_str = "";
    if(!is_array($ary))
      return "0:$ary";
    if($ary['hi']===""){
	return $ary['lo'] . ":" . "~";
    } elseif($ary['lo']==="") {
	return "0:" . $ary['hi'];
    } else {
	return $ary['lo'] . ":" . $ary['hi'];
    }
}

# compare $val against $thresh, where $thresh may or may not be a range
# of $thresh['low'] < $thresh['hi'], in which case we make sure $val is
# between the two numbers, inclusively.
function passes_threshold($val, $thresh)
{
	global $low_is_good;
    # print "comparing $val to $thresh\n";
    # var_dump($thresh);
    # Consider it ok that tresh is not set.
    if(isset($thresh) && $thresh === false){
#	 print "no tresh\n";
	return(1);
    }

	if (is_array($thresh)) {
	    # echo "Comparing $thresh[lo] <= $val && $val <= $thresh[hi]\n";
#	    if($thresh['hi']===0){
	    if($thresh['hi']===""){
		return($thresh['lo'] <= intval($val));
	    } else{
		return(intval($thresh['lo']) <= $val && $val <= intval($thresh['hi']));
	    }
	}
    # echo "thresh is: ";
    # print_r($thresh);


	# $thresh is not a range, so match it against $val as a numeric value.
	# What we return depends on whether low or high is better.
	if ($low_is_good && $val <= $thresh)
	  return(1);

	if (!$low_is_good && $val >= $thresh)
	  return(1);

	return(0);
}

# Convert array to comma separated string, chop if to long
# and pad with '...' to indicat it has been cut.
# Result example:
# "123, 456, 789"
# "123, 456, ..."
function array_to_string($ary, $max_length){
    $result_str = "";
    $result_str = implode(", ", $ary);
    if(strlen($result_str)>$max_length){
	$result_str = substr_replace($result_str, '', $max_length-6);
	$result_str = rtrim($result_str, "1234567890");
	$result_str = rtrim($result_str, " ,");
	$result_str .= "...";
    }
    $result_str = trim($result_str, " ,");

    return $result_str;
}


function check_log_file($ary, $id, $crit, $warn, $args){
	if(!isset($args['expect'])){
		unknown("No expect string set, don't know what to search for.");
    }
	$buf2;
	$out_str="";
	$url;
	$res_arr = array();
    $num_failed = 0;
    $num_ok = 0;
    $num_tot = 0;
    foreach($ary as $entry) {
		if(count($entry)!=9){
#			echo "Wrong num of cols\n";
			continue;
		}
		if(stristr($entry[1],$args['expect'])){
			$url=$entry[5];
			$buf2=fetch_data($entry[5]);
			$res_arr=explode("\n",$buf2);
			break;
		}
    }
	foreach($res_arr as $val){
		if(strncmp($val, "END", 3) == 0){
			$str=trim(substr($val, 4));
			if(stristr($str, "OK")){
				$num_ok++;
			}
			if(stristr($str, "FAIL")){
				$num_failed++;
			}
			$num_tot++;
			$out_str.=", $str";
		}
	}
	$out_str = trim($out_str, ", ");

	$url = preg_replace("/http[s]?:\/\/localhost/", "", $url);
	$url = preg_replace("/http[s]?:\/\/127.0.0.1/", "", $url);
	if ($num_failed != 0){
		critical("CHECKS=$num_tot OK=$num_ok FAIL=$num_failed. ($out_str) Logfile: <a href=\"$url\">$url</a>");
	}
	ok("CHECKS=$num_tot OK=$num_ok FAIL=$num_failed. ($out_str) Logfile: <a href=\"$url\">$url</a>");
}

function check_mecs_messages($ary, $id, $crit, $warn, $args){
    if(!isset($args['expect'])){
	unknown("No expect string set, don't know what to search for.");
    }
    $res_arr = array();
    $num_failed = 0;
    $num_ok = 0;
    $num_tot = 0;
    foreach($ary as $entry) {
	if(count($entry)!=11 || $entry[10] === 'State')
	   continue;

#	if($entry[10] != $args['expect']){
	if(!preg_match($args['expect'],$entry[10])) {
	    $num_failed++;
	    $res_arr[$entry[0]]=$entry[10];
	} else {
	    $num_ok++;
	}
	$num_tot++;
    }
#print "num_failed: $num_failed\n";
    if(!passes_threshold($num_failed, $crit))
      critical("$num_failed of $num_tot Messages do NOT have state '" . $args['expect'] . "'" );

    if(!passes_threshold($num_failed, $warn))
      warning("$num_failed of $num_tot Messages do NOT have state '" . $args['expect'] . "'" );

    ok("$num_ok of $num_tot Messages have state '" . $args['expect'] . "'" );

}


function check_mecs_channel_status($ary, $id, $crit, $warn, $args){
#    var_dump($ary);

    if(!isset($args['expect'])){
	unknown("No expect string set, don't know what to search for.");
    }
    $current_name = "";
    $res_arr = array();
    foreach($ary as $ent_id => $entry) {
#	print "id: $ent_id,  entry: $entry\n";
	if(isset($entry[0]) && $entry[0]==='Channel Name:' ){
	    if($current_name){
		unknown("Failed to parse output.");
	    }
#	    print "e: $entry[0], $entry[1]\n";
	    $current_name = $entry[1];
	}
	if(isset($entry[0]) && $entry[0]==='Channel State:' ){
#	    print "e: $entry[0], $entry[1]\n";
	    if($current_name === ""){
		unknown("Failed to parse output.");
	    }
	    $res_arr[$current_name] = $entry[1];
	    $current_name = "";
	}
    }
    $failed = array();
    foreach($res_arr as $k => $v){
#	if($v !== $args['expect'])
	if(!preg_match($args['expect'],$v))
	  $failed[]=$k;
    }
    if(count($failed) > 0){
	critical(count($failed). " of " . count($res_arr) .
		 " channel(s) are NOT in state '" .
		 $args['expect'] . "'");
    }
    ok("All (" . count($res_arr) . ") channels are in state '"
       . $args['expect'] . "'");
#    var_dump($res_arr);
#    var_dump($failed);

}

# check job status
# Check if there are jobs that have been in a non ok state during a period
# of time.
# function check_job_status($ary, $id, $crit, $warn, $expect, $change){
function check_job_status($ary, $id, $crit, $warn, $args){
    global $debug;
    $change = $args['severity'];
    if($debug)
      print "check_job_status\n";

    if($debug)
      var_dump($args);

    if(!isset($args['state_file']))
      unknown("Statefile not set");

    # Read the 'state' file and create an array of previous data
    # File format is: <id>:<time>\n<id>:<time>\n...
    # Build array with <id> as key and <time> as value
    $state_file = $args['state_file'];
#    print "statfile: $state_file\n";
    $file_str = "";
    $file_arr = array();
    if(file_exists($state_file)){
	$file_str = file_get_contents($state_file);
    }
    $file_str = trim($file_str);
    $tmp_arr = explode("\n",$file_str);
    foreach($tmp_arr as $row){
	$file_arr[strtok($row,':')]= (int)strtok('');
    }

    # Build the corresponding array from live data
    $live_arr = array();
    $now = floor(time()/60);
    $num_tot = 0;
    foreach($ary as $ent_id => $entry) {

	if (count($entry) !== 9 || $entry[0] === 'No')
	  continue;
	if(isset($args['id']) && $args['id'] != $entry[1])
	  continue;
	if($debug)
	  print "No: ". $entry[0] . ", Type: " . $entry[1] . ", id: " . $entry[4] . ", Change: " . $entry[7] ."\n";
	$num_tot++;
	if (!passes_threshold($entry[7], $change)) {
	    $live_arr[$entry[4]]=$now;
	}
    }

    # If key (id) from live data exist in file -> use from file
    # If key (id) from file do not exist in live -> delete
    foreach($live_arr as $k=>$v){
	if(array_key_exists($k, $file_arr)){
	    $live_arr[$k]=$file_arr[$k];
	}
    }

    # Create a string from the array and write to file so
    # that we remember how long the repective jobs have been non ok.
    $keep_str = " ";
    foreach($live_arr as $k=>$v){
	$keep_str .= "$k:$v\n";
    }
    if($debug)
      print "About to write to $state_file:\n $keep_str\n";
    $file_handle = fopen($state_file, 'w');
    if(!fwrite($file_handle,$keep_str)){
	unknown ("Failed to write to '$state_file'");
    }
    fclose($file_handle);

    # Check the times agains warning and critical treshold.
    foreach($live_arr as $k => $v){
	if (!passes_threshold( ($now - $v), $crit)) {
	    $critical[] = $k;
	}
	if (!passes_threshold( ($now - $v), $warn)) {
	    $warning[] = $k;
	}
    }

    if(isset($critical)){
	$result_str = array_to_string($critical,20);
	critical(count($critical) . " of $num_tot  jobs is outside the change range " . thresh_to_string($change) . " for a critical amount of time (ID's: $result_str)");
    }
    if(isset($warning)){
	$result_str = array_to_string($warning,20);
	warning(count($warning) . " of $num_tot jobs is outside the change range " . thresh_to_string($change) . " for a warning amount of time (ID's: $result_str)");
    }
    ok("All $num_tot jobs are inside the tresholds");
}


# Check Current Events and Warnings
# check the 'Events and warnings' page for jobs that are in a particular
# severity.
# function check_current_events($ary, $id, $crit, $warn, $expect, $severity){
function check_current_events($ary, $id, $crit, $warn, $args){
    global $debug;
    if($debug)
      print "check_current_events\n";

    # Bail out if no severity
    if(!isset($args['severity'])){
	unknown("Severity range not set");
    }
    $severity = $args['severity'];

    $numhits=0;
    $critical=false;

    # If severity is numeric, make it a range starting from 0
    if(is_numeric($severity))
      $severity = parse_thresh("0:$severity");
    $i=0;
    # Fetch all jobs that are inte selected priority
    foreach($ary as $ent_id => $entry) {

	if (count($entry) !== 7 || $entry[0] === 'Severity')
	  continue;

	$current_severity = $entry[0];
#	$current_severity = 0;
	if($i>20){
	    $current_severity = 10;
	}
	$i++;
	# If outside of range, place in array.
	if (passes_threshold($current_severity, $severity)) {
	    $numhits += 1;
	    $critical[] = $entry[6];
	}
    }
    # Count the number of hits and compare against treshold
    if (!passes_threshold($numhits, $crit)) { # thresh_to_string
#	critical($numhits . " events has severity in the range " .$severity['lo'].":".$severity['hi']);
	critical($numhits . " events has severity in the range " . thresh_to_string($severity));
    }
    if (!passes_threshold($numhits, $warn)) {
#	warning($numhits . " events has severity in the range " .$severity['lo'] . ":" . $severity['hi'] );
	warning($numhits . " events has severity in the range " . thresh_to_string($severity));
    }
#    ok($numhits . " events has severity in the range " .$severity['lo'] . ":" . $severity['hi'] );
    ok($numhits . " events has severity in the range " . thresh_to_string($severity));
}


# Check status of specified job
# function check_subsys_status($ary, $id, $crit, $warn, $expect){
function check_subsys_status($ary, $id, $crit, $warn, $args){

    global $debug;
    if($debug)
      print "check_subsys_status\n";

    # Bail if we do not know what status to look for
    if(!isset($args['expect'])){
	unknown("expect string missing");
    }
    $expect = $args['expect'];

    if ($id)
      $msg = "Subsystem $id ";
    else
      unknown("Subsystem id missing");

    # Loop through subsystems and check the status field
    # on the one indicated by id.
    foreach($ary as $ent_id => $entry) {

	if (count($entry) !== 12 || $entry[11] !== 'Shutdown')
	  continue;
	# If type is given and this is not the one we continue
	if (!empty($id) && $entry[1] !== $id)
	  continue;

	if ($id)
	  $found = true;

	$status = $entry[9];
	# Compare status with the expect string
	if(strcmp($status,$expect)){
	    if ($id) {
		critical("Subsystem '$id' has status '$status'");
	    }
	}
	ok("Subsystem '$id' has status '$status'");
    }
    unknown("Subsystem '$id' not found");
}


# Check the memory usage of a specific subsystem.
# When we end up here we've already fetched the data we need.
function check_subsys_heap($ary, $id, $crit, $warn)
{
	global $crit, $warn, $debug;
    if($debug)
      print "check_subsys_heap\n";

	$critical = false;
	$warning = false;

	# The thresholds
	$max_heap = array('Sub:A' => 512 * 1024, 'I' => 2560 * 1024,
					  'Sub:B' => 640 * 1024, 'Sub:M' => 640 * 1024,
					  'Sub:X' => 640 * 1024, 'Sub:Y' => 640 * 1024,
					  'Sub:Z' => 640 * 1024, 'Super' => 360 * 1024);

	# set up the output prefix
	if ($id)
	  $msg = "Subsystem $id ";
	else
	  $msg = "All subsystems ";

	$heap_max = 0;
	$found = false;
	foreach($ary as $ent_id => $entry) {
		if (count($entry) !== 12 || $entry[11] !== 'Shutdown')
		  continue;
		if (!empty($id) && $entry[1] !== $id)
		  continue;

		if ($id)
		  $found = true;

		$tmp = substr($entry[1], 0, 5);
#		echo "tmp = $tmp\n";
		if (!isset($max_heap[$tmp]))
		  continue;

		# Column 8 holds the size of the allocated heap
		$heap_alloced = $entry[8];
		$heap_max = $max_heap[$tmp];

		# Convert to percent
		$heap_used = 100 * ($heap_alloced / $heap_max);
#		echo "heap_max = $heap_max\n";
#		echo "heap_alloced = $heap_alloced\n";
#		echo "heap_used = $heap_used\n";

		# don't bother with more than 2 decimal points
		$heap_used = sprintf("%.2f", $heap_used);
		$heap_max = $heap_max / 1024;
		$heap_alloced = $heap_alloced / 1024;
#		echo "heap_max = $heap_max\n";
#		echo "heap_alloced = $heap_alloced\n";
#		echo "heap_used = $heap_used\n";

		# check done, basically, so compare what we found with
		# the thresholds and tuck away the subsystem(s) that
		# have a non-ok state.
		if (!passes_threshold($heap_used, $crit)) {
			if ($id) {
				critical("Subsystem $id uses $heap_used% of its total memory");
			}
			$critical[] = $entry[1];
		}
		elseif(!passes_threshold($heap_used, $warn)) {
			if ($id) {
				warning("Subsystem $id uses $heap_used% of its total memory");
			}
			$warning[] = $entry[1];
		}
	}

	# Everything's compared, so tell the user how things went.
	if ($id && !$found) {
		critical("No subsystem named $id found\n");
	}
	if ($critical) {
		critical(implode(", ", $critical) . " uses too much memory");
	}
	elseif($warning) {
		warning(implode(", ", $warning) . " uses too much memory");
	}

	# Neither critical nor warning, so must be OK
	ok("Subsystem $id uses $heap_used% of its total memory");
}

# This fetches data from the front-page of the movex info-thingie.
# All entries with exactly 12 items and has "Shutdown" in the LAST
# slot of the array is valid for looking at
#function check_subsys_jobs($ary, $id, $crit, $warn, $expect)
function check_subsys_jobs($ary, $id, $crit, $warn)
{
	global $crit, $warn, $debug;

    if($debug)
      print "check_subsys_jobs\n";


	$found = false;
	$critical = false;
	$warning = false;

	if ($id)
	  $msg = "Subsystem '$id'";
	else
	  $msg = "All subsystems";

	# Walk the table row by row
	foreach($ary as $ent_id => $entry) {
		# Discard rows that don't have exactly 12 entries,
		# that have "Shutdown" in the 12'th column

		if (count($entry) !== 12 || $entry[11] !== 'Shutdown')
		  continue;

		# If the user specified a subsystem Id (like "Sub:A:PROD")
		# we can also skip all rows that show other subsystems
		if (!empty($id) && $entry[1] !== $id)
		  continue;
#		print "id: $entry[1]\n";
		if ($id)
		  $found = true;

		# 6'th column holds the number of jobs
		$jobs = $entry[5];

		# check value agains thresholds. If user didn't specify a
		# specific subsystem, we tuck all non-OK subsystems in
		# an array for later printing, otherwise we break early on
		# errors and tell the user immediately
		if (!passes_threshold($jobs, $crit)) {
			if ($id) {
				critical("Subsystem '$id' has $jobs jobs running");
			}
#		    print "add $entry[1] to crit list\n";
			$critical[] = $entry[1];
		}
		elseif(!passes_threshold($jobs, $warn)) {
			if ($id) {
				warning("Subsystem '$id' has $jobs jobs running");
			}
			$warning[] = $entry[1];
		}
	}

	# Tell the user what happened
	if ($id && !$found) {
		critical("No subsystem running with type-name '$id'");
	}
	if ($critical) {
		critical(implode(", ", $critical) . " don't have the right amount of jobs running\n");
	}
	elseif($warning) {
		warning(implode(", ", $warning) . " don't have the right amount of jobs running\n");
	}
    if($id)
	ok("Subsystem '$id' has $jobs jobs running");
    else
      ok("$msg is running with the correct amount of jobs");
}

# Parse a threshold value, either as a simple numerical string or
# as a range in the format "01:35", meaning "anywhere between 01 and
# 35, inclusively, is OK"
function parse_thresh($str)
{
    global $debug;
	$ret = false;

	$ary = explode(':', $str);
	if (count($ary) === 0 || count($ary) > 2) {
		return(false);
	}

	if (count($ary) === 1) {
		$ret = intval($ary[0]);
		return($ret);
	}

	elseif ($ary[0] <= $ary[1]) {
# 		$ret = array('lo' => $ary[0]+0, 'hi' => $ary[1]+0);
		$ret = array('lo' => $ary[0], 'hi' => $ary[1]);
	}
	elseif ($ary[0] > $ary[1]) {
#		$ret = array('lo' => $ary[1], 'hi' => $ary[0]);
		$ret = array('lo' => $ary[0], 'hi' => $ary[1]);
	}

    if($debug>0){
	print "thresholds:\n";
	var_dump($ret);
    }
	return($ret);
}


function timeout_signal_handler ($signal) {
    global $timeout;
    unknown("Plugin timed out after $timeout seconds");
#    pexit(UNKNOWN, "Plugin timed out.");
}



# while checking counters, threads, processes and subsystem instances,
# low is good. I'm not sure where high_is_good, so we stick with this
# as the default for now
$low_is_good = 1;


global $debug;
global $check_params;
# critical / warning thresholds. We parse them possibly as ranges
# given in the format '12:13' to mean "no less than 12 and no more than 13"
$crit = false;
$warn = false;
$id = false;
$protocol = 'http';
$user = '';
$pass = '';
$host = '';
$port = "6666";
$timeout = 5;
$url_path = '';
$expect = false;
$severity = false;
$args = array();
$verify_string = " ";

# parse arguments here
if ($argc < 3)
	usage("");

function get_opt_arg($val, &$i)
{
	global $argv, $argc;

	if ($val !== false)
	  return($val);

	if ($i === $argc - 1)
	  usage("Option $argv[$i] requires an argument\n");

	return($argv[++$i]);
}

$url = false;
for ($i = 0; $i < $argc - 1; $i++) {
	$val = false;
	$ary = explode('=', $argv[$i], 2);
	if (count($ary) === 1)
	  $arg = $argv[$i];
	else {
		$arg = $ary[0];
		$val = $ary[1];
	}

	switch ($arg) {
	 case '-H': case '--host':
		$host = get_opt_arg($val, $i);
#		echo "host = $host\n";
		break;
	 case '-U': case '--user':
		$user = get_opt_arg($val, $i);
#		echo "user = $user\n";
		break;
	 case '-P': case '--pass':
		$pass = get_opt_arg($val, $i);
#		echo "pass = $pass\n";
		break;
	 case '-p': case '--port':
		$port = get_opt_arg($val, $i);
#		echo "port = $port\n";
		break;
	 case '-w': case '--warn':
		$warn = parse_thresh(get_opt_arg($val, $i));
		break;
	 case '-c': case '--crit':
		$crit = parse_thresh(get_opt_arg($val, $i));
		break;
	 case '-u': case '--url-path':
		$url_path = get_opt_arg($val, $i);
		break;
	 case '--url':
		$url = get_opt_arg($val, $i);
#		echo "url = $url\n";
		break;
	 case '-i': case '--id':
		$id = get_opt_arg($val, $i);
	    $args['id'] = $id;
#		echo "id = $id\n";
		break;
	 case '-e': case '--expect':
#		$expect = get_opt_arg($val, $i);
		$args['expect'] = get_opt_arg($val, $i);
#		echo "expect = $expect\n";
		break;
	 case '-s': case '--severity':
#		$severity = parse_thresh(get_opt_arg($val, $i));
		$args['severity'] = parse_thresh(get_opt_arg($val, $i));
#		echo "severity = $severity\n";
		break;
	 case '-t': case '--timeout':
		$timeout = get_opt_arg($val, $i);
#		echo "debug = true\n";
		break;
	 case '-d': case '--debug':
		$debug = get_opt_arg($val, $i);
#		echo "debug = true\n";
		break;
	 case '-f': case '--state_file':
		$args['state_file'] = get_opt_arg($val, $i);
#		echo "debug = true\n";
		break;
	 case '-o': case '--check':
	    $check_params = get_opt_arg($val, $i);
	    $check_params = str_replace(",", "_", $check_params);
	    #		echo "check_params = $check_params\n";
	    if (!function_exists('check_' . $check_params)) {
		warning("Unknown check argument '$check_params'\n");
	    }
	    $check_func = 'check_' . $check_params;
	    if($check_params === 'current_events' && $url_path === ''){
		$url_path = '/news';
	    }
	    if($check_params === 'current_events' && $verify_string === " "){
		$verify_string = "Current Events and Warnings";
	    }

	    if($check_params === 'job_status' && $url_path === ''){
		$url_path = '/findjob?name=&owner=&type=&bjno=&find=Find';
	    }
	    if($check_params === 'mecs_channel_status'){
		$user='admin';
		$pass='admin';
		if(!$url_path)
		  $url_path = '/jsp/main.jsp?action=ComControl.htm';
		if(!isset($args['expect'])){
		    $args['expect'] = 'STARTED';
		}
	    }
	    if($check_params === 'mecs_messages'){
		$user='admin';
		$pass='admin';
		if(!$url_path)
		  $url_path = '/jsp/main.jsp?action=StateWithInfo';
	    }
	    break;
	 case '-h': case '--help':
	    usage("");
	    break;
	 default:
		break;
	}
}

# build the url (should possibly be in a function of its own)
if (strlen($user)) {
	$user = $user . ':';
}
if (strlen($pass)) {
	$pass = $pass . '@';
}
if (strlen($port)) {
	$port = ':' . $port;
}
if (!$url)
  $url = $protocol . '://' . $user . $pass . $host . $port . $url_path;


declare(ticks = 1);
pcntl_signal(SIGALRM, "timeout_signal_handler", true);
pcntl_alarm($timeout);

if($debug)
  echo "Fetching data from $url\n";

$ret = ini_set('default_socket_timeout', $timeout);
# print "ret: $ret\n";
$buf = fetch_data($url);
if($debug)
  printf("Fetched %d bytes of data from $url\n", strlen($buf));

if(!verify_data($buf, $verify_string)){
    critical("Page could not be parsed, please verify the address $url.");
}
$ary = de_tabulate_html($buf);
# var_dump($ary);
if(!isset($check_func) || $check_func == ""){
	unknown("No check command defined. For usage instructions exec 'check_movex.php --help'");
}
if (function_exists($check_func))
#  $check_func($ary, $id, $crit, $warn, $expect, $severity);
  $check_func($ary, $id, $crit, $warn, $args);
else
  unknown("Non existing command '$check_func'. For usage instructions exec 'check_movex.php --help'");
?>


