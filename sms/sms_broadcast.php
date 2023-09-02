<?php
/*
	FusionPBX
	Version: MPL 1.1

	The contents of this file are subject to the Mozilla Public License Version
	1.1 (the "License"); you may not use this file except in compliance with
	the License. You may obtain a copy of the License at
	http://www.mozilla.org/MPL/

	Software distributed under the License is distributed on an "AS IS" basis,
	WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
	for the specific language governing rights and limitations under the
	License.

	The Original Code is FusionPBX

	The Initial Developer of the Original Code is
	Mark J Crane <markjcrane@fusionpbx.com>
	Portions created by the Initial Developer are Copyright (C) 2008-2020
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	Mark J Crane <markjcrane@fusionpbx.com>
*/

//includes
	require_once "root.php";
	require_once "resources/require.php";
	require_once "resources/check_auth.php";
	require_once "resources/paging.php";
	require_once "resources/functions/order_by.php";
	require_once "resources/functions/limit_offset.php";
	require_once 'resources/functions/version.php';

//check permissions
	if (permission_exists('call_broadcast_view')) {
		//access granted
	}
	else {
		echo "access denied";
		exit;
	}

//add multi-lingual support
	$language = new text;
	$text = $language->get();


//get the http get variables and set them to php variables
	$order_by = $_GET["order_by"];
	$order = $_GET["order"];

//add the search term
	$search = strtolower($_GET["search"]);
	if (strlen($search) > 0) {
		$sql_search = " (";
		$sql_search .= "	lower(sms_sms_broadcast_name) like :search ";
		$sql_search .= "	or lower(sms_broadcast_description) like :search ";
		$sql_search .= ") ";
		$parameters['search'] = '%'.$search.'%';
	}

//get the count
	$sql = "select count(*) from v_sms_broadcast ";
	$sql .= "where domain_uuid = :domain_uuid ";
	if (isset($sql_search)) {
		$sql .= "and ".$sql_search;
	}
	$database = new database;
	$parameters['domain_uuid'] = $_SESSION['domain_uuid'];
	$num_rows = $database->select($sql, $parameters, 'column');

//prepare the paging
	$rows_per_page = ($_SESSION['domain']['paging']['numeric'] != '') ? $_SESSION['domain']['paging']['numeric'] : 50;
	$param = "&search=".$search;
	$page = $_GET['page'];
	if (strlen($page) == 0) { $page = 0; $_GET['page'] = 0; }
	list($paging_controls, $rows_per_page) = paging($num_rows, $param, $rows_per_page);
	list($paging_controls_mini, $rows_per_page) = paging($num_rows, $param, $rows_per_page, true);
	$offset = $rows_per_page * $page;

//get the call broadcast
	$sql = str_replace('count(*)','*', $sql);
	$sql .= order_by($order_by, $order);
	$sql .= limit_offset($rows_per_page, $offset);
	$database = new database;
	$result = $database->select($sql, $parameters, 'all');
	unset($sql, $parameters);

//create token
	 if(class_exists('token')){
		$object = new token;
		$token = $object->create($_SERVER['PHP_SELF']);
	 }

//include the header
	$document['title'] = $text['title-call_broadcast'];
	require_once "resources/header.php";	


//
//show the content
	echo "<table width=\"100%\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\">\n";
	echo "  <tr>\n";
	echo "	<td align='left' width='100%'><b>".$text['header-sms']." (".$total_sms_destinations.")</b><br>\n";
	echo "		".$text['description-sms']."\n";
	echo "	</td>\n";
	echo "		<form method='get' action=''>\n";
	echo "			<td style='vertical-align: top; text-align: right; white-space: nowrap;'>\n";
	if (if_group("superadmin")) {
		echo "				<input type='button' class='btn' style='margin-right: 15px;' value='".$text['button-mdr']."' onclick=\"window.location.href='sms_mdr.php'\">\n";
	}
		echo "				<input type='button' class='btn' style='margin-right: 15px;' value='".$text['button-broadcast']."' onclick=\"window.location.href='sms_broadcast.php'\">\n";

	echo "				<input type='text' class='txt' style='width: 150px' name='search' id='search' value='".$search."'>";
	echo "				<input type='submit' class='btn' name='submit' value='".$text['button-search']."'>";
	if ($paging_controls_mini != '') {
		echo 			"<span style='margin-left: 15px;'>".$paging_controls_mini."</span>\n";
	}
	echo "			</td>\n";
	echo "		</form>\n";
	echo "  </tr>\n";
	echo "</table>\n";
	echo "<br />";

	$c = 0;
	$row_style["0"] = "row_style0";
	$row_style["1"] = "row_style1";

	echo "<form name='frm' method='post' action='sms_delete.php'>\n";
	echo "<table class='tr_hover' width='100%' border='0' cellpadding='0' cellspacing='0'>\n";
	echo "<tr>\n";
	if (permission_exists('sms_delete') && is_array($sms_destinations)) {
		echo "<th style='width: 30px; text-align: center; padding: 0px;'><input type='checkbox' id='chk_all' onchange=\"(this.checked) ? check('all') : check('none');\"></th>";
	}
	echo th_order_by('destination', $text['label-destination'], $order_by, $order);
	echo th_order_by('carrier', $text['label-carrier'], $order_by, $order);
	echo th_order_by('enabled', $text['label-enabled'], $order_by, $order);
	echo th_order_by('description', $text['label-description'], $order_by, $order);
	echo "<td class='list_control_icon'>\n";
	if (permission_exists('sms_add')) {
			echo "<a href='sms_edit.php' alt='".$text['button-add']."'>".$v_link_label_add."</a>";
	}
	if (permission_exists('sms_delete') && is_array($sms_destinations)) {
		echo "<a href='javascript:void(0);' onclick=\"if (confirm('".$text['confirm-delete']."')) { document.forms.frm.submit(); }\" alt='".$text['button-delete']."'>".$v_link_label_delete."</a>";
	}
	echo "</td>\n";
	echo "</tr>\n";

	if (is_array($sms_destinations)) {

		foreach($sms_destinations as $row) {
			$tr_link = (permission_exists('sms_edit')) ? " href='sms_edit.php?id=".$row['sms_destination_uuid']."'" : null;
			echo "<tr ".$tr_link.">\n";
			if (permission_exists('sms_delete')) {
				echo "	<td valign='top' class='".$row_style[$c]." tr_link_void' style='text-align: center; vertical-align: middle; padding: 0px;'>";
				echo "		<input type='checkbox' name='id[]' id='checkbox_".$row['sms_destination_uuid']."' value='".$row['sms_destination_uuid']."' onclick=\"if (!this.checked) { document.getElementById('chk_all').checked = false; }\">";
				echo "	</td>";
				$ext_ids[] = 'checkbox_'.$row['sms_destination_uuid'];
			}
			echo "	<td valign='top' class='".$row_style[$c]."'>";
			if (permission_exists('sms_edit')) {
				echo "<a href='sms_edit.php?id=".$row['sms_destination_uuid']."'>".$row['destination']."</a>";
			}
			else {
				echo $row['destination'];
			}
			echo "</td>\n";
			echo "	<td valign='top' class='".$row_style[$c]."'>".$row['carrier']."</td>\n";
			echo "	<td valign='top' class='".$row_style[$c]."'>".ucwords($row['enabled'])."</td>\n";
			echo "	<td valign='top' class='row_stylebg' width='30%'>".$row['description']."&nbsp;</td>\n";
			echo "	<td class='list_control_icons'>";
			if (permission_exists('sms_edit')) {
				echo "<a href='sms_edit.php?id=".$row['sms_destination_uuid']."' alt='".$text['button-edit']."'>$v_link_label_edit</a>";
			}
			if (permission_exists('sms_delete')) {
				echo "<a href='sms_delete.php?id[]=".$row['sms_destination_uuid']."' alt='".$text['button-delete']."' onclick=\"return confirm('".$text['confirm-delete']."')\">$v_link_label_delete</a>";
			}
			echo "</td>\n";
			echo "</tr>\n";
			$c = ($c) ? 0 : 1;
		}
		unset($sms_destinations, $row);
	}

	if (is_array($sms_destinations)) {
		echo "<tr>\n";
		echo "	<td colspan='20' class='list_control_icons'>\n";
		if (permission_exists('sms_add')) {
				echo "<a href='sms_edit.php' alt='".$text['button-add']."'>".$v_link_label_add."</a>";
		}
		if (permission_exists('sms_delete')) {
			echo "<a href='javascript:void(0);' onclick=\"if (confirm('".$text['confirm-delete']."')) { document.forms.frm.submit(); }\" alt='".$text['button-delete']."'>".$v_link_label_delete."</a>";
		}
		echo "	</td>\n";
		echo "</tr>\n";
	}

	echo "</table>";
	echo "</form>";


//show the content
	echo "<div class='action_bar' id='action_bar'>\n";
	echo "	<div class='heading'><b>".$text['title-call_broadcast']." (".$num_rows.")</b></div>\n";
	echo "	<div class='actions'>\n";
	if (permission_exists('sms_broadcast_add')) {
		echo button::create(['type'=>'button','label'=>$text['button-add'],'icon'=>$_SESSION['theme']['button_icon_add'],'id'=>'btn_add','link'=>'sms_broadcast_edit.php']);
	}
	if (numeric_version() > 40500){
		if (permission_exists('sms_broadcast_add') && $result) {
			echo button::create(['type'=>'button','label'=>$text['button-copy'],'icon'=>$_SESSION['theme']['button_icon_copy'],'name'=>'btn_copy','onclick'=>"modal_open('modal-copy','btn_copy');"]);
		}
		if (permission_exists('sms_broadcast_delete') && $result) {
			echo button::create(['type'=>'button','label'=>$text['button-delete'],'icon'=>$_SESSION['theme']['button_icon_delete'],'name'=>'btn_delete','onclick'=>"modal_open('modal-delete','btn_delete');"]);
		}
		echo 		"<form id='form_search' class='inline' method='get'>\n";
		echo 		"<input type='text' class='txt list-search' name='search' id='search' value=\"".escape($search)."\" placeholder=\"".$text['label-search']."\" onkeydown='list_search_reset();'>";
		echo button::create(['label'=>$text['button-search'],'icon'=>$_SESSION['theme']['button_icon_search'],'type'=>'submit','id'=>'btn_search','style'=>($search != '' ? 'display: none;' : null)]);
		echo button::create(['label'=>$text['button-reset'],'icon'=>$_SESSION['theme']['button_icon_reset'],'type'=>'button','id'=>'btn_reset','link'=>'sms_broadcast.php','style'=>($search == '' ? 'display: none;' : null)]);
		if ($paging_controls_mini != '') {
			echo 	"<span style='margin-left: 15px;'>".$paging_controls_mini."</span>";
		}
		echo "		</form>\n";
	}
	echo "	</div>\n";
	echo "	<div style='clear: both;'></div>\n";
	echo "</div>\n";

	if (numeric_version() > 40500){
		if (permission_exists('sms_broadcast_add') && $result) {
			echo modal::create(['id'=>'modal-copy','type'=>'copy','actions'=>button::create(['type'=>'button','label'=>$text['button-continue'],'icon'=>'check','id'=>'btn_copy','style'=>'float: right; margin-left: 15px;','collapse'=>'never','onclick'=>"modal_close(); list_action_set('copy'); list_form_submit('form_list');"])]);
		}
		if (permission_exists('sms_broadcast_delete') && $result) {
			echo modal::create(['id'=>'modal-delete','type'=>'delete','actions'=>button::create(['type'=>'button','label'=>$text['button-continue'],'icon'=>'check','id'=>'btn_delete','style'=>'float: right; margin-left: 15px;','collapse'=>'never','onclick'=>"modal_close(); list_action_set('delete'); list_form_submit('form_list');"])]);
		}
	}
	echo $text['title_description-call_broadcast']."\n";
	echo "<br /><br />\n";

	echo "<form id='form_list' method='post'>\n";
	echo "<input type='hidden' id='action' name='action' value=''>\n";
	echo "<input type='hidden' name='search' value=\"".escape($search)."\">\n";

	echo "<table class='list'>\n";
	echo "<tr class='list-header'>\n";
	if (permission_exists('sms_broadcast_add') || permission_exists('sms_broadcast_delete')) {
		echo "	<th class='checkbox'>\n";
		echo "		<input type='checkbox' id='checkbox_all' name='checkbox_all' onclick='list_all_toggle();' ".($result ?: "style='visibility: hidden;'").">\n";
		echo "	</th>\n";
	}
	echo th_order_by('sms_broadcast_name', $text['label-name'], $order_by, $order);
	echo th_order_by('sms_broadcast_description', $text['label-description'], $order_by, $order);
	if (permission_exists('sms_broadcast_edit') && $_SESSION['theme']['list_row_edit_button']['boolean'] == 'true') {
		echo "	<td class='action-button'>&nbsp;</td>\n";
	}
	echo "</tr>\n";

	if (is_array($result) && @sizeof($result) != 0) {
		$x = 0;
		foreach($result as $row) {
			if (permission_exists('sms_broadcast_edit')) {
				$list_row_url = "sms_broadcast_edit.php?id=".urlencode($row['sms_broadcast_uuid']);
			}
			echo "<tr class='list-row' href='".$list_row_url."'>\n";
			if (permission_exists('sms_broadcast_add') || permission_exists('sms_broadcast_delete')) {
				echo "	<td class='checkbox'>\n";
				echo "		<input type='checkbox' name='sms_broadcast[$x][checked]' id='checkbox_".$x."' value='true' onclick=\"if (!this.checked) { document.getElementById('checkbox_all').checked = false; }\">\n";
				echo "		<input type='hidden' name='sms_broadcast[$x][uuid]' value='".escape($row['sms_broadcast_uuid'])."' />\n";
				echo "	</td>\n";
			}
			echo "	<td>";
			if (permission_exists('sms_broadcast_edit')) {
				echo "<a href='".$list_row_url."'>".escape($row['sms_broadcast_name'])."</a>";
			}
			else {
				echo escape($row['sms_broadcast_name']);
			}
			echo "	</td>\n";
			echo "	<td class='description overflow hide-xs'>".escape($row['sms_broadcast_description'])."</td>\n";
			if (permission_exists('sms_broadcast_edit') && $_SESSION['theme']['list_row_edit_button']['boolean'] == 'true') {
				echo "	<td class='action-button'>";
				echo button::create(['type'=>'button','title'=>$text['button-edit'],'icon'=>$_SESSION['theme']['button_icon_edit'],'link'=>$list_row_url]);
				echo "	</td>\n";
			}
			echo "</tr>\n";
			$x++;
		}
	}
	unset($result);

	echo "</table>\n";
	echo "<br />\n";
	echo "<div align='center'>".$paging_controls."</div>\n";

	if(class_exists('token')){
		echo "<input type='hidden' name='".$token['name']."' value='".$token['hash']."'>\n";
	}

	echo "</form>\n";
	
	
//include the footer
	require_once "resources/footer.php";

?>
