if not user.loggedOn then
    print("You need to be logged on to use this feature!")
    return
end

if user.unread > 0 then
    print("You have <a href='/user/email'>unread email</a>!")
end