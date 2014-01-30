templating.title = "Manage event"

if not user.loggedOn then
    print("You need to be registered and logged in to use this feature.")
    return
end

-- Get args, rewrite if need be
local get = r:parseargs()
if get.event then
    r.args = get.event
end
local event = tonumber(r.args or 0) or 0
get.event = event

-- Get basic event information
local event = getEvent(r, db, event)
if not event or not event.owner == user.id then
    print("<h4>Error: no such event!</h4>")
    return
end
print("<h3>Manage event: <a href='/events?" .. event.id .. "'>" .. event.title .. "</a></h3>")
get.etitle = event.title

if get.p then
    local post = r:parsebody()
    if get.p == 'basic' then
        if post and post.title and post.starts and post.ends and post.closes and post.resolves then
            event.title = post.title
            event.description = post.description
            event.starts = parseymd(post.starts)
            event.ends = parseymd(post.ends)
            event.closes = parseymd(post.closes)
            event.resolves = parseymd(post.resolves)
            event.open = tonumber(post.open or 0) or 0
            event.location = post.location
            saveEvent(r, db, event)
            post.err = "Event data saved at " .. os.date("%c") .. "!"
        end
        get.starts = os.date("%Y-%m-%d", event.starts)
        get.ends = os.date("%Y-%m-%d", event.ends)
        get.closes = os.date("%Y-%m-%d", event.closes)
        get.resolves = os.date("%Y-%m-%d", event.resolves)
        local f = getFile(r, "docs/events/manage_basic.html"):gsub("{{(.-)}}", function(a) return get[a] or post[a] or event[a] or "" end)
        print(f)
        
    elseif get.p == 'types' then
        if get.d then
            local tid = tonumber(get.d or 0) or 0
            local prep = db:prepare(r, "DELETE FROM `talktypes` WHERE `event` = %u and `id` = %u LIMIT 1")
            prep:query(event.id, tid)
        end
        if post and post.title and post.description and post.duration then
            local prep = db:prepare(r, "INSERT INTO `talktypes` (event, title, description, duration) VALUES (%u, %s, %s, %u)")
            prep:query(event.id, post.title, post.description, tonumber(post.duration or 45) or 45)
        end
        local prep = db:prepare(r, "SELECT `id`, `title`, `description`, `duration` FROM `talktypes` WHERE `event` = %u")
        local res = prep:select(event.id)
        local list = ""
        for k, row in pairs(res(0) or {}) do
            list = list .. ([[<li>%s<blockquote><b>Duration:</b> %s minutes<br/><b>Description:</b> %s<br/><a href="/events/manage?event=%s&p=types&d=%u">Delete type</a></blockquote></li>]]):format(row[2], row[4], row[3], event, row[1])
        end
        get.list = "<ul>"..list.."</ul>"
        local f = getFile(r, "docs/events/manage_types.html"):gsub("{{(.-)}}", get)
        print(f)
    elseif get.p == 'reviewers' then
        get.err = ""
        if get.d then
            local tid = tonumber(get.d or 0) or 0
            local prep = db:prepare(r, "DELETE FROM `reviewers` WHERE `event` = %u and `uid` = %u LIMIT 1")
            prep:query(event.id, tid)
        end
        if post and post.user and post.category then
            local prep = db:prepare(r, "SELECT `id` FROM `users` WHERE `name` = %s LIMIT 1")
            local res = prep:select(post.user)
            local row = res(-1)
            if not row then
                get.err = "No such user. Did you misspell the name?"
            else
                local prep = db:prepare(r, "INSERT INTO `reviewers` (event, uid, categories) VALUES (%u, %u, %s)")
                prep:query(event.id, tonumber(row[1]), post.category)
            end
        end
        local prep = db:prepare(r, "SELECT `uid`, `categories` FROM `reviewers` WHERE `event` = %u")
        local res = prep:select(event.id)
        local list = ""
        for k, row in pairs(res(0) or {}) do
            local usr = getUser(r, db, tonumber(row[1]))
            if usr then
                list = list .. ([[<li><a href="/user/profile?%u">%s</a><blockquote><b>Categories:</b> %s <br/><a href="/events/manage?event=%s&p=reviewers&d=%u">Delete reviewer</a></blockquote></li>]]):format(usr.id, usr.name, row[2], event.id, row[1])
            end
        end
        get.list = "<ul>"..list.."</ul>"
        local f = getFile(r, "docs/events/manage_reviewers.html"):gsub("{{(.-)}}", get)
        print(f)
    end
    
else
    
    local f = getFile(r, "docs/events/manage_index.html"):gsub("{{(.-)}}", get)
    print(f)
end