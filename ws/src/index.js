const http = require("./http");

http.on("/api/info", (request, socket) => {
    console.log("/api/info")
    //console.log(request);
    request.send("hello");
});

http.on("/test123", (request, socket) => {
    console.log("test123", request);
    request.send("test43");
});

http.on("teleport", (socket) => console.log("Someone teleported"));

http.on("ping", () => console.log("Ping"));

http.on("close", () => console.log("Someone disconnected"));

http.on("ready", (address) => console.log(`Http listening to ${address.port}`));