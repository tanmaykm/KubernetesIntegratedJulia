using HTTP, JSON

function query(pattern)
    resp = HTTP.request("POST", "http://127.0.0.1:30005/search", [], "{\"pattern\": \"$pattern\"}")
    jsonresp = JSON.parse(String(resp.body))
    @assert jsonresp["success"]
    for x in jsonresp["data"]
        println(x["file"], ":", x["line"])
    end
end
