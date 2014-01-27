return function(r)
    subs = {
        committer = "Committer documents",
        pmc = "PMC documents",
        infra = "Infrastructure documents"
    }
    local docRoot = "/www/reference.a.o/"
    local results = {}
    local get = r:parseargs()
    
    local oquery = (get['query'] or ""):gsub("+", " ")
    local query = oquery:gsub("[^-a-zA-Z+ _.0-9*?]", ""):lower():gsub("([-])","%%%1")
    local words = {} for word in query:gmatch("(%S+)") do table.insert(words, word) end
    if query == "" then
        print("Please enter a search string")
        return "Search the documentation"
    end
    for sub, sect in pairs(subs) do
        for _, filename in pairs(r:get_direntries(docRoot .. "docs/" .. sub) or {}) do
            if (filename:match(".md$") or filename:match(".html$")) and not (filename == "start.md") then
                local f = io.open(docRoot.."docs/" .. sub.."/" ..filename)
                if f then
                    local data = f:read("*a")
                    local matched = true
                    for k, v in pairs(words) do
                        if not data:lower():match(v) then
                            matched = false
                            break
                        end
                    end
                    if matched then
                        title = (data:match("#+[ \t]*([^#{}\r\n]+)") or data:match("<h1>(.-)</h1>")):gsub("[#_=`]+", "")
                        table.insert(results, { filename = "/" .. sub.."/" ..filename:gsub("%.[a-z]+$",""), title = title, section = sect })
                    end
                    f:close()
                end
            end
        end
    end
    
    if #results == 0 then
        print("<h3>Your search for <code>"..oquery.."</code> yielded no results.</h3>")
    else
        print("<h3>Your search for <code>"..oquery.."</code> yielded " .. #results .. " result" .. (#results == 1 and "" or "s") .. ":</h3>")
        print("<ul>")
        for k, v in pairs(results) do
            print (("<li><a href='%s'>%s</a> <small><i>In %s</i></small></li>"):format(v.filename, v.title, v.section))
        end
        print("</ul>")
    end
    return "Search the documentation"
end