local post = r:parsebody()
local success = false
local err = ""
if post and post.username and post.password then
    local usr = post.username
    local pass = cycle(post.password)
    local prep = db:prepare(r, "SELECT `id` FROM `users` WHERE `name` = %s AND `password` = %s LIMIT 1")
    if prep then
        local res = prep:select(usr, pass)
        if res then
            local row = res(-1)
            if row then
                local prep = db:prepare(r, "UPDATE `users` SET `cookie` = %s WHERE `id` = %u LIMIT 1")
                prep:query(cookie, row[1])
                r.headers_out['Location'] = "/"
                return 302
            end
        end
    end
    err = "Wrong username or password entered!"
end

if not success then
    print(( [[
<h4>Log on</h4>
<p>Enter your desired username and password to register an account.<br/>
Your full name and email address is optional, but it might help you get your talk submitted.</p>
<form action="/logon" method="POST">
  <input name="username" type="text" value="%s" placeholder="Enter your username" style="width: 300px;"/><br/>
  <input name="password" type="password" value="%s" placeholder="Enter your password" style="width: 300px;"/><br/>
  <input type="hidden" name="action" value="logon"/>
  <input type="submit" value="Log on"/>
  <h4>%s</h4>
</form>]]):format(post.username or "", post.password or "", err or "")
         )
end
