// Stream-Only HUD
// Choose, element by element, what the player sees on their own screen and what viewers
// see on stream. Elements hidden from the player are redrawn for viewers by an OBS
// Browser Source served by this plugin.

[Setting hidden] bool S_FirstRun = true;
[Setting hidden] string S_Visibility = "";   // "key=MS;" pairs, M = my screen, S = stream
[Setting hidden] int S_MedalsCorner = 0;     // 0 top right, 1 top left, 2 bottom right, 3 bottom left

[Setting category="Advanced" name="Overlay port" min=1024 max=65535 description="Only change this if the plugin says the port is in use. The OBS link changes with it."]
int S_Port = 7878;

void Main() {
    Elements::Init();
    Server::LoadOverlay();
    if (S_FirstRun) {
        Window::g_open = true;
        UI::ShowNotification("Stream-Only HUD", "Installed! Press F3 and follow the setup window to connect it to OBS.", 15000);
    }
    while (true) {
        Elements::Update();
        Server::Tick();
        yield();
    }
}

void OnDisabled()  { Shutdown(); }
void OnDestroyed() { Shutdown(); }

void Shutdown() {
    Elements::ReleaseAll();
    Server::Stop();
}

void RenderMenu() {
    if (UI::MenuItem("\\$f80" + Icons::VideoCamera + "\\$z Stream-Only HUD", "", Window::g_open)) {
        Window::g_open = !Window::g_open;
    }
}

void RenderInterface() {
    Window::Render();
}

void Render() {
    Elements::g_medals.RenderInGame();
}

[SettingsTab name="Stream-Only HUD" order=0]
void RenderSettingsTab() {
    Window::RenderContent();
}
