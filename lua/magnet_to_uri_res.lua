require("binstd")
require("encoding")
require("settings")
local dbg = false

function dbgmsg(...)
	if dbg then
		usermsg(unpack(arg))
	end
end
function usermsg(...)
	io.stderr:write(table.concat(arg, "\t"))
end
local urn = {}

local urn_name
local hash
	
while not next(urn) do
	if not arg[1] then
		usermsg("\ninput urn or magnet, or press Enter to exit: \n")
	end
	magnet = arg[1] or io.stdin:read("*l")
	if #magnet <= 1 then os.exit(0) end
	dbgmsg("\nmagnet: ", magnet)
	
	string.gsub(magnet, "urn:([0-9A-Za-z:%./]+)",  function(urn_part)
		if string.match(urn_part, "^tree:tiger") then
			urn["tree:tiger:"] = string.match(urn_part, ":([0-9A-Za-z]+)$")
		elseif string.match(urn_part, "^bitprint:") then
			urn["sha1:"], urn["tree:tiger:"] = string.match(urn_part, ":([0-9A-Za-z]+).([0-9A-Za-z]+)$")
		elseif string.match(urn_part, "^ed2k") then
			urn["ed2k:"] = string.match(urn_part, ":([0-9A-Za-z]+)$")
		elseif string.match(urn_part, "^sha1:") then
			urn["sha1:"] = string.match(urn_part, ":([0-9A-Za-z]+)$")
		elseif string.match(urn_part, "^btih:") then
			urn["btih:"] = string.match(urn_part, ":([0-9A-Za-z]+)$")	
		end
	end)
	
	if urn["tree:tiger:"] then
		urn_name = "tree:tiger:"
		hash = urn[urn_name]
		decode = "b32dec"
	elseif urn["ed2k:"] then
		urn_name = "ed2k:"
		hash = urn[urn_name]
		decode = "hexdec"
	elseif urn["sha1:"] then
		urn_name = "sha1:"
		hash = urn[urn_name]
		decode = "b32dec"
	elseif urn["btih:"] then
		urn_name = "btih:"
		hash = urn[urn_name]
		decode = "hexdec"	
	end
	
	if not next(urn) then
		usermsg("\nurn not found; pattern: (urn:[0-9A-Za-z:%./]+)")
		arg[3] = nil
	else 
		usermsg("\nurn found: ", urn_name, hash)
	end
end

if hash then
	local cmd = {}
	table.insert(cmd, [[lua5.1 -lbinstd -lencoding -e "io.write('d'..bencode(']]..urn_name..[[')..bencode(]]..decode..[[(']]..
	hash..[['))..'8:protocol7:uri-rese')"]])
	table.insert(cmd, [[rhash -p"io.write('http://127.0.0.1:]]..port_number..[[/uri-res/N2R?urn:]]..urn_name..hash..
	[=[&info_hash='..urlhex([[%@h]]))" -]=])
	table.insert(cmd, [[lua5.1 -lbinstd -lencoding -]])
	dbgmsg(table.concat(cmd, "|"))
	os.execute(table.concat(cmd, "|"))
end
	