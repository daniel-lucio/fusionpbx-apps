<?php

include "../root.php";

require_once "resources/require.php";
require_once "../sms_hook_common.php";

// {"from":"1999999999","body":"texto","to":"100@okay.pbx"}

if (!class_exists('IP4Filter')) {
	class IP4Filter {

		private static $_IP_TYPE_SINGLE = 'single';
		private static $_IP_TYPE_WILDCARD = 'wildcard';
		private static $_IP_TYPE_MASK = 'mask';
		private static $_IP_TYPE_CIDR = 'CIDR';
		private static $_IP_TYPE_SECTION = 'section';
		private $_allowed_ips = array();

		public function __construct($allowed_ips) {
			$this->_allowed_ips = $allowed_ips;
		}

		public function check($ip, $allowed_ips = null) {
			$allowed_ips = $allowed_ips ? $allowed_ips : $this->_allowed_ips;

			foreach ($allowed_ips as $allowed_ip) {
				$type = $this->_judge_ip_type($allowed_ip);
				$sub_rst = call_user_func(array($this, '_sub_checker_' . $type), $allowed_ip, $ip);

				if ($sub_rst) {
					return true;
				}
			}

			return false;
		}

		private function _judge_ip_type($ip) {
			if (strpos($ip, '*')) {
				return self :: $_IP_TYPE_WILDCARD;
			}

			if (strpos($ip, '/')) {
				$tmp = explode('/', $ip);
				if (strpos($tmp[1], '.')) {
					return self :: $_IP_TYPE_MASK;
				} else {
					return self :: $_IP_TYPE_CIDR;
				}
			}

			if (strpos($ip, '-')) {
				return self :: $_IP_TYPE_SECTION;
			}

			if (ip2long($ip)) {
				return self :: $_IP_TYPE_SINGLE;
			}

			return false;
		}

		private function _sub_checker_single($allowed_ip, $ip) {
			return (ip2long($allowed_ip) == ip2long($ip));
		}

		private function _sub_checker_wildcard($allowed_ip, $ip) {
			$allowed_ip_arr = explode('.', $allowed_ip);
			$ip_arr = explode('.', $ip);
			for ($i = 0; $i < count($allowed_ip_arr); $i++) {
				if ($allowed_ip_arr[$i] == '*') {
					return true;
				} else {
					if (false == ($allowed_ip_arr[$i] == $ip_arr[$i])) {
						return false;
					}
				}
			}
		}

		private function _sub_checker_mask($allowed_ip, $ip) {
			list($allowed_ip_ip, $allowed_ip_mask) = explode('/', $allowed_ip);
			$begin = (ip2long($allowed_ip_ip) & ip2long($allowed_ip_mask)) + 1;
			$end = (ip2long($allowed_ip_ip) | (~ ip2long($allowed_ip_mask))) + 1;
			$ip = ip2long($ip);
			return ($ip >= $begin && $ip <= $end);
		}

		private function _sub_checker_section($allowed_ip, $ip) {
			list($begin, $end) = explode('-', $allowed_ip);
			$begin = ip2long($begin);
			$end = ip2long($end);
			$ip = ip2long($ip);
			return ($ip >= $begin && $ip <= $end);
		}

		private function _sub_checker_CIDR($CIDR, $IP) {
			list ($net, $mask) = explode('/', $CIDR);
			return ( ip2long($IP) & ~((1 << (32 - $mask)) - 1) ) == ip2long($net);
		}

	}
}

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
		$rawdata = file_get_contents("php://input");
		$data = json_decode($rawdata);
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
