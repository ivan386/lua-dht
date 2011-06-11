%~d0
cd %~p0
copy nodes.tbl "%SYSTEMROOT%\system32\nodes.tbl"
LuaService -i
info.url
pause