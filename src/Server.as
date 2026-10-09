// Tiny localhost-only HTTP server.
//   GET /        -> overlay.html (the OBS Browser Source page)
//   GET /events  -> live stream (Server-Sent Events): "state" 10x per second, and
//                   "vehicle" (inputs, gear, speed) up to 60x per second when needed
//   GET /state   -> one-off state as JSON (fallback)
// Binds to 127.0.0.1 only, so nothing is exposed to the network.
namespace Server {
    Net::Socket@ g_listener;
    int g_boundPort = 0;
    string g_lastError = "";
    uint64 g_nextRetry = 0;
    uint64 g_lastPoll = 0;
    uint64 g_previewUntil = 0;
    string g_overlayHtml = "<h1>overlay.html missing</h1>";

    class Conn {
        Net::Socket@ sock;
        uint64 openedAt;
        bool replied = false;
        bool streaming = false;
        string request = "";   // bytes received so far, until the request line is complete
        Conn(Net::Socket@ s) { @sock = s; openedAt = Time::Now; }
    }
    array<Conn@> g_conns;

    bool IsRunning() { return g_listener !is null; }
    string LastError() { return g_lastError; }
    string Url() { return "http://127.0.0.1:" + S_Port + "/"; }

    // OBS keeps polling while the Browser Source is in the current scene (or active in the background).
    bool ObsConnected() { return g_lastPoll > 0 && Time::Now - g_lastPoll < 2000; }

    uint64 g_nextState = 0;
    uint64 g_nextVehicle = 0;

    bool get_Preview() { return Time::Now < g_previewUntil; }
    void StartPreview() { g_previewUntil = Time::Now + 30000; }
    void StopPreview() { g_previewUntil = 0; }
    int PreviewSecondsLeft() { return Preview ? int((g_previewUntil - Time::Now) / 1000) + 1 : 0; }

    void LoadOverlay() {
        try {
            IO::FileSource f("overlay.html");
            g_overlayHtml = f.ReadToEnd();
        } catch {
            g_lastError = "Could not read overlay.html: " + getExceptionInfo();
        }
    }

    void Start() {
        @g_listener = Net::Socket();
        if (!g_listener.Listen("127.0.0.1", uint16(S_Port))) {
            g_lastError = "Port " + S_Port + " is already used by another program.";
            @g_listener = null;
            g_nextRetry = Time::Now + 5000;
            return;
        }
        g_boundPort = S_Port;
        g_lastError = "";
        trace("Overlay available at " + Url());
    }

    void Stop() {
        for (uint i = 0; i < g_conns.Length; i++) g_conns[i].sock.Close();
        g_conns.RemoveRange(0, g_conns.Length);
        if (g_listener !is null) g_listener.Close();
        @g_listener = null;
    }

    void Tick() {
        if (g_listener !is null && g_boundPort != S_Port) Stop();
        if (g_listener is null) {
            if (Time::Now >= g_nextRetry) Start();
            if (g_listener is null) return;
        }

        while (true) {
            auto client = g_listener.Accept();
            if (client is null) break;
            Conn@ conn = Conn(client);
            g_conns.InsertLast(conn);
        }

        PushEvents();

        for (int i = int(g_conns.Length) - 1; i >= 0; i--) {
            auto c = g_conns[i];
            bool done = false;
            if (c.streaming) {
                done = c.sock.IsHungUp();
            } else if (c.replied) {
                done = true; // close one frame after writing so the reply is flushed
            } else if (c.sock.Available() > 0) {
                // A request can arrive in pieces: route it once the request line is complete.
                c.request += c.sock.ReadRaw(c.sock.Available());
                if (c.request.Contains("\r\n") || c.request.Length > 8192) {
                    c.streaming = Handle(c.sock, c.request);
                    c.replied = true;
                }
            } else if (c.sock.IsHungUp() || Time::Now - c.openedAt > 3000) {
                done = true;
            }
            if (done) {
                c.sock.Close();
                g_conns.RemoveAt(i);
            }
        }
    }

    // Sends live updates to every open /events connection.
    void PushEvents() {
        bool anyStream = false;
        for (uint i = 0; i < g_conns.Length; i++) {
            if (g_conns[i].streaming) anyStream = true;
        }
        if (!anyStream) return;
        g_lastPoll = Time::Now;

        string msg = "";
        if (Time::Now >= g_nextState) {
            g_nextState = Time::Now + 100;
            msg += "event: state\n"
                + "data: " + Elements::StateJson(Preview) + "\n\n";
        }
        if (Time::Now >= g_nextVehicle && (Preview || Elements::NeedsVehicle())) {
            g_nextVehicle = Time::Now + 16;
            msg += "event: vehicle\n"
                + "data: " + Vehicle::Json() + "\n\n";
        }
        if (msg.Length == 0) return;

        for (uint i = 0; i < g_conns.Length; i++) {
            auto c = g_conns[i];
            if (c.streaming && !c.sock.WriteRaw(msg)) c.streaming = false; // closed on the next pass
        }
    }

    // Returns true when the connection stays open as an event stream.
    bool Handle(Net::Socket@ sock, const string &in request) {
        // Request line: "GET /state?x=y HTTP/1.1"
        auto parts = request.Split(" ");
        string path = parts.Length >= 2 ? parts[1].Split("?")[0] : "/";

        if (path == "/events") {
            sock.WriteRaw(
                "HTTP/1.1 200 OK\r\n"
                + "Content-Type: text/event-stream\r\n"
                + "Cache-Control: no-store\r\n"
                + "Connection: keep-alive\r\n"
                + "\r\n"
                + "retry: 1000\n\n"
            );
            g_nextState = 0; // send the full state straight away
            return true;
        } else if (path == "/state") {
            g_lastPoll = Time::Now;
            Reply(sock, "200 OK", "application/json", Elements::StateJson(Preview));
        } else if (path == "/" || path == "/index.html") {
            Reply(sock, "200 OK", "text/html; charset=utf-8", g_overlayHtml);
        } else {
            Reply(sock, "404 Not Found", "text/plain", "not found");
        }
        return false;
    }

    void Reply(Net::Socket@ sock, const string &in status, const string &in type, const string &in body) {
        sock.WriteRaw(
            "HTTP/1.1 " + status + "\r\n"
            + "Content-Type: " + type + "\r\n"
            + "Content-Length: " + body.Length + "\r\n"
            + "Cache-Control: no-store\r\n"
            + "Connection: close\r\n"
            + "\r\n" + body
        );
    }
}
