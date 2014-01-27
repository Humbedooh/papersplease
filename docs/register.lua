local post = r:parsebody()
local regged = false
if not post then
    post = { error = "" }
end
if post and post['action'] and post['action'] == 'register' and post['username'] then
    local usr = post.username:match("^%s*(.-)%s*$")
    local password = post.password
    if #usr > 0 and #password > 0 then
        local prep = db:prepare(r, "SELECT `id` FROM `users` WHERE `name` = %s LIMIT 1")
        local res prep:select(usr)
        if res and res(-1) then
            post.error = "Sorry, that username is already in use!"
        else
            local prep, err = db:prepare(r, "INSERT INTO `users` (name, password, fullname, email, cookie) VALUES (%s, %s, %s, %s, %s)")
            prep:query(usr, cycle(password), post.fullname or "", post.email or "", cookie)
            post.error = "Account was successfully registered!"
            user.loggedOn = true
            user.name = usr
            user.fullname = post.fullname or ""
            regged = true
        end
    else
        post.error = "Please select a proper username and password."
    end
end

if not regged then
    local f = getFile(r, "docs/register.html")
    f = f:gsub("{{(.-)}}", function(a) return post[a] or "" end)
    print(f)
else
    print("<h3>Account registered, welcome!</h3>")
end