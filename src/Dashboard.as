// Support for the "Dashboard" plugin by Miss (inputs pad, gearbox, speed).
//
// Another plugin's drawing lands in the game picture, so it can't be hidden from the
// player and kept on stream directly. Instead, when "On my screen" is unticked we switch
// that Dashboard part off through Openplanet's settings API, and the OBS overlay redraws it
// with Dashboard's own layout and colours from live car data.
class DashboardElement : Element {
    string part;          // "Pad", "Gearbox" or "Speed", as in Dashboard's setting names
    vec2 defaultPos;      // Dashboard defaults, used when Dashboard isn't installed
    vec2 defaultSize;
    string[] styleSettings;
    bool takenOver = false;
    bool origShowHidden = true;

    DashboardElement(const string &in key, const string &in title, const string &in help,
                     const string &in part, vec2 defaultPos, vec2 defaultSize, const string[] &in styleSettings) {
        super(key, title, help);
        this.part = part;
        this.defaultPos = defaultPos;
        this.defaultSize = defaultSize;
        this.styleSettings = styleSettings;
    }

    bool get_Available() const override { return Dashboard::Installed(); }
    string get_UnavailableReason() const override { return "Needs the Dashboard plugin"; }

    Meta::PluginSetting@ Setting(const string &in name) {
        auto p = Dashboard::Plugin();
        return p is null ? null : p.GetSetting(name);
    }

    void Update(CGameManiaAppPlayground@ cmap) override {
        auto show = Setting("Setting_General_Show" + part);
        auto showHidden = Setting("Setting_General_Show" + part + "Hidden");
        if (show is null || showHidden is null) {
            takenOver = false;
            return;
        }
        if (!ShowMe) {
            if (!takenOver) {
                origShowHidden = showHidden.ReadBool();
                takenOver = true;
            }
            if (show.ReadBool()) show.WriteBool(false);
            if (showHidden.ReadBool()) showHidden.WriteBool(false);
        } else if (takenOver) {
            Release();
        }
    }

    // Map changes don't matter here; only give Dashboard its part back when asked to or on unload.
    void Detach() override {}

    void Release() override {
        if (!takenOver) return;
        auto show = Setting("Setting_General_Show" + part);
        auto showHidden = Setting("Setting_General_Show" + part + "Hidden");
        // "On my screen" means visible, whatever Dashboard had saved.
        if (show !is null) show.WriteBool(true);
        if (showHidden !is null) showHidden.WriteBool(origShowHidden);
        takenOver = false;
    }

    Json::Value@ State() override {
        auto o = Json::Object();
        vec2 pos = defaultPos, size = defaultSize;
        auto posS = Setting("Setting_General_" + part + "Pos");
        auto sizeS = Setting("Setting_General_" + part + "Size");
        if (posS !is null) pos = posS.ReadVec2();
        if (sizeS !is null) size = sizeS.ReadVec2();
        o["visible"] = true;
        o["pos"] = Vec2Json(pos);
        o["size"] = Vec2Json(size);
        o["screen"] = Vec2Json(vec2(Display::GetWidth(), Display::GetHeight()));
        o["style"] = Dashboard::ReadStyle(styleSettings);
        if (part == "Pad") o["padType"] = Dashboard::PadType();
        return o;
    }
}

Json::Value@ Vec2Json(vec2 v) {
    auto o = Json::Object();
    o["x"] = v.x;
    o["y"] = v.y;
    return o;
}

namespace Dashboard {
    Meta::Plugin@ Plugin() {
        auto p = Meta::GetPluginFromID("Dashboard");
        return (p is null || !p.Enabled) ? null : p;
    }

    bool Installed() { return Plugin() !is null; }

    // Dashboard settings forwarded to the overlay, keyed by their variable name.
    Json::Value@ ReadStyle(const string[] &in names) {
        auto o = Json::Object();
        auto p = Plugin();
        if (p is null) return o;
        for (uint i = 0; i < names.Length; i++) {
            auto s = p.GetSetting(names[i]);
            if (s is null) continue;
            switch (s.Type) {
                case Meta::PluginSettingType::Bool:  o[names[i]] = s.ReadBool(); break;
                case Meta::PluginSettingType::Float: o[names[i]] = s.ReadFloat(); break;
                case Meta::PluginSettingType::Enum:  o[names[i]] = s.ReadEnum(); break;
                case Meta::PluginSettingType::Vec4:  o[names[i]] = Css(s.ReadVec4()); break;
                default: break;
            }
        }
        return o;
    }

    string Css(vec4 c) {
        return "rgba(" + int(c.x * 255) + "," + int(c.y * 255) + "," + int(c.z * 255) + "," + Text::Format("%.3f", c.w) + ")";
    }

    // "gamepad" or "keyboard", picked the same way Dashboard does: forced setting, else the
    // most recently used input device.
    string PadType() {
        auto p = Plugin();
        if (p !is null) {
            auto force = p.GetSetting("Setting_General_ForcePadType");
            if (force !is null) {
                int v = force.ReadEnum(); // None, Gamepad, Keyboard
                if (v == 1) return "gamepad";
                if (v == 2) return "keyboard";
            }
        }
        CInputScriptPad@ recent;
        auto port = GetApp().InputPort;
        for (uint i = 0; i < port.Script_Pads.Length; i++) {
            auto pad = port.Script_Pads[i];
            if (recent is null || pad.IdleDuration < recent.IdleDuration) @recent = pad;
        }
        if (recent !is null && recent.Type == CInputScriptPad::EPadType::Keyboard) return "keyboard";
        return "gamepad";
    }
}

// Live car data for the overlay, sent every frame while a Dashboard part is stream-only.
namespace Vehicle {
    string Json() {
        auto vis = VehicleState::ViewingPlayerState();
        if (vis is null) return '{"on":false}';
        float brake = vis.InputIsBraking ? 1.0f : vis.InputBrakePedal;
        float speed = vis.FrontSpeed * 3.6f;
        if (speed < 0 && speed > -0.99f) speed = 0;
        return '{"on":true'
            + ',"steer":' + Text::Format("%.3f", vis.InputSteer)
            + ',"gas":' + Text::Format("%.3f", vis.InputGasPedal)
            + ',"brake":' + Text::Format("%.3f", brake)
            + ',"gear":' + vis.CurGear
            + ',"rpm":' + Text::Format("%.0f", VehicleState::GetRPM(vis))
            + ',"speed":' + Text::Format("%.1f", speed)
            + '}';
    }
}
