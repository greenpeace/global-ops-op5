#! /usr/bin/php
<?php

# License: GPL
# Copyright (c) 2007-2008 op5 AB
# Author: op5 dev team <op5-users@lists.op5.com>
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
#
# Syntax: check_ls_log.php -f <filtername> -i <interval> [-H <hostname>]
#
# Description:
#
# This plugin works in conjunction with OP5 LogServer to check the number of
# messages that matches the filter given by parameter filtername. The
# parameter interval specifies the number of minutes back in time that the
# plugin will check messages.
#
# If an optional <hostname> parameter is present, the plugin will only return
# the number of messages for this host. <hostname> can contain several hosts,
# separated by space.
#
# Examples:
#
# 1. Check the number of all log messages for the last 10 minutes.
# ./check_ls_log.php -f "All Log Messages" -i 10
#
# 2. Same as 1, but only for host devel
# ./check_ls_log.php -f "All Log Messages" -i 10 -H devel
#
# 3. Same as 1, but for hosts devel, backup or owl
# ./check_ls_log.php -f "All Log Messages" -i 10 -H "devel backup owl"
#
# 4. Same as 1, output html-links
# ./check_ls_log.php -f "All Log Messages" -i 10 -u "https://hostname.domain/logserver/"
#
# Note that OP5 LogServer needs to be installed in /opt/logserver/
# for this plugin to work correctly.
#

/* cut and paste from database.php */
define("DB_USERNAME", "logs");
define("DB_PASSWORD", "logs");
define("DB_DATABASE", "logs");

function db_list_filters(& $retval) {
	$query = "SELECT * FROM filters WHERE userid=0";

	if (! $result = mysql_query($query)) {
		trigger_error("Error retrieving filterlist.");
		return false;
	}
	$retval = array();
	while ($row = mysql_fetch_assoc($result)) {
		$retval[] = array($row["id"], $row["description"]);
	}
	return true;
}

# parses a critical/warning range
function parse_range($rng)
{
	$ret = array('lo' => false, 'hi' => false);

	if (!strchr($rng, ':')) {
		if (is_numeric($rng)) {
			$ret['lo'] = 0;
			$ret['hi'] = $rng;
			return $ret;
		}
		pexit(UNKNOWN, "$rng is not a valid threshold range\n", false);
	}

	$ary = split(':', $rng);
	$lo = $ary[0];
	$hi = $ary[1];

	if (strlen($lo) && is_numeric($lo)) {
		$ret['lo'] = intval($lo);
		$ret['hi'] = true;
	}
	if (strlen($hi) && is_numeric($hi))
	  $ret['hi'] = intval($hi);

	if ($ret['lo'] === false && $ret['hi'] === false)
		pexit(UNKNOWN, "$rng is not a valid threshold range\n", false);

	return $ret;
}

function matches_range($val, $rng)
{

	if ($val < intval($rng['lo'])) return true;
	if ($val > intval($rng['hi']) && $rng['hi'] !== true) return true;

	return false;
}

/* This function parses a string containg words separated
 * by spaces. Spaces insides quotes do not delimit strings.
 * retval becomes an array(array(x, string)).
 * x = 0 means normal word
 * x = 1 means exact match (quoted)
 * FIXME: need to add escaping of quotes.
 * */
function string_to_word_list($string, & $retval) {
	$words = array();
	$tmp = "";
	$in_quote = false;
	for ($i = 0; $i < strlen($string); $i++) {
		if (! $in_quote && ($string[$i] == " ")) {
			$tmp = trim($tmp);
			if ($tmp != "")
			  $words[] = array(0, $tmp);
			$tmp = "";
		} else if ($string[$i] == '"') {
			if ($in_quote) {
				$words[] = array(1, $tmp);
				$in_quote = false;
				$tmp = "";
			} else {
				$in_quote = true;
			}
		} else {
			$tmp .= $string[$i];
		}
	}
	if ($in_quote) {
		// Malformed string, quote did not end
		return false;
	}
	$tmp = trim($tmp);
	if ($tmp != "")
	  $words[] = array(0, $tmp);
	$retval = $words;
	return true;
}


$db_operators = array("<", "=", ">", "<=", ">=", "!=", "<>", "in", "not in", "like", "not like", "&",
					  "time_abs_from", "time_abs_to", "time_rel_from",
					  "host_include", "host_exclude", "msg_include", "msg_exclude",
					  "sev", "fac",
					  "ident_include", "ident_exclude",
					  "eventid_include", "eventid_exclude");

function db_find_sql_op_id($name, & $id) {
	global $db_operators;
	for ($i = 0; $i < count($db_operators); $i++) {
		if ($db_operators[$i] == $name) {
			$id = $i;
			return true;
		}
	}
	return false;
}

$db_fields = array("id", "fac", "sev", "time", "event_id", "ident", "host", "pid", "msg");

function db_find_field_id($name, & $id) {
	global $db_fields;
	for ($i = 0; $i < count($db_fields); $i++) {
		if ($db_fields[$i] == $name) {
			$id = $i;
			return true;
		}
	}
	return false;
}

class Filter {
	var $id;
	var $userid;
	var $description;
	var $rules;
	// Array[db_operator] => Array(ruleid, db_field_name, value, operator, extra)

	var $host_msg_fields = array("host_include", "host_exclude", "msg_include", "msg_exclude",
								 "ident_include", "ident_exclude");

	function Filter($id) {
		$this->id = intval($id);

		$this->userid = 0;
		$this->description = "";

		$this->rules = array();
		$this->rules["eventid_include"] = array(0, "event_id", "", "IN", "");
		$this->rules["eventid_exclude"] = array(0, "event_id", "", " IS NULL OR event_id NOT IN", "");
		$this->rules["ident_include"] = array(0, "ident", "", "LIKE", "OR");
		$this->rules["ident_exclude"] = array(0, "ident", "", "NOT LIKE", "AND");
		$this->rules["msg_include"] = array(0, "msg", "", "LIKE", "OR");
		$this->rules["msg_exclude"] = array(0, "msg", "", "NOT LIKE", "AND");
		$this->rules["host_include"] = array(0, "host", "", "LIKE", "OR");
		$this->rules["host_exclude"] = array(0, "host", "", "NOT LIKE", "AND");

		$this->rules["time_abs_from"] = array(0, "time", "0", ">", "AND");
		$this->rules["time_abs_to"] = array(0, "time", "0", "<", "AND");
		$this->rules["time_rel_from"] = array(0, "time", "", ">", "AND");

		$this->rules["sev"] = array(0, "sev", "255", "&", "AND");
		$this->rules["fac"] = array(0, "fac", "33554431", "&", "AND");
	}

        function whats_new()
        {
            $result = array();

            $filter = new Filter(0);

            foreach ($this->rules as $key => $rule)
            {
                if ( $rule[2] != $filter->rules[$key][2] )
		    $result[$key] = true;
            }

            return $result;
        }

	function init() {
		if (!$this->load_filter()) {
			trigger_error("Filter::init load_filter returns false");
			return false;
		}
		if (!$this->load_rules()) {
			trigger_error("Filter::init load_rules returns false");
			return false;
		}
		return true;
	}

	function make_public() {
		$this->userid = 0;
	}

	function set_desc($desc) {
		$this->description = $desc;
	}

	function get_sev() {
		return intval($this->_get_rule_value("sev"));
	}

	function set_sev($value) {
		$this->_set_rule_value("sev", $value);
	}

	function get_fac() {
		return intval($this->_get_rule_value("fac"));
	}

	function set_fac($value) {
		$this->_set_rule_value("fac", $value);
	}

	function get_from() {
		return intval($this->_get_rule_value("time_abs_from"));
	}

	function get_to() {
		return intval($this->_get_rule_value("time_abs_to"));
	}

	function get_time_relative() {
		return $this->_get_rule_value("time_rel_from");
	}

	function set_time_relative($value) {
		if (is_numeric($value) && (0 == intval($value)))
		  $value = "";
		$this->_set_rule_value("time_rel_from", $value);
	}

	function set_time($from, $to) {
		$this->_set_rule_value("time_abs_from", $from);
		$this->_set_rule_value("time_abs_to", $to);
	}

	function _get_rule_value($key) {
		return $this->rules[$key][2];
	}

	function _set_rule_value($key, $value) {
		$this->rules[$key][2] = $value;
	}

	function set_host_msg($type, $string) {
		if (isset($this->rules[$type])) {
			$this->rules[$type][2] = $string;
			return true;
		}
		return false;
	}

	function get_host_msg($type) {
		if (isset($this->rules[$type])) {
			return $this->rules[$type][2];
		}
		return "";
	}

	function validate_field($type) {
		if (isset($this->rules[$type])) {
			$val = $this->_get_rule_value($type);
			if ($type == "time_rel_from") {
				return (("" == $val) || ctype_digit($val));
			} else if (false !== (array_search($type, $this->host_msg_fields))) {
				return string_to_word_list($val, $tmp);
			} else if (false !== strpos($type, "eventid_")) {
				if ($val != "") {
					$tmp = explode(" ", $val);
					foreach ($tmp as $int) {
						if (! ctype_digit($int)) {
							return false;
						}
					}
				}
				return true;
			}
		}
		return false;
	}

	function delete_filter() {
		$query = 'DELETE FROM filters WHERE id=%d';
		$query2 = 'DELETE FROM filterrules WHERE filterid=%d';

		$query = sprintf($query, $this->id);
		$query2 = sprintf($query2, $this->id);

		if (! mysql_query($query)) {
			return false;
		}
		if (! mysql_query($query2)) {
			return false;
		}
		return true;
	}

	// Load description and userid of filter
	function load_filter() {
		$query = "SELECT * FROM filters WHERE id=%s";

		$query = sprintf($query, mysql_escape_string($this->id));

		if (! ($result = mysql_query($query))) {
			trigger_error("Filter::load_filter cannot execute query " . $query);
			return false;
		}

		if ($row = mysql_fetch_assoc($result)) {
			$this->description = $row["description"];
			$this->userid = intval($row["userid"]);
			return true;
		} else {
			trigger_error("Filter::load_filter no results from query " . $query);
			return false;
		}
	}

	function _save_filter() {
		$query = 'UPDATE filters SET description="%s",userid=%u WHERE id=%d';

		$query = sprintf($query, $this->description, $this->userid, $this->id);
		if (! mysql_query($query)) {
			return false;
		}
		return true;
	}

	// Load rules of this filter
	function load_rules() {
		global $db_operators;
		$query = 'SELECT * FROM filterrules WHERE filterid=%d';

		$query = sprintf($query, $this->id);
		if (! ($result = mysql_query($query)))
		  return false;

		while ($row = mysql_fetch_assoc($result)) {
			$sql_op = $db_operators[$row["sql_op"]];
			if (isset($this->rules[$sql_op])) {
				$this->rules[$sql_op][0] = intval($row["id"]);
				$this->rules[$sql_op][2] = $row["value"];
			}
		}
		return true;
	}

	function _insert_rule($field, $sql_op, $value) {
		$query = 'INSERT INTO filterrules (filterid, field, sql_op, value) VALUES (%u, %d, %d, "%s")';

		// find id from field_name
		if (!db_find_field_id($field, $field_id)) {
			trigger_error("Could not find sql_field_id for " . $field);
			return false;
		}

		// and from sql_op
		if (!db_find_sql_op_id($sql_op, $sql_op_id)) {
			trigger_error("Could not find sql_op_id for " . $sql_op);
			return false;
		}

		// insert the new rule into db
		$query = sprintf($query,
						 $this->id,
						 $field_id,
						 $sql_op_id,
						 mysql_escape_string($value));

		return mysql_query($query);
	}

	function _update_rule($id, $value) {
		$query = 'UPDATE filterrules SET value="%s" WHERE id=%u AND filterid=%u';
		$query = sprintf($query,
						 mysql_escape_string($value),
						 intval($id),
						 $this->id);
		return mysql_query($query) ? true : false;
	}

	function _save_rules() {
		$retval = true;
		foreach ($this->rules as $field => $arr) {
			if ($arr[0] == 0) {
				$retval = $this->_insert_rule($arr[1], $field, $arr[2]);
			} else {
				$retval = $this->_update_rule($arr[0], $arr[2]);
			}
		}
		return $retval;
	}

	function save() {
		return ($this->_save_filter() && $this->_save_rules());
	}

	function _generate_sql_time_table_clause($table, $age, $from, $to, $extra_where = "") {
		$query = 'SELECT min(id) as min_id, max(id) as max_id FROM %s WHERE %s';
		$rules = array();

		if ($extra_where != "") {
			$rules[] = $extra_where;
		}
		if ($age != 0) {
			$rules[] = sprintf("(%u <= time)", time() - ($age));
		} else {
			if ($from != 0)
			  $rules[] = sprintf("(%u <= time)", $from);
			if ($to != 0)
			  $rules[] = sprintf("(time <= %u)", $to);
		}

		return sprintf($query, $table, implode(" AND ", $rules));
	}

	function _generate_sql_in(& $rules_arr, $field, $add_quotes = false) {
		$arr = $this->rules[$field];
		if ($arr[2] == "")
		  return;
		$tmp = explode(" ", $arr[2]);
		$rules_arr[] = sprintf(" (%s %s (%s)) ",
							   $arr[1],
							   $arr[3],
							   implode(", ", $tmp));
	}

	// generate host and msg rules
	function _generate_sql_like(& $rules_arr, $field) {
		$arr = $this->rules[$field];
		$rule_parts = array();
		// Convert the rule value into an array of words
		if (! string_to_word_list($arr[2], $words)) {
			return false;
		}
		// loop through the array.
		// $word_arr[0] is 0 (normal) or 1 (quoted),
		// $word_arr[1] contains the actual string
		foreach ($words as $word_arr) {
			// tmp becomes (field operator "%value%"), eg ("msg" like "%kalle%")
			$tmp = sprintf(' (%s %s "%%%s%%") ',
						   $arr[1],
						   $arr[3],
						   mysql_escape_string($word_arr[1]));
			$rule_parts[] = $tmp;
		}
		// join sql clauses with operator AND, OR
		if (count($rule_parts) > 0) {
			$rules_arr[] = sprintf(" ( %s ) ",
							   implode(sprintf(" %s ", $arr[4]),
									   $rule_parts));
		}
		return true;
	}

	// Returns true with $retval set to a valid sql-query if trigger query
	// could be constructed.
	function generate_trigger_sql(& $retval, $since_timestamp, $hostnames, $db_table, $query_fields, $extra_after = "") {
		global $db_operators, $db_fields;
		$rules = array();

		if(!$db_table)
		  $table_name = "messages";
		else
		  $table_name = $db_table;

		$time_clause = $this->_generate_sql_time_table_clause($table_name, 0,
															  $since_timestamp, 0, "");
		$wnew = $this->whats_new();

		$empty = count($wnew) == 0 && !$hostnames;

		$query = sprintf("%s %s, (%s) as time_table WHERE min_id <= id AND id <= max_id %s",
							  $table_name, $empty?"":"IGNORE INDEX(PRIMARY)", $time_clause, $empty?"":"AND ");


		if ( $empty )
		{
		    $retval = sprintf("SELECT %s FROM %s %s",
						  $query_fields, $query, $extra_after);
		    return true;
		}

                if( $wnew['sev'] )
                    $rules[] = sprintf("(sev & %u)", $this->get_sev());

                if( $wnew['fac'] )
                    $rules[] = sprintf("(fac & %u)", $this->get_fac());

		if ($hostnames) {
			$tmp = array();
			foreach ($hostnames as $hostname)
			  $tmp[] = mysql_escape_string($hostname);
			$rules[] = sprintf('(host in ("%s"))', implode('", "', $tmp));
		} else {
			// If no hostnames as argument, default to normal
			// selection from database
			foreach (array("host_include", "host_exclude") as $rule_key) {
				if (!$this->_generate_sql_like($rules, $rule_key))
				  return false;
			}
		}

		foreach (array("msg_include", "msg_exclude", "ident_include", "ident_exclude") as $rule_key) {
			if (!$this->_generate_sql_like($rules, $rule_key))
			  return false;
		}
		foreach (array("eventid_include", "eventid_exclude") as $rule_key) {
			$this->_generate_sql_in($rules, $rule_key);
		}

		$retval = sprintf("SELECT %s FROM %s %s %s",
						  $query_fields,
						  $query,
						  implode(" AND ", $rules),
						  $extra_after);
		return true;
	}

	// Returns a string ' $tabla_name WHERE condition '
	function generate_sql_query(& $retval, $table_name, $extra_where, $extra_after = "") {
		global $db_operators, $db_fields;
		$rules = array();

		if (! $this->validate_field("time_rel_from")) {
			return false;
		}

                $wnew = $this->whats_new();

                if( count($wnew) == 0 && empty($extra_where))
                {
                    $retval = sprintf("%s %s", $table_name, $extra_after);
                    return true;
                }


		$query_init = "";
		if ($extra_where != "")
		  $extra_where .= " AND ";
		// time_from and time_to
		if ($this->get_time_relative() || $this->get_from() || $this->get_to()) {
			$time_clause = $this->_generate_sql_time_table_clause($table_name,
																  $this->get_time_relative() * (24 * 60 * 60),
																  $this->get_from(),
																  $this->get_to(),
																  $extra_where);
			$query_init = sprintf("%s, (%s %s) as time_table WHERE min_id <= id AND id <= max_id AND %s ",
								  $table_name, $time_clause, $extra_after, $extra_where);
		} else {
			$query_init = sprintf("%s WHERE %s ", $table_name, $extra_where);
		}

                if( $wnew['sev'] )
                    $rules[] = sprintf("(sev & %u)", $this->get_sev());

                if( $wnew['fac'] )
                    $rules[] = sprintf("(fac & %u)", $this->get_fac());

		foreach ($this->host_msg_fields as $key) {
			if (!$this->_generate_sql_like($rules, $key))
			  return false;
		}
		foreach (array("eventid_include", "eventid_exclude") as $rule_key) {
			$this->_generate_sql_in($rules, $rule_key);
		}

		$retval = sprintf("%s %s %s", $query_init, implode(" AND ", $rules), $extra_after);
		return true;
	}

	function validate_query() {
		$query = "SELECT id FROM %s";

		/* TODO: Maybe we should validate against tmp_* tablename?
		 * Since mysql only does parsing of the query (thanks to limit 0),
		 * it should be ok to validate against messages table.
		 */
		if (! $this->generate_sql_query($tmp, "messages", "", "LIMIT 0")) {
			return false;
		}
		$query = sprintf($query, $tmp);
		trigger_error("filter::validate_query: " . $query);
		if (! mysql_query($query)) {
			trigger_error("Filter::validate_query: could not execute " . $query);
			return false;
		}
		return true;
	}
}

function db_get_filter($filterid, & $filter) {
	$tmp = new Filter($filterid);

	trigger_error("db_get_filter: called with filterid = " . $filterid);
	if ($tmp->init()) {
		$filter = $tmp;
		return true;
	} else {
		trigger_error("db_get_filter() Filter::init returns false");
		return false;
	}
}

/* Start of plugin */

define("UNKNOWN", 3);
define("CRITICAL", 2);
define("WARNING", 1);
define("OK", 0);

declare(ticks = 1);

/* Default values. */
$warning = array('lo' => false, 'hi' => true);
$critical = array('lo' => false, 'hi' => true);
$verbosity = 0;
$parse_host_string = false;
$timeout = "10";
$url = "";

/* Dont output debug messages */
error_reporting(E_ALL ^ (E_USER_NOTICE | E_USER_WARNING | E_WARNING | E_NOTICE));

function usage() {
	echo "Usage: \n";
	echo "check_ls_log.php -f <filtername> -a <timestamp> -i <interval> [-H <hostname>]\n";
	echo "     [-u <url>] [-w <warning>] [-c <critical>] [-t <timeout>] [-v]\n";
	echo "\n";
	echo "Options:\n";
	echo " * -f, --filtername - name of the filter to apply\n";
	echo " | -a, --absolute   - check logs newer than this time (seconds since epoch).\n";
	echo " | -i, --interval   - check logs this many minutes back\n";
	echo "   -H, --hostname   - hostname(s) to apply this filter to\n";
	echo "   -u, --url        - url to append to html-output\n";
	echo "   -w, --warning    - warning threshold: default 1\n";
	echo "   -c, --critical   - critical threshold: default 1\n";
	echo "   -t, --timeout    - seconds before plugin times out: default 10\n";
	echo "   -v, --verbose    - increase verbosity\n";
	echo "\n";
	echo "Options marked with * is required.\n";
	echo "One of the options marked with | is required.\n";
	echo "\n";
	echo "Hostname is a string of hosts, delimited by spaces. If specified, the\n";
	echo "normal host-selection for this filter does not apply.\n";
	echo "\n";
}

function pexit($result_code, $message, $print_usage = false) {
	$result_names = array("OK", "WARNING", "CRITICAL", "UNKNOWN");

	echo sprintf("%s - %s\n", $result_names[$result_code], $message);
	if ($print_usage) {
		echo "\n";
		usage();
	}
	exit($result_code);
}

function print_verbose($level, $message) {
	global $verbosity;
	if ($verbosity > $level) {
		echo $message . "\n";
	}
}

function microtime_float() {
	list($usec, $sec) = explode(" ", microtime());
	return ((float) $usec + (float) $sec);
}

function parse_arguments() {
	global $argv;
	$progname = array_shift($argv);
	global $db_host, $filter_name, $warning, $critical;
	global $verbosity, $interval, $host_string, $parse_host_string;
	global $timeout, $timestamp, $url;

	while (count($argv) > 0) {
		$p_switch = array_shift($argv);
		if (in_array($p_switch, array("-f", "--filtername"))) {
			$filter_name = array_shift($argv);
		} else if (in_array($p_switch, array("-i", "--interval"))) {
			$interval = array_shift($argv);
			print_verbose(2, "Got interval arg: " . $interval);
		} else if (in_array($p_switch, array("-a", "--absolute"))) {
			$timestamp = array_shift($argv);
			print_verbose(2, "Got timestamp arg: " . $timestamp);
		} else if (in_array($p_switch, array("-H", "--hostname"))) {
			$parse_host_string = true;
			$host_string = array_shift($argv);
		} else if (in_array($p_switch, array("-u", "--url"))) {
			$url = array_shift($argv);
		} else if (in_array($p_switch, array("-h", "--help"))) {
			usage();
			exit(UNKNOWN);
		} else if (in_array($p_switch, array("-w", "--warning"))) {
			$warning = parse_range(array_shift($argv));
		} else if (in_array($p_switch, array("-c", "--critical"))) {
			$critical = parse_range(array_shift($argv));
		} else if (in_array($p_switch, array("-t", "--timeout"))) {
			$timeout = array_shift($argv);
		} else if (in_array($p_switch, array("-v", "--verbose"))) {
			$verbosity++;
		} else {
			echo "Unknown argument $p_switch\n";
			exit(3);
		}
	}
}

/* Start with argument parsing, so you can get help without db connection */
parse_arguments();

/* Start of main program */
if (!isset($filter_name)) {
	pexit(UNKNOWN, "Missing filtername.", true);
}

if (isset($timestamp)) {
	if (!ctype_digit($timestamp)) {
		pexit(UNKNOWN, sprintf("Not a valid timestamp: %s", $timestamp), true);
	}
	$timestamp = intval($timestamp);
} else if (isset($interval)) {
	if (!ctype_digit($interval)) {
		pexit(UNKNOWN, sprintf("Not a valid interval: %s", $interval), true);
	}
	$timestamp = time() - (60 * intval($interval));
} else {
	pexit(UNKNOWN, "Missing timestamp/interval argument.", true);
}

if (!ctype_digit($timeout)) {
	pexit(UNKNOWN, sprintf("Not a valid timeout parameter: %s", $timeout));
}
$timeout = intval($timeout);

/* Parse the host-string. Individual hosts are separated by space. */
$hosts = array();
if ($parse_host_string) {
	/* Break up by space, string to array */
	$hosts = explode(" ", $host_string);
	$new_hosts = array();
	foreach ($hosts as $host) {
		/* Only add hostname if it is nonempty */
		$tmp = trim($host);
		if ($tmp != "")
		  $new_hosts[] = $tmp;
	}
	$hosts = $new_hosts;
	print_verbose(1, sprintf("Found hosts: %s", implode(" ", $hosts)));
	if (count($hosts) < 1) { /* Need at least one host */
		pexit(UNKNOWN, "No hosts given.", true);
	}
}

function timeout_signal_handler ($signal) {
	pexit(UNKNOWN, "Plugin timed out.");
}

print_verbose(1, sprintf("Timeout set to %d seconds", $timeout));
pcntl_alarm($timeout);
pcntl_signal(SIGALRM, "timeout_signal_handler", true);

if (!mysql_connect("localhost", DB_USERNAME, DB_PASSWORD)) {
	pexit(UNKNOWN, sprintf("Cannot connect to mysql %s with username %s password %s.",
					 $db_host, $db_user, $db_pass));
}

if (!mysql_select_db(DB_DATABASE)) {
	pexit(UNKNOWN, sprintf("Cannot select database %s.", DB_DATABASE));
}

print_verbose(1, sprintf("Trying to find named query '%s'\n", $filter_name));
if (!db_list_filters($filters)) {
	pexit(UNKNOWN, "Error retrieving filter list.");
}
/* Walk through filter descriptions and look for the filtername from user. */
foreach ($filters as $filter_arr) {
	if ($filter_arr[1] == $filter_name) {
		$filter_id = $filter_arr[0];
		break;
	}
}
/* Didn't find the name, bail out. */
if (! isset($filter_id)) {
	pexit(UNKNOWN, sprintf("Could not find filter '%s'.", $filter_name));
}

/* Load the filter from database. */
if (! db_get_filter($filter_id, $filter)) {
	pexit(UNKNOWN, sprintf("Could not load filter %d.", $filter_id));
}

/* Try to generate the SQL-query. */
if (! $filter->generate_trigger_sql($query, $timestamp, $hosts, "", "count(*) as id_count")) {
	pexit(UNKNOWN, sprintf("Could not generate SQL-query for filter %d.", $filter->id));
}

$query_start_time = microtime_float();
print_verbose(2, sprintf("Executing query '%s'", $query));
if (! $result = mysql_query($query)) {
	pexit(UNKNOWN, sprintf("Could not execute trigger query."));
}
//$query_exec_time = microtime_float() - $query_start_time;

/* Sanity check, row count should always be 1. */
if (mysql_num_rows($result) != 1) {
	pexit(UNKNOWN, sprintf("No results for trigger query."));
}

$row = mysql_fetch_assoc($result);
$result_count = intval($row["id_count"]);

$result_string = sprintf("%d matches for ", $result_count);
if (count($hosts) > 0) {
	$result_string .= sprintf("filter '%s' with hosts: %s.", $filter_name, implode(" ", $hosts));
} else {
	$result_string .= sprintf("general filter '%s'.", $filter_name);
}

if ($url != "") {
	$result_string .= sprintf(' <a href="%sview.php?filter_id=%u" target="_MON_LS_VIEW">Show log</a>',
							  $url, $filter_id);
}

if (! $filter->generate_trigger_sql($query, $timestamp, $hosts, "", "host, msg", "GROUP BY host LIMIT 10")) {
        pexit(UNKNOWN, sprintf("Could not generate SQL-query for filter %d.", $filter->id));
}

print_verbose(2, sprintf("Executing query '%s'", $query));

if (! $result = mysql_query($query)) {
        pexit(UNKNOWN, sprintf("Could not execute trigger query."));
}
$query_exec_time = microtime_float() - $query_start_time;

if ( $row = mysql_fetch_assoc($result))
{
    $msg_first = substr($row["msg"], 0, 200);
    $host_and_msg  .= sprintf("%s", $row["host"]);
}

while ( $row = mysql_fetch_assoc($result) )
{
    $host_and_msg  .= sprintf(",%s", $row["host"]);
}

$host_and_msg .= ":" . $msg_first;

/* Add performance data. */
$result_string .= $host_and_msg . sprintf("|query_time=%.2fms nr_matches=%d;%d;%d\n",
						  (1000 * $query_exec_time), $result_count,
						  $warning['hi'], $critical['hi']);
if (!matches_range($result_count, $critical))
	pexit(CRITICAL, $result_string);

if (!matches_range($result_count, $warning))
	pexit(WARNING, $result_string);

pexit(OK, $result_string);

?>
