require "app.sms.resources.functions.send_outgoing";
--connect to the database
local Database = require "resources.functions.database";
dbh = Database.new('system');

--debug
debug["info"] = true;
debug["sql"] = true;

--set the api
api = freeswitch.API();

--include json library
if (debug["sql"]) then
    json = require "resources.functions.lunajson"
end

sms_message_uuid = argv[1];
if (debug["info"]) then
    freeswitch.consoleLog("notice", "[sms-distpacher] sms_message_uuid: " .. sms_message_uuid .. "\n");
end

send_outgoing(sms_message_uuid);
