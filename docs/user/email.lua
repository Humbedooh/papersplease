--[[
CREATE TABLE email (
sender INT(32),
recipient INT(32),
date INT(32),
subject VARCHAR(128),
text TEXT,
unread INT(3),
RID int(11) NOT NULL auto_increment,
primary KEY (RID));
]]
templating.title = "Emails"
if not user.loggedOn then
    print("You need to be logged on to use this feature!")
    return
end
local get = r:parseargs()
local people = {}

function getSubject(a)
    local title = "Unknown talk"
    local prep = db:prepare(r, "SELECT `subject` FROM `talks` WHERE `id` = %u LIMIT 1")
    local res = prep:select(tonumber(a or 0) or 0)
    local row = res(-1)
    if row then
        title = row[1]
    end
    return "<b><a href='/talks?"..a.."'><span style='color: #0F6D89;'>" .. title .. "</span></a></b>"
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

-- Email list
if not (get['i'] or get['r'] or get['c'] or get['a'] or get['d']) then
    if get['s'] and get['s'] == "1" then
        print[[<h4>Your email was sent!</h4>]]
    end
    print[[<h3>Emails:</h3>[<a href="/user/email?c=0">Compose</a>]<br/><table style="width: 800px;"><thead><tr><th>Date</th><th>Sender</th><th>Subject</th><th>Actions</th></tr></thead><tbody>]]
    local p = tonumber(get['p'] or 0) or 0
    local t = p * 20
    local prep, err = db:prepare(r, "SELECT `mid`, `sender`, `date`, `subject`, `unread` FROM `emails` WHERE `recipient` = %u ORDER BY `mid` DESC LIMIT %u, 21 ")
    if err then print(err) return end
    local res = prep:select(user.id, t)
    if res then
        for k, row in rows(res, true) do
            local sid = row[2]
            local unread = (row[5] == "1" and true) or false
            if not people[sid] then
                people[sid] = getUser(r, db, sid) or { fullname = "(non-existent user)" }
            end
            local date = row[3] or os.date("%c", os.time())
            row[4] = r:escape_html(row[4])
            if unread then
                row[4] = "<b>" .. row[4] .. "</b>"
            end
            local name = people[sid].fullname and people[sid].fullname or people[sid].name
            print(( "<tr><td>%s</td><td><a href='/user/profile?%s'>%s</a></td><td><a href='/user/email?i=%s'>%s</a></td><td> [<a href='/user/email?c=%s'>Reply</a>] &nbsp; [<a href='/user/email?d=%s'>Delete</a>]</td></tr>"):format(date, sid, name, row[1], row[4], row[1], row[1]))
        end
    end
    print[[</tbody></table>]]
end


-- View an email
if get['i'] then
    local mid = tonumber(get['i'] or 0) or 0
    local prep = db:prepare(r, "SELECT `sender`, `date`, `subject`, `text`, `unread` FROM `emails` WHERE `recipient` = %u AND `mid` = %u LIMIT 1")
    local res = prep:select(user.id, mid)
    if res then
        local row = res(-1)
        if row then
            if row[5] == "1" then
                local prep = db:prepare(r, "UPDATE `emails` SET `unread` = 0 WHERE `mid` = %u LIMIT 1")
                prep:query(mid)
                local prep = db:prepare(r, "UPDATE `users` SET `unread` = (`unread` - 1) WHERE `id` = %u LIMIT 1")
                prep:query(user.id)
            end
            local email = {}
            local sender = getUser(r, db, tonumber(row[1])) or { name= "Non-existent user", id=0}
            email.sender = (sender.fullname and #sender.fullname > 0 and sender.fullname) or sender.name
            email.sid = sender.id
            email.id = mid
            email.date = row[2] or os.date("%c", os.time())
            email.subject = r:escape_html(row[3])
            email.message = r:escape_html(row[4]):gsub("\n", "<br/>\n"):gsub("%[#t([0-9]+)%]", function(a) return getSubject(a) or "<i>(unknown talk)</i>" end):gsub("%[#e([0-9]+)%]", function(a) return getEvent(a) or "<i>(unknown event)</i>" end)
            local out = ( [[
                    <h3>View email:</h3>
                    <a href="/user/email">Back to mail list</a><br/>
                    <table style="width: 800px;">
                    <tr><th>From:</th><td><a href="/user/profile?{{sid}}">{{sender}}</a> &nbsp; [<a href="/user/email?c={{id}}">Reply</a>]  [<a href="/user/email?d={{id}}">Delete</a>]</td></tr>
                    <tr><th>Date:</th><td>{{date}}</td></tr>
                    <tr><th>Subject:</th><td>{{subject}}</td></tr>
                    <tr><td colspan="2">{{message}}</td></tr>
                    </table>
                ]] ):gsub("{{(.-)}}", email)
            print (out)
        else
            print("<h3>Error:</h3>No such email!")
        end
    end
end


-- Delete an email
if get['d'] then
    local mid = tonumber(get['d'] or 0) or 0
    local prep = db:prepare(r, "SELECT `sender`, `date`, `subject`, `text`, `unread` FROM `emails` WHERE `recipient` = %u AND `mid` = %u LIMIT 1")
    local res = prep:select(user.id, mid)
    if res then
        local row = res(-1)
        if row then
            if row[5] == "1" then
                local prep = db:prepare(r, "UPDATE `emails` SET `unread` = 0 WHERE `mid` = %u LIMIT 1")
                prep:query(mid)
                local prep = db:prepare(r, "UPDATE `users` SET `unread` = (`unread` - 1) WHERE `id` = %u LIMIT 1")
                prep:query(user.id)
            end
            local prep = db:prepare(r, "DELETE FROM `emails` WHERE `mid` = %u LIMIT 1")
            prep:query(mid)
        end
    end
    r.headers_out['Location'] = "/user/email"
    return 302
end


-- Send away an email
if get['a'] and get['a'] == 'send' then
    local post = r:parsebody(1024*1024)
    local recipient = post['recipient']:match("<(.-)>") or post['recipient']
    local subject = post['subject']
    local message = post['message']
    local prep = db:prepare(r, "SELECT `id` FROM `users` WHERE `name` = %s LIMIT 1")
    local res = prep:select(recipient)
    local row = res(-1)
    if row then
        local prep = db:prepare(r, "INSERT INTO `emails` (`recipient`, `sender`, `date`, `subject`, `text`, `unread`) VALUES (%u, %u, NOW(), %s, %s, 1)")
        prep:query(tonumber(row[1]), user.id, subject, message)
        
        -- Increment unread email number for recipient account
        local prep = db:prepare(r, "UPDATE `users` SET `unread` = (`unread` + 1) WHERE `id` = %u LIMIT 1")
        prep:query(tonumber(row[1]))
        
        r.headers_out['Location'] = "/user/email?s=1"
        return 302
    else
        get['c'] = post['id'] or 0
        get['err'] = "Failed to send: No such recipient!"
    end
end

-- Reply to an email (or compose a new)
if get['c'] then
    local mid = tonumber(get['c'] or 0) or 0
    local prep = db:prepare(r, "SELECT `sender`, `date`, `subject`, `text`, `unread` FROM `emails` WHERE `recipient` = %u AND `mid` = %u LIMIT 1")
    local res = prep:select(user.id, mid)
    local email = {subject="", sid="", sender="", message="", err = ""}
    if res then
        local row = res(-1)
        if row then
            local sender = getUser(r, db, tonumber(row[1])) or { name= "Non-existent user", id=0}
            email.sender = (sender.fullname and #sender.fullname > 0 and sender.fullname) or sender.name
            if email.sender ~= sender.name then
                email.sender = email.sender .. " &lt;" .. sender.name .. "&gt;"
            end
            email.sid = sender.id
            email.id = mid
            email.subject = r:escape_html("Re: " .. row[3])
            email.message = r:escape_html("\n\n\n---------- Original message follows --------\n" .. row[4])
        end
    end
    if get['err'] then
        email.err = get['err']
    end
    if get['u'] then
        local usr = getUser(r, db, get['u'])
        email.sender = (usr.fullname and #usr.fullname > 0 and usr.fullname) or usr.name
        if email.sender ~= usr.name then
            email.sender = email.sender .. " &lt;" .. usr.name .. "&gt;"
        end
    end
    local out = ( [[
            <h3>Reply to email:</h3>
            <form action="/user/email?a=send" method="POST">
            <input type="hidden" name="mid" value="{{id}}"/>
            <table style="width: 800px;">
            <tr><th>To:</th><td><input type="text" placeholder="Enter a recipient username" name="recipient" value="{{sender}}" /></td></tr>
            <tr><th>Subject:</th><td><input type="text" placeholder="Enter a subject" name="subject" value="{{subject}}" /></td></tr>
            <tr><td colspan="2"><textarea style="height: 300px; width: 780px;" name="message">{{message}}</textarea></td></tr>
            <tr><td colspan="2"><input type="submit" value="Send email"/></td></tr>
            </table>
            <h3>{{err}}</h3>
        ]] ):gsub("{{(.-)}}", email)
    print (out)
end

