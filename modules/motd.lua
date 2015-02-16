local IRCe = require "irce"

return {
	senders = {
		["MOTD"] = function(self, state, server)
			if server then
				return "MOTD :" .. server
			else
				return "MOTD"
			end
		end;
	};

	handlers = {
		-- Start MOTD
		["375"] = function(self, state, sender, params)
			state.partial_motd = {}
			return sender, params
		end;
		-- MOTD line
		["372"] = function(self, state, sender, params)
			local motd = assert(state.partial_motd, "MOTD has not started")
			local line = params[2]:match("%- (.*)")
			table.insert(motd, line)
			return sender, line
		end;
		-- End MOTD
		["376"] = function(self, state, sender, params)
			local motd = assert(state.partial_motd, "MOTD has not started")
			state.partial_motd = nil
			motd = table.concat(motd, "\n")
			self:handle("MOTD", motd)
			return sender, params
		end;
		-- MOTD error
		["422"] = function(self, state, sender, params)
			local err = params[2]
			state.partial_motd = nil
			self:handle("MOTD", nil, err)
			return sender, params
		end;
	};

	hooks = {
		[IRCe.DISCONNECT] = function(self, state)
			state.partial_motd = nil
		end;
	};
}
