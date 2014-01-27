local id = tonumber(r.args or 0) or 0
local usr = getUser(r, db, id)
if not usr then
    print("<h4>No such user :(</h4>")
    return
end

local img = ""
if usr.email and #usr.email > 0 then
    img = "<img src='https://1.gravatar.com/avatar/" .. r:md5(usr.email) .. "'/>"
end
local fullname = r:escape_html(usr.fullname and #usr.fullname > 0 and usr.fullname or usr.name)

templating.title = "Speaker profile: " .. fullname

-- Grab approved talks, in date order
local prep = db:prepare(r, "SELECT `id`, `subject` FROM `talks` WHERE `speaker` = %u AND `approved` = 1 ORDER BY `id` DESC")
local res = prep:select(id)
local rows = res(0)

print( ([[
    <h2>%s %s</h2>
    <p>Profile goes here</p>
]]):format(img, fullname))

if rows and #rows > 0 then
    print[[<h3>Talks by this speaker:</h3>]]
    for k, row in pairs(rows) do
        print("- <a href='/talks?" .. row[1] .."'>" .. r:escape_html(row[2]) .. "</a><br/>\n")
    end
else
    print[[<h5>This speaker does not have any previous or upcoming talks listed</h5>]]
end

if user.loggedOn then
    print( ([[<a href="/user/email?c=0&u=%u">Write a message to %s</a>]]):format(id, fullname) )
end