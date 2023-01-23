<?php
/*
        SMS for FusionPBX

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

$debug = (strtolower($_SESSION['sms']['debug']['boolean']) == 'true')?true:false;

$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
if ($debug){
        $action = 'SELECT *';
}
else{
        $action = 'DELETE';
}

$sql = "$action FROM v_sms_messages WHERE direction = 'inbound' AND (deliver_stamp IS NULL" .($db_type=='mysql'?" OR deliver_stamp = '0000-00-00 00:00:00'":"").") AND ";

$unqueue_period = isset($_SESSION['sms']['unqueue_period']['numeric'])?intval($_SESSION['sms']['unqueue_period']['numeric']):1;

if ($db_type == 'mysql'){
        $sql .=  "start_stamp > DATE_SUB(NOW(), INTERVAL $unqueue_period DAY)";
}
else{
        $sql .= "start_stamp > (NOW() - INTERVAL '$unqueue_period DAY')";
}

if ($debug){
        print $sql.PHP_EOL;
        $result = $db->query($sql)->fetchAll(PDO::FETCH_NAMED);
        foreach($result as &$sms){
                echo '/////////////////////////////////////////'.PHP_EOL;
                print_r($sms);
        }
}
else{
        $prep_statement = $db->prepare(check_sql($sql));
        $prep_statement->execute();
        unset($prep_statement, $sql);
}
