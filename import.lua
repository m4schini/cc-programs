-- this is a function intended to be copied to the top of a script file.
-- It downloads the current lib version from the github repo if no local file exists.
-- If you want to update your local lib, remove them and restart the program that uses
-- this function for its imports

function Import(modname)
    if not fs.exists("/libs/" .. modname .. ".lua") then
        local request = http.get("https://raw.githubusercontent.com/m4schini/cc-programs/main/libs/" .. modname .. ".lua")
        if request ~= nil then 
            local handler = fs.open("/libs/" .. modname .. ".lua", "w");
            handler.write(request.readAll())
            handler.close()
        end
    end
    return require("/libs/" .. modname)
end