templating.title = "Submit a talk"

if not user.loggedOn then
    print("You need to be registered and logged in to submit a paper.")
    return
end

print[[<h3>Submit a talk</h3>]]
local get = r:parseargs()
local post = r:parsebody()
post.err = ""

if get['e'] then
    local id = tonumber(get['e'])
    local prep = db:prepare(r, "SELECT `title`, `description`, `closes` FROM `events` WHERE `id` = %u LIMIT 1")
    local res = prep:select(id)
    local row = res(-1)
    if not row then
        print("<h4>Sorry: No such event ID</h4>")
        return
    end
    if tonumber(row[3]) < os.time() then
        print("<h4>Error: The CFP deadline for this event has passed.</h4>")
        return
    end
    if post['action'] then
        local title = post['title'] or ""
        local category = post['category'] or ""
        local difficulty = tonumber(post['difficulty'] or 1) or 1
        local bio = post['bio'] or ""
        local abstract = post['abstract'] or ""
        local audience = post['audience'] or ""
        local eco = post['eco'] or ""
        local typ = tonumber(post['type'] or 0) or 0
        if #title == 0 or #category == 0 or #bio == 0 or #abstract == 0 or #audience == 0 or #eco == 0  or typ == 0 then
            post.err = "Please fill out all the fields before submitting your talk"
        else
            local prep, err = db:prepare(r, "INSERT INTO `talks` (`speaker`, `event`, `subject`, `category`, `difficulty`, `bio`, `abstract`, `audience`, `eco`, `approved`, `type`) VALUES (%u, %u, %s, %s, %u, %s, %s, %s, %s, 0, %u)")
            if err then print(err) return end
            prep:query(user.id, id, title, category, difficulty, bio, abstract, audience, eco, typ)
            
            -- Update default bio to match the latest submitted bio
            local prep, err = db:prepare(r, "UPDATE `users` SET `bio` = %s WHERE `id` = %u LIMIT 1")
            prep:query(bio, user.id)
            
            r.headers_out['Location'] = '/user/dashboard';
            return 302
        end
    end
    post.etitle = row[1]
    post.edesc = row[2]
    post.id = id
    
    -- Insert default (latest) bio
    if not post.bio then
        local prep, err = db:prepare(r, "SELECT `bio` FROM `users` WHERE `id` = %u LIMIT 1")
        local res = prep:select(user.id)
        local row = res(-1)
        if row then
            post.bio = row[1]
        end
    end
    
    -- Get talk types
    local types = ""
    local prep = db:prepare(r, "SELECT `id`, `title`, `duration` FROM `talktypes` WHERE `event` = %s")
    local res = prep:select(id)
    local a = 0
    for k, row in pairs(res(0) or {}) do
        a = a + 1
        types = types .. ("<option value=\"%s\">%s (%s minutes)</option>\n"):format(row[1], r:escape_html(row[2]), row[3])
    end
    if a == 0 then
        print("<h2>Event error:</h2><p>There are currently no submission types available to pick for this event, and thus no submissions can be made. Please contact the event administrator about this.</p>")
        return
    end
    local f = getFile(r, "docs/cfp/submit.html")
    f = f:gsub("{{types}}", types)
    f = f:gsub("{{(.-)}}", function(a) return r:escape_html(post[a] or get[a] or "") end)
    print(f)
else
    
    -- Print a listing of open events
    local res = db:select(r, "SELECT `id`, `title`, `description`, `closes` FROM `events` WHERE  `ofb` = 1 AND `closes` > UNIX_TIMESTAMP(NOW()) ORDER BY `closes` ASC")
    local rows = res(0)
    print( ("<h4>There %s currently %u event%s open for new submissions</h4>"):format(#rows == 1 and "is" or "are", #rows, #rows == 1 and "" or "s"))
    print[[<ul>]]
    for k, row in pairs(rows) do
        local closes = os.date("!%A, %d. %B, %Y", tonumber(row[4]))
        print (([[<li><a href="/events?%s">%s</a>: <br/><blockquote>%s<br/><i>CFP closes on %s.</i></blockquote></li>%s]]):format(row[1], r:escape_html(row[2]), r:escape_html(row[3]), closes, "\n"))
    end
    print[[</ul>]]
end