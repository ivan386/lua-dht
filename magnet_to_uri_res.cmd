%~d0
cd %~p0
del temp2.txt
lua5.1.exe lua\magnet_to_uri_res.lua > temp2.txt
temp2.txt
pause