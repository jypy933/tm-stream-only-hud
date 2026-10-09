// Map medals + personal best. Unlike the other elements this one is drawn by the plugin
// itself: in game as a small window ("my screen"), or by the OBS overlay ("stream").
class MedalsElement : Element {
    bool hasMap = false;
    string mapName;
    string mapAuthor;
    int author, gold, silver, bronze;
    int pb = -1;
    uint64 nextPbRead = 0;

    MedalsElement() {
        super("medals", "Medals & personal best",
            "Author/Gold/Silver/Bronze times and your PB, in a corner. Turn off other medal plugins to avoid two panels.");
    }

    void Update(CGameManiaAppPlayground@ cmap) override {
        auto map = GetApp().RootMap;
        hasMap = cmap !is null && map !is null && map.MapInfo !is null;
        if (!hasMap) {
            pb = -1;
            return;
        }
        mapName = Text::StripFormatCodes(string(map.MapInfo.Name));
        mapAuthor = string(map.MapInfo.AuthorNickName);
        author = int(map.TMObjective_AuthorTime);
        gold = int(map.TMObjective_GoldTime);
        silver = int(map.TMObjective_SilverTime);
        bronze = int(map.TMObjective_BronzeTime);

        if (Time::Now >= nextPbRead) {
            nextPbRead = Time::Now + 1000;
            pb = ReadPb(cmap, map.MapInfo.MapUid);
        }
    }

    int ReadPb(CGameManiaAppPlayground@ cmap, const string &in mapUid) {
        // Editions without record access (e.g. Starter) get no PB row; the medals stay.
        if (!Permissions::ViewRecords()) return -1;
        if (cmap.ScoreMgr is null || cmap.UserMgr is null || cmap.UserMgr.Users.Length == 0) return -1;
        uint t = cmap.ScoreMgr.Map_GetRecord_v2(cmap.UserMgr.Users[0].Id, mapUid, "PersonalBest", "", "TimeAttack", "");
        if (t == 0 || t == uint(-1)) return -1;
        return int(t);
    }

    Json::Value@ State() override {
        auto o = Json::Object();
        o["visible"] = hasMap;
        o["corner"] = S_MedalsCorner;
        o["map"] = mapName;
        o["mapAuthor"] = mapAuthor;
        o["author"] = author;
        o["gold"] = gold;
        o["silver"] = silver;
        o["bronze"] = bronze;
        o["pb"] = pb;
        return o;
    }

    void RenderInGame() {
        if (!ShowMe || !hasMap || !UI::IsGameUIVisible()) return;

        int flags = UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize
                  | UI::WindowFlags::NoCollapse | UI::WindowFlags::NoFocusOnAppearing;
        if (!UI::IsOverlayShown()) flags |= UI::WindowFlags::NoInputs;

        if (UI::Begin("Stream-Only HUD medals", flags)) {
            UI::Text(mapName);
            UI::TextDisabled("by " + mapAuthor);
            if (UI::BeginTable("medals", 2)) {
                // The PB row slots in between the medals by time, like the usual medal windows.
                bool pbDone = pb <= 0;
                pbDone = PbRowBefore(author, pbDone);
                Row("\\$071" + Icons::Circle, "Author", author);
                pbDone = PbRowBefore(gold, pbDone);
                Row("\\$fc0" + Icons::Circle, "Gold", gold);
                pbDone = PbRowBefore(silver, pbDone);
                Row("\\$ccc" + Icons::Circle, "Silver", silver);
                pbDone = PbRowBefore(bronze, pbDone);
                Row("\\$c73" + Icons::Circle, "Bronze", bronze);
                if (!pbDone) Row("\\$0ff" + Icons::Circle, "\\$0ffPers. Best", pb);
                UI::EndTable();
            }
        }
        UI::End();
    }

    bool PbRowBefore(int medalTime, bool pbDone) {
        if (pbDone || pb > medalTime) return pbDone;
        Row("\\$0ff" + Icons::Circle, "\\$0ffPers. Best", pb);
        return true;
    }

    void Row(const string &in dot, const string &in name, int time) {
        UI::TableNextRow();
        UI::TableNextColumn();
        UI::Text(dot + "\\$z " + name);
        UI::TableNextColumn();
        UI::Text(time > 0 ? Time::Format(time) : "-");
    }
}
