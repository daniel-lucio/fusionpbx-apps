--	sms.lua
--	Part of FusionPBX
--	Copyright (C) 2010-2017 Mark J Crane <markjcrane@fusionpbx.com>
--	All rights reserved.
--
--	Redistribution and use in source and binary forms, with or without
--	modification, are permitted provided that the following conditions are met:
--
--	1. Redistributions of source code must retain the above copyright notice,
--	   this list of conditions and the following disclaimer.
--
--	2. Redistributions in binary form must reproduce the above copyright
--	   notice, this list of conditions and the following disclaimer in the
--	   documentation and/or other materials provided with the distribution.
--
--	THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
--	INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
--	AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
--	AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
--	OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
--	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
--	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
--	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
--	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
--	POSSIBILITY OF SUCH DAMAGE.

	start_epoch = os.time(os.date("!*t"));
--cluster enabled
	if sms == nil then
                sms = {};
        end

	if sms["fs_path"] == nil then
		USE_FS_PATH = false;
	else
		USE_FS_PATH = sms["fs_path"];
	end

	if sms["broadcast"] == nil then
		SMS_BROADCAST = false;
	else
		SMS_BROADCAST = sms["broadcast"];
	end

	require "resources.functions.split";
--connect to the database
	local Database = require "resources.functions.database";
	dbh = Database.new('system');

--debug
	debug["info"] = true;
	debug["sql"] = true;

--set the api
	api = freeswitch.API();

--include json library
	local json
	if (debug["sql"] or USE_FS_PATH) then
		json = require "resources.functions.lunajson"
	end

--define uuid function
	local random = math.random;
	local function uuid()
		local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
		return string.gsub(template, '[xy]', function (c)
			local v = (c == 'x') and random(0, 0xf) or random(8, 0xb);
			return string.format('%x', v);
		end)
	end

--define encoding function
	function encodeChar(chr)
		return string.format("%%%X",string.byte(chr))
	end

	function encodeString(str)
		local output, t = string.gsub(str,"[^%w]",encodeChar)
		return output
	end

	local function urlencode2 (str)
	   str = string.gsub (str, "([^0-9a-zA-Z !*._~-])", -- locale independent
	      function (c) return string.format ("%%%02X", string.byte(c)) end)
	   str = string.gsub (str, " ", "+")
	   return str
	end

	local function urldecode2 (str)
	   str = string.gsub (str, "+", " ")
	   str = string.gsub (str, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
	   return str
	end

	function build_xml_string(params, variables)
		direction = params['direction'] or '';
		uuid = params['uuid'] or uuid();
		from = params['from'] or '';
		to = params['to'] or '';
		extension_uuid = params['extension_uuid'] or '';
		domain_uuid = params['domain_uuid'] or '';
		domain_name = params['domain_name'] or '';
		core_uuid = params['core_uuid'] or '';
		start_epoch = params['start_epoch'] or os.time(os.date("!*t"));
		end_epoch = params['end_epoch'] or os.time(os.date("!*t"));
		start_stamp = os.date('%Y-%m-%d %H%%3A%M%%3A%S', tonumber(start_epoch));
		end_stamp = os.date('%Y-%m-%d %H%%3A%M%%3A%S', tonumber(end_epoch));
		duration = (end_epoch - start_epoch + 1) or 1;
		billsec = 1;
		billmsec = 1000;
		deliver_epoch = params['deliver_epoch'] or os.time(os.date("!*t"));
		deliver_stamp = os.date('%Y-%m-%d %H%%3A%M%%3A%S', tonumber(deliver_epoch));
		accountcode = params['accountcode'] or '';
		switchname = params['switchname'] or trim(api:execute("switchname", ""));
		user_context = params['user_context'] or '';
		body = params['body'] or '';
		context = params['context'] or '';
		caller_destination = params['caller_destination'] or to;
		answer = [[<?xml version="1.0"?>
<cdr core-uuid="b658d05e-c42c-11e3-bdcd-65b6c3cdac7d" switchname="]] .. switchname .. [[">
  <channel_data>
    <state>CS_REPORTING</state>
    <direction>]] .. direction .. [[</direction>
    <state_number>11</state_number>
    <flags>0=1;37=1;39=1;73=1</flags>
    <caps>1=1;2=1;3=1;4=1;5=1;6=1</caps>
  </channel_data>
  <variables>
    <direction>]] .. direction .. [[</direction>
    <call_direction>]] .. direction .. [[</call_direction>
    <uuid>]] .. uuid .. [[</uuid>
    <session_id>1600</session_id>
    <sip_from_user>]] .. from .. [[</sip_from_user>
    <sip_from_uri>]] .. from .. [[%40XX.XX.XXX.XXX</sip_from_uri>
    <sip_from_host>XX.XX.XXX.XXX</sip_from_host>
    <hangup_cause>NORMAL_CLEARING</hangup_cause>
    <hangup_cause_q850>16</hangup_cause_q850>
    <start_epoch>]] .. start_epoch .. [[</start_epoch>
    <start_uepoch>]] .. start_epoch ..[[000000</start_uepoch>
    <start_stamp>]] .. start_stamp .. [[</start_stamp>
    <profile_start_stamp>]] .. start_stamp .. [[</profile_start_stamp>
    <profile_start_epoch>]] .. start_epoch .. [[</profile_start_epoch>
    <profile_start_uepoch>]] .. start_epoch .. [[000000</profile_start_uepoch>
    <answer_epoch>]] .. deliver_epoch .. [[</answer_epoch>
    <answer_uepoch>]] .. deliver_epoch .. [[000000</answer_uepoch>
    <answer_stamp>]] .. deliver_stamp .. [[</answer_stamp>
    <end_stamp>]] .. end_stamp .. [[</end_stamp>
    <end_epoch>]] .. end_epoch .. [[</end_epoch>
    <end_uepoch>]] .. end_epoch .. [[000000</end_uepoch>
    <duration>]] .. duration .. [[</duration>
    <billsec>]] .. billsec .. [[</billsec>
    <billmsec>]] .. billmsec .. [[</billmsec>
    <extension_uuid>]] .. extension_uuid .. [[</extension_uuid>
    <caller_id_number>]] .. from .. [[</caller_id_number>
    <last_sent_callee_id_number>]] .. to .. [[</last_sent_callee_id_number>
    <effective_caller_id_number>]] .. from .. [[</effective_caller_id_number>
    <caller_destination>]] .. caller_destination .. [[</caller_destination>
    <domain_name>]] .. domain_name .. [[</domain_name>
    <domain_uuid>]] .. domain_uuid .. [[</domain_uuid>
    <accountcode>]] .. accountcode .. [[</accountcode>
    <user_context>]] .. user_context .. [[</user_context>
    <context>]] .. context .. [[</context>
    <message>]] .. body .. [[</message>
    <leg>a</leg>
]];
		if (variables ~= nil) then
			if (type(variables) == 'table') then
				for i,v in ipairs(variables) do
					freeswitch.consoleLog("notice", "[sms] Adding #" .. i .. " " .. v .."\n");
					var_name = string.match(v,'(.+)=');
					var_value = string.match(v,'=(.+)');
					freeswitch.consoleLog("notice", "[sms] Detected " .. var_name .. " = " .. var_value .."\n");
					answer = answer .. [[<]] .. var_name .. [[>]] .. var_value .. [[</]] .. var_name .. [[>
]];
				end
			else
				freeswitch.consoleLog("notice", "[sms] Skipping, variables is not NIL but not a Table\n");
			end
		else
			freeswitch.consoleLog("notice", "[sms] Skipping, variables is NIL\n");
		end
		answer = answer .. [[
  </variables>
  <callflow>
    <times>
      <created_time>]] .. start_epoch .. [[</created_time>
      <answered_time>]] .. deliver_epoch .. [[</answered_time>
      <hangup_time>]] .. end_epoch .. [[</hangup_time>
    </times>
    <caller_profile>
      <context>]] .. context .. [[</context>
      <username>]] .. from .. [[</username>
      <dialplan>XML</dialplan>
      <caller_id_name></caller_id_name>
      <caller_id_number>]] .. from .. [[</caller_id_number>
      <callee_id_name></callee_id_name>
      <callee_id_number></callee_id_number>
      <ani>]] .. from .. [[</ani>
      <aniii></aniii>
      <network_addr></network_addr>
      <rdnis></rdnis>
      <destination_number>]] .. to .. [[</destination_number>
      <uuid>]] .. uuid .. [[</uuid>
      <source>mod_sms</source>
      <chan_name></chan_name>
    </caller_profile>
  </callflow>
</cdr>]];

		return answer;
	end
--get the argv values
	script_name = argv[0];
	direction = argv[2];
	deliver_stamp = nil;
	
	if (debug["info"]) then
		freeswitch.consoleLog("notice", "[sms] DIRECTION: " .. direction .. "\n");
		freeswitch.consoleLog("info", "chat console\n");
	end
	
	if direction == "inbound" then
		to = argv[3];
		from = argv[4];
		body = argv[5];
		mailsent = tonumber(argv[6]) or 0;
		final = tonumber(argv[7]) or 0;
		original_to = argv[8] or '';
	
		domain_name = string.match(to,'%@+(.+)');
--		extension = string.match(to,'%d+');
		extension = string.match(to,'^[%w.]+');
		if (body ~= nil) then
			body = urldecode2(body);
		end
		savebody = body;
		body = body:gsub('<br>','\n');
		
		if (debug["info"]) then
			freeswitch.consoleLog("notice", "[sms] TO: " .. to .. "\n");
			freeswitch.consoleLog("notice", "[sms] Extension: " .. extension .. "\n");
			freeswitch.consoleLog("notice", "[sms] FROM: " .. from .. "\n");
			freeswitch.consoleLog("notice", "[sms] BODY: " .. body .. "\n");
			freeswitch.consoleLog("notice", "[sms] DOMAIN_NAME: " .. domain_name .. "\n");
			if (mailsent == nil) then
				freeswitch.consoleLog("notice", "[sms] MAILSENT (already): nil\n");
			else
				freeswitch.consoleLog("notice", "[sms] MAILSENT (already): " .. mailsent .. "\n");
			end
			freeswitch.consoleLog("notice", "[sms] ORIGINAL_TO: " .. original_to .. "\n");
			freeswitch.consoleLog("notice", "[sms] FINAL: " .. final .. "\n");
			freeswitch.consoleLog("notice", "[sms] USE_FS_PATH: " .. tostring(USE_FS_PATH) .. "\n");
			freeswitch.consoleLog("notice", "[sms] SMS_BROADCAST: " .. tostring(SMS_BROADCAST) .. "\n");
				
		end

		is_local_user = true;
		database_hostnames = {};
		if (USE_FS_PATH and final == 0) then
			is_local_user = false;
			dbh_switch = Database.new('switch');
			if (SMS_BROADCAST) then
				sql = "SELECT DISTINCT hostname FROM registrations";
				params = {};
				if (debug["sql"]) then
					freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "\n");
				end
			else
				require "resources.functions.trim";
				local_hostname = trim(api:execute("switchname", ""));
				freeswitch.consoleLog("notice", "[sms] local_hostname is " .. local_hostname .. "\n");

				sql = "SELECT hostname FROM registrations WHERE reg_user = :reg_user AND realm = :domain_name ";
				params = {reg_user=extension, domain_name=domain_name};
				if (database["type"] == "mysql") then
					params.now = os.time();
					sql = sql .. "AND expires > :now ";
				else
					sql = sql .. "AND to_timestamp(expires) > NOW()";
				end
				if (debug["sql"]) then
					freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
				end
			end

			dbh_switch:query(sql, params, function(row)
				database_hostname = row["hostname"];	-- Last hostname
				if  database_hostname ~= nil then
					freeswitch.consoleLog("notice", "[sms] database_hostname is " .. database_hostname .. "\n");
					table.insert(database_hostnames, database_hostname)
				end
			end);

			freeswitch.consoleLog("notice", '[sms] #database_hostnames = '..#database_hostnames);
			if (#database_hostnames == 0) then
				USE_FS_PATH = false;
			elseif (#database_hostnames == 1) and (local_hostname == database_hostname) then		-- TODO: review this logic
				freeswitch.consoleLog("notice", "[sms] local_host and database_host are the same\n");
				is_local_user = true;
			end
			dbh_switch:release();
		end

		if (domain_uuid == nil) then
			--get the domain_uuid using the domain name required for multi-tenant
			if (domain_name ~= nil) then
				sql = "SELECT domain_uuid FROM v_domains ";
				sql = sql .. "WHERE domain_name = :domain_name and domain_enabled = 'true' ";
				local params = {domain_name = domain_name}

				if (debug["sql"]) then
					freeswitch.consoleLog("notice", "[sms] SQL: "..sql.."; params:" .. json.encode(params) .. "\n");
				end
				status = dbh:query(sql, params, function(rows)
					domain_uuid = rows["domain_uuid"];
				end);
			end
		end

		freeswitch.consoleLog("notice", "[sms] is_local_user: " .. tostring(is_local_user) .. "\n");

		if (domain_uuid ~= nil) then
			require "resources.functions.settings";
			if (type(settings) ~= 'table') then
				freeswitch.consoleLog("notice", "[sms] getting default settings for ".. domain_uuid);
				settings = settings(domain_uuid);	-- TODO: find a fix attempt to call global 'settings' (a table value)			
			else
				freeswitch.consoleLog("notice", "[sms] no need to continue");
				return;
			end
		end

		if (is_local_user) then
			local send = true;

			accountcode = api:executeString('user_data ' .. extension .. '@' .. domain_name .. ' var accountcode');
			user_context = api:executeString('user_data ' .. extension .. '@' .. domain_name .. ' var user_context');
			freeswitch.consoleLog("NOTICE", "[sms] accountcode: " .. accountcode .. "\n");
			freeswitch.consoleLog("NOTICE", "[sms] user_context: " .. user_context .. "\n");

			--See if target ext is registered.
			extension_status = "sofia_contact " .. to;
			reply = api:executeString(extension_status);
			--freeswitch.consoleLog("NOTICE", "[sms] Ext status: "..reply .. "\n");
			if (reply == "error/user_not_registered") then
				freeswitch.consoleLog("NOTICE", "[sms] Target extension "..to.." is not registered, not sending via SIMPLE.\n");
				send = false;
			end

			if (send) then
				local sofia_lines =  api:executeString('sofia status profile internal user '..to);
				local l  = split(sofia_lines,"\n",true);
				local total_registrations = 0;
				local total_passive_registrations = 0;
				for i,v in ipairs(l) do
					freeswitch.consoleLog("notice", "[sms] "..v);
					-- Agent:
					_, _, agent = v:find('Agent:%s+(.+)');
					if (agent ~= nil) then
						freeswitch.consoleLog("notice", "[sms] Agent found:"..agent);
						-- TODO: find a better way to push it
--						if (agent == 'SessionPush 1.2') then
--							total_passive_registrations = total_passive_registrations + 1;
--						end
						if settings['sms']['passive_user_agents'] ~= nil then
							for ii, aa in ipairs(settings['sms']['passive_user_agents']) do
								if (agent == aa) then
									total_passive_registrations = total_passive_registrations + 1;
								end
							end
						end
					end
					_, _, total = v:find('Total items returned:%s+(%d+)');
					if (total ~= nil) then
						total_registrations = total;
					end
				end
				freeswitch.consoleLog("notice", "[sms] total registrations:"..total_registrations);
				freeswitch.consoleLog("notice", "[sms] total passive registrations:"..total_passive_registrations);

				if total_registrations == total_passive_registrations then
					-- there is no active registration
					send = false;
				end
			end
			if (send) then
				local event = freeswitch.Event("CUSTOM", "SMS::SEND_MESSAGE");
				event:addHeader("proto", "sip");
				event:addHeader("dest_proto", "sip");
				event:addHeader("from", "sip:" .. from);
				event:addHeader("from_user", from);
				event:addHeader("from_host", domain_name);
				event:addHeader("from_full", "sip:" .. from .."@".. domain_name);
				event:addHeader("sip_profile","internal");
				event:addHeader("to", to);
				event:addHeader("to_user", extension);
				event:addHeader("to_host", domain_name);
				event:addHeader("subject", "SIMPLE MESSAGE");
				event:addHeader("type", "text/plain");
				event:addHeader("hint", "the hint");
				event:addHeader("replying", "true");
				event:addHeader("DP_MATCH", to);
				event:addBody(body);

				if (debug["info"]) then
					freeswitch.consoleLog("info", event:serialize() .. "\n");
				end
				event:fire();
				deliver_stamp = os.date("%Y-%m-%d %H:%M:%S");
				final = 1;
			end
			to = extension;

			if (mailsent == 0) then
				--Send inbound SMS via email delivery 
				-- This is legacy code retained for backwards compatibility.  See /var/www/fusionpbx/app/sms/sms_email.php for current.
				if (domain_uuid == nil) then
					--get the domain_uuid using the domain name required for multi-tenant
						if (domain_name ~= nil) then
							sql = "SELECT domain_uuid FROM v_domains ";
							sql = sql .. "WHERE domain_name = :domain_name and domain_enabled = 'true' ";
							local params = {domain_name = domain_name}

							if (debug["sql"]) then
								freeswitch.consoleLog("notice", "[sms] SQL: "..sql.."; params:" .. json.encode(params) .. "\n");
							end
							status = dbh:query(sql, params, function(rows)
								domain_uuid = rows["domain_uuid"];
							end);
						end
				end
				if (domain_uuid == nil) then
					freeswitch.consoleLog("notice", "[sms] domain_uuid is nil, cannot send sms to email.");
				else
--					sql = "SELECT v_contact_emails.email_address ";
--					sql = sql .. "from v_extensions, v_extension_users, v_users, v_contact_emails ";
--					sql = sql .. "where v_extensions.extension = :toext and v_extensions.domain_uuid = :domain_uuid and v_extensions.extension_uuid = v_extension_users.extension_uuid ";
--					sql = sql .. "and v_extension_users.user_uuid = v_users.user_uuid and v_users.contact_uuid = v_contact_emails.contact_uuid ";
--					sql = sql .. "and (v_contact_emails.email_label = 'sms' or v_contact_emails.email_label = 'SMS')";
				
					toext2 = string.match(original_to,'%d+');
					sql = "SELECT email as email_address FROM v_sms_destinations WHERE (destination = :toext OR destination = :toext2) and domain_uuid = :domain_uuid";
			
					local params = {toext = extension, domain_uuid = domain_uuid, toext2 = toext2}

					if (debug["sql"]) then
						freeswitch.consoleLog("notice", "[sms] SQL: "..sql.."; params:" .. json.encode(params) .. "\n");
					end
					status = dbh:query(sql, params, function(rows)
						send_to_email_address = rows["email_address"];
					end);

					send_from_email_address = 'noreply@example.com'  -- this gets overridden if using v_mailto.php

					if (send_to_email_address ~= nil and send_from_email_address ~= nil) then
						subject = 'Text Message from: ' .. from;
						emailbody = 'To: ' .. to .. '<br>Msg:' .. body;
						if (debug["info"]) then
							freeswitch.consoleLog("info", emailbody);
						end
						--luarun email.lua send_to_email_address send_from_email_address '' subject emailbody;
						--replace the &#39 with a single quote
							emailbody = emailbody:gsub("&#39;", "'");

						--replace the &#34 with double quote
							emailbody = emailbody:gsub("&#34;", [["]]);

						--send the email
							freeswitch.email(send_to_email_address,
								send_from_email_address,
								"To: "..send_to_email_address.."\nFrom: "..send_from_email_address.."\nX-Headers: \nSubject: "..subject,
								emailbody
								);
					end
				end 
			end
		else
			freeswitch.consoleLog("notice", "[sms] Forwarding to the right server(s) using HTTP\n");
			--forward to the right server using HTTP
			for i,v in ipairs(database_hostnames) do
--				local url = http_protocol.."://"..v..project_path..'/app/sms/hook/sms_hook_internal.php';
				local url = "https://"..v..project_path..'/app/sms/hook/sms_hook_internal.php';
				local payload = {from=from, to=original_to, body=urlencode2(body)};	-- we use to to find the right server, but we need to pass the original destination tho
				local json_payload = json.encode(payload);
				local sms_cmd = "curl -k -H \"Content-Type: application/json\" -X POST -d '"..json_payload.."' "..url;
				freeswitch.consoleLog("notice", "[sms] url: "..url);
				freeswitch.consoleLog("notice", "[sms] json_payload: "..json_payload);
				freeswitch.consoleLog("notice", "[sms] sms_cmd: "..sms_cmd);
				local result = api:executeString("system "..sms_cmd);
				if (debug["info"]) then
					freeswitch.consoleLog("notice", "[sms] CURL Returns: " .. result .. "\n");
				end
			end
		end
	elseif direction == "outbound" then
		if (argv[3] ~= nil) then
			to_user = argv[3];
			to_user = to_user:gsub("^+?sip%%3A%%40","");
			to = string.match(to_user,'%d+');
		else 
			to = message:getHeader("to_user");
			to = to:gsub("^+?sip%%3A%%40","");
		end
		if (argv[3] ~= nil) then
			domain_name = string.match(to_user,'%@+(.+)');
		else
			domain_name = message:getHeader("from_host");
		end
		if (argv[4] ~= nil) then
			from = argv[4];
		else
			from = message:getHeader("from_user");
		end
		extension = string.match(from,'%d+');
		if extension:len() > 7 then
			outbound_caller_id_number = extension;
		end 
		if (argv[5] ~= nil) then
			body = argv[5];
		else
			body = message:getBody();
		end
		if (debug["info"]) then
			freeswitch.consoleLog("notice", "[sms] BODY-raw: " .. body .. "\n");
		end
		mailsent = argv[6] or 0;
		final = argv[7] or 0;
		--Clean body up for Groundwire send
		smsraw = body;
		smstempst, smstempend = string.find(smsraw, 'Content%-length:');
		if (smstempend == nil) then
			body = smsraw;
		else
			smst2st, smst2end = string.find(smsraw, '\r\n\r\n', smstempend);
			if (smst2end == nil) then
				body = smsraw;
			else
				body = string.sub(smsraw, smst2end + 1);
			end
		end
		body = body:gsub('%"','');
		savebody = body;
		body = encodeString((body));
		body = body:gsub('\n','\\n');

		accountcode = api:executeString('user_data ' .. from .. '@' .. domain_name .. ' var accountcode');
		user_context = api:executeString('user_data ' .. from .. '@' .. domain_name .. ' var user_context');
		freeswitch.consoleLog("NOTICE", "[sms] accountcode: " .. accountcode .. "\n");
		freeswitch.consoleLog("NOTICE", "[sms] user_context: " .. user_context .. "\n");

		if (debug["info"]) then
			if (message ~= nil) then
				freeswitch.consoleLog("info", message:serialize());
			end
			freeswitch.consoleLog("notice", "[sms] DIRECTION: " .. direction .. "\n");
			freeswitch.consoleLog("notice", "[sms] TO: " .. to .. "\n");
			freeswitch.consoleLog("notice", "[sms] FROM: " .. from .. "\n");
			freeswitch.consoleLog("notice", "[sms] BODY: " .. body .. "\n");
			freeswitch.consoleLog("notice", "[sms] DOMAIN_NAME: " .. domain_name .. "\n");
		end
		
		if (domain_uuid == nil) then
			--get the domain_uuid using the domain name required for multi-tenant
				if (domain_name ~= nil) then
					sql = "SELECT domain_uuid FROM v_domains ";
					sql = sql .. "WHERE domain_name = :domain_name and domain_enabled = 'true' ";
					local params = {domain_name = domain_name}

					if (debug["sql"]) then
						freeswitch.consoleLog("notice", "[sms] SQL: "..sql.."; params:" .. json.encode(params) .. "\n");
					end
					status = dbh:query(sql, params, function(rows)
						domain_uuid = rows["domain_uuid"];
					end);
				end
		end
		freeswitch.consoleLog("notice", "[sms] DOMAIN_UUID: " .. domain_uuid .. "\n");

		if (outbound_caller_id_number == nil) then
			freeswitch.consoleLog("notice", "[sms] outbound_caller_id_number is nil\n");
			--get the outbound_caller_id_number using the domain_uuid and the extension number
				if (domain_uuid ~= nil) then
					sql = "SELECT outbound_caller_id_number, extension_uuid, carrier FROM v_extensions ";
					sql = sql .. ", v_sms_destinations ";
					sql = sql .. "WHERE outbound_caller_id_number = destination and  ";
					sql = sql .. "v_extensions.domain_uuid = :domain_uuid and extension = :from and ";
					sql = sql .. "v_sms_destinations.enabled = 'true' and ";
					sql = sql .. "v_extensions.enabled = 'true'";
					local params = {domain_uuid = domain_uuid, from = from}

					if (debug["sql"]) then
						freeswitch.consoleLog("notice", "[sms] SQL: "..sql.."; params:" .. json.encode(params) .. "\n");
					end
					status = dbh:query(sql, params, function(rows)
						outbound_caller_id_number = rows["outbound_caller_id_number"];
						extension_uuid = rows["extension_uuid"];
						carrier = rows["carrier"];
					end);
				end
		elseif (outbound_caller_id_number ~= nil) then
			freeswitch.consoleLog("notice", "[sms] outbound_caller_id_number is [" .. outbound_caller_id_number .. "]\n");
			--get the outbound_caller_id_number using the domain_uuid and the extension number
				if (domain_uuid ~= nil) then
					sql = "SELECT extension_uuid, carrier FROM  ";
					sql = sql .. " v_sms_destinations, v_extensions ";
					sql = sql .. "WHERE outbound_caller_id_number = destination AND outbound_caller_id_number = :from and ";
					sql = sql .. "v_sms_destinations.domain_uuid = :domain_uuid and ";
					sql = sql .. "v_sms_destinations.enabled = 'true'";
					local params = {from = from, domain_uuid = domain_uuid};

					if (debug["sql"]) then
						freeswitch.consoleLog("notice", "[sms] SQL: "..sql.."; params:" .. json.encode(params) .. "\n");
					end
					status = dbh:query(sql, params, function(rows)
						carrier = rows["carrier"];
						extension_uuid = rows["extension_uuid"];
					end);
				end
		end

		freeswitch.consoleLog("notice", "[sms] carrier: " .. carrier .. "\n");		
		--get settings 
		require "resources.functions.settings";
		if (type(settings) ~= 'table') then
			settings = settings(domain_uuid);	-- TODO: find a fix attempt to call global 'settings' (a table value)
		else
			return;
		end
		if (settings['sms'] ~= nil) then
			if (settings['sms']['outbound_delivery_method'] ~= nil) then
				if (settings['sms']['outbound_delivery_method']['text'] ~= nil) then
					outbound_delivery_method = settings['sms']['outbound_delivery_method']['text'] or 'direct';
				end
			end
			if (settings['sms'][carrier..'_access_key'] ~= nil) then
				access_key = settings['sms'][carrier..'_access_key']['text']
			end
			if (settings['sms'][carrier..'_secret_key'] ~= nil) then
				if (settings['sms'][carrier..'_secret_key']['text'] ~= nil) then
					secret_key = settings['sms'][carrier..'_secret_key']['text']
				end
			end
			if (settings['sms'][carrier..'_api_url'] ~= nil) then
				if (settings['sms'][carrier..'_api_url']['text'] ~= nil) then
					api_url = settings['sms'][carrier..'_api_url']['text']
				end
			end
			if (settings['sms'][carrier..'_username'] ~= nil) then
				if (settings['sms'][carrier..'_username']['text'] ~= nil) then
					username = settings['sms'][carrier..'_username']['text']
				end
			end
			if (settings['sms'][carrier..'_delivery_status_webhook_url'] ~= nil) then
				if (settings['sms'][carrier..'_delivery_status_webhook_url']['text'] ~= nil) then
					delivery_status_webhook_url = settings['sms'][carrier..'_delivery_status_webhook_url']['text']
				end
			end
		end
		if (debug["info"]) then
			if (access_key ~= nil) then freeswitch.consoleLog("notice", "[sms] access_key: " .. access_key .. "\n") end;
			if (secret_key ~= nil) then freeswitch.consoleLog("notice", "[sms] secret_key: " .. secret_key .. "\n") end;
			if (api_url ~= nil) then freeswitch.consoleLog("notice", "[sms] api_url: " .. api_url .. "\n") end;
			if (username ~= nil) then freeswitch.consoleLog("notice", "[sms] username: " .. username .. "\n") end;
			if (delivery_status_webhook_url ~= nil) then freeswitch.consoleLog("notice", "[sms] delivery_status_webhook_url: " .. delivery_status_webhook_url .. "\n") end;
			if (outbound_delivery_method ~= nil) then  freeswitch.consoleLog("notice", "[sms] outbound_delivery_method: " .. outbound_delivery_method .. "\n") end;
		end

		--Check for xml content or delivery status notification type
		smstempst, smstempend = string.find(body, '<%?xml');
		if (smstempst ~= nil) then freeswitch.consoleLog("notice", "[sms] smstempst = '" .. smstempst .. "\n") end;
		if (smstempend ~= nil) then freeswitch.consoleLog("notice", "[sms] smstempend = '" .. smstempend .. "\n") end;
		mdn = (smstempst ~= nil); --message delivery notification
		if (message ~= nil) then
			msgtype = message:getHeader("type");
		end;
		if (msgtype ~= nil and string.find(msgtype, "imdn") ~= nil) then mdn = true end;
		if (not mdn) then 
			-- No XML content, continue processing
			if (carrier == "flowroute") then
				cmd = "curl -u ".. access_key ..":" .. secret_key .. " -H \"Content-Type: application/json\" -X POST -d '{\"to\":\"" .. to .. "\",\"from\":\"" .. outbound_caller_id_number .."\",\"body\":\"" .. body .. "\"}' " .. api_url;
			elseif (carrier == "peerless") then	
				cmd = "curl -u" .. access_key .. ":" .. secret_key .. " -ki  https://mms1.pnwireless.net:443/partners/messageReceiving/".. access_key .."/submitMessage -H \"Content-Type: application/json\" -X POST -d '{\"from\":\"" .. outbound_caller_id_number .."\",\"recipients\":[\"+".. to .."\"],\"text\":\"" .. body .. "\"}'";
			elseif (carrier == "twilio") then
				if to:len() < 11 then
					to = "1" .. to;
				end
				if outbound_caller_id_number:len() < 11 then
					outbound_caller_id_number = "1" .. outbound_caller_id_number;
				end
			-- Can be either +1NANNNNXXXX or NANNNNXXXX
				api_url = string.gsub(api_url, "{ACCOUNTSID}",  access_key);
				cmd ="curl -X POST '" .. api_url .."' --data-urlencode 'To=+" .. to .."' --data-urlencode 'From=+" .. outbound_caller_id_number .. "' --data-urlencode 'Body=" .. body .. "' -u ".. access_key ..":" .. secret_key .. " --insecure";
			elseif (carrier == "teli") then
				cmd ="curl -X POST '" .. api_url .."' --data-urlencode 'destination=" .. to .."' --data-urlencode 'source=" .. outbound_caller_id_number .. "' --data-urlencode 'message=" .. body .. "' --data-urlencode 'token=" .. access_key .. "' --insecure";
			elseif (carrier == "plivo") then
				if to:len() <11 then
					to = "1"..to;
				end
				cmd="curl -i --user " .. access_key .. ":" .. secret_key .. " -H \"Content-Type: application/json\" -d '{\"src\": \"" .. outbound_caller_id_number .. "\",\"dst\": \"" .. to .."\", \"text\": \"" .. body .. "\"}' " .. api_url;
			elseif (carrier == "bandwidth") then
				if to:len() <11 then
					to = "1"..to;
				end
				if outbound_caller_id_number:len() < 11 then
					outbound_caller_id_number = "1" .. outbound_caller_id_number;
				end
				cmd="curl -v -X POST " .. api_url .." -u " .. access_key .. ":" .. secret_key .. " -H \"Content-type: application/json\" -d '{\"from\": \"+" .. outbound_caller_id_number .. "\", \"to\": \"+" .. to .."\", \"text\": \"" .. body .."\"}'"		
			elseif (carrier == "thinq") then
				if to:len() < 11 then
					to = "1" .. to;
				end
				if outbound_caller_id_number:len() < 11 then
					outbound_caller_id_number = "1" .. outbound_caller_id_number;
				end
				cmd = "curl -X POST '" .. api_url .."' -H \"Content-Type:multipart/form-data\"  -F 'message=" .. body .. "' -F 'to_did=" .. to .."' -F 'from_did=" .. outbound_caller_id_number .. "' -u '".. username ..":".. access_key .."'"
			elseif (carrier == "telnyx") then
				if to:len() < 11 then
					to = "1" .. to;
				end
				if outbound_caller_id_number:len() < 11 then
					outbound_caller_id_number = "1" .. outbound_caller_id_number;
				end
				cmd ="curl -X POST \"" .. api_url .."\" -H \"Content-Type: application/json\"  -H \"x-profile-secret: " .. secret_key .. "\" -d '{\"from\": \"+" .. outbound_caller_id_number .. "\", \"to\": \"+" .. to .. "\", \"body\": \"" .. body .. "\", \"delivery_status_webhook_url\": \"" .. delivery_status_webhook_url .. "\"}'";
			elseif (carrier == "bulkvs") then
				if to:len() < 11 then
					to = "1" .. to;
				end
				if outbound_caller_id_number:len() < 11 then
					outbound_caller_id_number = "1" .. outbound_caller_id_number;
				end
				cmd ="curl -X POST \"" .. api_url .."\" -H  \"Accept: application/json\" -H \"Content-Type: application/json\"  -u '" .. username .. ":" .. secret_key .. "' -d '{\"From\": \"" .. outbound_caller_id_number .. "\", \"To\": [\"" .. to .. "\"], \"Message\": \"" .. body .. "\"}'";
			elseif (carrier == "fibernetics") then
				if to:len() < 11 then
					to = "1" .. to;
				end
				if outbound_caller_id_number:len() < 11 then
					outbound_caller_id_number = "1" .. outbound_caller_id_number;
				end
				cmd ="curl \"" .. api_url .. "?password=" .. secret_key .. "&username=" .. username .. "&to=" .. to .. "&from=" .. outbound_caller_id_number .. "&coding=0&text=" .. body .. "\"";
			elseif (carrier == "382") then
				if to:len() < 11 then
					to = "1" .. to;
				end
				if outbound_caller_id_number:len() < 11 then
					outbound_caller_id_number = "1" .. outbound_caller_id_number;
				end
				cmd ="curl -X POST '" .. api_url .."' -d \"user=" .. username .. "&pass=" .. password .. "&source=" .. outbound_caller_id_number .. "&destination=" .. to .. "&message=" .. body .. "\"";                       
                        end
			if (debug["info"]) then
				freeswitch.consoleLog("notice", "[sms] CMD: " .. cmd .. "\n");
			end
			final = 1;
			if (outbound_delivery_method == nil or outbound_delivery_method == 'direct') then
				local result = api:executeString("system "..cmd);
			
				if (debug["info"]) then
					freeswitch.consoleLog("notice", "[sms] CURL Returns: " .. result .. "\n");
				end
				deliver_stamp = os.date("%Y-%m-%d %H:%M:%S");
			end
		
			if (mailsent == 0) then
				freeswitch.consoleLog("notice", "[sms] Looks like email hasn't been sent");
				--Send inbound SMS via email delivery 
				-- This is legacy code retained for backwards compatibility.  See /var/www/fusionpbx/app/sms/sms_email.php for current.
				if (domain_uuid == nil) then
					--get the domain_uuid using the domain name required for multi-tenant
						if (domain_name ~= nil) then
							sql = "SELECT domain_uuid FROM v_domains ";
							sql = sql .. "WHERE domain_name = :domain_name and domain_enabled = 'true' ";
							local params = {domain_name = domain_name}

							if (debug["sql"]) then
								freeswitch.consoleLog("notice", "[sms] SQL: "..sql.."; params:" .. json.encode(params) .. "\n");
							end
							status = dbh:query(sql, params, function(rows)
								domain_uuid = rows["domain_uuid"];
							end);
						end
				end
				if (domain_uuid == nil) then
					freeswitch.consoleLog("notice", "[sms] domain_uuid is nil, cannot send sms to email.");
				else
					sql = "SELECT v_contact_emails.email_address ";
					sql = sql .. "from v_extensions, v_extension_users, v_users, v_contact_emails ";
					sql = sql .. "where v_extensions.extension = :toext and v_extensions.domain_uuid = :domain_uuid and v_extensions.extension_uuid = v_extension_users.extension_uuid ";
					sql = sql .. "and v_extension_users.user_uuid = v_users.user_uuid and v_users.contact_uuid = v_contact_emails.contact_uuid ";
					sql = sql .. "and (v_contact_emails.email_label = 'sms' or v_contact_emails.email_label = 'SMS')";
					local params = {toext = extension, domain_uuid = domain_uuid}

					if (debug["sql"]) then
						freeswitch.consoleLog("notice", "[sms] SQL: "..sql.."; params:" .. json.encode(params) .. "\n");
					end
					status = dbh:query(sql, params, function(rows)
						send_to_email_address = rows["email_address"];
					end);


					if (send_to_email_address == nil) then
						sql = "select email from v_sms_destinations where domain_uuid = :domain_uuid AND destination = :outbound_caller_id_number";
						local params = {outbound_caller_id_number = outbound_caller_id_number, domain_uuid = domain_uuid}
						if (debug["sql"]) then
							freeswitch.consoleLog("notice", "[sms] SQL: "..sql.."; params:" .. json.encode(params) .. "\n");
						end
						status = dbh:query(sql, params, function(rows)
							send_to_email_address = rows["email"];
						end);
					end


					send_from_email_address = 'noreply@example.com'  -- this gets overridden if using v_mailto.php

					if (send_to_email_address ~= nil and send_from_email_address ~= nil) then
						subject = 'Text Message from: ' .. from .. '[' .. outbound_caller_id_number .. ']';
						body = urldecode2(body);
						emailbody = 'To: ' .. to .. '<br>Msg:' .. body;
						if (debug["info"]) then
							freeswitch.consoleLog("info", emailbody);
						end
						--luarun email.lua send_to_email_address send_from_email_address '' subject emailbody;
						--replace the &#39 with a single quote
							emailbody = emailbody:gsub("&#39;", "'");

						--replace the &#34 with double quote
							emailbody = emailbody:gsub("&#34;", [["]]);

						--send the email
							freeswitch.email(send_to_email_address,
								send_from_email_address,
								"To: "..send_to_email_address.."\nFrom: "..send_from_email_address.."\nX-Headers: \nSubject: "..subject,
								emailbody
								);
					end
				end 
			else
				freeswitch.consoleLog("notice", "[sms] Email has alraedy been sent, no need to do anything");
			end
		
		else
			-- XML content
			freeswitch.consoleLog("notice", "[sms] Body contains XML content and/or is message delivery notification, not sending\n");
		end	
--		os.execute(cmd)
	end
	
--write message to the database
	if (domain_uuid == nil) then
		--get the domain_uuid using the domain name required for multi-tenant
			if (domain_name ~= nil) then
				sql = "SELECT domain_uuid FROM v_domains ";
				sql = sql .. "WHERE domain_name = :domain_name";
				local params = {domain_name = domain_name}

				if (debug["sql"]) then
					freeswitch.consoleLog("notice", "[sms] SQL DOMAIN_NAME: "..sql.."; params:" .. json.encode(params) .. "\n");
				end
				status = dbh:query(sql, params, function(rows)
					domain_uuid = rows["domain_uuid"];
				end);
			end
	end

	if (domain_uuid ~= nil) then
		freeswitch.consoleLog("notice", "[sms] domain_uuid:" .. domain_uuid .. "\n");
	else
		freeswitch.consoleLog("notice", "[sms] domain_uuid is null\n");
	end

	if (extension_uuid == nil) then
		--get the extension_uuid using the domain_uuid and the extension number
			if (domain_uuid ~= nil and extension ~= nil) then
				sql = "SELECT extension_uuid FROM v_extensions ";
				sql = sql .. "WHERE domain_uuid = :domain_uuid and extension = :extension";
				local params = {domain_uuid = domain_uuid, extension = extension}

				if (debug["sql"]) then
					freeswitch.consoleLog("notice", "[sms] SQL EXTENSION: "..sql.."; params:" .. json.encode(params) .. "\n");
				end
				status = dbh:query(sql, params, function(rows)
					extension_uuid = rows["extension_uuid"];
					if (debug["sql"]) then
						freeswitch.consoleLog("notice", "[sms] Found extension UUID: " .. extension_uuid .. "\n");
					end
				end);
			end
	else
		freeswitch.consoleLog("notice", "[sms] Extension UUID: " .. extension_uuid .. "\n");
	end
	if (carrier == nil) then
		carrier = '';
	end

	freeswitch.consoleLog("notice", "[sms] extension_uuid: " .. extension_uuid .. "\n");
	freeswitch.consoleLog("notice", "[sms] final: " .. final .. "\n");
	if (extension_uuid ~= nil and tonumber(final) == 1) then
		end_epoch = os.time(os.date("!*t"));
		sql = "insert into v_sms_messages";

		if deliver_stamp ~= nil then
			sql = sql .. "(sms_message_uuid,extension_uuid,domain_uuid,start_stamp,from_number,to_number,message,direction,response,carrier,deliver_stamp)";
			sql = sql .. " values (:uuid,:extension_uuid,:domain_uuid,now(),:from,:to,:body,:direction,'',:carrier,:deliver_stamp)";
			params = {uuid = uuid(), extension_uuid = extension_uuid, domain_uuid = domain_uuid, from = from, to = to, body = savebody, direction = direction, carrier = carrier, deliver_stamp = deliver_stamp }
		else
			sql = sql .. "(sms_message_uuid,extension_uuid,domain_uuid,start_stamp,from_number,to_number,message,direction,response,carrier,deliver_stamp)";
			sql = sql .. " values (:uuid,:extension_uuid,:domain_uuid,now(),:from,:to,:body,:direction,'',:carrier, NULL)";
			params = {uuid = uuid(), extension_uuid = extension_uuid, domain_uuid = domain_uuid, from = from, to = to, body = savebody, direction = direction, carrier = carrier}
		end

		if (debug["sql"]) then
			freeswitch.consoleLog("notice", "[sms] SQL: "..sql.."; params:" .. json.encode(params) .. "\n");
		end
		dbh:query(sql,params);

		params['domain_name'] = domain_name;
		if message ~= nil then
			params['core_uuid'] = message:getHeader("Core-UUID") or uuid();
		params['context'] = message:getHeader("context");
		else
			params['core_uuid'] = uuid();
			params['context'] = 'public';
		end
		params['start_epoch'] = start_epoch;
		params['end_epoch'] = end_epoch;
		params['accountcode'] = accountcode;
		params['switchname'] = trim(api:execute("switchname", ""));
		params['user_context'] = user_context;
		params['caller_destination'] = original_to;
		variables = settings['sms']['variables'];
		xml = build_xml_string(params, variables);
		freeswitch.consoleLog("notice", "[sms] xml: " .. xml .. "\n");
		curl_cmd = "curl -v -X POST \"http://127.0.0.1/app/enhanced-cdr-importer/xml_cdr_import.php?record_type=text&uuid=a_" .. params['core_uuid'] .. "\" --data 'cdr="..xml.."'  -u '3OjcDkwGSoHP1S9hHJxFh980nLU:y4h5Mbv5uLioHoq5qSQzdNpbZi8'  -H 'Expect:'";
		freeswitch.consoleLog("notice", "[sms] curl_cmd: " .. curl_cmd .. "\n");
		result = api:execute('system', curl_cmd);
		freeswitch.consoleLog("notice", "[sms] result: " .. result .. "\n");
	else
		freeswitch.consoleLog("notice", "[sms] no pushing into xml handler\n");
	end
