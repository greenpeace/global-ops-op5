#!/usr/bin/env php
<?php

define('OK', 0);
define('WARNING', 1);
define('CRITICAL', 2);
define('UNKNOWN', 3);

function get_options() {
	$options = getopt('w:c:a:u:p:h');

	if(!$options['u']) {
		throw new Exception("Missing -u (username)");
	}
	if(!$options['p']) {
		throw new Exception("Missing -u (password)");
	}
	if(!$options['w']) {
		throw new Exception("Missing -w (warning), must be integer, 0 or larger");
	}
	if(!is_numeric($options['w']) || 0 > $options['w']) {
		throw new Exception("Missing -w (warning), must be integer, 0 or larger");
	}
	if(!$options['c']) {
		throw new Exception("Missing -c (critical), must be positive integer, higher than warning");
	}
	if(!is_numeric($options['c']) || $options['w'] >= $options['c']) {
		throw new Exception("Missing -c (critical), must be positive integer, higher than warning");
	}
	if(!$options['a']) {
		throw new Exception("Missing -a (API endpoint, e.g. https://your-monitor/api)");
	}

	// missing longopts-support workaround:
	if(isset($options['h']) || in_array('--usage', $GLOBALS['argv']) || in_array('--help', $GLOBALS['argv'])) {
		throw new Exception("Check for saved objects that are not yet imported into op5 Monitor's config.\n\nUsage:\n\t".realpath(__FILE__)." -a https://your-monitor-installation/api -w 2 -c 4");
	}
	return $options;
}

try {
	$options = get_options();
} catch(Exception $e) {
	echo $e->getMessage();
	exit(UNKNOWN);
}
$warning = $options['w'];
$critical = $options['c'];
$username = $options['u'];
$password = $options['p'];
$api_endpoint = rtrim($options['a'], '/');

function get_items_in_changelog($username, $password, $api_endpoint) {
	$a_handle = curl_init("$api_endpoint/config/change?format=json");
	curl_setopt($a_handle, CURLOPT_USERPWD, "$username:$password");
	curl_setopt($a_handle, CURLOPT_RETURNTRANSFER, TRUE);
	curl_setopt($a_handle, CURLOPT_SSL_VERIFYPEER, FALSE);
	$body = curl_exec($a_handle);
	if($body === false) {
		throw new Exception("Curl failed, is the correct endpoint set? ($api_endpoint) Is the API enabled in api.ini? Did you provide the correct user credentials, for user '$username'?");
	}
	$changes = json_decode($body, true);
	if(null === $changes) {
		throw new Exception("Invalid JSON provided by the API. Please contact op5 with these details:\nFailed to json_decode '$body'");
	}
	return count($changes);
}

try {
	$changes = get_items_in_changelog($username, $password, $api_endpoint);
} catch(Exception $e) {
	echo $e->getMessage();
	exit(UNKNOWN);
}
if($changes < $warning) {
	echo "OK | changes=$changes;$warning;$critical";
	exit(OK);
}
if($changes >= $critical) {
	echo "CRITICAL | changes=$changes;$warning;$critical";
	exit(CRITICAL);
}
echo "WARNING | changes=$changes;$warning;$critical";
exit(WARNING);
