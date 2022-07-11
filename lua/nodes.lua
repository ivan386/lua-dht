require("compact_encoding")

nodes = {ap = {}, by_id={}, id_map={}}


function getbit(number)
	if number == 0 then
		return 0, number
	elseif number > 0 then
		local bit = math.mod(number,2)
		return bit, (number-bit)/2
	else
		return nil, "number must be >= 0"
	end
end


function xor(n1, n2, hamming_distance)
	local getbit = getbit
	local n3 = 0
	local cnt = 1
	local bit1 = 0
	local bit2 = 0
	while (n1 > 0) or (n2 > 0) do
		
		bit1, n1 = getbit(n1)
		bit2, n2 = getbit(n2)
 
		if(bit1 ~= bit2) then
			n3 = n3 + cnt
		end
		
		if not hamming_distance then
			cnt = cnt * 2 
		end
	end
	
	return n3
end

function hamming_distance(n1, n2)
	return xor(n1, n2, true)
end

function table.get_by_keys(tbl, ...)
	local keys = {...}
	local value = tbl
	for i, key in ipairs(keys) do
		if type(value) == "table" then
			value = value[key]
		else
			return nil
		end
	end
	return value
end

function node_by_ip_port(ip, port)
	return table.get_by_keys(nodes.ap, ip, port)
end

function node_by_id_ip(id, ip)
	return table.get_by_keys(nodes.by_id, id, ip)
end

function add_node(id, address, port, check_fnc, ... )
	if is_blocked_port(port) then return end 
	if is_local(address) then return end
	
	local node = node_by_ip_port(address, port)
	
	if (not node) then
		node = node_by_id_ip(id, address)
	end
	
	if (not node) then
		node = { address = address, port = port, id = id, added = os.time() }
	elseif check_fnc then
		check_fnc(id, address, port, node, unpack(arg))
	end
	
	add_id_ip(node)
	add_ip_port(node)
	add_id(nodes.id_map, node.id)

	return node
end

function add_id_ip(node)
	local by_ip = nodes.by_id[node.id]
	if not by_ip then
		by_ip = {}
		nodes.by_id[node.id] = by_ip
	end
	
	by_ip[node.address] = node
end

function add_ip_port(node)
	local port_list = nodes.ap[node.address]
	
	if not port_list then
		port_list = {}
		nodes.ap[node.address] = port_list
	end
	
	if port_list[node.port] ~= node then
		port_list[node.port] = node
		nodes.count = (nodes.count or 0) + 1
		nodes.counted = false
	end
end


function add_id(list, id, index)
	index = index or 1
	local sub_list = list[id:byte(index)]
	if not sub_list then
		list[id:byte(index)] = id
	elseif type(sub_list) == "table" then
		add_id(sub_list, id, index + 1)
	elseif (type(sub_list) == "string") and not (sub_list == id) then
		local id2 = sub_list
		local new_list = {}
		list[id:byte(index)] = new_list
		for i = index + 1, #id2 do
			local id_byte = id:byte(i)
			local id2_byte = id2:byte(i)
			if id_byte == id2_byte then
				new_list[id_byte] = {}
				new_list = new_list[id_byte]
			else
				new_list[id_byte] = id
				new_list[id2_byte] = id2
				break
			end
		end
	end
end


function remove_node_id_ip(node)
	list = nodes.by_id[node.id]
	if list then
		list[node.address] = nil
		if not next(list) then nodes.by_id[node.id] = nil end
	end
end

function remove_node_ip_port(node)
	local port_list = nodes.ap[node.address]
	if port_list and (port_list[node.port] == node) then
		port_list[node.port] = nil
		nodes.count = (nodes.count or 0) - 1
		nodes.counted = false
		if not next(port_list) then
			nodes.ap[node.address] = nil
		end
	end
end

function count_nodes()
	local count = 0
	
	for ip, port_list in pairs(nodes.ap) do
		for port, node in pairs(port_list) do
			count = count + 1
		end
	end
	
	nodes.count = count
	nodes.counted = true
end

function check_node(key, node, nodes_list, node_id)
	local valid = true
	if node.id ~= node_id then
		nodes_list[key] = nil
		valid = false
	end
	
	if (not nodes.counted) and ((nodes.count or 0) <= 300)  then
		count_nodes()
	end
	
	if nodes_clear and (nodes.count > 300) 
	and (((node.last_seen or node.added) < (os.time() - 30*60)) 
		or (node.sended and node.sended.time and (node.sended.time < (os.time() - 3*60))))
	then
		remove_node_ip_port(node)
		remove_node_id_ip(node)
		valid = false
		if on_node_removed then
			on_node_removed(node)
		end
	end
	
	return valid
end

function find_close_id(id, count, check_fnc, args, list, index, k_nodes)
	count = count or 8
	index = index or 1
	k_nodes = k_nodes or {}
	list = list or nodes.id_map
	args = args or {}
	
	for i = 0, 255 do
		local byte = xor(id:byte(index), i)
		local el = list[byte]
		if type(el) == "table" then
			_, list[byte] = find_close_id( id, count, check_fnc, args, el, index + 1, k_nodes)
		elseif el then
			local node_id = el
			local nodes_list = nodes.by_id[node_id]
			if nodes_list and next(nodes_list) then
				for key, node in pairs(nodes_list) do
					if check_node(key, node, nodes_list, node_id) then
						if (not check_fnc) or check_fnc(node, unpack(args)) then
							--print(b32enc(node_id), "("..#node_id..")", statistic_distance(id, node_id))
							table.insert(k_nodes, node)
						end
					end
				end
			end
			
			if (not nodes_list) or (not next(nodes_list)) then
				if nodes_list then nodes.by_id[node_id] = nil end
				list[byte] = nil
			end
			 
		end
		
		if #k_nodes >= count then break end
	end
	
	local index, el = next(list)
	if not index then
		list = nil
	elseif not next(list, index) and type(el) == "string" then
		list = el
	end
	return k_nodes, list
end

function is_local(ip)
	local ip = ipv4_array(ip)
	if ip[1] == 10 then
		return true
	elseif (ip[1] == 172) and (ip[2] >= 16) and (ip[2] <= 32) then
		return true
	elseif (ip[1] == 192) and (ip[2] == 168) then
		return true
	elseif (ip[1] == 127) then	
		return true
	end
end

function is_blocked_port(port)
	return (port < 1024) or (port > 65535)
end
