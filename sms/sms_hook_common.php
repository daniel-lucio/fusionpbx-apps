<?php
/* $Id$ */
/*
	call.php
	Copyright (C) 2008, 2009 Mark J Crane
	All rights reserved.

	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:

	1. Redistributions of source code must retain the above copyright notice,
	   this list of conditions and the following disclaimer.

	2. Redistributions in binary form must reproduce the above copyright
	   notice, this list of conditions and the following disclaimer in the
	   documentation and/or other materials provided with the distribution.

	THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
	INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
	AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
	AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
	OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
	POSSIBILITY OF SUCH DAMAGE.
	Contributor(s):
	Mark J Crane <markjcrane@fusionpbx.com>
	James Rose <james.o.rose@gmail.com>

*/
include "root.php";
include "app/sms/sms_email.php";

//luarun /var/www/html/app/sms/sms.lua TO FROM 'BODY'

$debug = true;

require_once "resources/require.php";

function route_and_send_sms($from, $to, $body, $media = "") {
	global $db, $debug, $domain_uuid, $domain_name, $mailsent;

	//create the event socket connection and send the event socket command
		$fp = event_socket_create($_SESSION['event_socket_ip_address'], $_SESSION['event_socket_port'], $_SESSION['event_socket_password']);
		if (!$fp) {
			//error message
			echo "<div align='center'><strong>Connection to Event Socket failed.</strong></div>";
		}
		else {
			$mailsent = 0;
//			$email_regex = '/^((?!(?:(?:\x22?\x5C[\x00-\x7E]\x22?)|(?:\x22?[^\x5C\x22]\x22?)){255,})(?!(?:(?:\x22?\x5C[\x00-\x7E]\x22?)|(?:\x22?[^\x5C\x22]\x22?)){65,}@)(?:(?:[\x21\x23-\x27\x2A\x2B\x2D\x2F-\x39\x3D\x3F\x5E-\x7E]+)|(?:\x22(?:[\x01-\x08\x0B\x0C\x0E-\x1F\x21\x23-\x5B\x5D-\x7F]|(?:\x5C[\x00-\x7F]))*\x22))(?:\.(?:(?:[\x21\x23-\x27\x2A\x2B\x2D\x2F-\x39\x3D\x3F\x5E-\x7E]+)|(?:\x22(?:[\x01-\x08\x0B\x0C\x0E-\x1F\x21\x23-\x5B\x5D-\x7F]|(?:\x5C[\x00-\x7F]))*\x22)))*@(?:(?:(?!.*[^.]{64,})(?:(?:(?:xn--)?[a-z0-9]+(?:-[a-z0-9]+)*\.){1,126}){1,}(?:(?:[a-z][a-z0-9]*)|(?:(?:xn--)[a-z0-9]+))(?:-[a-z0-9]+)*)|(?:\[(?:(?:IPv6:(?:(?:[a-f0-9]{1,4}(?::[a-f0-9]{1,4}){7})|(?:(?!(?:.*[a-f0-9][:\]]){7,})(?:[a-f0-9]{1,4}(?::[a-f0-9]{1,4}){0,5})?::(?:[a-f0-9]{1,4}(?::[a-f0-9]{1,4}){0,5})?)))|(?:(?:IPv6:(?:(?:[a-f0-9]{1,4}(?::[a-f0-9]{1,4}){5}:)|(?:(?!(?:.*[a-f0-9]:){5,})(?:[a-f0-9]{1,4}(?::[a-f0-9]{1,4}){0,3})?::(?:[a-f0-9]{1,4}(?::[a-f0-9]{1,4}){0,3}:)?)))?(?:(?:25[0-5])|(?:2[0-4][0-9])|(?:1[0-9]{2})|(?:[1-9]?[0-9]))(?:\.(?:(?:25[0-5])|(?:2[0-4][0-9])|(?:1[0-9]{2})|(?:[1-9]?[0-9]))){3}))\])))$/i';
			$email_regex = '/[\w\-\_\.]+@[\w\-\_\.]+/i';
			$matches = array();
			if ($debug) {
				error_log("ORIGINAL TO: " . print_r($to,true).PHP_EOL);
			}
			$original_to = $to;
			if (preg_match($email_regex, $to, $matches)){
				$to = $matches[0];
				$internal_to = true;
				error_log("Internal To".PHP_EOL);
			}
			else{
				$to = intval(preg_replace('/(^[1])/','', $to));
				$internal_to = false;
				error_log("NOT Internal To".PHP_EOL);
			}
			$from = intval($from);
			$body = preg_replace('([\'])', '\\\'', $body); // escape apostrophes
			if ($debug) {
				error_log("TO: " . print_r($to,true).PHP_EOL);
				error_log("FROM: " . print_r($from,true).PHP_EOL);
				error_log("BODY: " . print_r($body,true).PHP_EOL);
			}
			$mailbody = $body;
			if (gettype($media)=="array") {
				if (empty($body)) {
					$body = "MMS message received, see email for attachment";
				}
				else {
					$body .= " (MMS message received, see email for attachment)";
				}
				if ($debug) {
					error_log("MMS message (media array present)");
				}
			}
			if ($debug) {
				error_log("BODY: " . print_r($body,true).PHP_EOL);
			}
			$body = preg_replace('([\n])', '<br>', $body); // escape newlines
			if ($debug) {
				error_log("BODY-revised: " . print_r($body,true).PHP_EOL);
			}


			if ($internal_to){
				$switch_cmd = "api luarun app.lua sms inbound $to $from '$body' 1 1";
				if ($debug) {
					error_log('LUA SCRIPT: '.print_r($switch_cmd,true).PHP_EOL);
				}
				$result2 = trim(event_socket_request($fp, $switch_cmd));
				if ($debug) {
					error_log("RESULT: " . print_r($result2,true).PHP_EOL);
				}
			}
			else{
				// Check for chatplan_detail in sms_destinations table
				$sql = "select domain_name, ";
				$sql .= "chatplan_detail_data, ";
				$sql .= "v_sms_destinations.domain_uuid as domain_uuid ";
				$sql .= "from v_sms_destinations, ";
				$sql .= "v_domains ";
				$sql .= "where v_sms_destinations.domain_uuid = v_domains.domain_uuid";
				$sql .= " and destination like :to";
				$sql .= " and chatplan_detail_data <> ''";

				if ($debug) {
					error_log("SQL: " . print_r($sql,true).PHP_EOL);
				}

				$prep_statement = $db->prepare(check_sql($sql));
				$prep_statement->bindValue(':to', "%{$to}%");
				$prep_statement->execute();
				$result = $prep_statement->fetchAll(PDO::FETCH_NAMED);

				if (count($result) > 0) {
					if ($debug){
						error_log("result: " . print_r($result, true).PHP_EOL);
					}
					foreach ($result as &$row) {
						$domain_name = $row["domain_name"];
						preg_match('/([\w\.\-]+)/',$row["chatplan_detail_data"],$match);
						$domain_uuid = $row["domain_uuid"];
						break; //limit to 1 row
					}
				}
				else { // Fall back to destinations table for backwards compatibility
					$sql = "select domain_name, ";
					$sql .= "dialplan_detail_data, ";
					$sql .= "v_domains.domain_uuid as domain_uuid ";
					$sql .= "from v_destinations, ";
					$sql .= "v_dialplan_details, ";
					$sql .= "v_domains ";
					$sql .= "where v_destinations.dialplan_uuid = v_dialplan_details.dialplan_uuid ";
					$sql .= "and v_destinations.domain_uuid = v_domains.domain_uuid";
					$sql .= " and destination_number like :to and dialplan_detail_type = 'transfer'";
					if ($debug) {
						error_log("SQL: " . print_r($sql,true).PHP_EOL);
					}

					$prep_statement = $db->prepare(check_sql($sql));
					$prep_statement->bindValue(':to', "%{$to}%");
					$prep_statement->execute();
					$result = $prep_statement->fetchAll(PDO::FETCH_NAMED);
					if (count($result) == 0) {
						error_log("Cannot find a destination: " . print_r($result,true).PHP_EOL);
						die("Invalid Destination");
					}
					foreach ($result as &$row) {
						$domain_name = $row["domain_name"];
						preg_match('/(\d{2,7})/',$row["dialplan_detail_data"],$match);
						$domain_uuid = $row["domain_uuid"];
						break; //limit to 1 row
					}
				}

				unset ($prep_statement);

				if ($debug) {
					error_log("SQL: " . print_r($sql,true).PHP_EOL);
					error_log("MATCH: " . print_r($match[0],true).PHP_EOL);
					error_log("DOMAIN_NAME: " . print_r($domain_name,true).PHP_EOL);
					error_log("DOMAIN_UUID: " . print_r($domain_uuid,true).PHP_EOL);
				}

				//load default and domain settings
				$_SESSION["domain_uuid"] = $domain_uuid;
				require_once "resources/classes/domains.php";
				$domain = new domains();
				$domain->set();

				if ($debug) {
					error_log("Email from: ". $_SESSION['email']['smtp_from']['text'].PHP_EOL);
				}
//				$mailsent = send_sms_to_email($from, $to, $mailbody, $media);

				//check to see if we have a ring group or single extension
				$sql = "select destination_number ";
				$sql .= "from v_ring_groups, v_ring_group_destinations ";
				$sql .= "where v_ring_groups.ring_group_uuid = v_ring_group_destinations.ring_group_uuid ";
				$sql .= "and ring_group_extension = :extension ";
				$sql .= "and v_ring_groups.domain_uuid = :domain_uuid";
				$prep_statement = $db->prepare(check_sql($sql));
				$prep_statement->execute(array(':extension' => $match[0], ':domain_uuid' => $domain_uuid));
				$result = $prep_statement->fetchAll(PDO::FETCH_NAMED);
				if ($debug) {
					error_log("SQL: " . print_r($sql,true).PHP_EOL);
					error_log("RG RESULT: " . print_r($result,true).PHP_EOL);
				}
				
				//send sms via Lua script
				if (count($result)) { //ring group
					foreach ($result as &$row) {
						$switch_cmd = "api luarun app.lua sms inbound ";
						$switch_cmd .= $row['destination_number'] . "@" . $domain_name;
						$switch_cmd .= " " . $from . " '" . $body . "' " . (int)$mailsent. " 0 " . $original_to;
						if ($debug) {
							error_log('Ring group'.PHP_EOL);
							error_log(print_r($switch_cmd,true).PHP_EOL);
						}
						if (strlen($_SESSION['sms']['incoming_script']['text'])){
							$script_cmd = $_SESSION['sms']['incoming_script']['text'];
							$script_cmd = str_replace('${caller_id_number}', $from, $script_cmd);
							$script_cmd = str_replace('${destination_number}', $to, $script_cmd);
							$script_cmd = str_replace('\\', "", $script_cmd);
							if ($debug) {
								error_log(print_r($switch_cmd,true));
							}
							error_log(print_r($script_cmd,true));
							exec($script_cmd);
						}
						$result2 = trim(event_socket_request($fp, $switch_cmd));
						if ($debug) {
							error_log("RESULT: " . print_r($result2,true).PHP_EOL);
						}
					}
				} else { //single extension
					$switch_cmd = "api luarun app.lua sms inbound " . $match[0] . "@" . $domain_name . " " . $from . " '" . $body . "' " . (int)$mailsent . " 0 " . $original_to;
					if ($debug) {
						error_log('Single extension'.PHP_EOL);
						error_log(print_r($switch_cmd,true));
					}
					if (strlen($_SESSION['sms']['incoming_script']['text'])){
						$script_cmd = $_SESSION['sms']['incoming_script']['text'];
						$script_cmd = str_replace('${caller_id_number}', $from, $script_cmd);
						$script_cmd = str_replace('${destination_number}', $to, $script_cmd);
						$script_cmd = str_replace('\\', "", $script_cmd);
						if ($debug) {
							error_log(print_r($switch_cmd,true));
						}
						error_log(print_r($script_cmd,true));
						exec($script_cmd);
					}
					$result2 = trim(event_socket_request($fp, $switch_cmd));
					if ($debug) {
						error_log("RESULT: " . print_r($result2,true));
					}
				}

			unset ($prep_statement);
			}
		}
}
?>
