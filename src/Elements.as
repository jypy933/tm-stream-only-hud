// The concrete HUD elements and the registry that drives them every frame.
// Control IDs come from Nadeo's own UI module scripts.

class SplitsElement : NativeElement {
    SplitsElement() {
        super("splits", "Checkpoint splits",
            "Your time and the +/- difference to your PB when you cross a checkpoint.",
            "UIModule_Race_Checkpoint", vec2(-10, 45));
    }

    void Fill(Json::Value@ o, bool vis) override {
        o["visible"] = vis && Shown("frame-checkpoint");
        o["race"] = Part("frame-race", "race");
        o["lap"] = Part("frame-lap", "lap");
    }

    Json::Value@ Part(const string &in frameId, const string &in p) {
        auto o = Json::Object();
        o["visible"] = Shown(frameId);
        o["time"] = Label("label-" + p + "-time");
        o["timeVisible"] = Shown("frame-" + p + "-time");
        o["diff"] = Label("label-" + p + "-diff");
        o["diffVisible"] = Shown("frame-" + p + "-diff");
        o["diffColor"] = QuadColour("quad-" + p + "-diff");
        return o;
    }
}

class TimerElement : NativeElement {
    TimerElement() {
        super("timer", "Race timer",
            "The running clock at the bottom of the screen.",
            "UIModule_Race_Chrono", vec2(0, -80));
    }

    void Fill(Json::Value@ o, bool vis) override {
        o["visible"] = vis && Shown("frame-chrono");
        o["text"] = Label("label-chrono");
    }
}

class CounterElement : NativeElement {
    CounterElement() {
        super("counter", "Checkpoint & lap counter",
            "\"CP 2/5\" and \"Lap 1/3\" in the top right corner.",
            "UIModule_Race_LapsCounter", vec2(155.7, 80));
    }

    void Fill(Json::Value@ o, bool vis) override {
        auto lap = Json::Object();
        lap["visible"] = Shown("frame-laps-counter");
        lap["text"] = Label("label-laps-counter");
        o["lap"] = lap;

        auto cp = Json::Object();
        auto cpFrame = Ctrl("frame-checkpoints-counter");
        cp["visible"] = cpFrame !is null && cpFrame.Visible && Shown("label-checkpoints-counter");
        cp["text"] = Label("label-checkpoints-counter");
        cp["y"] = cpFrame is null ? 0.0f : cpFrame.RelativePosition_V3.y;
        o["cp"] = cp;
    }
}

class RecordsElement : NativeElement {
    RecordsElement() {
        super("records", "Records panel",
            "The leaderboard and next-medal panel on the left side.",
            "UIModule_Race_Record", vec2(-160, 30));
    }

    void Fill(Json::Value@ o, bool vis) override {
        o["visible"] = vis && Shown("frame-records");

        auto medal = Json::Object();
        medal["visible"] = Shown("frame-medal") && Label("label-medal-time").Length > 0;
        medal["name"] = Label("label-medal-name");
        medal["time"] = Label("label-medal-time");
        o["medal"] = medal;

        // The leaderboard rows are map records: without record access serve none (the medal
        // target above comes from the map itself and stays).
        auto rows = Json::Array();
        bool canView = Permissions::ViewRecords();
        for (uint i = 0; canView && i < 30; i++) {
            auto row = cast<CGameManialinkFrame>(Ctrl("button-record-" + i));
            if (row is null) break;
            if (!row.Visible) continue;
            string score = LabelText(cast<CGameManialinkLabel>(row.GetFirstChild("label-score")));
            if (score.Length == 0) continue;
            auto r = Json::Object();
            r["rank"] = LabelText(cast<CGameManialinkLabel>(row.GetFirstChild("label-rank")));
            r["name"] = FirstLabel(row.GetFirstChild("playername-name"));
            r["score"] = score;
            rows.Add(r);
        }
        o["rows"] = rows;
    }
}

namespace Elements {
    const vec2 OFFSCREEN = vec2(0, 1000); // the ManiaLink screen is about +-160 x +-90

    const string[] PAD_STYLE = {
                "Setting_Gamepad_Style", "Setting_Gamepad_EmptyFillColor", "Setting_Gamepad_FillColor",
                "Setting_Gamepad_BorderColor", "Setting_Gamepad_BorderWidth", "Setting_Gamepad_Spacing",
                "Setting_Gamepad_ArrowPadding", "Setting_Gamepad_MiddleScale", "Setting_Gamepad_UpDownSymbols",
                "Setting_Gamepad_TextColor", "Setting_Keyboard_Shape", "Setting_Keyboard_EmptyFillColor",
                "Setting_Keyboard_FillColor", "Setting_Keyboard_BorderColor", "Setting_Keyboard_BorderWidth",
                "Setting_Keyboard_BorderRadius", "Setting_Keyboard_Spacing", "Setting_Keyboard_InactiveAlpha" };
    const string[] GEARBOX_STYLE = {
                "Setting_Gearbox_ShowText", "Setting_Gearbox_ShowTachometer", "Setting_Gearbox_TachometerStyle",
                "Setting_Gearbox_Downshift", "Setting_Gearbox_Upshift", "Setting_Gearbox_BackdropColor",
                "Setting_Gearbox_BorderColor", "Setting_Gearbox_BorderWidth", "Setting_Gearbox_BorderRadius",
                "Setting_Gearbox_Spacing", "Setting_Gearbox_LowRPMColor", "Setting_Gearbox_MidRPMColor",
                "Setting_Gearbox_HighRPMColor", "Setting_Gearbox_TextColor", "Setting_Gearbox_FontSize" };
    const string[] SPEED_STYLE = {
                "Setting_Speed_BackdropColor", "Setting_Speed_BorderColor", "Setting_Speed_TextColor",
                "Setting_Speed_BorderWidth", "Setting_Speed_BorderRadius", "Setting_Speed_FontSize" };

    array<Element@> All;
    array<NativeElement@> Native;
    MedalsElement@ g_medals = MedalsElement();

    CGameManiaAppPlayground@ g_cmap;
    bool g_peek = false;   // show/hide key: stream-only elements temporarily back on the player's screen

    bool AnyStreamOnly() {
        for (uint i = 0; i < All.Length; i++) {
            auto e = All[i];
            if (e.Available && e.stream && !e.me) return true;
        }
        return false;
    }

    void TogglePeek() {
        g_peek = !g_peek;
        if (!AnyStreamOnly()) {
            g_peek = false;
            UI::ShowNotification("Stream-Only HUD", "Nothing is hidden from you right now.", 2500);
            return;
        }
        UI::ShowNotification("Stream-Only HUD", g_peek ? "Hidden items are back on your screen." : "Hidden items are off your screen again.", 2000);
    }
    uint64 g_nextScan = 0;

    void Add(NativeElement@ e) {
        All.InsertLast(e);
        Native.InsertLast(e);
    }

    void Init() {
        Add(SplitsElement());
        Add(TimerElement());
        Add(CounterElement());
        Add(RecordsElement());
        All.InsertLast(g_medals);
        All.InsertLast(DashboardElement("inputs", "Inputs (Dashboard)",
            "The steering/gas/brake display from the Dashboard plugin.",
            "Pad", vec2(0.9f, 0.1f), vec2(350, 200), PAD_STYLE));
        All.InsertLast(DashboardElement("gearbox", "Gear & RPM (Dashboard)",
            "The gear number and rev bar from the Dashboard plugin.",
            "Gearbox", vec2(0.9f, 0.32f), vec2(350, 50), GEARBOX_STYLE));
        All.InsertLast(DashboardElement("speed", "Speed (Dashboard)",
            "The speedometer from the Dashboard plugin.",
            "Speed", vec2(0.909f, 0.4f), vec2(230, 50), SPEED_STYLE));
        LoadVisibility();
    }

    Element@ Find(const string &in key) {
        for (uint i = 0; i < All.Length; i++) {
            if (All[i].key == key) return All[i];
        }
        return null;
    }

    void Update() {
        auto cmap = GetApp().Network.ClientManiaAppPlayground;
        if (cmap !is g_cmap) {
            RestoreAll();
            @g_cmap = cmap;
            g_nextScan = 0;
        }
        if (cmap !is null) AttachMissing(cmap);
        for (uint i = 0; i < All.Length; i++) All[i].Update(cmap);
    }

    // One pass over the UI layers to find every module we haven't found yet.
    // Throttled: reading layer pages is not free and modules load a little after the map.
    void AttachMissing(CGameManiaAppPlayground@ cmap) {
        if (Time::Now < g_nextScan) return;
        g_nextScan = Time::Now + 250;

        // On a server the playground lives on across maps, and a module's layer can be
        // replaced: let go of any layer that is no longer in the list so the new one is found.
        bool missing = false;
        for (uint i = 0; i < Native.Length; i++) {
            auto e = Native[i];
            if (e.Attached && !HasLayer(cmap, e.layer)) e.Detach();
            if (!e.Attached) missing = true;
        }
        if (!missing) return;

        for (uint i = 0; i < cmap.UILayers.Length; i++) {
            auto layer = cmap.UILayers[i];
            if (layer is null || layer.LocalPage is null) continue;
            int len = Math::Min(int(layer.ManialinkPage.Length), 300);
            if (len < 20) continue;
            string head = string(layer.ManialinkPage.SubStr(0, len));
            for (uint j = 0; j < Native.Length; j++) {
                auto e = Native[j];
                if (!e.Attached && head.Contains('"' + e.pageName + '"')) e.TryAttach(layer);
            }
        }
    }

    bool HasLayer(CGameManiaAppPlayground@ cmap, CGameUILayer@ layer) {
        for (uint i = 0; i < cmap.UILayers.Length; i++) {
            if (cmap.UILayers[i] is layer) return true;
        }
        return false;
    }

    void RestoreAll() {
        for (uint i = 0; i < All.Length; i++) All[i].Detach();
    }

    // Each element on its own, so one failure doesn't leave the others hidden.
    void ReleaseAll() {
        for (uint i = 0; i < All.Length; i++) {
            try {
                All[i].Release();
            } catch {
                error("Stream-Only HUD could not give back " + All[i].key + ": " + getExceptionInfo());
            }
        }
    }

    // Live car data is only worth sending when a Dashboard part is drawn by the overlay.
    bool NeedsVehicle() {
        for (uint i = 0; i < All.Length; i++) {
            if (cast<DashboardElement>(All[i]) !is null && All[i].OnOverlay) return true;
        }
        return false;
    }

    // ---- persistence of the "my screen / stream" choices ----

    void LoadVisibility() {
        // Defaults: only the splits are hidden from the player; medals panel is opt-in.
        Find("splits").Set(false, true);
        g_medals.Set(false, false);

        auto pairs = S_Visibility.Split(";");
        for (uint i = 0; i < pairs.Length; i++) {
            auto kv = pairs[i].Split("=");
            if (kv.Length != 2 || kv[1].Length != 2) continue;
            auto e = Find(kv[0]);
            if (e !is null) e.Set(kv[1].SubStr(0, 1) == "1", kv[1].SubStr(1, 1) == "1");
        }
    }

    void SaveVisibility() {
        string s = "";
        for (uint i = 0; i < All.Length; i++) {
            auto e = All[i];
            s += e.key + "=" + (e.me ? "1" : "0") + (e.stream ? "1" : "0") + ";";
        }
        S_Visibility = s;
        Meta::SaveSettings();
    }

    // ---- overlay state ----

    string StateJson(bool preview) {
        auto root = Json::Object();
        root["preview"] = preview;
        auto els = Json::Object();
        for (uint i = 0; i < All.Length; i++) {
            if (All[i].OnOverlay) els[All[i].key] = All[i].State();
        }
        root["elements"] = els;
        return Json::Write(root);
    }

    string OverlayNames() {
        string[] names;
        for (uint i = 0; i < All.Length; i++) {
            if (All[i].OnOverlay) names.InsertLast(All[i].title);
        }
        return Text::Join(names, ", ");
    }
}
