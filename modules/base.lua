return {
	senders = {
		PING = function(self, param)
			return "PING :" .. param
		end,

		PONG = function(self, param)
			return "PONG :" .. param
		end,

		NICK = function(self, nick)
			return "NICK :" .. nick
		end,

		USER = function(self, username, realname, mode)
			return ("USER %s %s * :%s"):format(username, mode or 8, realname)
		end,

		QUIT = function(self, quit_message)
			if quit_message then
				return "QUIT :" .. quit_message
			else
				return "QUIT"
			end
		end
	},

	handlers = {
		PING = function(self, sender, params)
			self:send("PONG", params[1])
			return sender, params[1]
		end,

		PONG = function(self, sender, params)
			return sender, params[1]
		end,

		NICK = function(self, sender, params)
			local new_nick = params[2]
			return sender, new_nick
		end,

		QUIT = function(self, sender, params)
			local quit_message = params[1]
			return sender, quit_message
		end
	}
}
