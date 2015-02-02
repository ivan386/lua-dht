--local table1 = _G

-- local table0 = {"self key", name_test = 1, }
-- table0.self = table0
-- table0[table0]={"oiewrhter"}
-- local table1={nil,nil,nil, recovery = 1, recovery0 = 2, recovery1 = 5, [{x = 1, "no linked table as key 1"}]={"nn1"},"test1", [table0] = table0}
-- local table2={table1,nil,nil,[{x = 2, "no linked table as key 2",table1}]={"nn2"},"test2"}
-- local table3={table1,table2,nil,[{x = 3, "no \\ \n linked table as key 3",table1,table2,[{"no linked table as key 3.1"}]="3.1"}]={"nn3"},"test3"}
-- table1[1]=table3
-- table1["numbers test"] = {0/0, -1/0, 1/0, 1234567890.1234567890, 1,2,3,4,5,6, 6.2 }
-- table1["boolean test"] = {true, false}
-- table1["string test"] = "\0\1\2\3\4\5\6\7\8\9\10\t\n\\"
-- table1["order test"] = {"1", "2", [5] = "5", "3 or 6?"}
-- table1["lng str"] = "too long string copy test."
-- table1["lng str copy"] = table1["lng str"]
-- table1[table1["lng str"]] = "lng str as key"
-- table1["function test"] = function() return "test" end
-- table1[table1["function test"]] = "function as key"
--table1[table1]={[table1]={[table1]="multi key test"}}
--table1["nodes test"] = dofile("nodes.tbl")
-- table1[2]=table2
-- table1[3]=table2
-- table2[2]=table2
-- table2[3]=table3
-- table3[3]=table1
-- table1[table1]="table1.1"
-- table1[table2]="table1.2"
-- table1[table3]="table1.3"
-- table2[table1]=table1
-- table2[table2]=table2
-- table2[table3]=table3
-- table3[table1]=table1

--table1._G=_G


	
-- local seri=serialize(table1,"testtable").."\n return testtable"
-- print(seri)
-- local file = io.open("D:\\xxx.txt","w")
-- file:write(seri)
-- for i=0,1000 do
	-- seri=serialize(assert(loadstring(seri))(),"testtable").."\n return testtable"
-- end
-- print(seri)

--[[
    return ({
			value1,
			value2,
            key1 = value3,
            key2 = value4,
            ...
            function recovery(self)

            end
        }):recovery()
]]
function safe_string(value, cache)
	if type(value) == "string" then
		local c = cache and cache[value]
		if c then
			return c
		end

		local v = '"'..string.gsub(value, "([\\\10\13%c%z\"])([0-9]?)", function(chr, digit)
			local b = string.byte(chr)
			if #digit == 1 then
				if string.len(b) == 1 then return "\\00"..b..digit end
				if string.len(b) == 2 then return "\\0"..b..digit end
			end
			return "\\"..b..digit
		end)..'"'
		
		if cache then
			cache[value] = v
		end
		
		return v

		--return string.format('%q', value)
	elseif type(value) == "number" then
		if not ( (value > 0) or (value < 0) or (value == 0) ) then -- indeterminate form
			return "0/0"
		elseif value == 1/0 then -- infinity
			return "1/0"
		elseif value == -1/0 then -- negative infinity
			return "-1/0"
		else
			return tostring(value)
		end
	elseif type(value) == "function" then
		local ok, dump = pcall(string.dump, value)
		if ok then
			return "loadstring("..safe_string(dump, cache)..")"
		end
	elseif type(value) == "boolean" then
		return tostring(value)
	elseif type(value) == "nil" then
		--return "nil"
	end
	
	return nil
end

local function safe_key(key, cache, safe_string_cache)
	local c = cache and cache[key]
	if c then
		return c[1], c[2]
	end
	
	local safe_name = string.match(key, "^([A-Za-z_]+[A-Za-z0-9_]*)$")
	local dot = "."
	
	
	if not safe_name then
		safe_name = "["..safe_string(key, safe_string_cache).."]"
		dot = ""
	end
	
	if cache then
		cache[key] = {safe_name, dot}
	end
	return safe_name, dot
end

local function testname(name)
	--[[assert( (type(name) == "table")
			or (name:sub(1,1) == ".")
			or (name:sub(1,1) == "[")
			or (name:sub(1,4) == "root")
			or (name:sub(1,3) == "key")
	)]]
end
	
function serialize(value, fnc_write, skip)
	if type(value) == "table" then
		local obj_map = {}
		local keys = {order = {}, links = {}}
		local recover = {}
		local recovery_name = "recovery"
		local deep = 0
		local return_string = (not fnc_write) and {}
		local safe_string_cache = {}
		local safe_key_cache = {}
		
		if return_string then
			fnc_write = function(text)
				table.insert(return_string, text)
			end
		end

		
		local function add_key_value(tabl, key, value)
			local links = keys.links[key]
			if not links then
				table.insert(keys.order, key)
				links = {}
				keys.links[key] = links
			end
			table.insert(links, {tabl = tabl, value = value})
		end
		
		local serialize_table
		local function serialize_value(value, name, dot, parent, prefix)
			if type(value) == "table" then
				local not_empty, deferred_creation = serialize_table(value, name, dot, parent, prefix);
				return (not_empty or (not deferred_creation)), deferred_creation
			else
				local serialized = safe_string(value, safe_string_cache)
				if serialized then
					if prefix then fnc_write(prefix) end
					fnc_write(serialized)
				
					if (type(value) == "function") then
						obj_map[value] = {name = name, dot = dot , parent = parent}
					end
					return true
				end
			end
		end	

		local function tbl_new_line(not_empty, deep)
			return string.format((not_empty and ",\n%s") or "\n%s", string.rep("\t", deep))
		end
		
		
		

		local function serialize_by_index(tabl, prefix)
			local not_empty, last_index
			
			for index, value in ipairs(tabl) do
				if obj_map[value] then
					break
				end
				if (not skip) or not skip(tabl, index, value) then
					local value_prefix = ((not_empty and "") or prefix or "") .. tbl_new_line(not_empty, deep)
					local writen, deferred_creation = serialize_value(value, string.format("[%i]", index), nil, tabl, value_prefix)
					if writen then
						last_index = index
						not_empty = true
					elseif deferred_creation then
						return not_empty, index-1, deferred_creation
					else
						return not_empty, last_index
					end
				else
					break
				end
			end
			return not_empty, last_index
		end
		
		local function check_in_parents(obj, parent)
			
			if not parent then
				return false
			elseif obj == parent then
				return true
			end
			local info = obj_map[parent]
			return check_in_parents(obj, info.parent)
		end
		
		local function serialize_by_keys(tabl, last_index, parent, not_empty, prefix)
			local have_recover, parent_link, obj_as_key
			for key, value in pairs(tabl) do
				if (not skip) or not skip(tabl, key, value) then
					
				
					if 	   (type(key) == "table")
						or (type(key) == "function")
					then
						obj_as_key = true
						add_key_value(tabl, key, value)
					elseif (not last_index)
						or (type(key) ~= "number")
						or (key > last_index)
						or (key < 1)
						or (key > math.floor(key))
					then
						local name, dot = safe_key(key, safe_key_cache, safe_string_cache)
						local value_prefix = string.format("%s%s%s=", ((not_empty and "") or prefix or ""), tbl_new_line(not_empty, deep), name)
						local info = obj_map[value]
						if info then
							parent_link = check_in_parents(value, parent)
							have_recover = true
							table.insert(recover, {tabl = tabl, dot = dot, name = name, value = value})
						else 
							local writed, deferred_creation = serialize_value( value, 
											 name,
											 dot,
											 tabl,
											 value_prefix )
							if writed then
								not_empty = true
							elseif deferred_creation then
								have_recover = true
							end
						end
					end
				end
			end
			return not_empty, have_recover and not(parent_link or obj_as_key)
		end
		
		function serialize_table(tabl, name, dot, parent, prefix, open)
			assert(obj_map[tabl] == nil)
			obj_map[tabl] = {name = name, dot = dot , parent = parent}
			testname(name)
			
			if prefix then
				prefix = prefix.."{"
			else
				prefix = "{"
			end

			deep = deep + 1

			local not_empty, last_index, deferred_creation = serialize_by_index(tabl, prefix)
			
			
			if not_empty then
				serialize_by_keys(tabl, last_index, parent, not_empty)
			else
				not_empty, deferred_creation = serialize_by_keys(tabl, last_index, parent, not_empty, prefix)
			end
			
			deep = deep - 1
			if not open then 
				if not_empty then
					fnc_write(string.format("\n%s}", string.rep("\t", deep))) 
				elseif deferred_creation and parent then
					obj_map[tabl].deferred_creation = deferred_creation
				else
					fnc_write(prefix)
					fnc_write("}")
				end
			end
			return not_empty, deferred_creation
		end
		
		local get_key, format_key
		
		function format_key(key)
			if obj_map[key] then
				return string.format("[%s]", get_key(key))
			else
				return key
			end
		end
		

		
		function get_key(obj)
			local key = {}
			local info = obj_map[obj]
			local open_objects = 0
			local dot = ""
			while info do
				if info.deferred_creation then
					table.insert(key, 1, "={")
					open_objects = open_objects + 1
					info.deferred_creation = false;
				else
					table.insert(key, 1, dot)
				end
				dot = info.dot or ""
				table.insert(key, 1, format_key(info.name))
				info = obj_map[info.parent]
			end
			return table.concat(key), open_objects
		end
	
        fnc_write("(")
		
		if value[recovery_name] then
			local indx = 0
			local new_name
			repeat 
				new_name = recovery_name..indx
				indx = indx + 1
			until not value[new_name]
			recovery_name = new_name
		end
		
        local not_empty = serialize_table(value, "root", nil, nil, nil, true)
		
		-- recover links
        if next(keys.order) or next(recover) then
			deep = deep + 2
			local tabs = string.rep("\t", deep)
            fnc_write(string.format("%s%s=function(root)\n\t\troot.%s=nil;\n", 
				((not_empty and ",\n\t") or ""), recovery_name, recovery_name))
			local idx = 0
			if next(keys.order) then
				
				local local_key = "\t\tlocal key={};\n"
				repeat
					local keys_old = keys
					keys = {order = {}, links = {}}
					for _, key in ipairs(keys_old.order) do
						if not obj_map[key] then
							idx = idx + 1

							local key_name = string.format("key[%i]", idx)
							local prefix = string.format("%s\t\t%s=", local_key, key_name)
							if serialize_value(key, key_name, nil, nil, prefix) then
								fnc_write(";\n")
								local_key = ""
							end
						end
						if obj_map[key] then
							for _, link in pairs(keys_old.links[key]) do
								if obj_map[link.value] then
									table.insert(recover, {tabl = link.tabl, name = key, value = link.value})
								elseif serialize_value(	link.value,
														key,
														nil,
														link.tabl,
														string.format("%s%s[%s]=", tabs, get_key(link.tabl), get_key(key)))
								then
									fnc_write(";\n")
								end
							end
						end
					end
				until not next(keys.order)
			end
			for _, rec in ipairs(recover) do
				local in_key, open_objects = get_key(rec.tabl)
				local dot = ""
				if open_objects == 0 and rec.dot then
					dot = rec.dot
				end
				
				fnc_write(string.format("%s%s%s%s=%s%s;\n", tabs, in_key, dot,  format_key(rec.name), get_key(rec.value), string.rep("}", open_objects)))
			end
            fnc_write(string.format("\t\treturn root;\n\tend\n}):%s()", recovery_name))
        else
            fnc_write("})")
        end
		if return_string then
			return table.concat(return_string)
		end
    else
		local serialized = safe_string(value)
        if serialized then 
			if fnc_write then
				fnc_write(serialized) 
			else
				return serialized
			end
		end
    end
end
--[[
local buf
function step_by_step(text)
	io.write(text)
	table.insert(buf, text)
	--io.read(1)
end

for i = 1, 1 do
	buf = {}
	step_by_step("return ")
	serialize(table1, step_by_step)
	f = io.open("rex.txt", "wb")
	f:write(table.concat(buf))
	f:close()
	local t, e = loadstring(table.concat(buf))
	print(e)
	table1 = t()
end]]
