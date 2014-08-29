-- Utility functions --
local function string_explode(str)
	local result = {}
	for s in str:gmatch("%S+") do
		table.insert(result, s)
	end
	return result
end
-- ================= --

return {
    senders = {
		NOTICE = function(self, target, msg)
			return ("NOTICE %s :%s"):format(target, msg)
		end,

		PRIVMSG = function(self, target, msg)
			return ("PRIVMSG %s :%s"):format(target, msg)
		end,

		CTCP = function(self, target, command, params)
			return self:translate("PRIVMSG", target, ("\001%s %s\001"):format(command, params))
		end,

		ACTION = function(self, target, action)
			return self:translate("CTCP", target, "ACTION", action)
		end
    },

    handlers = {
		NOTICE = function(self, sender, params)
			local target = params[1]
			local msg = params[2]
			local pm = not target:find("[#&]")
			local origin = pm and sender[1] or target

			if msg:find("\001") == 1 then
				return self:handle("CTCP", sender, origin, msg, pm)
			else
				return sender, origin, msg, pm
			end
		end,

		PRIVMSG = function(self, sender, params)
			local target = params[1]
			local msg = params[2]
			local pm = not target:find("[#&]")
			local origin = pm and sender[1] or target

			if msg:find("\001") == 1 then
				-- Chain CTCP handler. PRIVMSG callback won't be called
				-- since the PRIVMSG handler (this function) isn't returning
				-- anything.
				self:handle("CTCP", sender, origin, msg, pm)
			else
				return sender, origin, msg, pm
			end
		end,

		CTCP = function(self, sender, origin, msg, pm)
			local params = string_explode(msg:gsub("\001", ""))

			local command = params[1]
			table.remove(params, 1)

			if command == "ACTION" then
				local action = table.concat(params, " ")
				self:handle("ACTION", sender, origin, action, pm)
			else
				return sender, origin, command, params, pm
			end
		end,

		ACTION = function(self, sender, origin, action, pm)
			return sender, origin, action, pm
		end
    }
}
