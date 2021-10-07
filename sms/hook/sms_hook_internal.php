<?php

include "../root.php";

require_once "resources/require.php";
require_once "../sms_hook_common.php";

// {"from":"1999999999","body":"texto","to":"100@okay.pbx"}

if (check_acl()) {
	if  ($_SERVER['CONTENT_TYPE'] == 'application/json') {
		$data = json_decode(file_get_contents("php://input"));
		if ($debug) {
			error_log('[SMS] REQUEST: ' .  print_r($data, true));
		}
		//$to = intval(preg_replace('/(^[\+][1])/','', $data->To[0]));
		route_and_send_sms($data->from, $data->to, $data->body, null);
	} else {
	  die("no");
	}
} else {
	error_log('ACCESS DENIED [SMS]: ' .  print_r($_SERVER['REMOTE_ADDR'], true));
	die("access denied");
}
?>
