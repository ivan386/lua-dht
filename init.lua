-- init.lua for the LuaDHT service
return {
	tracelevel = 0,			-- Framework trace level
	name = "LuaDHT",	-- Service name for SCM
	script = "lua/dht.lua",	-- Script that runs the service
}