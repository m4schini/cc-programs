local SOURCES = {
    ["libs/os"] = "https://raw.githubusercontent.com/m4schini/cc-programs/main/libs/os.lua",
    ["libs/ui"] = "https://raw.githubusercontent.com/m4schini/cc-programs/main/libs/ui.lua",
    ["programs/farm"] = "https://raw.githubusercontent.com/m4schini/cc-programs/main/programs/farm.lua",
    ["programs/mine"] = "https://raw.githubusercontent.com/m4schini/cc-programs/main/programs/mine.lua",
    ["turtle"] = "https://raw.githubusercontent.com/m4schini/cc-programs/main/turtle.lua"
}

term.clear()
term.setCursorPos(1,1)

for path, url in pairs(SOURCES) do
    local source = url .. "?flush_cache=True"-- #<number> used as cache break
    print("GET:", source)
    local response = http.get(source) 
    if response ~= nil then
        local h, err = fs.open(path, fs.exists(path) "w")
        if err ~= nil then
            print(path, ":", err)
        else
            h.write(response.readAll())
            h.flush()
            h.close()

            print(path, ":", "was succesfully installed")
        end
    else
        print(path, ":", "response is empty")
    end
end

local programsPath = "programs"
if not fs.isDir(programsPath) then
    fs.makeDir(programsPath)
else
    print("programs directory already exists")
end