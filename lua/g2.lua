require("socket")
require("serialize2")
require("string2")
require("compact_encoding")

--bind = socket.bind("127.0.0.1", 6754)

old_print, print = print, function(...)
	local text = table.concat(arg, "\t").."\n"
	io.stderr:write(text)
	io.stderr:flush()
	io.stdout:write(text)
	io.stdout:flush()
end

function bintonumber(binstr, big_endian)
	local number = 0 
	local n = (big_endian and #binstr) or 1
	local m = (big_endian and 1) or (-1)
	for i = 1, #binstr do
		number = number + binstr:byte(i)*(256^(m*(n - i)))
	end
	
	return number
end

function numbertobin(number, big_endian)
	local bin = ""
	while (number > 0) do
		local last = math.mod(number, 256)
		number = (number - last) / 256
		
		if big_endian then
			bin = string.char(last) .. bin
		else
			bin = bin .. string.char(last)
		end
	end
	
	return bin
end

function readheader(client)
	local control_byte = client:receive(1):byte(1)
	
	if control_byte == 0 then return false, 1 end
	
	local packet = {
		big_endian = false,
		compound_packet = false,
		name_len = 1,
		len_len = 0
	}
	
	local cnt = 0
	while (control_byte > 0) do
		local bit = math.mod(control_byte, 2)
		control_byte = (control_byte - bit)/2
		
		if bit > 0 then
			if cnt == 0 then
				return nil, 1
			elseif cnt == 1 then
				packet.big_endian = true
			elseif cnt == 2 then
				packet.compound_packet = true
			elseif cnt >= 3 and cnt <= 5 then
				packet.name_len = packet.name_len + 2^(cnt-3)
			elseif cnt >= 6 and cnt <= 7 then
				packet.len_len = packet.len_len + 2^(cnt-6)
			end
		end
		
		cnt = cnt + 1
	end
	
	packet.len = 0 
	if packet.len_len > 0 then
		local len = client:receive(packet.len_len)
		if not len then return end
		packet.len = bintonumber(len)
	end
	
	packet.name = client:receive(packet.name_len)
	
	print(packet.name, packet.len_len, packet.len)
	
	return packet, 1 + packet.len_len + packet.name_len
end

function readpacket(client)
	local packet, head_len = readheader(client)
	
	if not packet then return packet, head_len end
	
	local data_len = packet.len
	
	if (data_len > 0) and packet.compound_packet then
		packet.childs = {}
		local child_packet, child_len
		
		repeat
			child_packet, child_len = readpacket(client)
			data_len = data_len - child_len
			--print(data_len, "data_len")
			if child_packet then table.insert(packet.childs, child_packet) end
		until not (child_packet and (data_len > 0))

		if child_packet == nil then return end
	end
	
	if data_len > 0 then packet.data = client:receive(data_len) end
	
	return packet, head_len + packet.len
end

function encode_packet(packet)
	local control_byte = 0
	local buffer = new_string_builder()
	
	if packet.big_endian then
		control_byte = control_byte + 2
	end
	
	if packet.childs then
		control_byte = control_byte + 4
		for index, child in ipairs(packet.childs) do
			local data = encode_packet(child)
			assert(data)
			buffer.add(data)
		end
	end
	
	if packet.data then
		if buffer.len() > 0 then
			buffer.add("\000")
		end
		buffer.add(packet.data)
	end
	
	local bin_len = numbertobin(buffer.len(), packet.big_endian)
	local len_len = #bin_len
	assert(len_len <= 3)
	control_byte = control_byte + len_len * (2^6)
	
	assert(packet.name)
	local name_len = #(packet.name) - 1
	assert(name_len < 8)
	control_byte = control_byte + name_len * (2^3)
	
	buffer.insert(string.char(control_byte), bin_len, packet.name)
	
	return buffer.get()
end

function send_packet(client, packet)
	local data = encode_packet(packet)
	print("responce =", safestring(data))
	client:send(data)
end

function g2_main(client)
	local state = 1
	local line = ""
	
	function readline(client)
		line = client:receive("*l")
		return line
	end
	
	while readline(client) do
		print(safestring(line))
		
		if line == "" then
			if state == 1 then
					client:send([[
GNUTELLA/0.6 200 OK
Listen-IP: 127.0.0.1:6754
Remote-IP: ]]..client:getpeername().."\n".. [[
User-Agent: g2.lua 0.1
Content-Type: application/x-gnutella2
Accept: application/x-gnutella2
X-Hub: True
X-Hub-Needed: False

]])
				state = 2
			elseif state == 2 then
				local packet = readpacket(client)
				while packet do
					print(serialize(packet, "packet"))
					--print (client:getsockname())
					--print (decode_peer(encode_peer(client:getsockname())))
					if packet.name =="LNI" then
						send_packet(client,
							{
								name = "LNI",
								childs = {
									{
										big_endian = true,
										name = "NA",
										data = encode_peer_le(client:getsockname())
									},
									{
										name = "V",
										data = "G2LA"
									},
									{
										name = "GU",
										data = "g2.lua gui test1"
									},
									{
										name = "HS",
										data = "\000\000\001\000"
									}
								}
							}
						)

					elseif packet.name =="PI" then
						send_packet(client, { name = "PO" })
					elseif packet.name == "Q2" then
						local urn, dn, sz, btih
						for index, child in ipairs(packet.childs) do
							if child.name == "URN" then
								urn = child
								if child.data:sub(1,2) = "bt" then
									btih = child.data:sub(3, 23)
								end
							end
							if child.name == "DN" then
								dn = child
							end
							if child.name == "SZ" then
								sz = child
							end
						end
						if urn then
							send_packet(client, 
								{
									name = "QH2",
									data = "\001"..packet.data,
									childs = {
										{
											big_endian = true,
											name = "NA",
											data = encode_peer_le(client:getsockname())
										},
										{
											name = "GU",
											data = "g2.lua gui test1"
										},
										{
											name = "H",
											childs = {
												urn, dn, sz,
												{
													name = "URL",
													--data = "http://downloads.sourceforge.net/shareaza/Shareaza_2.5.3.0_Win32.exe"
												}
											}
										}
									}
								}
							)
						end
					end
					packet = readpacket(client)
					-- send responce
				end
			end
		end
	end
end

