templating.title = "Edit a talk"

if not user.loggedOn then
    print("You need to be registered and logged in to submit a paper.")
    return
end

print[[<h3>Edit a talk</h3>]]
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
    post.etitle = row[1]
    post.edesc = row[2]
    post.id = id
    
    if post['action'] then
        local title = post['title'] or ""
        local category = post['category'] or ""
        local difficulty = tonumber(post['difficulty'] or 1) or 1
        local bio = post['bio'] or ""
        local abstract = post['abstract'] or ""
        local audience = post['audience'] or ""
        local eco = post['eco'] or ""
        local typ = tonumber(post['type'] or 0) or 0
        local tid = tonumber(post['tid'] or 0) or 0
        if #title == 0 or #category == 0 or #bio == 0 or #abstract == 0 or #audience == 0 or #eco == 0  or typ == 0 or tid == 0 then
            post.err = "Please fill out all the fields before submitting your talk"
        else
            local prep, err = db:prepare(r, "UPDATE `talks` SET `subject` = %s, `category` = %s, `difficulty` = %s, `bio` = %s, `abstract` = %s, `audience` = %s, `eco` = %s, `type` = %s WHERE `id` = %s AND `speaker` = %u LIMIT 1")
            if err then print(err) return end
            prep:query(title, category, difficulty, bio, abstract, audience, eco, typ, tid, user.id)
            
            -- Update default bio to match the latest submitted bio
            local prep, err = db:prepare(r, "UPDATE `users` SET `bio` = %s WHERE `id` = %u LIMIT 1")
            prep:query(bio, user.id)
            
            r.headers_out['Location'] = '/user/dashboard';
            return 302
        end
    else
        local tid = tonumber(get.t or 0) or 0
        local prep = db:prepare(r, "SELECT `event`, `subject`, `category`, `difficulty`, `bio`, `abstract`, `audience`, `eco`, `type` FROM `talks` WHERE `id` = %u and `speaker` = %u LIMIT 1")
        local res = prep:select(tid, user.id)
        local row = res(-1)
        if not row then
            print("<h4>Error: invalid talk ID supplied!</h4>")
            return
        end
        post.tid = tid
        post.id = row[1]
        post.title = row[2]
        post.category = row[3]
        post.difficulty = row[4]
        post.bio = row[5]
        post.abstract = row[6]
        post.audience = row[7]
        post.eco = row[8]
        post.type = row[9]
    end
    
    -- Get talk types
    local types = ""
    local prep = db:prepare(r, "SELECT `id`, `title`, `duration` FROM `talktypes` WHERE `event` = %s")
    local res = prep:select(id)
    for k, row in pairs(res(0) or {}) do
        types = types .. ("<option value=\"%s\">%s (%s minutes)</option>\n"):format(row[1], r:escape_html(row[2]), row[3])
    end
    
    local f = getFile(r, "docs/cfp/edit.html")
    f = f:gsub("{{types}}", types)
    f = f:gsub("{{(.-)}}", function(a) return r:escape_html(post[a] or get[a] or "") end)
    print(f)
end