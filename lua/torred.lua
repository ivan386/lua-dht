
function is_dictionary(data)
	return data:sub(1,1) == "d" and data:sub(-1) == "e"
end

local numbers={["0"]=0,["1"]=1,["2"]=2,["3"]=3,["4"]=4,["5"]=5,["6"]=6,["7"]=7,["8"]=8,["9"]=9}

function from_bencode(data, no_info)
	local table_info 
	if not no_info then
		table_info = {}
	end
	
	local function  parse(index)
		if index > #data then return end 
		local t = data:byte(index)
		
		if (t == 105) or (t >=48 and t <=57) then -- (i)nteger or string
			local start, endindex, number = string.find(data, "i?(%-?[0-9]+)[e:]", index)
			
			if start ~= index then return end
			
			number = tonumber(number)
			
			if not number then return end
			
			if t == 105 then -- is (i)nteger?
				return number, endindex 
			end
			
			if ( number < 0 ) or (math.floor(number) ~= number) or ( endindex + number > #data ) then return end
			local value = data:sub(endindex + 1, endindex + number)
			return value, endindex + number
		
		elseif (t == 108) then -- (l)ist
			local value, endindex = parse(index + 1)
			local list={}
			--
			while value do
				table.insert(list,value)
				value, endindex = parse(endindex + 1)
			end
			
			if not endindex then return end
			
			return list, endindex
		elseif (t == 100) then -- (d)ictionary
			local dict={}
			local dict_info
			if table_info then
				dict_info = { o = {} }
				table_info[dict] = dict_info
			end
			local key, endindex = parse(index + 1)
			local value
			while key do
				value, endindex = parse(endindex + 1)
				if value then
					if dict_info then
						table.insert(dict_info.o, key)
					end
					dict[key]=value
				else
					break
				end
				if not endindex then return end
				key, endindex = parse(endindex + 1)
				if not endindex then return end
			end
			return dict, endindex
		elseif t == 101 then
			return nil, index
		end
	end
	return parse(1), table_info
end

function to_bencode(value, table_info, buff)
	--print(type(value))
	if not buff then
		local buff = {}
		to_bencode(value, table_info, buff)
		return table.concat(buff)
	elseif type(value) == "number" then
		table.insert(buff, "i"..value.."e")
	elseif type(value) == "string" then
		table.insert(buff, #value..":"..value)
	elseif type(value) == "table" then
		
		
		if value[1] then
			table.insert(buff, "l")
			for _, v in ipairs(value) do
				to_bencode(v, table_info, buff)
			end
		else
			local dict 
			if table_info then
				dict = table_info[value]
			end
			
			table.insert(buff, "d")
			if dict and dict.o then
				for _, k in ipairs(dict.o) do
					if value[k] then
						to_bencode(k , table_info, buff)
						to_bencode(value[k] , table_info, buff)
					end
				end
			else
				for k, v in pairs(value) do
					to_bencode(k , table_info, buff)
					to_bencode(v , table_info, buff)
				end
			end
		end
		
		table.insert(buff, "e")
	end
end

function set_value(tbl, table_info, value, key)
	local info = table_info[tbl]
	if key and value then
		if not info then 
			info = {t = "d", o = {}}
			table_info[tbl] = info
		end
		tbl[key] = value
		table.insert( info.o, key )
	elseif value and not (info or key) then 
		table.insert( tbl, value )
	end
end