-- CREATE DATABASE `cfp` CHARACTER SET utf8 COLLATE utf8_general_ci;
local rootFolder = "/www/CFP/"
local template = ""
local output = ""


function print(...)
    output = output .. table.concat({...}, "")
end

function parseymd(txt)
    local y,m,d = txt:match("(%d+)-(%d+)-(%d+)")
    if y and m and d then
        return os.time{year=y,month=m,day=d}
    end
    return 0
end

function getEvent(r, db, id)
    local prep, err = db:prepare(r, "SELECT `title`, `owner`, `description`, `starts`, `ends`, `location`, `closes`, `resolves`, `ofb` FROM `events` WHERE `id` = %u LIMIT 1")
    local res = prep:select(tonumber(id))
    local row = res(-1)
    if row then
        local event = {}
        event.id = tonumber(id)
        event.title = row[1]
        event.owner = tonumber(row[2])
        event.description = row[3]
        event.starts = tonumber(row[4])
        event.ends = tonumber(row[5])
        event.location = row[6]
        event.closes = tonumber(row[7])
        event.resolves = tonumber(row[8])
        event.open = tonumber(row[9])
        return event
    end
end

function saveEvent(r, db, event)
    if event.id and event.id > 0 then
        local prep = db:prepare(r, "UPDATE `events` SET `title` = %s, `owner` = %u, `description` = %s, `starts` = %u, `ends` = %u, `location` = %s, `closes` = %u, `resolves` = %u, `ofb` = %u WHERE `id` = %u LIMIT 1")
        prep:query(event.title, event.owner, event.description, event.starts, event.ends, event.location, event.closes, event.resolves, event.open, event.id)
    elseif event.owner and event.owner > 0 then
        local prep = db:prepare(r, "INSERT INTO `events` (`owner`, `title`, `description`, `starts`, `ends`, `location`, `closes`, `resolves`) VALUES (%u, %s, %s, %u, %u, %s, %u, %u)")
        prep:query(event.owner, event.title, event.description, event.starts, event.ends, event.location, event.closes, event.resolves)
    end
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
            usr.fullname = (#row[3] > 0 and row[3]) or row[1]
            return usr
        end
    end
end

function getTalkTypes(r, db, event)
    local types = {}
    local prep = db:prepare(r, "SELECT `id`,  `title`, `description`, `duration` FROM `talktypes` WHERE `event` = %u")
    local res = prep:select(tonumber(event))
    local rows = res(0) or {}
    for k, row in pairs(rows) do
        types[tonumber(row[1])] = { title = row[2], description = row[3], duration = tonumber(row[4])}
    end
    return types
end

function getTalk(r, db, tid)
    local prep = db:prepare(r, "SELECT `event`, `speaker`, `subject`, `type`, `category`, `abstract`, `bio`, `eco`, `audience`, `difficulty`, `requirements`, `approved` FROM `talks` WHERE `id` = %u LIMIT 1")
    local res = prep:select(tonumber(tid))
    local row = res(-1)
    if row then
        local talk = {
            id = tonumber(tid),
            event = tonumber(row[1]),
            speaker = tonumber(row[2]),
            subject = row[3],
            type = tonumber(row[4]),
            category = row[5] or "*",
            abstract = row[6] or "(None)",
            bio = row[7] or "(None)",
            eco = row[8] or "(None)",
            audience = row[9] or "(None)",
            difficulty = tonumber(row[10]),
            requirements = row[11] or "(None)",
            approved = tonumber(row[12])
        }
        return talk
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
    output = ""
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
    local prep, err = db:prepare(r, "SELECT `id`, `name`, `fullname`, `email`, `unread`, `level` FROM `users` WHERE `cookie` = %s LIMIT 1")
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
            user.id = tonumber(row[1])
            user.name = row[2]
            user.fullname = row[3]
            user.unread = tonumber(row[5])
            user.level = tonumber(row[6])
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