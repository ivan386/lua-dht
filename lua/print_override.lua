print_list = {}

function add_print_fnc(print_fnc)
	print_list[print_fnc] = true
end

function remove_print_fnc(print_fnc)
	print_list[print_fnc] = nil
end

function nb_print(...)
	io.stderr:write(table.concat(arg, "\t"))
end

function nb_out(...)
	io.stdout:write(table.concat(arg, "\t"))
end

function flush()
	io.stderr:flush()
	io.stdout:flush()
end

function status_print(...)
	local line = table.concat(arg, " ")
	if #line < 79 then
		line = string.rep(" ", 79 - #line)..line.."\r"
	end
	nb_print(line)
end

old_print = print

function print(...)
	local line = table.concat(arg, "\t")
	nb_print(line.."\n")
	for print_fnc, _ in pairs( print_list ) do
		print_fnc( line )
	end
end 



function print2(...)
	local line = table.concat(arg, "\t")
	print(line)
	old_print(line)
	io.stdout:flush()
end

function mid_print(...)
	local line = table.concat(arg, " ")
	if #line < 79 then
		local hlf = math.floor((79 - #line) / 2)
		line = string.rep(" ", hlf)..line
	end
	print(line)
end

function print_msg(...)
	print(string.rep("-", 79))
	print(unpack(arg))
	print(string.rep("-", 79))
end
