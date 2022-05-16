local ws = {} do
    local format  = string.format;
    local sub     = string.sub;
    local concat  = table.concat;
    local type    = type;
    local pairs   = pairs;
    local wait    = wait;
    local wrap    = coroutine.wrap;
    local connect = syn and syn.websocket.connect or WebSocket.connect;
    
    -- Turns request into JSON format (string&table support only since numbers arent allowed in requests anyway)
    local function FormatPacket(packet) 
        local serialzed = {};
        for i,v in pairs(packet) do
            serialzed[#serialzed+1] = format("\"%s\":%s,", i, type(v) == "table" and FormatPacket(v) or "\"" .. v .. "\"");
        end;
        return "{" .. sub(concat(serialzed), 0, -2) .. "}";
    end;

    -- Main websocket hander includes reconnection/hearbeat
    local function WebsocketHandler(self)
        local function MessageHandler(msg)
            if msg == "PONG" then
                self.LastPong = tick();
                return; -- dont send message event
            end;
            return self.OnMessageSignal:Fire(msg);
        end;

        local function ClosedHandler() 
            if self.SocketClosed then return end;
            self.__OBJECT_ACTIVE = false;

            while wait(5) do
                local ok, ws = pcall(connect, self.Url);
                if ok then
                    self.__OBJECT_ACTIVE = true;
                    self.Websocket = ws;
                    ws:Send(FormatPacket({ Opcode = "PING", Data = {} }));

                    -- Reconnect events
                    ws.OnClose:Connect(ClosedHandler);
                    ws.OnMessage:Connect(MessageHandler);
                    break;
                end;
            end;
        end;

        self.Websocket.OnClose:Connect(ClosedHandler);
        self.Websocket.OnMessage:Connect(MessageHandler);
        self.LastPong = tick();

        while wait(10) do
            if self.__OBJECT_ACTIVE then
                self.Websocket:Send(FormatPacket({ Opcode = "PING", Data = {} }));
                if tick() - self.LastPong > 20 then
                    warn("Server timeout");
                    self.Websocket:Close();
                end;
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
        self.OnMessageSignal = Instance.new("BindableEvent");
        self.OnMessage = self.OnMessageSignal.Event;
        self.__OBJECT_ACTIVE = true;
        wrap(WebsocketHandler)(self);

        repeat wait() until self.LastPong;
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
        self.SocketClosed = true;
        self.Websocket:Close();
    end;
end;

local http = ws:new("ws://localhost:8088");
http.OnMessage:Connect(function(...)
    print("msg", ...);
end);

local response = http:request({
    Url = "ws://localhost:8088/api/info"
});

print(response)