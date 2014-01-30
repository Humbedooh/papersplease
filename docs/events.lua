local id = tonumber(r.args or 0) or 0
local event = getEvent(r, db, id)
if not event or (event.open == 0 and (not user.loggedOn or event.owner ~= user.id)) then
    print("<h3>Error: No such event</h3>")
    return
end

local strcloses = os.date("!%A, %d. %B, %Y", tonumber(event.closes))
local strresolves = os.date("!%A, %d. %B, %Y", tonumber(event.resolves))

local starts = os.date("!%A, %d. %B, %Y", tonumber(event.starts))
local ends = os.date("!%A, %d. %B, %Y", tonumber(event.ends))
local dates = ""
if event.starts ~= 0 and event.ends ~= 0 then
    dates = starts ..  " through " .. ends .. "<br/>" .. (event.location or "")
end

local cfp = ""
if event.closes > os.time() then
    cfp = ([[<p><a href="/cfp/submit?e=%s" class="small [radius round success] button" style="background-color: #60A07F;">Submit a talk &rarr;</a></p>]]):format(id)
else
    cfp = "The CFP for this event is now closed."
end

local owned = ""
if event.owner == user.id then
    owned = "<p><i>This event is owned by you!</i> [<a href='/events/manage?" .. id .. "'>manage</a>]</p>"
    if event.open == 0 then
        owned = owned .. "<p><span style='color: #D50;'>This event is currently not visible to the public!</span></p>"
    end
end

templating.title = event.title
print ( ([[
    <h2>%s</h2>
    <h4>%s</h4>
    %s
    <p>
        %s
    </p>
    <p>
        <b>CFP Closes:</b> %s<br/>
        <b>Schedule announcement:</b> %s<br/>
        <h5>%s</h5>
    </p>
]]):format(event.title, dates, owned, event.description, strcloses, strresolves, cfp)
       )
