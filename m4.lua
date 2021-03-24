local args = { ... }

local URL_REPO_RAW = "https://raw.githubusercontent.com/m4schini/cc-programs/main/" 

function Install(name, asStartup)
    if asStartup then
        shell.run("wget", URL_REPO_RAW .. name .. ".lua", "startup")
    else
        shell.run("wget", URL_REPO_RAW .. name .. ".lua", name)
    end
end

function InstallModule(name)
    local fileEnding = ".lua"
    local filename = name .. fileEnding

    shell.run("wget", URL_REPO_RAW .. "libs/" .. filename, filename)
    shell.run("mv", )
end


if args[1] == "install" then
    local name = args[2]
    local asStartup = args[3] == "--startup"
    
    Install(name, asStartup)
elseif args[1] == "import" then
    local name = args[2]

else
    print(args[1] .. " was not recognized")
end