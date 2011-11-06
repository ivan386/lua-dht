function decode_ip(data, start_index)
	local start_index = start_index or 1
	return ( data:byte(start_index).."."..data:byte(start_index+1).."."..data:byte(start_index+2).."."..data:byte(start_index+3) )
end

function decode_port(data, start_index)
	local start_index = start_index or 1
	return ( data:byte(start_index)*256 + data:byte(start_index+1) )
end

function decode_peer(data, start_index)
	local start_index = start_index or 1
	
	return decode_ip(data, start_index), decode_port(data, start_index + 4)
end

function read_ip(ip)
	return string.match(ip, "([0-9]+).([0-9]+).([0-9]+).([0-9]+)")
end

function ipv4_array(address)
	local ip = {}
	ip[1], ip[2], ip[3], ip[4] = read_ip(address)
	if ip[1] then
		ip[1], ip[2], ip[3], ip[4] = tonumber(ip[1]), tonumber(ip[2]), tonumber(ip[3]), tonumber(ip[4])
		return ip
	end
end

function encode_ipv4(ip, swap)
	local a1, a2, a3, a4 = read_ip(ip)
	if swap then
		return string.char(a4,a3,a2,a1) 
	else
		return string.char(a1,a2,a3,a4)
	end
end

function encode_port(port, le)
	local p1 = math.mod(port, 256)
	local p2 = (port - p1) / 256
	if le then p1, p2 = p2, p1 end
	return string.char(p2, p1)
end


function encode_peer_le(address, port)
	return encode_ipv4(address)..encode_port(port, true)
end

function encode_peer(address, port, le)
	return encode_ipv4(address)..encode_port(port)
end

function decode_node(data, node_index)
	node_index = node_index or 1
	local s  = (26 * node_index) - 25
	if #data < (s + 25) then return nil end
	return data:sub(s, s + 19), decode_peer(data, s+20)
end

function encode_node(node)
	return node.id..encode_peer(node.address, node.port)
end