local Database = require "resources.functions.database"
--local Settings = require "resources.functions.lazy_settings"

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

function send_outgoing(sms_message_uuid)
    local dbh = Database.new('system');
  
    local sql = [[SELECT * FROM v_sms_messages WHERE direction = 'outbound' AND sms_message_uuid = :sms_message_uuid]];
    local params = {sms_message_uuid = sms_message_uuid};
  
    if (debug["sql"]) then
        freeswitch.consoleLog("notice", "[send-outgoing] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
    end
  
    dbh:query(sql, params, function(row)
        extension_uuid = row["extension_uuid"];
        domain_uuid = row["domain_uuid"];
        start_stamp = row["start_stamp"];
        from_number = row["from_number"];
        to_number = row["to_number"];
        message = row["message"];
        direction = row["direction"];
        response = row["response"];
        carrier = row["carrier"];
        deliver_stamp = row["deliver_stamp"];
    end);
  
    if (message ~= nil) then
        -- record found
        freeswitch.consoleLog("notice", "[send-outgoing]  " .. sms_message_uuid .. " found \n");
    
        require "resources.functions.settings";
        freeswitch.consoleLog("notice", "[send-outgoing]  getting settings for " .. domain_uuid .. "\n");
        settings = settings(domain_uuid);	-- TODO: find a fix attempt to call global 'settings' (a table value)
    
        if (settings['sms'] ~= nil) then
            if (settings['sms'][carrier..'_access_key'] ~= nil) then
                if (settings['sms'][carrier..'_access_key']['text'] ~= nil) then
                    access_key = settings['sms'][carrier..'_access_key']['text']
                end
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

            if (debug["info"]) then
                if (access_key ~= nil) then freeswitch.consoleLog("notice", "[sms] access_key: " .. access_key .. "\n") end;
                if (secret_key ~= nil) then freeswitch.consoleLog("notice", "[sms] secret_key: " .. secret_key .. "\n") end;
                if (api_url ~= nil) then freeswitch.consoleLog("notice", "[sms] api_url: " .. api_url .. "\n") end;
                if (username ~= nil) then freeswitch.consoleLog("notice", "[sms] username: " .. username .. "\n") end;
                if (delivery_status_webhook_url ~= nil) then freeswitch.consoleLog("notice", "[sms] delivery_status_webhook_url: " .. delivery_status_webhook_url .. "\n") end;
            end
        end
    
        if (smstempst ~= nil) then freeswitch.consoleLog("notice", "[sms] smstempst = '" .. smstempst .. "\n") end;
        if (smstempend ~= nil) then freeswitch.consoleLog("notice", "[sms] smstempend = '" .. smstempend .. "\n") end;
        mdn = (smstempst ~= nil); --message delivery notification
    
        if (not mdn) then 
            -- No XML content, continue processing
            to = to_number;
            outbound_caller_id_number = string.match(from_number,'%d+');
            body = encodeString(message);
            
            if (domain_uuid ~= nil) then
                    sql = "SELECT outbound_caller_id_number FROM v_extensions WHERE extension = :from_number and domain_uuid = :domain_uuid";
                    local params = {from_number = from_number, domain_uuid = domain_uuid};

                    if (debug["sql"]) then
                            freeswitch.consoleLog("notice", "[sms] SQL: "..sql.."; params:" .. json.encode(params) .. "\n");
                    end
                    status = dbh:query(sql, params, function(rows)
                            outbound_caller_id_number = rows["outbound_caller_id_number"];
                    end);
            end

            
            if (carrier == "flowroute") then
                cmd = "curl -u ".. access_key ..":" .. secret_key .. " -H \"Content-Type: application/json\" -X POST -d '{\"to\":\"" .. to .. "\",\"from\":\"" .. outbound_caller_id_number .."\",\"body\":\"" .. body .. "\"}' " .. api_url;
            elseif (carrier == "peerless") then	
                cmd = "curl -u" .. access_key .. ":" .. secret_key .. " -ki  https://mms1.pnwireless.net:443/partners/messageReceiving/".. access_key .."/submitMessage -H \"Content-Type: application/json\" -X POST -d '{\"from\":\"" .. outbound_caller_id_number .."\",\"recipients\":[\"+".. to .."\"],\"text\":\"" .. body .. "\"}'";
            elseif (carrier == "twilio") then
                if to:len() < 11 then   --TODO, verify if this is true
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
            end
            if (debug["info"]) then
                freeswitch.consoleLog("notice", "[send-outgoing] CMD: " .. cmd .. "\n");
            end
            local result = api:executeString("system "..cmd);
            final = 1;
            if (debug["info"]) then
                freeswitch.consoleLog("notice", "[send-outgoing] CURL Returns: " .. result .. "\n");
            end
            deliver_stamp = os.date("%Y-%m-%d %H:%M:%S");

            local sql = [[UPDATE v_sms_messages SET deliver_stamp = :deliver_stamp WHERE  sms_message_uuid = :sms_message_uuid]];
            local params = {deliver_stamp = deliver_stamp, sms_message_uuid = sms_message_uuid};
             if (debug["sql"]) then
                     freeswitch.consoleLog("notice", "[send-outgoing] SQL: "..sql.."; params:" .. json.encode(params) .. "\n");
             end
             dbh:query(sql,params);
        end
    end
end
