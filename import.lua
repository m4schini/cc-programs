-- this is a function intended to be copied to the top of a script file.
-- It downloads the current lib version from the github repo if no local file exists.
-- If you want to update your local lib, remove them and restart the program that uses
-- this function for its imports

function Import(modname)
    local request = nil
    if fs.exists("DEVENV") then
        request = http.get("https://raw.githubusercontent.com/m4schini/cc-programs/dev/libs/" .. modname .. ".lua")
    elseif not fs.exists("/libs/" .. modname .. ".lua") then
        request = http.get("https://raw.githubusercontent.com/m4schini/cc-programs/main/libs/" .. modname .. ".lua")
    end

    if request ~= nil then 
            local handler = fs.open("/libs/" .. modname .. ".lua", "w");
            handler.write(request.readAll())
            handler.close()
        end
    return require("/libs/" .. modname)
end