require "app.sms.resources.functions.send_outgoing";
local Database = require "resources.functions.database";
dbh = Database.new('system');

sms_message_uuid = argv[1];
if (debug["info"]) then
    freeswitch.consoleLog("notice", "[sms-distpacher] sms_message_uuid: " .. sms_message_uuid .. "\n");
end

send_outgoing(sms_message_uuid);
