// The in-game window: what shows where, and step-by-step OBS setup.
// Written for someone who has never touched a plugin setting before.
namespace Window {
    bool g_open = false;
    const string[] CORNERS = { "Top right", "Top left", "Bottom right", "Bottom left" };

    void Render() {
        if (!g_open) return;
        UI::SetNextWindowSize(620, 560, UI::Cond::FirstUseEver);
        if (UI::Begin(Icons::VideoCamera + " Stream-Only HUD", g_open)) {
            RenderContent();
        }
        UI::End();
        if (!g_open && S_FirstRun) {
            S_FirstRun = false;
            Meta::SaveSettings();
        }
    }

    void RenderContent() {
        RenderStatus();
        UI::Separator();
        if (UI::BeginTabBar("tabs")) {
            if (UI::BeginTabItem(Icons::Eye + " What shows where")) {
                RenderElements();
                UI::EndTabItem();
            }
            if (UI::BeginTabItem(Icons::Plug + " Connect to OBS")) {
                RenderObsSetup();
                UI::EndTabItem();
            }
            UI::EndTabBar();
        }
    }

    // One line that answers "is everything working?"
    void RenderStatus() {
        string overlayOnly = Elements::OverlayNames();
        if (!Server::IsRunning()) {
            UI::Text("\\$f44" + Icons::ExclamationTriangle + " Problem: " + Server::LastError());
            UI::TextWrapped("Close the other program using it, or pick another port in Openplanet Settings > Stream-Only HUD > Advanced, then copy the new OBS link.");
        } else if (Server::ObsConnected()) {
            UI::Text("\\$0f0" + Icons::CheckCircle + " OBS is connected.");
        } else if (overlayOnly.Length > 0) {
            UI::Text("\\$fa0" + Icons::ExclamationTriangle + " OBS is not connected: viewers can't see " + overlayOnly + " right now.");
            UI::TextWrapped("Open the \"Connect to OBS\" tab and follow the steps (only needed once).");
        } else {
            UI::Text("\\$888" + Icons::InfoCircle + " Nothing is hidden from you, so OBS doesn't need the overlay right now.");
        }
        if (Elements::g_peek) {
            UI::Text("\\$fa0" + Icons::Eye + " Hidden items are on your screen for now (show/hide key: " + Hotkey::KeyName() + ").");
            UI::SameLine();
            if (UI::Button("Hide them again")) Elements::TogglePeek();
        }
    }

    void RenderElements() {
        UI::TextWrapped("Untick \"On my screen\" to hide something from yourself. Your viewers keep seeing it if \"On stream\" stays ticked.");
        UI::Dummy(vec2(0, 4));

        bool changed = false;
        if (UI::BeginTable("elements", 4, UI::TableFlags::SizingFixedFit | UI::TableFlags::RowBg)) {
            UI::TableSetupColumn("Element", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("On my screen");
            UI::TableSetupColumn("On stream");
            UI::TableSetupColumn("Result");
            UI::TableHeadersRow();

            for (uint i = 0; i < Elements::All.Length; i++) {
                auto e = Elements::All[i];
                UI::PushID(e.key);
                UI::TableNextRow();

                UI::TableNextColumn();
                UI::Text(e.title);
                if (UI::IsItemHovered()) UI::SetTooltip(e.help);

                UI::BeginDisabled(!e.Available);
                UI::TableNextColumn();
                bool me = UI::Checkbox("##me", e.me);

                UI::TableNextColumn();
                bool stream = e.stream;
                UI::BeginDisabled(e.me);
                stream = UI::Checkbox("##stream", e.me || stream);
                UI::EndDisabled();
                if (e.me && UI::IsItemHovered(UI::HoveredFlags::AllowWhenDisabled)) {
                    UI::SetTooltip("OBS records your screen, so anything you can see is on stream too.");
                }

                UI::EndDisabled();

                UI::TableNextColumn();
                UI::Text(e.Summary());

                if (me != e.me || stream != e.stream) {
                    e.Set(me, stream);
                    changed = true;
                }
                UI::PopID();
            }
            UI::EndTable();
        }

        UI::Dummy(vec2(0, 4));
        UI::Text("Quick choices:");
        if (UI::Button(Icons::EyeSlash + " Hide only the splits from me")) {
            Preset(false, true, true, true);
            changed = true;
        }
        UI::SameLine();
        if (UI::Button(Icons::ClockO + " Hide all times from me")) {
            Preset(false, false, true, false);
            changed = true;
        }
        UI::SameLine();
        if (UI::Button(Icons::Undo + " Show everything normally")) {
            Preset(true, true, true, true);
            changed = true;
        }

        UI::Dummy(vec2(0, 4));
        Hotkey::Render();

        UI::Dummy(vec2(0, 4));
        UI::SetNextItemWidth(160);
        if (UI::BeginCombo("Medals panel corner on stream", CORNERS[S_MedalsCorner])) {
            for (uint i = 0; i < CORNERS.Length; i++) {
                if (UI::Selectable(CORNERS[i], S_MedalsCorner == int(i))) S_MedalsCorner = i;
            }
            UI::EndCombo();
        }

        if (changed) Elements::SaveVisibility();
    }

    // splitsMe/timerMe/counterMe/recordsMe; everything stays on stream. Medals panel is left alone.
    void Preset(bool splitsMe, bool timerMe, bool counterMe, bool recordsMe) {
        Elements::Find("splits").Set(splitsMe, true);
        Elements::Find("timer").Set(timerMe, true);
        Elements::Find("counter").Set(counterMe, true);
        Elements::Find("records").Set(recordsMe, true);
        auto medals = Elements::g_medals;
        if (medals.me && !splitsMe && !timerMe) medals.Set(false, true);
    }

    void RenderObsSetup() {
        UI::TextWrapped("Do this once. OBS remembers it afterwards.");
        UI::Dummy(vec2(0, 4));

        Step(1, "In OBS, find the \"Sources\" box, click the \\$fff+\\$z button and choose \\$fffBrowser\\$z. Click OK.");
        Step(2, "Click this button to copy the link:");
        UI::Indent(28);
        if (UI::Button(Icons::Clipboard + " Copy OBS link")) {
            IO::SetClipboard(Server::Url());
            UI::ShowNotification("Stream-Only HUD", "Link copied! Paste it in the URL box in OBS.");
        }
        UI::SameLine();
        UI::TextDisabled(Server::Url());
        UI::Unindent(28);
        Step(3, "In the OBS window: click in the \\$fffURL\\$z box, delete what's there and paste (Ctrl+V).");
        Step(4, "Set \\$fffWidth 1920\\$z and \\$fffHeight 1080\\$z, then click OK.");
        Step(5, "Right-click the new source > Transform > \\$fffFit to screen\\$z. Keep it at the top of the Sources list.");

        UI::Dummy(vec2(0, 6));
        UI::Separator();
        UI::Text("Check it works:");
        if (Server::Preview) {
            if (UI::Button(Icons::Stop + " Stop test picture")) Server::StopPreview();
            UI::SameLine();
            UI::Text("Test picture on for " + Server::PreviewSecondsLeft() + "s - look at OBS: you should see a green \"Connected\" banner.");
        } else if (UI::Button(Icons::Play + " Show a test picture in OBS")) {
            Server::StartPreview();
        }
        UI::Text(Server::ObsConnected()
            ? "\\$0f0" + Icons::CheckCircle + " OBS is connected. All done!"
            : "\\$fa0" + Icons::HourglassHalf + " Waiting for OBS... (the Browser source must be in the scene you're on)");
    }

    void Step(int n, const string &in text) {
        UI::Text("\\$fa0" + n + ".");
        UI::SameLine();
        UI::TextWrapped(text);
    }
}
