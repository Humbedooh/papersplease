if not user.loggedOn or user.level < 2 then
    print("You need to be logged on and have event level access to use this feature.")
    return
end

local get = r:parseargs()
local post = r:parsebody()

if post and post.title and post.starts and post.ends and post.closes and post.resolves then
 
    event = {
        title = post.title,
        owner = user.id,
        description = post.description,
        starts = parseymd(post.starts),
        ends = parseymd(post.ends),
        location = post.location,
        closes = parseymd(post.closes),
        resolves = parseymd(post.resolves),
        open = 0
    }
    saveEvent(r, db, event)
    
    print("<h4>Event created!</h4><p>The event has been created, but is not yet open to the public. To do so, you should first create submission types so people can submit papers. Once that is done, you must manually switch the event to 'open' in the management console found on your <a href='/user/dashboard'>dashboard</a>.</p>")
    return
end
local f = getFile(r, "docs/events/create.html")
f = f:gsub("{{(.-)}}", function(a) return r:escape_html(post[a] or get[a] or "") end)
print(f)