--- Require ---
local util = require("irce.util")
--- ==== ---


return {
	senders = {
		NOTICE = function(self, state, target, message)
			return ("NOTICE %s :%s"):format(target, message)
		end,

		PRIVMSG = function(self, state, target, message)
			return ("PRIVMSG %s :%s"):format(target, message)
		end,

		_CTCP = function(self, state, command, params)
			if params == nil then
				return ("\001%s\001"):format(command)
			end

			if type(params) == "table" then
				params = table.concat(params, " ")
			end
			return ("\001%s %s\001"):format(command, params)
		end,


		---

		CTCP = function(self, state, target, command, params)
			return self:translate("PRIVMSG", target, self:translate("_CTCP", command, params))
		end,

		CTCP_REPLY = function(self, state, target, command, params)
			return self:translate("NOTICE", target, self:translate("_CTCP", command, params))
		end,

		---

		ACTION = function(self, state, target, action)
			return self:translate("CTCP", target, "ACTION", action)
		end
	},

	handlers = {
		NOTICE = function(self, state, sender, params)
			local target = params[1]
			local message = params[2]
			local pm = not target:find("[#&]")
			local origin = pm and sender[1] or target

			if message:find("\001") == 1 then
				self:handle("CTCP", sender, origin, message, pm, true)
			else
				return sender, origin, message, pm
			end
		end,

		PRIVMSG = function(self, state, sender, params)
			local target = params[1]
			local message = params[2]
			local pm = not target:find("[#&]")
			local origin = pm and sender[1] or target

			if message:find("\001") == 1 then
				self:handle("CTCP", sender, origin, message, pm, false)
			else
				return sender, origin, message, pm
			end
		end,

		CTCP = function(self, state, sender, origin, message, pm, notice)
			local params = util.string.words(message:gsub("\001", ""))

			local command = params[1]
			table.remove(params, 1)

			if command == "ACTION" then
				local action = table.concat(params, " ")
				self:handle("ACTION", sender, origin, action, pm)
			elseif notice then
				self:handle("CTCP_REPLY", sender, origin, command, params, pm)
			else
				return sender, origin, command, params, pm
			end
		end
	}
}
