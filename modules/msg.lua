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
		end
    },

    handlers = {
		NOTICE = function(self, sender, params)
			local target = params[1]
			local msg = params[2]
			local pm = not target:find("[#&]")
			local origin = pm and sender[1] or target

			return sender, origin, msg, pm
		end,

		PRIVMSG = function(self, sender, params)
			local target = params[1]
			local msg = params[2]
			local pm = not target:find("[#&]")
			local origin = pm and sender[1] or target

			return sender, origin, msg, pm
		end,

		-- TODO: CTCP? May need to change how callbacks work.
    }
}
