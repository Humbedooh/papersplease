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


local prep = db:prepare(r, "SELECT `id`, `event`, `subject` FROM `talks` WHERE `approved` = 0 AND `speaker` = %u")
local res = prep:select(user.id)
local rows = res(0)
if rows and #rows > 0 then
    print[[<h4>Pending talks:</h4><p>You have the following talks pending approval from the content selection committee:</p>]]
    print[[<table><thead><tr><th>Conference</th><th>Talk</th></td></thead><tbody>]]
    local events = {}
    for k, row in pairs(rows) do
        local eid = row[2]
        if not events[eid] then
            events[eid] = getEvent(eid)
        end
        print ( ([[<tr><td><a href="/events?%s">%s</a></td><td><a href="/talks?%s">%s</a></td></tr>]]):format(row[2], events[eid], row[1], r:escape_html(row[3])) )
    end
    print[[</tbody></table>]]
end