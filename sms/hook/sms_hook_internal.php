<?php

include "../root.php";

require_once "resources/require.php";
require_once "../sms_hook_common.php";

// {"from":"1999999999","body":"texto","to":"100@okay.pbx"}

if (!function_exists('check_acl')){
	function check_acl(){
		global $db, $debug, $domain_uuid, $domain_name;

		//select node_cidr from v_access_control_nodes where node_cidr != '';
		$sql = "select node_cidr from v_access_control_nodes where node_cidr != '' and node_type = 'allow'";
		$prep_statement = $db->prepare(check_sql($sql));
		$prep_statement->execute();
		$result = $prep_statement->fetchAll(PDO::FETCH_NAMED);
		if (count($result) == 0) {
			die("No ACL's");
		}
		foreach ($result as &$row) {
			$allowed_ips[] = $row['node_cidr'];
		}

		$acl = new IP4Filter($allowed_ips);

		return $acl->check($_SERVER['REMOTE_ADDR'],$allowed_ips);
	}
}

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
