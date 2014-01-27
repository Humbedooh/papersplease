local prep = db:prepare(r, "UPDATE `users` SET `cookie` = '!nil!' WHERE `cookie` = %s LIMIT 1")
if prep then
    prep:query(cookie)
    r:setcookie("cfp", "0")
    r.headers_out['location'] = "/"
    return 302
end