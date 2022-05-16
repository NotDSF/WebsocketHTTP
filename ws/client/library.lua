local ws = {} do
    local format  = string.format;
    local sub     = string.sub;
    local concat  = table.concat;
    local type    = type;
    local pairs   = pairs;
    local wait    = wait;
    local wrap    = coroutine.wrap;
    local connect = syn and syn.websocket.connect or WebSocket.connect;
    local closed;
    
    -- Turns request into JSON format (string&table support only since numbers arent allowed in requests anyway)
    local function FormatPacket(packet) 
        local serialzed = {};
        for i,v in pairs(packet) do
            serialzed[#serialzed+1] = format("\"%s\":%s,", i, type(v) == "table" and FormatPacket(v) or "\"" .. v .. "\"");
        end;
        return "{" .. sub(concat(serialzed), 0, -2) .. "}";
    end;

    -- Automatic reconnection/hearbeat (not using onclose since it can fuck up sometimes)
    local function HeartbeartHandler(self) 
        local function ClosedHandler() 
            if closed then return end;
            self.__OBJECT_ACTIVE = false;

            while wait(5) do
                local ok, ws = pcall(connect, self.Url);
                if ok then
                    self.__OBJECT_ACTIVE = true;
                    self.Websocket = ws;
                    ws:Send(FormatPacket({ Opcode = "PING", Data = {} }));
                    ws.OnClose:Connect(ClosedHandler); -- reconnect handler
                    break;
                end;
            end;
        end;

        self.Websocket.OnClose:Connect(ClosedHandler);

        while wait(10) do
            if self.__OBJECT_ACTIVE then
                self.Websocket:Send(FormatPacket({ Opcode = "PING", Data = {} }));
            end;
        end;
    end;

    -- Connects to the url
    function ws:new(url) 
        local object = {};
        setmetatable(object, self);
        self.__index = self

        local ok, ws = pcall(connect, url);
        assert(ok, ws);

        self.Websocket = ws;
        self.Url = url;
        self.__OBJECT_ACTIVE = true;
        wrap(HeartbeartHandler)(self);

        return object;
    end;

    -- Send a request to the websocket
    function ws:request(request) 
        while not self.__OBJECT_ACTIVE do wait() end;

        self.Websocket:Send(FormatPacket({
            Opcode = "REQUEST",
            Data = request
        }));

        return self.Websocket.OnMessage:Wait();
    end;

    function ws:close() 
        closed = true;
        self.Websocket:Close();
    end;
end;

local http = ws:new("ws://localhost:8080");
local response = http:request({
    Url = "ws://localhost:8080/api/info"
});

print(response)