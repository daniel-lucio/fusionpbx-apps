<?php

include "../root.php";

require_once "resources/require.php";
require_once "../sms_hook_common.php";

if ($debug) {
	// error_log('[SMS] REQUEST: ' .  print_r($_SERVER, true));
}

if (check_acl()) {
	if  (isset($_GET)) {
		$data = $_GET;
		if ($debug) {
			error_log('[SMS] REQUEST: ' .  print_r($data, true));
		}
		route_and_send_sms($data['from'], $data['to'], $data['message']);
	} else {
		error_log('[SMS] REQUEST: No SMS Data Received');
		die("no");
	}
} else {
	error_log('ACCESS DENIED [SMS]: ' .  print_r($_SERVER['REMOTE_ADDR'], true));
	die("access denied");
}
?>
