function print_err(...)
	local first, err = ...
	if not first then
		print(err)
	end
	return ...
end

function do_if(fnc, ...)
	local first = ...
	if first then
		return fnc(...)
	end
end

function get_or_create(node, ...)
	local keys = {...}
	local created
	for i, key in ipairs(keys) do
		
		local sub_node = (not created) and node[key]
		
		if sub_node then
			node = sub_node
		else
			sub_node = {}
			node[key] = sub_node
			node = sub_node
			created = created or i
		end
	end
	return node, created
end

function repl(chr,ord,sch)
	
	if (ord(sch)>=192 and ord(sch)<=239)  then return chr(208)..chr(ord(sch)-48) end
	if (ord(sch)>=240 and ord(sch)<=255) then return chr(209)..chr(ord(sch)-112) end
	if (ord(sch)==168) then return chr(208)..chr(129) end --¨
	if (ord(sch)==184) then return chr(209)..chr(145) end --¸
	if (ord(sch)==150) then return chr(226)..chr(128)..chr(147) end --–
	if (ord(sch)==151) then return chr(226)..chr(128)..chr(148) end --—
	--[[if (ord(sch)==218) then return chr(208)..chr(172) end --Ú
	if (ord(sch)==220) then return chr(208)..chr(170) end --Ü
	if (ord(sch)==250) then return chr(208)..chr(140) end --ú
	if (ord(sch)==252) then return chr(208)..chr(138) end --ü]]
	return chr(ord(sch))
end

function wintoutf8ru(text)
	local chr=string.char
	local ord=string.byte
	local rez=string.gsub(text, "(.)", function(sch)
		return repl(chr,ord,sch)
	end)
	return rez
end

local function new_timer(count)
	count = count or 1

	local last_time = os.time()
	function object(time)
		if os.time() - last_time >= time then
			last_time = os.time()
			return true
		end
	end
	if count == 1 then 
		return object
	elseif count > 1 then
		return object, new_timer(count - 1)
	end
end
_G.new_timer=new_timer

function get_random_tid()
	return string.char(math.random(0, 255), math.random(0, 255), math.random(0, 255))
end

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

function less(first_id, second_id, by_id)
	for i = 1 , 20 do
		local fl = xor(first_id:byte(i), by_id:byte(i))
		local sl = xor(second_id:byte(i), by_id:byte(i))
		if fl < sl then return true end
		if fl > sl then return false end
	end
	return false
end