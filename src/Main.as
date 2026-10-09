// Stream-Only HUD
// Choose, element by element, what the player sees on their own screen and what viewers
// see on stream. Elements hidden from the player are redrawn for viewers by an OBS
// Browser Source served by this plugin.

[Setting hidden] bool S_FirstRun = true;
[Setting hidden] string S_Visibility = "";   // "key=MS;" pairs, M = my screen, S = stream
[Setting hidden] int S_MedalsCorner = 0;     // 0 top right, 1 top left, 2 bottom right, 3 bottom left

[Setting category="Advanced" name="Overlay port" min=1024 max=65535 description="Only change this if the plugin says the port is in use. The OBS link changes with it."]
int S_Port = 7878;

const int MAX_FAILED_FRAMES = 60;      // this many errors in a row, for at least
const uint GIVE_UP_AFTER = 5000;       // this many ms, and the plugin gives up
const uint ERROR_LOG_INTERVAL = 10000; // ms between repeated error log lines

bool g_inited = false; // Elements::Init() adds elements to a global list, so it must only run once
bool g_stopped = false; // gave up after repeated errors: draw nothing until the plugin is reloaded

void Main() {
    if (!g_inited) {
        g_inited = true;
        Elements::Init();
    }
    Server::LoadOverlay();
    if (S_FirstRun) {
        Window::g_open = true;
        UI::ShowNotification("Stream-Only HUD", "Installed! Press F3 and follow the setup window to connect it to OBS.", 15000);
    }

    int failedFrames = 0;
    uint64 failingSince = 0;
    uint64 lastErrorLog = 0;
    while (true) {
        try {
            Elements::Update();
            Server::Tick();
            failedFrames = 0;
        } catch {
            if (failedFrames++ == 0) failingSince = Time::Now;
            if (failedFrames == 1 || Time::Now - lastErrorLog >= ERROR_LOG_INTERVAL) {
                lastErrorLog = Time::Now;
                error("Stream-Only HUD error (" + failedFrames + " frame(s) in a row): " + getExceptionInfo());
            }
            if (failedFrames > MAX_FAILED_FRAMES && Time::Now - failingSince >= GIVE_UP_AFTER) {
                error("Stream-Only HUD keeps failing, giving the HUD back and stopping.");
                g_stopped = true;
                try {
                    Shutdown();
                } catch {
                    error("Stream-Only HUD could not clean up: " + getExceptionInfo());
                }
                UI::ShowNotification("Stream-Only HUD",
                    "Something went wrong, so the plugin stopped and your HUD is back to normal. Turn the plugin off and on again in the Plugin Manager to try again.",
                    15000);
                return;
            }
        }
        yield();
    }
}

void OnDisabled()  { Shutdown(); }
void OnDestroyed() { Shutdown(); }

void Shutdown() {
    Elements::ReleaseAll();   // catches per element, so the server is always stopped too
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
    if (g_stopped) return;
    Elements::g_medals.RenderInGame();
}

[SettingsTab name="Stream-Only HUD" order=0]
void RenderSettingsTab() {
    Window::RenderContent();
}
