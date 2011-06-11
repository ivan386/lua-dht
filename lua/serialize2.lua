
-- local table1={nil,nil,nil,[{"no linked table as key 1"}]={"nn1"},"test1"}
-- local table2={table1,nil,nil,[{"no linked table as key 2",table1}]={"nn2"},"test2"}
-- local table3={table1,table2,nil,[{"no \\ \n linked table as key 3",table1,table2,[{"no linked table as key 3.1"}]="3.1"}]={"nn3"},"test3"}
-- table1[1]=table1
-- table1[2]=table2
-- table1[3]=table2
-- table2[2]=table2
-- table2[3]=table3
-- table3[3]=table3
-- table1[table1]="table1.1"
-- table1[table2]="table1.2"
-- table1[table3]="table1.3"
-- table2[table1]=table1
-- table2[table2]=table2
-- table2[table3]=table3
-- table3[table1]=table1

	
function safestring(value)
	if type(value)=="string" then
		local v = string.gsub(value, "([\\\10\13%c%z\128-\255\"])([0-9]?)", function(chr, digit)
			local b = string.byte(chr)
			if #digit == 1 then
				if string.len(b)<2 then b="0"..b end
				if string.len(b)<3 then b="0"..b end
			end
			b="\\"..b..digit
			return b
		end)
		return '"'..v..'"'
	end
end

function serialize(tTable, sTableName,sNewLine ,sTab, fSkipValue)
	assert(tTable, "tTable equals nil");
	sTableName = sTableName or "";
    assert(type(tTable) == "table", "tTable must be a table!");
    assert(type(sTableName) == "string", "sTableName must be a string!");
	if not sNewLine then sNewLine="\n" end
	if not sTab then sTab="\t" end
    local tTablesCollector={}
	local kidx = 0
	
	local function next2(tbl, index)
		local new_index, new_value = next(tbl, index)
		while new_index and fSkipValue(tbl, new_index, new_value) do
			new_index, new_value = next(tbl, new_index)
		end
		return new_index, new_value
	end

	local function pairs2(tbl)
		return next2, tbl, nil
	end
	
	if not fSkipValue then pairs2 = pairs end
	
	local function SerializeInternal(tTable, sTableName, sTabs, sLongKey)
		local tRepear = {}
		local tTmp = {}
		sLongKey = sLongKey or sTableName;
		sTabs = sTabs or "";
		if tTablesCollector[tTable] then
			local sKey = tTablesCollector[tTable]
			table.insert(tRepear, sNewLine..sTab..sLongKey.."="..sKey..";")
			if #sKey > #sLongKey then
				tTablesCollector[tTable] = sLongKey;
			end
			return nil, tRepear
		else
			tTablesCollector[tTable] = sLongKey
		end
		
		if not next(tTable) then
			table.insert(tTmp, sTabs..sTableName.."={}")
			return tTmp, tRepear
		end
		
		if sTableName~="" then
			table.insert(tTmp, sTabs..sTableName.."={")
		end
		
		local bEmpty = true
		for key, value in pairs2(tTable) do
			local sKey
			local bToRepear = false
			if (type(key) == "table") then
				if tTablesCollector[key] then
					sKey="["..tTablesCollector[key].."]"
				else
					kidx=kidx+1
					sKey="keys["..kidx.."]"
					local tTmp2, tRepear2 = SerializeInternal(key, sKey, sTab)
					table.insert(tRepear, sNewLine..table.concat(tTmp2, "")..";"..table.concat(tRepear2, ""))
					sKey="["..sKey.."]"
				end
				bToRepear = true
			elseif (type(key) == "string") then
				local m = string.match(key, "([A-Za-z_]+)")
				if m and (#m == #key) then
					sKey = m
				else
					sKey = "["..safestring(key).."]" 
				end
			elseif (type(key) == "number") then
				sKey = string.format("[%d]",key);
			else
				sKey = "["..tostring(key).."]" 
			end
			
			local prefix = (bEmpty and sNewLine) or ","..sNewLine
			
			if(type(value) == "table") then
				local tTmp2, tRepear2=SerializeInternal(value, sKey,(bToRepear and sTab) or sTabs..sTab, sLongKey..((sKey:sub(1,1)=="[" and "") or ".")..sKey)

				if tTmp2 and next(tTmp2) then
					if bToRepear then
						table.insert(tRepear, sNewLine..sTab..sLongKey..table.concat(tTmp2, "")..";")
					else
						table.insert(tTmp, prefix..table.concat(tTmp2, ""));
						bEmpty = false
					end
				end
				
				if tRepear2 and next(tRepear2) then
					table.insert(tRepear, table.concat(tRepear2, ""))
				end
			else
				local sValue = ((type(value) == "string") and safestring(value)) or tostring(value);
				if bToRepear then
					table.insert(tRepear, sNewLine..sTab..sLongKey..sKey.."="..sValue..";")
				else
					table.insert(tTmp, prefix..sTabs..sTab..sKey.."="..sValue)
					bEmpty = false
				end
			end
			
		end
		
		if sTableName~="" then
			if bEmpty then
				table.insert(tTmp, "}")
			else
				table.insert(tTmp, sNewLine..sTabs.."}")
			end
		end
		
        return tTmp, tRepear
	end
	
	local ret=nil
	if sTableName=="return" then
		ret="temp"
		sTableName=ret
	end
	
    local tResult, tRepear = SerializeInternal(tTable,sTableName,sTab)
	local prefix, suffix = (ret and "return ") or "", ""
	
	
	if tRepear and next(tRepear) then
		if not ret then
			prefix = sTableName.."="
		end
		if tResult[1] and tResult[1]:sub(1,1) == "\t" then
			tResult[1] = tResult[1]:sub(2)
		end
		prefix = prefix.."(function()"..sNewLine..sTab.."local keys={};"..sNewLine..sTab.."local "
		suffix = ";"..sNewLine..sTab..table.concat(tRepear, "")..sNewLine..sTab.."return "..sTableName..";"..sNewLine.."end)()"
	elseif ret then
		local st,ed = string.find(tResult[1],ret.."=",1,true)
		if st and ed then
			tResult[1] = string.sub(tResult[1], ed+1)
		end
	end
	
	collectgarbage()
	--print(sResult)
	return prefix..table.concat(tResult, "")..suffix
end

	

-- local seri=serialize(table1,"testtable").."\n return testtable"
-- print(seri)
-- local file = io.open("D:\\xxx.txt","w")
-- file:write(seri)
-- for i=0,1000 do
	-- seri=serialize(assert(loadstring(seri))(),"testtable").."\n return testtable"
-- end
-- print(seri)
