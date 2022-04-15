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
	if (debug["sql"]) then
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
	   str = string.gsub (str, "([^0-9a-zA-Z !'()*._~-])", -- locale independent
	      function (c) return string.format ("%%%02X", string.byte(c)) end)
	   str = string.gsub (str, " ", "+")
	   return str
	end

	local function urldecode2 (str)
	   str = string.gsub (str, "+", " ")
	   str = string.gsub (str, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
	   return str
	end

--get the argv values

	sms_message_uuid = argv[1];
	if (debug["info"]) then
		freeswitch.consoleLog("notice", "[sms-distpacher] sms_message_uuid: " .. sms_message_uuid .. "\n");
	end

	sql = "SELECT v_sms_messages.from_number, v_sms_messages.to_number, v_sms_messages.message, v_domains.domain_name, v_domains.domain_uuid FROM v_sms_messages INNER JOIN v_extensions USING(extension_uuid) INNER JOIN v_domains ON v_domains.domain_uuid = v_sms_messages.domain_uuid  WHERE sms_message_uuid = :sms_message_uuid";
	params = {sms_message_uuid=sms_message_uuid};
	if (debug["sql"]) then
		freeswitch.consoleLog("notice", "[sms-distpacher] SQL: "..sql.."; params:" .. json.encode(params) .. "\n");
	end

	dbh:query(sql, params, function(row)
		from = row['from_number'];
		to = row['to_number'];
		body = row['message'];
		domain_name = row['domain_name'];
		domain_uuid = row['domain_uuid'];
		extension = string.match(to,'^[%w.]+');
		if (body ~= nil) then
			body = urldecode2(body);
			body = body:gsub('<br>','\n');
		end
	end);

	if (debug["info"]) then
		freeswitch.consoleLog("notice", "[sms-distpacher] TO: " .. to .. "\n");
		freeswitch.consoleLog("notice", "[sms-distpacher] Extension: " .. extension .. "\n");
		freeswitch.consoleLog("notice", "[sms-distpacher] FROM: " .. from .. "\n");
		freeswitch.consoleLog("notice", "[sms-distpacher] BODY: " .. body .. "\n");
		freeswitch.consoleLog("notice", "[sms-distpacher] DOMAIN_NAME: " .. domain_name .. "\n");
	end

	send = true;

	--See if target ext is registered.
	extension_status = "sofia_contact " .. to .. '@' .. domain_name;
	reply = api:executeString(extension_status);
	--freeswitch.consoleLog("NOTICE", "[sms-distpacher] Ext status: "..reply .. "\n");
	if (reply == "error/user_not_registered") then
		freeswitch.consoleLog("NOTICE", "[sms-distpacher] Target extension "..to.." is not registered, not sending via SIMPLE.\n");
		send = false;
	end

	if (send) then
		local sofia_lines =  api:executeString('sofia status profile internal user '..to);
		local l  = split(sofia_lines,"\n",true);
		local total_registrations = 0;
		local total_passive_registrations = 0;
		for i,v in ipairs(l) do
			freeswitch.consoleLog("notice", "[sms-distpacher] "..v);
			-- Agent:
			_, _, agent = v:find('Agent:%s+(.+)');
			if (agent ~= nil) then
				freeswitch.consoleLog("notice", "[sms-distpacher] Agent found:"..agent);
				-- TODO: find a better way to push it
--				if (agent == 'SessionPush 1.2') then
--					total_passive_registrations = total_passive_registrations + 1;
--				end
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
		freeswitch.consoleLog("notice", "[sms-distpacher] total registrations:"..total_registrations);
		freeswitch.consoleLog("notice", "[sms-distpacher] total passive registrations:"..total_passive_registrations);
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
		event:addHeader("to", to .."@".. domain_name);
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
		--deliver_stamp = os.date("%Y-%m-%d %H:%M:%S");


		sql = "UPDATE v_sms_messages SET deliver_stamp = NOW() WHERE sms_message_uuid = :sms_message_uuid";
		params = {sms_message_uuid=sms_message_uuid};
		if (debug["sql"]) then
			freeswitch.consoleLog("notice", "[sms-distpacher] SQL: "..sql.."; params:" .. json.encode(params) .. "\n");
		end
		dbh:query(sql,params);
	end
	
