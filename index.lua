-- CREATE DATABASE `cfp` CHARACTER SET utf8 COLLATE utf8_general_ci;
local rootFolder = "/www/CFP/"
local template = ""
local output = ""


function print(...)
    output = output .. table.concat({...}, "")
end

function getUser(r, db, id)
    local prep = db:prepare(r, "SELECT `name`, `email`, `fullname` FROM `users` WHERE `id` = %u LIMIT 1")
    local res = prep:select(tonumber(id))
    if res then
        local row = res(-1)
        if row then
            local usr = {}
            usr.id = id
            usr.name = row[1]
            usr.email = row[2]
            usr.fullname = row[3]
            return usr
        end
    end
end

function cycle(what)
    for n = 1, 100 do
        what = r:sha1(what .. "cfp01886")
    end
    return r:md5(what)
end

function rows(resultset, async)
    local a = 0
    local function getnext()
        a = a + 1
        local row = resultset(-1)
        return row and a or nil, row
    end
    if not async then
        return pairs(resultset(0))
    else
        return getnext, self
    end
end

function getFile(r, filename)
    local path = rootFolder .. "/" .. filename
    if r:stat(path) then
        local f = io.open(path)
        if f then
            local d = f:read("*a")
            f:close()
            return d
        end
    end
    return "<!-- Could not find " .. filename .. "! -->"
end

function handle(r)
    -- Acquire database handle
    local db, err = r:dbacquire("mod_dbd") -- Assume mod_dbd is set up with DB access
    if err then
        r:warn("Could not establish a database connection via mod_dbd, please check configuration!")
        return 500 -- Internal Server Error!
    end
    
    -- Get/set cookies
    local cookie = r:getcookie("cfp") or ""
    cookie = cookie:gsub("[^a-z0-9]+", "") -- Rid non-sha1 chars from cookie
    if cookie == "" or cookie == "0" then
        cookie = r:sha1(math.random(1,os.time()) .. r:clock() .. os.time())
        r:setcookie("cfp", cookie, false, os.time() + (86400*30))
    end
    
    
    -- Get user data if logged on
    local user = {}
    local prep, err = db:prepare(r, "SELECT `id`, `name`, `fullname`, `email`, `unread` FROM `users` WHERE `cookie` = %s LIMIT 1")
    if err then
        r:warn("Error while preparing statement: " .. err)
        db:close()
        return 500
    end
    local res = prep:select(cookie)
    if res then
        local row = res(-1) -- Get the first row
        if row then
            user.loggedOn = true
            user.id = row[1]
            user.name = row[2]
            user.fullname = row[3]
            user.unread = tonumber(row[5])
        end
    end
    
    
    -- Execute page thingermajig
    local templating = {}
    templating.year = 2014
    templating.title = "Welcome!"
    
    local page = r.unparsed_uri:match("^/([-a-zA-Z_/]+)")
    if not page or page == "" then
        page = "index"
    end
    local scriptPath = rootFolder .. "/docs/" .. page .. ".lua"
    if r:stat(scriptPath) then
        local s, err = loadfile(scriptPath)
        if s then
            _G.r = r
            _G.user = user
            _G.db = db
            _G.cookie = cookie
            _G.templating = templating
            local rv = s() or 0
            if rv == 302 then
                db:close()
                return 302
            end
        else
            r:warn("Could not load " .. scriptPath .. ": " .. err)
            db:close()
            return 500
        end
    else
        db:close()
        r.uri = page
        return 404
    end
    db:close()
    
    -- Fetch HTML5 skeleton
    if user.loggedOn then
        template = getFile(r, "templates/main_lo.html")
    else
        template = getFile(r, "templates/main.html")
    end
    
    -- Merge script output with template
    templating.user = (user and (user.fullname and #user.fullname > 0 and user.fullname) or user.name) or "Unknown entity"
    templating.emails = user and user.unread and user.unread or 0
    templating.output = output
    template = template:gsub("{{(.-)}}", templating)
    
    r.content_type = "text/html"
    r:puts(template)
    
    -- All done!
    return apache2.OK
end