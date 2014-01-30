if not user.loggedOn then
    print("This feature requires you to be logged on")
    return
end

local get = r:parseargs()
local post = r:parsebody()
local dmp = require 'diff_match_patch'


local eid = tonumber(get.event or 0) or 0

if eid == 0 then
    -- Get a list of events where this user is either owner or reviewer
    local events = {}
    
    -- Owns events?
    local prep = db:prepare(r, "SELECT `id` FROM `events` WHERE `owner` = %u AND `ends` > UNIX_TIMESTAMP(NOW())")
    local res = prep:select(user.id)
    for k, row in rows(res, true) do
        events[tonumber(row[1])] = 2;
    end
    
    -- Reviewer?
    local prep = db:prepare(r, "SELECT `event` FROM `reviewers` WHERE `uid` = %u")
    local res = prep:select(user.id)
    for k, row in rows(res, true) do
        events[tonumber(row[1])] = 1;
    end
    
    -- List the events
    print("<h3>Events you have review access to:</h3>")
    local a = 0
    print[[<ul>]]
    for eid, typ in pairs(events) do
        a = a + 1
        local event = getEvent(r, db, eid)
        print( ([[<li><a href="/cfp/review?event=%u">%s</a><br/><blockquote>%s</blockquote></li>]]):format(event.id, event.title, event.description) )
    end
    print[[</ul>]]
    if a == 0 then
        print("<p>You do not have access to any events at the moment.</p>")
    end
else
    -- Get event data
    local event = getEvent(r, db, eid)
    
    -- Various errors
    if not event then
        print("<h3>Error: No such event!</h3>")
        return
    elseif event.ends < os.time() then
        print("<h3>Error: This event has ended!</h3>")
        return
    end
    
    -- Check if the reviewer has access to review this event
    local canReview = (event.owner == user.id) and true or false
    if not canReview then
        local prep = db:prepare(r, "SELECT `id` FROM `reviewers` WHERE `event` = %u and `uid` = %u LIMIT 1")
        local res = prep:select(eid, user.id)
        canReview = res(-1) and true or false
    end
    
    -- If not a reviewer (or owner) of said event, do the sad panda thing
    if not canReview then
        print("<h3>Error:</h3><p>You are not listed as a reviewer of this event. If you believe this to be an error, please contact the event manager and have them add you as a reviewer. Be sure to tell them your username.</p>")
        return
    end
    
    -- Now, let's get to the reviewing!!
    print("Reviewing " .. r:escape_html(event.title))
    
    
    -- No talk selected? Let's show 'em all then!
    if not get.talk then
        local prep = db:prepare(r, "SELECT `id`, `speaker`, `subject`, `category`, `type` FROM `talks` WHERE `event` = %u AND `approved` = 0 ORDER BY `id`") -- only show unapproved talks.
        local res = prep:select(event.id)
        local rows = res(0)
        if #rows == 0 then
            print("<p>There are no talks awaiting review.</p>")
            return
        end
        local types = getTalkTypes(r, db, event.id)
        print(( "<h4>Talks awaiting review (%u):</h4>"):format(#rows) )
        print[[<small><ol>]]
        for k, row in pairs(rows) do
            local usr = getUser(r, db, row[2])
            if usr then
                local t = tonumber(row[5])
                if types[t] then -- If valid submission type:
                    print ( ([[<li><a href="/cfp/review?event=%u&talk=%u">%s</a><blockquote><b>Submitted by:</b> %s<br/><b>Type:</b> %s (%u minutes)</blockquote></li>]]):format(event.id, row[1], row[3], usr.fullname, types[t].title, types[t].duration) )
                end
            end
        end
        print[[</ol></small>]]
        
    -- Talk selected? Let's show things...
    else
        
        -- First, get talk data and ensure it matches the request
        local talk = getTalk(r, db, tonumber(get.talk))
        if not talk or talk.event ~= event.id then
            print("<h3>Error:</h3>")
            print("<p>This talk does not exist or is not assigned to this event. If you believe this to be an error, please contact the event manager.</p>")
            return
        end
        
        -- Did we cast a vote or leave a comment? Do some stuff first then!
        if post.vote and post.vote ~= "none" then
            
            -- Delete any votes cast earlier
            local prep = db:prepare(r, "DELETE FROM `review_votes` WHERE `talk` = %u AND `uid` = %u LIMIT 1")
            prep:query(talk.id, user.id)
            
            -- Cast a vote
            local prep = db:prepare(r, "INSERT INTO `review_votes` (`event`, `talk`, `uid`, `vote`) VALUES (%u, %u, %u, %s)")
            prep:query(event.id, talk.id, user.id, post.vote) -- no need to tonumber() the vote, as it's a string value
            
            print("<h4 style='color: #693;'>Your vote has been cast</h4>")
        end
        
        -- Did we comment on stuffs?
        if post.comment and post.comment ~= "" then
            local internal = post.share and post.share == "yes" and 0 or 1
            local prep = db:prepare(r, "INSERT INTO `review_comments` (`event`, `talk`, `uid`, `comment`, `internal`) VALUES (%u, %u, %u, %s, %u)")
            prep:query(event.id, talk.id, user.id, post.comment, internal)
            
            if internal == 0 then
                local subject = "Comment regarding your submission for " .. event.title .. "..."
                local text = ("%s has commented on your talk, [#t%u] at [#e%u]\n\n---------\n%s"):format(user.fullname, talk.id, event.id, post.comment)
                local prep = db:prepare(r, "INSERT INTO `emails` (`sender`, `recipient`, `date`, `unread`, `subject`, `text`) VALUES (%u, %u, NOW(), 1, %s, %s)")
                prep:query(user.id, talk.speaker, subject, text)
                prep = db:prepare(r, "UPDATE `users` SET `unread` = (`unread` + 1) WHERE `id` = %u LIMIT 1")
                prep:query(talk.speaker)
            end
        end
        
        -- did we edit something in the talk??
        if get.edit then
            local val = post.value or ""
            local what = get.edit:match("([a-z]+)")
            if what then
                local patch = ""
                if what == 'bio' then patch = dmp.patch_toText(dmp.patch_make(talk.bio, val)) end
                if what == 'abstract' then patch = dmp.patch_toText(dmp.patch_make(talk.abstract, val)) end
                if what == 'audience' then patch = dmp.patch_toText(dmp.patch_make(talk.audience, val)) end
                if what == 'eco' then patch = dmp.patch_toText(dmp.patch_make(talk.eco, val)) end
                if what == 'requirements' then patch = dmp.patch_toText(dmp.patch_make(talk.requirements, val)) end
                if what == 'category' then patch = dmp.patch_toText(dmp.patch_make(talk.category, val)) end
                
                -- Add patch to history
                local prep = db:prepare(r, "INSERT INTO `talk_edits` (`talk`, `uid`, `time`, `field`, `patch`) VALUES (%u, %u, UNIX_TIMESTAMP(NOW()), %s, %s)")
                prep:query(talk.id, user.id, what, patch)
                
                -- Apply patch
                prep = db:prepare(r, "UPDATE `talks` SET `" .. what .. "` = %s WHERE `id` = %u LIMIT 1")
                prep:query(val, talk.id)
                
                -- Refresh talk data
                talk = getTalk(r, db, talk.id)
            end
        end
        
        -- Viewing edit history??
        if get.history then
            local prep = db:prepare(r, "SELECT `uid`, `time`, `field`, `patch` FROM `talk_edits` WHERE `talk` = %u")
            local res = prep:select(talk.id)
            local rows = res(0) or {}
            print(("<h4>Edit history for %s:</h4>"):format(talk.subject))
            print(("<h5>&larr; <a href='/cfp/review?event=%u&talk=%u'>Back to review</a></h5>"):format(event.id, talk.id))
            print [[<ol>]]
            for k, row in pairs(rows) do
                local editor = getUser(r, db, row[1])
                local when = os.date("!%c", tonumber(row[2]))
                local patch = row[4]
                patch = patch:gsub("(+[^\r\n]+)", "<font color='#393'>%1</font>"):gsub("(-[^\r\n]+)", "<font color='#963'>%1</font>")
                print (("<li>%s: %s edited the field '%s':<blockquote><pre>%s</pre></blockquote></li>"):format(when, editor.fullname,row[3], patch))
            end
            print[[</ol>]]
            return
        end
            
        -- Check if there are edits to this review
        local prep = db:prepare(r, "SELECT COUNT(*) FROM `talk_edits` WHERE `talk` = %u")
        local res = prep:select(talk.id)
        local row = res(-1)
        if row then
            local howmany = tonumber(row[1])
            print( ("<h5>There have been %u edit(s) to this submission. <a href='/cfp/review?event=%u&talk=%u&history=view'>View edit history</a></h5>"):format(howmany, event.id, talk.id))
        end
        
        -- Print out the talk details
        print(("<p>&larr; <a href='/cfp/review?event=%u'>Back to talk selection</a></p><h3>Reviewing: %s</h3>"):format(event.id, talk.subject))
        local speaker = getUser(r, db, talk.speaker)
        local types = getTalkTypes(r, db, event.id)
        if not types[talk.type] then
            types[talk.type] = { title = "Unknown type?!", duration = 0, id = 0 }
        end
        local alevel = { "Beginner", "Intermediate", "Advanced" }
        print(("<p><b>Author:</b> <a href='/user/profile?%u'>%s</a><br/>"):format(talk.speaker, speaker.fullname) )
        print ( ("<b>Type:</b> %s (%u minutes)<br/>"):format(types[talk.type].title, types[talk.type].duration) )
        print ( ("<b>Audience level:</b> %s</p>"):format(alevel[talk.difficulty]) )
        print( ("<p><form action='/cfp/review?event=%u&talk=%u&edit=category' method='POST'><b>Category:</b>&nbsp; [<a href='#' onclick='editThis(\"category\");'>edit</a>]<blockquote id='category'>%s</blockquote></form> "):format(event.id, talk.id, r:escape_html(talk.category)) )
        print( ("<p><form action='/cfp/review?event=%u&talk=%u&edit=bio' method='POST'><b>Bio:</b>&nbsp; [<a href='#' onclick='editThis(\"bio\");'>edit</a>]<blockquote id='bio'>%s</blockquote></form> "):format(event.id, talk.id, r:escape_html(talk.bio)) )
        print( ("<b><form action='/cfp/review?event=%u&talk=%u&edit=abstract' method='POST'>Abstract:</b>&nbsp; [<a href='#' onclick='editThis(\"abstract\");'>edit</a>]<blockquote id='abstract'>%s</blockquote> </form>"):format(event.id, talk.id, r:escape_html(talk.abstract)) )
        print( ("<b><form action='/cfp/review?event=%u&talk=%u&edit=audience' method='POST'>Audience:</b>&nbsp; [<a href='#' onclick='editThis(\"audience\");'>edit</a>]<blockquote id='audience'>%s</blockquote> </form>"):format(event.id, talk.id, r:escape_html(talk.audience)) )
        print( ("<b><form action='/cfp/review?event=%u&talk=%u&edit=eco' method='POST'>Benefits to Ecosystem:</b>&nbsp; [<a href='#' onclick='editThis(\"eco\");'>edit</a>]<blockquote id='eco'>%s</blockquote> </form>"):format(event.id, talk.id, r:escape_html(talk.eco)) )
        print( ("<b><form action='/cfp/review?event=%u&talk=%u&edit=requirements' method='POST'>Technical requirements:</b>&nbsp; [<a href='#' onclick='editThis(\"requirements\");'>edit</a>]<blockquote id='requirements'>%s</blockquote></form>"):format(event.id, talk.id, r:escape_html(talk.requirements)) )
        print[[
            <script>
            function editThis(what) {
                var obj = document.getElementById(what);
                var ta = document.createElement('textarea');
                ta.name = "value";
                ta.style.width = "600px";
                ta.style.height = "150px";
                ta.innerHTML = obj.innerHTML;
                
                var btn = document.createElement('input');
                btn.type = 'submit';
                btn.value = 'Save changes';
                obj.parentNode.appendChild(btn);
                
                obj.parentNode.replaceChild(ta, obj);
                
            }
            </script>
        ]]
        -- Review form for doing stuff, this is static
        local f = getFile(r, "docs/cfp/review_form.html"):gsub("{{(.-)}}", get)
        print(f)
        
        -- Print comments and what have you
        print("<h3>Comments:</h3><p>Note, that some comments may be for reviewers only. You should not share these comments outside of the reviewer circle. Comments marked with 'shared' are visible to the speaker.</p><hr/>")
        local prep = db:prepare(r, "SELECT `uid`, `comment`, `internal` FROM `review_comments` WHERE `talk` = %u")
        local res = prep:select(talk.id)
        for k, row in pairs(res(0) or {}) do
            local usr = getUser(r, db, row[1])
            if usr then
                local shared = (row[3] == "0" and "<br/><i>Shared with speaker</i>") or ""
                print( ([[<hr/><p><b><a href="/user/profile?%u">%s</a>:</b>%s<blockquote>%s</blockquote>]]):format(usr.id, usr.fullname, shared, row[2]) )
            end
        end
    end
        
    
end