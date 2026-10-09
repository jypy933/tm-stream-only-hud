// One HUD element the player can toggle for "my screen" and "stream".
//
// OBS records the player's screen, so anything the player sees is on stream too.
// That leaves three useful states:
//   me + stream  -> shown in game, OBS captures it as usual       (overlay draws nothing)
//   stream only  -> hidden in game, the OBS overlay redraws it      (overlay draws it)
//   neither      -> hidden everywhere
class Element {
    string key;
    string title;
    string help;
    bool me = true;
    bool stream = true;

    Element(const string &in key, const string &in title, const string &in help) {
        this.key = key;
        this.title = title;
        this.help = help;
    }

    // False when the element depends on something that isn't installed.
    bool get_Available() const { return true; }
    string get_UnavailableReason() const { return ""; }

    // What the player actually sees right now. The show/hide key ("peek") temporarily puts
    // the stream-only elements back on the player's screen without changing their choices.
    bool get_ShowMe() const { return me || (Elements::g_peek && stream && Available); }

    bool get_OnOverlay() const { return Available && stream && !ShowMe; }

    string Summary() const {
        if (!Available) return "\\$888" + UnavailableReason;
        if (me) return "\\$0f0Everyone sees it";
        if (stream) return "\\$0cfOnly viewers see it";
        return "\\$888Hidden for everyone";
    }

    void Set(bool onMyScreen, bool onStream) {
        me = onMyScreen;
        stream = onMyScreen || onStream;
    }

    void Update(CGameManiaAppPlayground@ cmap) {}
    // Map changed: forget game objects (and put anything we moved back).
    void Detach() {}
    // Plugin unloading or disabled: undo everything.
    void Release() { Detach(); }
    bool get_Attached() const { return true; }

    // Data for the overlay. Only called when OnOverlay is true.
    Json::Value@ State() { return Json::Object(); }
}

// A native Nadeo HUD module ("UIModule_Race_*").
//
// Every module's root is a frame called "frame-global" whose position the game's own
// script never changes. Moving it off-screen hides the module from the player while the
// game keeps updating it, so we can read exactly what it would have shown.
class NativeElement : Element {
    string pageName;   // e.g. "UIModule_Race_Checkpoint"
    string moduleId;   // e.g. "Race_Checkpoint": the frame carrying the module's on-screen position
    vec2 defaultPos;

    CGameUILayer@ layer;
    CGameManialinkFrame@ global;
    CGameManialinkControl@ placement;
    vec2 origPos;
    bool moved = false;

    NativeElement(const string &in key, const string &in title, const string &in help, const string &in pageName, vec2 defaultPos) {
        super(key, title, help);
        this.pageName = pageName;
        this.moduleId = pageName.Replace("UIModule_", "");
        this.defaultPos = defaultPos;
    }

    bool get_Attached() const override { return global !is null; }

    bool TryAttach(CGameUILayer@ l) {
        if (l is null || l.LocalPage is null) return false;
        auto frame = cast<CGameManialinkFrame>(l.LocalPage.GetFirstChild("frame-global"));
        if (frame is null) return false;
        @layer = l;
        @global = frame;
        @placement = l.LocalPage.GetFirstChild(moduleId);
        origPos = frame.RelativePosition_V3;
        moved = false;
        return true;
    }

    void Update(CGameManiaAppPlayground@ cmap) override {
        if (global is null) return;
        if (ShowMe) {
            Restore();
        } else {
            global.RelativePosition_V3 = Elements::OFFSCREEN;
            moved = true;
        }
    }

    void Restore() {
        if (global !is null && moved) global.RelativePosition_V3 = origPos;
        moved = false;
    }

    void Detach() override {
        Restore();
        @global = null;
        @placement = null;
        @layer = null;
    }

    // ---- helpers to read the module ----

    CGameManialinkControl@ Ctrl(const string &in id) {
        if (layer is null || layer.LocalPage is null) return null;
        return layer.LocalPage.GetFirstChild(id);
    }

    bool Shown(const string &in id) {
        auto c = Ctrl(id);
        return c !is null && c.Visible;
    }

    string Label(const string &in id) {
        return LabelText(cast<CGameManialinkLabel>(Ctrl(id)));
    }

    string QuadColour(const string &in id) {
        auto q = cast<CGameManialinkQuad>(Ctrl(id));
        if (q is null) return "";
        vec3 c = q.BgColor;
        return "#" + Hex(c.x) + Hex(c.y) + Hex(c.z);
    }

    // Base state: visibility and where the module sits on screen (ManiaLink units).
    Json::Value@ State() override {
        auto o = Json::Object();
        vec2 pos = defaultPos;
        float scale = 1;
        if (placement !is null) {
            pos = placement.RelativePosition_V3;
            scale = placement.RelativeScale;
        }
        o["x"] = pos.x;
        o["y"] = pos.y;
        o["scale"] = scale;
        o["attached"] = Attached;
        bool vis = global !is null && global.Visible;
        o["visible"] = vis;
        if (global !is null) Fill(o, vis);
        return o;
    }

    // Subclasses add their own data; `vis` is whether the module itself is showing.
    void Fill(Json::Value@ o, bool vis) {}
}

string LabelText(CGameManialinkLabel@ l) {
    if (l is null) return "";
    return Text::StripFormatCodes(string(l.Value));
}

string Hex(float v) {
    return Text::Format("%02x", int(Math::Clamp(v, 0.0f, 1.0f) * 255));
}

// First non-empty label text anywhere under a control (used for player-name widgets).
string FirstLabel(CGameManialinkControl@ c, int depth = 0) {
    if (c is null || depth > 6 || !c.Visible) return "";
    string v = LabelText(cast<CGameManialinkLabel>(c));
    if (v.Length > 0) return v;
    auto f = cast<CGameManialinkFrame>(c);
    if (f is null) return "";
    for (uint i = 0; i < f.Controls.Length; i++) {
        v = FirstLabel(f.Controls[i], depth + 1);
        if (v.Length > 0) return v;
    }
    return "";
}
