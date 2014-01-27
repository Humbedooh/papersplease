local tid = tonumber(r.args or 0) or 0

local prep = db:prepare(r, "SELECT `speaker`, `subject`, `abstract`, `event` FROM `talks` WHERE `id` = %u LIMIT 1")
local res = prep:select(tid)
local row = res(-1)
if not row then
    print("<h3>Error:</h3>Unknown talk ID!")
    return
end

local usr = getUser(r, db, tonumber(row[1]))

local event = "Unknown event"
local prep = db:prepare(r, "SELECT `title` FROM `events` WHERE `id` = %u LIMIT 1")
local res = prep:select(tonumber(row[4]))
local erow = res(-1)
if not erow then
    print("<h3>Error:</h3>Unknown event ID!")
    return
else
    event = erow[1]
end


if usr and event then
    print (("<h2>Talk details:</h2><h3>%s</h3><p><b>Event:</b> <a href='/events?%s'>%s</a><br/><b>Speaker: </b> <a href='/user/profile?%s'>%s</a></p><p>%s</p>"):format(r:escape_html(row[2]), row[4], event, row[1], (usr.fullname and #usr.fullname > 0 and usr.fullname or usr.name), r:escape_html(row[3]) ) )
else
    print("<h3>Error:</h3>Uknown speaker :(")
end