function new_string_builder()
	local string_table = {}
	local object = {}
	
	function object.insert(...)
		for idx, str in ipairs(arg) do
			table.insert(string_table, idx, str)
		end
	end
	
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
	
	function object.len()
		local len = 0
		for index, str in ipairs(string_table) do
			len = len + #str
		end
		return len
	end
	
	return object
end
