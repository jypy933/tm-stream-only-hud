// Show/hide key: one key press puts the stream-only elements back on the player's screen,
// the next press hides them again. The saved choices in the window don't change.

[Setting hidden] bool S_KeyEnabled = true;
[Setting hidden] VirtualKey S_ToggleKey = VirtualKey::F7;

namespace Hotkey {
    bool g_capturing = false;

    string KeyName() {
        return S_KeyEnabled ? tostring(S_ToggleKey) : "none";
    }

    void Render() {
        UI::Text("Show/hide key:");
        UI::SameLine();
        if (g_capturing) {
            UI::Text("\\$fa0Press the key you want... \\$888(Esc to cancel)");
            return;
        }
        UI::Text("\\$fff" + KeyName());
        UI::SameLine();
        if (UI::Button(Icons::Keyboard + " Change")) g_capturing = true;
        if (S_KeyEnabled) {
            UI::SameLine();
            if (UI::Button(Icons::Times + " No key")) {
                S_KeyEnabled = false;
                Meta::SaveSettings();
            }
        }
        UI::TextDisabled("Press it during a run to see the hidden items yourself for a moment. Press it again to hide them.");
    }
}

UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
    if (!down) return UI::InputBlocking::DoNothing;

    if (Hotkey::g_capturing) {
        Hotkey::g_capturing = false;
        if (key != VirtualKey::Escape) {
            S_ToggleKey = key;
            S_KeyEnabled = true;
            Meta::SaveSettings();
        }
        return UI::InputBlocking::Block; // don't let the game act on the key being assigned
    }

    if (S_KeyEnabled && key == S_ToggleKey) Elements::TogglePeek();
    return UI::InputBlocking::DoNothing;
}
