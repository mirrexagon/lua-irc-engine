--- Require ---
local util = require("irce.util")
--- ==== ---


return {
	senders = {
		PING = function(self, state, param)
			return "PING :" .. param
		end,

		PONG = function(self, state, param)
			return "PONG :" .. param
		end,

		NICK = function(self, state, nick)
			return "NICK :" .. nick
		end,

		USER = function(self, state, username, realname, mode)
			return ("USER %s %s * :%s"):format(username, mode or 8, realname)
		end,

		QUIT = function(self, state, quit_message)
			if quit_message then
				return "QUIT :" .. quit_message
			else
				return "QUIT"
			end
		end,


		MODE = function(self, state, target, modes, mode_params)
			if mode_params then
				return ("MODE %s %s %s"):format(target, modes, mode_params)
			else
				return ("MODE %s %s"):format(target, modes)
			end
		end,
	},

	handlers = {
		PING = function(self, state, sender, params)
			self:send("PONG", params[1])
			return sender, params[1]
		end,

		PONG = function(self, state, sender, params)
			return sender, params[1]
		end,

		NICK = function(self, state, sender, params)
			local new_nick = params[2]
			return sender, new_nick
		end,

		QUIT = function(self, state, sender, params)
			local quit_message = params[1]
			return sender, quit_message
		end,


		MODE = function(self, state, sender, params)
			local target = params[1]
			local mode_string = params[2]

			local operation = mode_string:sub(1, 1)
			mode_string = mode_string:sub(2)

			local modes = util.string.chars(mode_string)

			if target:find("[#&]") then
				-- Channel mode.
				local mode_params = {}
				for i = 3, #params do
					mode_params[i-2] = params[i]
				end

				-- Do the callback for each separate mode.
				for i = 1, #modes do
					self:handle("CHANNELMODE", sender, operation, modes[i], mode_params[i])
				end
			else
				-- User mode.
				-- Do the callback for each separate mode.
				for i = 1, #modes do
					self:handle("USERMODE", sender, operation, modes[i], target)
				end
			end
		end,
	}
}
