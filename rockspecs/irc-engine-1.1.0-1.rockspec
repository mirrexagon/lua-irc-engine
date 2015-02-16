package = "irc-engine"
version = "1.1.0-1"

source = {
	url = "git://github.com/legospacy/lua-irc-engine",
	tag = "v1.1.0",
}

description = {
	summary = "A Lua IRC module that tries to be minimal and extensible.",
	detailed = [[
		Lua IRC Engine is a callback-based, basic IRC "translator".
		It provides basic message parsing and a way to easily add new command
		sending and handling functions, but leaves most of the actual processing
		of command content to the host application.
	]],
	homepage = "http://github.com/legospacy/lua-irc-engine",
	license = "MIT/X11"
}

dependencies = {
	"lua >= 5.1"
}

build = {
	type = "builtin",
	modules = {
		["irc-engine"] = "irc-engine.lua",

		-- Standard modules.
		["irce.modules.base"] = "modules/base.lua",
		["irce.modules.message"] = "modules/message.lua",
		["irce.modules.channel"] = "modules/channel.lua"
	}
}
