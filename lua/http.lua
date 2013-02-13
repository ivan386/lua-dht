http = {}

function next_client(tcp_port)
	local client, err = tcp_port:accept()
	
	if not client then
		if (err ~= "timeout") then
			print("accept error: "..err)
			debug.debug()
		end
		return 
	end
	
	local request = client:receive("*l")
	if not request then client:close() return end
	
	if string.find(request, "GNUTELLA CONNECT/0.6") then
		return g2_main(client)
	end
	
	-- Brouser --
	if string.find(request, " / ") then
		return http.main_page(client)
	end
	
	if string.find(request, " /console ") then
		to_http(nil, "text/html")
		local function print_fnc(request)
			if not client:send(request.."\n") then
				client:close()
				remove_print_fnc(print_fnc)
			end
		end
		add_print_fnc(print_fnc)
		return
	end
	
	if string.find(request, " /info ") then
		return http.info(client)
	end
	
	if string.find(request, " /map ") then
		return http.svg_map(client)
	end	
	
	
	-- Tracker --
	local info_hash = string.match(request, "[?&]info_hash=([^& ]+)")
	if not info_hash then 
		client:close()
		return
	else
		info_hash = unescape(info_hash)
		if #info_hash ~= 20 then
			print("#info_hash", #info_hash, info_hash)
			client:close()
			return
		end
	end
	
	local port = string.match(request, "[?&]port=([0-9]+)")
	port = (port and tonumber(port))
	local responce
	local table_type
	
	local header = client:receive("*l")
	while header and #header > 0 do
		local a, p = string.match(header, "Listen%-IP: ([0-9%.]+):([0-9]+)")
		port = port or (p and tonumber(p))
		header = client:receive("*l")
	end
	

	
	if string.find(request, " /announce", 1, true) then
		print("\t\t\t> http (announce)")
		search_peers(info_hash)
		announce_peer(info_hash, port)
		responce = {interval = 120}
		local values = get_values(info_hash, true)
		if values then
			responce.peers =table.concat(values)
			table_type = {[responce] = announce_responce}
		end
	elseif string.find(request, " /scrape", 1, true) then
		print("\t\t\t> http (scrape)")
		responce = {[info_hash] = {complete = 0, downloaded = 0, incomplete = 0}}
		table_type = {[responce] = scrape_responce, [responce[info_hash]] = scrape_details}
	else
		if info_hash then
			return http.search(client, info_hash, port, request)
		else
			return http.not_found(client)
		end
	end
	
	client:send(to_http(to_bencode(responce, table_type)))
	client:close()
end

announce_responce = { t = "d", o = {"interval", "peers"} }
scrape_responce = { t = "d" }
scrape_details = {t = "d", o = {"complete","downloaded","incomplete"}}

ferrmsg = function(text)
	return "d14:failure reason"..#text..":"..text.."e"
end

standart_header = [[
HTTP/1.1 200 OK
Server: ]]..script_name.."\n"..[[
Connection: close
]]

function to_http(body, content_type)
	body = body or ferrmsg("tracker internal error", content_type)
	local data = standart_header
	data = data.."Content-Type: "..(content_type or "text/plain").."\n"
	if body then data = data.."Content-Length: "..string.len(body).."\n" end
	data = data.."\n"..(body or '')
	return data
end


function http.main_page(client)
		local buff = new_string_builder()
		buff.add("<html><head><title>Lua DHT Tracker Info</title></head><body>")
		buff.add("<pre>"..welcome_msg.."</pre>")
		buff.add(
[[
<p>
	node ip: ]]..decode_ip(my_ip).."<br />\n"..[[
	node id: ]]..hexenc(my_id).."<br />\n"..[[
	nodes count: ]]..(nodes.count or "unknown").."\n"..[[
</p>

<p>
	<a href="/console">Console Out</a></br>
	<a href="/info">Hosted torrents</a></br>
	<a href="/map">Nodes Map</a></br>
</p>

 	
<p>
input btih and click this link:<br />
	<a href="" id="magnet">magnet:?xt=urn:btih:</a><input type="text" id="btih" onChange="document.getElementById('magnet').href='magnet:?xt=urn:btih:'+this.value+'&amp;tr=http://127.0.0.1:]]..port_number..[[/announce'; document.getElementById('magnet2').href=document.getElementById('magnet').href" /><a href="" id="magnet2">&amp;tr=http://127.0.0.1:]]..port_number..[[/announce </a>
</p>
]]		)
		buff.add("</table></body></html>")
		client:send(to_http(buff.get("\n"), "text/html"))
		client:close()
end

local maximum_ugol = 255 * 256 * 256 * 256

function spiral(ugol)
	--ugol = maximum_ugol - ugol
	local m1 = (ugol/maximum_ugol * 200)
	local m2 = (ugol/maximum_ugol * 46)
	return (50+math.cos(m1)*(m2)), (50+math.sin(m1)*(m2))
end

function http.svg_map(client)
	print("\t\t\t>http map")
	local buff = { new_string_builder(), new_string_builder(), new_string_builder(), 
	new_string_builder() }
	buff[1].add([[<?xml version="1.0" encoding="UTF-8"?>
<svg version="1.1"
 baseProfile="full"
 xmlns="http://www.w3.org/2000/svg"
 xmlns:xlink="http://www.w3.org/1999/xlink"
 xmlns:ev="http://www.w3.org/2001/xml-events"
 width="800" height="600">
]])
	
	
	buff[1].add([[<g stroke="red" >]])
	buff[2].add([[<g fill="#000088" >]])
	buff[3].add([[<g stroke="#000088" stroke-whith="2px" fill="none">]])
	buff[4].add([[<g stroke="#880000">]])
	
	for ip, port_list in pairs(nodes.ap) do
		for port, node in pairs(port_list) do
			local opacity = (1 - (os.time() - (node.last_seen or node.added)) / (15*60) )
			
			if opacity>0 then
				opacity = (svg_opacity and ' opacity="'..opacity..'" ') or ''
				
				local x, y = spiral(statistic_distance(my_id, node.id))

				local fill = (node.confirmed and ' fill="green" ') or (node.sended and ' fill="lime"') or ( (not node.last_seen) and ' fill="red" ' ) or ""
				
				buff[2].add([[<circle cx="]]..x..[[%" cy="]]..y..[[%" r="2px"]]
									..fill..opacity..[[ />]])
				
				if node.conected_to then
					local stroke = (node.confirmed and ' stroke="green" ') or (node.last_seen and ' stroke="bule" ') or ""
					local x2, y2 = spiral(statistic_distance(my_id, node.conected_to))
					buff[1].add('<line x1="'..x..'%" y1="'..y..'%" x2="'..x2..'%" y2="'..y2..'%"'..stroke..opacity..' />')
				end
				
				
				if node.announced then
					buff[3].add([[<circle cx="]]..x..[[%" cy="]]..y..[[%" r="5px"]]
									..opacity..[[ stroke="red" />]])
				elseif node.peer then
					buff[3].add([[<circle cx="]]..x..[[%" cy="]]..y..[[%" r="5px"]]
									..opacity..[[ />]])
				end
			end
		end
	end
	local  x, y =  spiral(0)
	
	buff[3].add([[<circle cx="]]..x..[[%" cy="]]..y..[[%" r="5px" stroke="green" />]])
	
	find_close_id(my_id, 50, 
		function(node, buff)
			local  x2, y2 =  spiral(statistic_distance(my_id, node.id))
			
			buff.add('<line x1="'..x..'%" y1="'..y..'%" x2="'..x2..'%" y2="'..y2..'%" />')
			
			x = x2
			y = y2
			return true
		end
		, {buff[4]}
	)
	
	buff[1].add("</g>")
	buff[2].add("</g>")
	buff[3].add("</g>")
	buff[4].add("</g>")
	buff[4].add("</svg>")
	client:send(to_http(buff[1].get("\n")..buff[2].get("\n")..buff[3].get("\n")..buff[4].get("\n"), "image/svg+xml"))
	client:close()
end

function sort_by_count(f, s)
	if f.count > s.count then
		return true
	elseif f.count < s.count then
		return false
	end
	
	return less(f.hash_raw, s.hash_raw, my_id)
end

function http.info(client)
	print("\t\t\t>http info")
	local buff1 = {}
	for hash, peer_list in pairs(peers.btih) do
		table.insert(buff1, { hash = hexenc(hash), hash_raw = hash, count = count_elements(peer_list), list = peer_list })
	end
	table.sort(buff1, sort_by_count)
	local buff = new_string_builder()
	buff.add("<html><head><title>Lua DHT Tracker Info</title></head><body><table>")
	buff.add("<tr><th>BitTorrent Info Hash or Name</th><th>count</th><th>list</th></tr>")
	for index, value  in pairs(buff1) do
		local name = (torrent_info[value.hash_raw] and torrent_info[value.hash_raw].name) or  value.hash
		buff.add(string.format("<tr><td><a href='magnet:?xt=urn:btih:%s&amp;tr=http://127.0.0.1:%s/announce&amp;dn=%s' title='%s'>%s</a></td><td>%s</td><td>",value.hash, port_number, name, value.hash, name, value.count  ))
		for compact, peer in pairs(value.list) do
			buff.add(string.format("<span>%s:%s</span> ", decode_peer(compact)))
		end
		buff.add("</td></tr>")
	end
	buff.add("</table></body></html>")
	client:send(to_http(buff.get("\n"), "text/html"))
	client:close()
	return
end

function http.search(client, info_hash, port, request)
	print("\t\t\t> http (search)")
	
	local buff = new_string_builder()
	buff.add([[
<html>
	<head>
		<title>search by info_hash</title>
	</head>
	<body>
		<p>This page refresh every 120 seconds. Whait plz.</p>
		<p>
]])
	local protocol = string.match(request, "[?&]protocol=([^& ]+)") or "bittorrent"
	local file_size = string.match(request, "[?&]xl=([^& ]+)") or ""
	local file_name = string.match(request, "[?&]dn=([^& ]+)") or ""
	local btih = string.match(request, "[?&]urn:btih:([^& ]+)") or hexenc(info_hash)
	local file_urn = string.match(request, "[?&](urn:[^& ]+)") or "urn:btih:"..btih
	local ed2k_hash = string.match(request, "[?&]urn:ed2k:([^& ]+)") or ""
	
	buff.add(string.format([[protocol: %s<br />
file_size: %s<br />
file_name: %s<br />
file_urn: %s<br />
btih: %s<br />
info_hash: %s<br />
ed2k_hash: %s<br />
</p><p>]],	protocol , file_size, file_name, 
			file_urn, btih, hexenc(info_hash), ed2k_hash))
	
	local peers = get_peers(info_hash, port)
	local x_alt = ""
	
	if peers then
	
		if protocol == "ed2k" then
			
			buff.add(string.format("<a href=\"ed2k://|file|%s|%s|%s|/|sources", 
									file_name, file_size, ed2k_hash))
		end
		
		local peers_x_alt = new_string_builder()
		for compact, peer in pairs(peers) do
			--if not peer.x_alt_sended then
				local a, p = decode_peer(compact)
				peers_x_alt.add(a..":"..p)
				--peer.x_alt_sended = os.time()
				if protocol == "ed2k" then
					buff.add(string.format(",%s:%s", a, p))
				elseif protocol == "uri-res" then
					buff.add(string.format("<a href=\"http://%s:%s/uri-res/N2R?%s\">%s:%s</a><br />\n", a, p, file_urn, a, p))
				elseif protocol == "p2p-radio" then
					buff.add(string.format("<a href=\"p2p-radio://%s:%s\">%s:%s</a><br />\n", a, p, a, p))
				else
					buff.add(string.format("<a href=\"btc://%s:%s//%s\">%s:%s</a><br />\n", a, p, btih, a, p))
				end
			--end
		end
		
		if protocol == "ed2k" then
			buff.add("|/")
		end
		
		if not peers_x_alt.empty() then
			x_alt = "X-Alt: "..peers_x_alt.get(",").."\n"
		end
	end

	buff.add([[
		</p>
	</body>
</html>
]])
	local content = buff.get()
	client:send([[
HTTP/1.1 503 Bisy
Server: ]]..script_name.."\n"..[[
X-Queue: position=2,length=10,limit=20,pollMin=10,pollMax=100");
Retry-After: 120
Refresh: 120]]
.."\n"..x_alt.."Content-Length: "..#content.."\n\n"..content)

	client:close()
	return
end

function http.not_found(client)
		client:send([[
HTTP/1.1 404 Not Found
Server: ]]..script_name.."\n"..
[[Content-Length: 9

Not Found]])
end