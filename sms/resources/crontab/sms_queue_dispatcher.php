<?php
/*
        Billing for FusionPBX

        Contributor(s):
        Luis Daniel Lucio Quiroz <dlucio@okay.com.mx>
*/

if(defined('STDIN')) {
	$document_root = str_replace("\\", "/", $_SERVER["PHP_SELF"]);
	preg_match("/^(.*)\/app\/.*$/", $document_root, $matches);
	$document_root = $matches[1];
	set_include_path($document_root);
	$_SERVER['DOCUMENT_ROOT'] = $document_root;
	require_once 'resources/require.php';
	$display_type = 'text'; //html, text
}
else {
	include 'root.php';
	require_once 'resources/require.php';
	$call_type = 1;
}

$debug = (strtolower($_SESSION['billing']['debug']['boolean']) == 'true')?true:false;
$https = (strtolower($_SESSION['billing']['https']['boolean']) == 'true')?true:false;


$fp = event_socket_create($_SESSION['event_socket_ip_address'], $_SESSION['event_socket_port'], $_SESSION['event_socket_password']);
if (!$fp) {
	exit;
}

$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$sql = "SELECT * FROM v_sms_messages WHERE direction = 'outbound' AND (deliver_stamp IS NULL" .($db_type=='mysql'?" OR deliver_stamp = '0000-00-00 00:00:00'":"").")";
$sql .= 'ORDER BY start_stamp DESC';
$result = $db->query($sql);

while ($sms = $result->fetch(PDO::FETCH_NAMED)){
	if ($debug){
		echo '/////////////////////////////////////////'.PHP_EOL;
		print_r($sms);
	}
	$switch_cmd = 'api luarun sms_queue_distpacher.lua '.$sms['sms_message_uuid'];
	$result2 = trim(event_socket_request($fp, $switch_cmd));
}
