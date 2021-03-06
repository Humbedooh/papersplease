templating.title = "Dashboard"

if not user.loggedOn then
    print("You need to be logged on to use this feature!")
    return
end

if user.unread > 0 then
    print("You have <a href='/user/email'>unread mail</a>!")
else
    print("Not much going on here right now. No new mail for you either :(")
end


function getEvent(a)
    local title = "Unknown event"
    local prep = db:prepare(r, "SELECT `title` FROM `events` WHERE `id` = %u LIMIT 1")
    local res = prep:select(tonumber(a or 0) or 0)
    local row = res(-1)
    if row then
        title = row[1]
    end
    return "<b><a href='/events?"..a.."'><span style='color: #0A935F;'>"..title.."</span></a></b>"
end

local get = r:parseargs()
if get.d then
    local id = tonumber(get.d or 0) or 0
    local prep, err = db:prepare(r, "DELETE FROM `talks` WHERE `speaker` = %u AND `id` = %u LIMIT 1")
    prep:query(user.id, id)
    r.headers_out['Location'] = "/user/dashboard"
    return 302
end

-- Pending talks
local prep = db:prepare(r, "SELECT `id`, `event`, `subject` FROM `talks` WHERE `approved` = 0 AND `speaker` = %u")
local res = prep:select(user.id)
local rows = res(0)
if rows and #rows > 0 then
    print[[<h4>Pending talks:</h4><p>You have the following talks pending approval from the content selection committee:</p>]]
    print[[<table><thead><tr><th>Conference</th><th>Talk</th><th>Status</th><th style="width: 150px;">Actions</th></tr></thead><tbody>]]
    local events = {}
    for k, row in pairs(rows) do
        local eid = row[2]
        if not events[eid] then
            events[eid] = getEvent(eid)
        end
        print ( ([[<tr><td><a href="/events?%s">%s</a></td><td><a href="/talks?%s">%s</a></td><td>Pending review</td><td>[<a href="/cfp/edit?e=%s&t=%s">Edit</a>] &nbsp; [<a href="?d=%s">Delete</a>]</td></tr>]]):format(row[2], events[eid], row[1], r:escape_html(row[3]), eid, row[1], row[1]) )
    end
    print[[</tbody></table>]]
end

-- Events owned
local prep = db:prepare(r, "SELECT `id`, `title`, `description` FROM `events` WHERE `owner` = %u ORDER BY `id` ASC")
local res = prep:select(user.id)
local rows = res(0)
if rows and #rows > 0 then
    print[[<h3>Events managed by you:</h3>]]
    for k, row in pairs(rows) do
        print( ([[<h4><a href="/events?%s">%s</a></h4><p>[<a href="/events/manage?%s">Manage</a>]<blockquote>%s</blockquote></p>]]):format(row[1], r:escape_html(row[2]), row[1], r:escape_html(row[3])) )
    end
end

-- Add a new event
if user.level > 1 then
    print[[<h5><a href="/events/create">Create a new event</a></h5>]]
end