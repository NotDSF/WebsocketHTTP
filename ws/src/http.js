const config = require("./config.json");
const { WebSocketServer } = require("ws")
const EventEmitter = require("node:events");
class MyEmitter extends EventEmitter {}

const http = new MyEmitter();
const wss = new WebSocketServer({
    port: config.port
});

wss.on("connection", (socket) => {
    socket.LastPing = Date.now();

    socket.on("message", (message) => {
        let Data;

        try {
            Data = JSON.parse(message);
        } catch (_) {
            http.emit("invalid", socket);
            return socket.close();
        }

       // console.log(Data);

        if (!Data.Opcode || !Data.Data) return socket.close();

        switch (Data.Opcode) {
            case "REQUEST":
                let Request = Data.Data;
                if (!Request.Url) return socket.close();

                let UrlData;
                try {
                    UrlData = new URL(Request.Url);
                } catch (_) {
                    return socket.close();
                }
                
                Request.params = UrlData.searchParams;
                Request.send = socket.send;
                http.emit(UrlData.pathname, Request, socket);
                
                break;
            case "PING":
                socket.LastPing = Date.now();
                http.emit("ping", socket);
        }
    });

    socket.on("close", (code, reason) => http.emit("close", code, reason));

    setInterval(() => {
        wss.clients.forEach(socket => {
            if (socket.LastPing && (Date.now() - socket.LastPing) / 1000 > 20) {
                socket.close();
            }
        });
    }, 1000);
});

wss.on("listening", () => http.emit("ready"));

module.exports = http;