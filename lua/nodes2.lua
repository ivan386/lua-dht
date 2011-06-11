require("compact_encoding")

nodes = {ap = {}, by_id={}, id_map={}}

function add_node(id, address, port, check_fnc, ... )
	if is_local(address) then return end
	
	local address_port = address..":"..port
	
	local node = nodes.ap[address_port]
	if (not node) then
		local by_address = nodes.by_id[id]
		node = by_address and by_address[address]
	end
	
	if (not node) then
		node = { address = address, port = port, id = id, added = os.time() }
		nodes.ap[address_port] = node
	else
		check_fnc(id, address, port, node, unpack(arg))
	end
	
	local by_address = nodes.by_id[node.id]
	if not by_address then
		by_address = {}
		nodes.by_id[node.id] = by_address
	end
	
	by_address[address] = node
	
	add_id(nodes.id_map, node.id)

	return node
end


function add_id(list, id, index)
	index = index or 1
	local sub_list = list[id:byte(index)]
	if not sub_list then
		list[id:byte(index)] = id:sub(index + 1)
	elseif type(sub_list) == "table" then
		add_id(sub_list, id, index + 1)
	elseif (type(sub_list) == "string") and not (sub_list == id:sub(index + 1)) then
		local new_list = {}
		list[id:byte(index)] = new_list
		local i = 1
		while i <= #sub_list do
			if id:byte(index + i) == sub_list:byte(i) then
				new_list[sub_list:byte(i)] = {}
				new_list = new_list[sub_list:byte(i)]
			else
				break
			end
			i = i + 1
		end
		
		new_list[sub_list:byte(i)] = (#sub_list < (i + 1)) or sub_list:sub(i + 1) 
		new_list[id:byte(index + i)] = (#id < (index + i + 1)) or id:sub(index + i + 1)
	end
end

function remove_id(id)

end


function remove_node_id_ip(node)
	nodes.by_id[node.id][node.address] = nil
end

function remove_node_ip_port(node)
	nodes.ap[node.address..":"..node.port] = nil
end


function find_close_id(id, count, check_fnc, args)
	count = count or 8
	args = args or {}
	local k_nodes = {}
	local k_count = 0
	
	local function check_el(byte, el, list, id_part)
		if type(el) == "table" then
			_, list[byte] = find_close_id( id, count, check_fnc, args, el, index + 1, id_part..string.char(byte), k_nodes)
		elseif el then
			local node_id = id_part..string.char(byte)..(((type(el) == "string") and el) or "")
			local nodes_list = nodes.by_id[node_id]
			if nodes_list and next(nodes_list) then
				for key, node in pairs(nodes_list) do
					if (node.id == node_id) then
						if check_fnc(node, unpack(args)) then
							--print(b32enc(node_id), "("..#node_id..")", statistic_distance(id, node_id))
							table.insert(k_nodes, node)
						end
					else
						nodes_list[key] = nil
					end
				end
			end
			
			if (not nodes_list) or (not next(nodes_list)) then
				if nodes_list then nodes.by_id[node_id] = nil end
				list[byte] = nil
			end
			 
		end
	end
	
	local function small_count(index, list, id_part)
		local id_byte = id:byte(index)
		repeat
			local byte_len = 256
			local byte_value = nil
			local byte_el = nil
			local count = 0
			for byte, sub_el in pairs(list) do
				local len = xor(id_byte, byte)
				if (cecked > len) and (len < byte_len) then
					byte_len = len
					byte_value = byte
					byte_el = sub_el
				end
				if count then
					count = count + 1
					if count > 15 then
						return false
					end
				end
			end
			count = nil
			cecked = byte_len
			if byte_el then
				check_el(byte_value, byte_el, list, id_part)
			end
		until byte_len == 256 or k_count >= count
		return true
	end
end


function find_close_id_old(id, count, check_fnc, args, list, index, id_part, k_nodes)
	count = count or 8
	index = index or 1
	id_part = id_part or ""
	
	local list = list or nodes.id_map
	args = args or {}
	

	
	function small_count()
		repeat
			local byte_len = 256
			local byte_value = nil
			local byte_el = nil
			local count = 0
			for byte, sub_el in pairs(list[byte]) do
				local len = xor(id:byte(index), byte)
				if (cecked > len) and (len < byte_len) then
					byte_len = len
					byte_value = byte
					byte_el = sub_el
				end
				if count then
					count = count + 1
					if count > 15 then
						return false
					end
				end
			end
			cecked = byte_len
			if byte_el then
				check_el(byte_value, byte_el)
			end
		until byte_len == 256 or #k_nodes >= count
		
	end
	
	
	if not small_count() then
		large_count()
	end
	


	
	if id_count[list] and (id_count[list] < 15) then
		local cecked = -1

	else
		for i = 0, 255 do
			local byte = xor(id:byte(index), i)
			local el = list[byte]
			if byte_el then
				check_el(byte_value, byte_el)
			end
			
			if #k_nodes >= count then break end
		end
	end
	
	if not next(list) then list = nil end
	return k_nodes, list
end

function check_id_list()
	for id, nodes_list in pairs(nodes.by_id) do
		for key, node in pairs(nodes_list) do
			if node.id ~= id then
				nodes_list[key] = nil
			end
		end
		if not next(nodes_list) then
			nodes.by_id[id] = nil 
			remove_id(id)
		end
	end
end

function is_local(address)
	local ip = ipv4_array(address)
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