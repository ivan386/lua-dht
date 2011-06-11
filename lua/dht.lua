require("settings")
require("print_override")

require("socket")
require("encoding")
require("torred")
require("serialize3")
require("compact_encoding")
require("nodes")
require("http")

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

function xor(n1, n2)
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
		
		cnt = cnt * 2
	end
	
	return n3
end

function less(first_id, second_id, by_id)
	for i = 1 , 20 do
		local fl = xor(first_id:byte(i), by_id:byte(i))
		local sl = xor(second_id:byte(i), by_id:byte(i))
		if fl < sl then return true end
		if fl > sl then return false end
	end
	return false
end

function statistic_distance(id1 , id2)
	return xor(id1:byte(1), id2:byte(1)) * (256^3)  + xor(id1:byte(2), id2:byte(2)) * (256^2) + xor(id1:byte(3), id2:byte(3)) * 256 + xor(id1:byte(4), id2:byte(4))
end

function count_elements(tbl, stop)
	local index = next(tbl)
	local element = tbl[index]
	local count = 0
	while element do
		count = count + 1
		index = next(tbl, index)
		element = tbl[index]
		if stop and count >= stop then break end
	end
	return count
end

function random_part(size)
	local part = ""
	for i = 1, size do
		part = part..string.char(math.random(0, 255))
	end
	return part
end

function new_timer()
	local last_time = os.time()

	function object(time)
		if os.time() - last_time >= time then
			last_time = os.time()
			return true
		end
	end
	
	return object
end

function new_string_builder()
	local string_table = {}
	local object = {}
	
	function object.add(...)
		for idx, str in ipairs(arg) do
			table.insert(string_table, str)
		end
	end
	
	function object.get(spliter)
		spliter = spliter or ""
		return table.concat(string_table, spliter)
	end
	
	function object.empty()
		return not next(string_table)
	end
	
	return object
end


local help = {
	["a.name"]="name of torrent",
	["q"]=[=[q=[help, ping, find_node, get_peers,  announce_peer]
help - Micro help about new parameter of dht packet.
 a.path (query packet) - path to new parameter
 r.help (responce packet) - help about new parameter

more: http://forum.bittorrent.org/viewtopic.php?pid=2134

other see on http://bittorrent.org/beps/bep_0005.html]=],
	["a.path"]=[[if (query packet) and (q="help") then it path to new parameter]],
	["r.help"]=[[if (responce packet) and (q="help") then it help text about new parameter]]
}

function get_help(path)
	return help(path)
end

math.randomseed(os.time())
my_id = random_part(9).."<<< ^-^ >>>"
my_id_plus = {my_id, "\0"..my_id:sub(2,20), "\127"..my_id:sub(2,20),  "\255"..my_id:sub(2,20)}

peers = {btih={}}
torrent_info = {}
search_btih = {}
announce_btih = {}

in_packet = 0
packet_id = 0
my_ip = ""

-----------------------------------------------------------------------------
function main()
	local loader, err =  loadfile(nodes_file)
	if not loader then welcome_msg = welcome_msg.."\n"..err end
	nodes = (loader and loader()) or nodes
	local timer = new_timer()
	local save_timer = new_timer()
	local check_timer = new_timer()
	local random_timer = new_timer()
	local udp_port = socket.udp()
	udp_port:setsockname("*", port_number)
	udp_port:settimeout(1)
	
	local tcp_port = socket.bind("127.0.0.1", port_number)
	tcp_port:settimeout(0.001)
	
	function on_error()
		if udp_port then udp_port:close() end
		if tcp_port then tcp_port:close() end
	end
	
	print(welcome_msg)
	local cycle = 0
	while not ( service and service.stopping() ) do
		cycle = cycle + 1
		status_print(cycle)
		next_packet(udp_port)
		next_client(tcp_port, udp_port)
		if not service and save_timer(5*60) then
			if mgs_on then mid_print("--- save nodes ---") end
			save_nodes()
		end
		if ( in_packet > 10 ) and not nodes_clear then
			if mgs_on then mid_print("--- nodes clear on ---") end
			nodes_clear = true
		end
		if random_timer(30) then
			if mgs_on then mid_print("--- random bootstrap ---") end
			bootstrap(udp_port, random_part(20), true)
			collectgarbage()
		end
		if timer(12) then
			if mgs_on then mid_print("--- bootstrap ---") end
			bootstrap(udp_port, my_id)
			search(udp_port)
			announce(udp_port)
		end
	end
	
	mid_print("--- save nodes ---")
	save_nodes()
	udp_port:close()
	tcp_port:close()
end

function by_last_seen(node1, node2)
	return 	(node1.last_seen or node1.added) 
			< (node2.last_seen or node2.added)
end


function skip_value(tbl, key, value)
	--print(tostring(key))
	return (key == "sended") and (type(value) == "table") or
			(key == "bs_send") and (type(value) == "number") or
			(key == "last_query") and (type(value) == "table") or
			(key == "conected_to") and (type(value) == "string") or
			(key == "peer") and (type(value) == "string") or
			(key == "confirmed")
end

function save_nodes()
	local fnodes = io.open(nodes_file, "wb")
	local writer = function(data)
		fnodes:write(data)
	end
	writer("return ")
	serialize(nodes, writer, skip_value)
	--fnodes:write(serialize(nodes, "return", nil, nil, skip_value))
	fnodes:close()
end

function is_searched(check_time)
	if check_time then
		return (os.time() - check_time) <  3*60
	else
		return false
	end
end

function check_search_node(node)
	return not ( is_searched(node.gp_sended) or ( node.sended and node.sended.packet ))
end

function search(udp_port)
	for info_hash, count in pairs(search_btih) do
		if count > 0 then
			local selected_nodes = find_close_id(info_hash, 3, check_search_node)
			
			for index, node in ipairs(selected_nodes) do
				node.gp_sended = os.time()
				send_get_peers(udp_port, node, info_hash)
			end
			
			search_btih[info_hash] = count - 1
		else
			search_btih[info_hash] = nil
		end
	end
end

function check_announce_node(node, info_hash)
	return node.token[info_hash] and not ( node.sended and node.sended.packet )
end

function announce(udp_port)
	for info_hash, info in pairs( announce_btih ) do
		for node, token in pairs( info.token ) do
			send_announce(udp_port, node, info_hash, info.token[node], info.port)
			info.token[node] = nil
		end
	end
end

function get_peers(info_hash, port)
	search_btih[info_hash] = 15
	if port and port > 0 then
		if not announce_btih[info_hash] then
			announce_btih[info_hash] = { token = {} }
		end
		announce_btih[info_hash].port = port
	else
		print("port nil")
	end
	return peers.btih[info_hash]
end

function next_packet(udp_port)
	local data, address, port = udp_port:receivefrom()
	if (not data) then
		if (address ~= "timeout" and address ~= "closed") then
			print("receivefrom error: "..address)
			debug.debug()
		end
		return 
	end
	
	packet_id = packet_id + 1
	if not is_dictionary(data) then return end
	if mgs_on then status_print("from_bencode") end
	local krpc = from_bencode(data, true)
	if not krpc then return end
	if mgs_on then status_print("decoded") end
	packet_analyze(krpc)
	
	if krpc.y == "e" then
		local node = nodes.ap[address..":"..port]
		local sended = node and node.sended and node.sended.packet
		if sended and (sended.t == krpc.t) then
			node.sended.packet = nil
			node.sended.time = nil
			node.error = krpc.e
		end
		if type(krpc.e) == "table" then
			print_msg("node error:", krpc.e[1] or '', krpc.e[2] or '')
		end
		return
	end
	
	if not krpc.t then return end

	local id = (krpc.a and krpc.a.id) or (krpc.r and krpc.r.id)
	if not id then return end
	
	local node = add_node(id, address, port, add_node_check, true)
	if not node then return end
	node.last_seen = os.time()
	
	in_packet = in_packet + 1
	
	if krpc.y == "q" then -- query
		return on_query(udp_port, krpc, node)
	end
	
	local packet = node.sended and node.sended.packet
	if packet and (krpc.y == "r") and (packet.t == krpc.t) then -- responce
		node.sended.packet = nil
		node.sended.time = nil
		node.error = nil
		node.checked = os.time()
		return on_responce(krpc, packet, node)
	end
end

function check_node_bootstrap(node, no_linked)
	return (node.id ~= my_id)
		and (not (node.sended and node.sended.packet))
		and ((node.bs_send or 0) < (os.time() - 600))
		and ((not no_linked) or not node.last_seen)
end

function bootstrap(udp_port, id, no_linked)
	local selected_nodes = find_close_id(id, 4, check_node_bootstrap, {no_linked})
	
	for index, node in ipairs(selected_nodes) do
		if (not nodes.count) or (nodes.count < (500*index)) or (index == 1) then
			node.bs_send = os.time()
			send_find_node(udp_port, node, id)
		else
			send_ping(udp_port, node)
		end
	end
end

function is_checked(check_time)
	if check_time then
		return (os.time() - check_time) <  15*60
	else
		return false
	end
end

function get_node_token(node)
	return global_token.."("..encode_peer(node.address, node.port)..")"
end

function check_token(token, node)
	if mgs_on then 
		print(string.format("token:\t%s\n client: %s", 
			safe_string(token), 
			(safe_string(node.client) or ""))) 
	end
	return token == get_node_token(node)
end

function check_node_on_query(node, for_node_id)
	return (node.id ~= my_id) and (for_node_id ~= node.id) and is_checked( node.last_seen )
end

packet_analyze = (function()
	-- local const
	local top_level_keys = {y = "string", e = "table", q = "string", t = "string", a = "table", r = "table", v = "string"}
	local tables_keys = {
		y = {q = true, r = true, e = true},
		q = {ping = true, find_node = true, get_peers = true, announce_peer = true},
		a = {id = "string", target = "string", info_hash = "string", token = "string", port = "number", want = "table", scrape = "number", name = "string"},
		r = {id = "string", nodes = "string", nodes2 = "table", values = "table", token = "string", ip = "string"},
		e = {[1] = "number", [2] = "string"}
	}
	
	return function(packet)
		if not packet_analyze_on then return end
		for tlk, v in pairs(packet) do
			if top_level_keys[tlk] == type(v) then
				local keys_types = tables_keys[tlk]
				if keys_types then
					if type(v) == "table" then
						for k, v in pairs(v) do
							if keys_types[k] ~= type(v) then
								print2('found key: '..safe_string(tlk)..'.'..safe_string(k))
								serialize(packet, nb_out)
								flush()
								return
							end
						end
					elseif not keys_types[v] then
						print2('found value: '..safe_string(tlk)..' = '..safe_string(v))
						serialize(packet, nb_out)
						flush()
						return
					end
				end
			else
				print2('found top level key: '..safe_string(tlk)..' = '..safe_string(v))
				serialize(packet, nb_out)
				flush()
				return
			end
		end
	end
end)()
	
function on_query(udp_port, query, node)
	
	local id = query.a.target or query.a.info_hash or query.a.id
	if not id then return end
	
	local tid = query.t
	if not tid then return end
	
	if not node.last_query then node.last_query = {} end
	
	if query.q ~= "announce_peer" and (os.time() - (node.last_query.time or 0) < 10) then
		return
	end
	
	node.client = query.v or node.client
	if mgs_on then
		print(string.format("%s\t\t\t> query (%s): %s, %s, %s ",
			packet_id,
			query.q,
			statistic_distance(id, my_id),
			safe_string(node.client) or "",
			( (node.last_query.time and (os.time() - node.last_query.time)) or "first" )))
	end
	node.last_query.query = query.q
	node.last_query.id = id
	node.last_query.time = os.time()
	
	
	local krpc = { t = tid, y = "r", r = {} }
	
	if query.q == "ping" then
		if node.ping_responce and (os.time() - node.ping_responce < 60) then 
			if mgs_on then 
				print("last ping: "..(os.time() - node.ping_responce)) 
			end 
			return 
		end
		node.ping_responce = os.time()
		return send_krpc( udp_port, node, krpc)
	elseif query.q == "help" then
		krpc.r.help = get_help(query.a.path)
		if not krpc.r.help then
			return send_error( udp_port, node, 203, tid, "help not found" )
		end
		return send_krpc( udp_port, node, krpc )
	elseif query.q == "announce_peer" then
		if mgs_on then print(string.rep("-", 79)) end
		if check_token(query.a.token, node) then
			node.checked = os.time()
			
			add_peer(query.a.info_hash, node.address, query.a.port, node)
			
			add_info(query.a, node)
			
			if mgs_on then print(string.rep("-", 79)) end
			return send_krpc( udp_port, node, krpc )
		else
			if mgs_on then print(string.rep("-", 79)) end
			return send_error( udp_port, node, 203, tid, "wrong token" )
		end
	end
	
	-- find_node or get_peers --

	local selected_nodes = find_close_id(id, 8, check_node_on_query, {node.id})
	
	local compact_nodes = {}
	for index, node in ipairs(selected_nodes) do
		table.insert(compact_nodes, encode_node(node))
	end
	
	if next(compact_nodes) then
		krpc.r.nodes = table.concat(compact_nodes)
	else
		return send_error( udp_port, node, 201, tid, "no nodes" )
	end
	
	if query.q == "get_peers" then
		krpc.r.token = get_node_token(node)
		local peers_list = peers.btih[query.a.info_hash]
		
		if peers_list then
			krpc.r.values = {}
			local peers_count = 0
			for compact, peer in pairs(peers_list) do
				if (os.time() - peer.last_seen) > 15*60 then
					peers_list[compact] = nil
				elseif peer.announce_node then
					peers_count = peers_count + 1
					table.insert(krpc.r.values, compact)
				end
			end
			if peers_count > 0 then
				if mgs_on then print_msg("found peers:", peers_count, hexenc(id)) end
				return send_krpc( udp_port, node, krpc, "responce peers" )
			elseif not next(peers.btih[query.a.info_hash]) then
				peers.btih[query.a.info_hash] = nil
			end
		end
	end
	
	return send_krpc( udp_port, node, krpc, "responce nodes" )
end

function add_node_check(id, address, port, node, self)
	if self then
		node.confirmed = true
		node.need_to_check = nil
		if node.id ~= id then
			node.ref = nil
			node.change_id = (node.change_id or 0) + 1
			print_msg(string.format("change id (%s)\n from: %s (%s)\n to: %s (%s)\n client: %s",
						node.change_id,
						hexenc(node.id),
						statistic_distance(node.id, my_id),
						hexenc(id),
						statistic_distance(id, my_id),
						safe_string(node.client) or ""))
			remove_node_id_ip(node)
			node.id = id
		elseif node.port ~= port then
			node.ref = nil
			node.change_port = (node.change_port or 0) + 1
			print_msg(string.format("change port (%s) from %s to %s\n for %s (%s)\n client: %s",
				node.change_port, 
				node.port, 
				port, 
				hexenc(node.id), 
				statistic_distance(node.id, my_id), 
				safe_string(node.client) or ""))
						
			remove_node_ip_port(node)
			node.port = port
		end
	elseif node.id ~= id then
		local msg = "wrong"
		if not node.confirmed then
			msg = "found other"
			node.need_to_check = true
		end
		
		print_msg(string.format("%s id: %s (%s)\n for %s (%s)",
			msg,
			hexenc(id),
			statistic_distance(id, my_id),
			hexenc(node.id),
			statistic_distance(node.id, my_id)))
	elseif node.port ~= port then
		local msg = "wrong"
		if not node.confirmed then
			local msg = "found other"
			node.need_to_check = true
		end
		print_msg(string.format("%s port: %s for %s (%s)",
			msg,
			port,
			hexenc(node.id),
			statistic_distance(node.id, my_id)))
	end
	
	if not self then
		node.ref = (node.ref or 0) + 1
	end
end

function on_responce(responce, query, node)
	local id = query.a.target or query.a.info_hash
	
	if responce.v then
		node.client = responce.v
	end
	
	if responce.r.ip and (my_ip ~= responce.r.ip) then
		my_ip = responce.r.ip
		if mgs_on then
			print(string.format("my_ip = %s", decode_ip(my_ip)))
		end
	end
	
	if mgs_on then
		print(string.format("%s\t\t\t> responce (%s): %s, %s",
			packet_id,
			query.q,
			statistic_distance(id or my_id, node.id),
			safe_string(node.client) or ""))
	end
	
	if (not id) or query.q == "ping" then
		free_krpc(query)
		return
	elseif query.q == "announce_peer" then
		node.announced = os.time()
		free_krpc(query)
		return
	elseif query.q == "get_peers" then
		if responce.r.token and announce_btih[id] then
			announce_btih[id].token[node] = responce.r.token
		end
		if responce.r.values then
			for i, v in pairs(responce.r.values) do
				if #v == 6 then
					add_peer(query.a.info_hash, decode_peer(v))
				end
			end
		end
	end
	
	if responce.r.nodes then
		count = #responce.r.nodes / 26
		for i = 1, count do
			local id, address, port = decode_node(responce.r.nodes, i)
			if id ~= my_id then
				local node1 = add_node(id, address, port, add_node_check)
				if node1 then
					node1.conected_to = node1.conected_to or node.id
				end
			end
		end
	end
	
	if responce.r.nodes2 then
		for i, compact in pairs(responce.r.nodes2) do
			if #compact == 26 then
				local id, address, port = decode_node(compact)
				if id ~= my_id then
					local node1 = add_node(id, address, port, add_node_check)
					if node1 then
						node1.conected_to = node1.conected_to or node.id
					end
				end
			end
		end
	end

	free_krpc(query)
end

function add_peer(id, address, port, announce_node)
	
	local peers_list = peers.btih[id]
	if not peers_list then
		peers_list = {}
		peers.btih[id] = peers_list
	end

	local compact = encode_peer(address, port)
	local peer = peers_list[compact]
	if not peer then
		if mgs_on then 
			print(string.format("new peer:\t%s:%s\t%s", address, port, hexenc(id))) 
		end
		peer = {}
		peers_list[compact] = peer
	end
	
	if announce_node then	
		peer.announce_node = announce_node
		announce_node.peer = id
	end
	
	peer.last_seen = os.time()
	
	return peer
end

function add_info(info, node)
	if info.id then
		torrent_info[info.id] = torrent_info[info.id] or {}
		if info.name then
			torrent_info[info.id].name = info.name
		end
	end
end

--[[          Send           ]]--


local send_krpc_const = {
	 query = { t = "d", o = { "t", "y", "q", "a", "v" } },
	 responce = { t = "d", o = { "t", "y", "r", "v" } },
	 error =  { t = "d", o = { "t", "y", "e", "v" } },

	 ping = { t = "d", o  = { "id" } },
	 announce_q = { t = "d", o = { "id", "info_hash", "port", "token" } },
	 find_node_q =  { t = "d", o  = { "id", "target", "want" } },
	 get_peers_q = { t = "d", o  = { "id", "info_hash", "want" } },
	 responce_r = { t = "d" , o = { "id", "nodes", "values", "token" } }
}

function get_id(node)
	local id = my_id
	if my_id_plus then
		for x = 1, #my_id_plus do
			if less(my_id_plus[x], id, node.id) then
				id = my_id_plus[x]
			end
		end
	end
	return id
end

function send_krpc(udp_port, node, krpc)

	local const = send_krpc_const
	
	if krpc.e then

	elseif krpc.r then
		if not krpc.r.id then 
			krpc.r.id = get_id(node)
		end
	else

		if not krpc.a.id then
			krpc.a.id = get_id(node)
		end
	end
	
	if not krpc.v then krpc.v = script_id end
	
	if mgs_on then 
		print(string.format("send ( %s )\t<", 
			(krpc.q
				or (krpc.r and ((krpc.r.values and "values") or (krpc.r.nodes and "nodes") or "pong"))
				or (krpc.e and "error"))))
	end
	
	--packet_analyze(krpc)
	
	local data = to_bencode(krpc)
	
	if krpc.q then
		local sended = node.sended
		if not sended then
			sended = {}
			node.sended = sended
		end
		sended.packet = krpc
		sended.time = os.time()
	end
	
	udp_port:sendto( data , node.address, node.port )
	socket.sleep(0.03)
end

function get_random_tid()
	return string.char(math.random(0, 255))..string.char(math.random(0, 255))..string.char(math.random(0, 255))
end

function send_error(udp_port, node, number, tid, description)
	local krpc = { t = tid, y = "e", e = { nubmer,  description or "unknown error" } }
	send_krpc(udp_port, node, krpc, "error")
end

local want = { "n4" }
local krpc_buff = {find_node = {}, ping={}}


function on_node_removed(node)
	if node.sended and node.sended.packet then
		free_krpc(node.sended.packet)
	end
end

function free_krpc(krpc)
	if krpc.q and krpc.q == "find_node" then
		krpc.a.target = nil
		table.insert(krpc_buff.find_node, krpc)
		--print("find_node_free:", #(krpc_buff.find_node))
	elseif krpc.q and krpc.q == "ping" then
		table.insert(krpc_buff.ping, krpc)
		--print("ping_free:", #(krpc_buff.ping))
	end
end

function send_ping(udp_port, node)
	local krpc = table.remove(krpc_buff.ping)
	if not krpc then
		krpc = { t = get_random_tid(), y = "q", q = "ping", a = {} }
	end
	send_krpc(udp_port, node, krpc)
end

function send_get_peers(udp_port, node, info_hash)
	local krpc = { t = get_random_tid(), y = "q", q = "get_peers", a = { info_hash = info_hash, want = want } }
	send_krpc(udp_port, node, krpc)
end

function send_find_node(udp_port, node, node_id)
	local krpc = table.remove(krpc_buff.find_node)
	if not krpc then
		krpc = { t = get_random_tid(), y = "q", q = "find_node", a = { want = want } }
	end
	krpc.a.target = node_id
	send_krpc(udp_port, node, krpc)
end

function send_announce(udp_port, node, info_hash, token, port)
	local krpc = { t = get_random_tid(), y = "q", q = "announce_peer", 
		a = { info_hash = info_hash, port = port, token = token }
	}
	send_krpc(udp_port, node, krpc)
end
-----------------------

for i = 1, 10 do
	local mainco = coroutine.create(main)
	local ok, err = coroutine.resume(mainco)
	if ok then
		break
	else
		errfile = io.open(error_log, "ab+")
		errfile:write("\n"..debug.traceback(mainco, err))
		errfile:close()
		on_error()
	end
end
