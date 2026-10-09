# Stream-Only HUD: setup (about 2 minutes)

## 1. Install the plugin (in Trackmania)

1. Press **F3**.
2. Click **Plugin Manager** at the top, then **Open manager**.
3. Search **Stream-Only HUD** and click **Install**.

A setup window opens by itself.

## 2. Connect it to OBS (once)

1. In OBS, in the **Sources** box, click **+** and choose **Browser**. Click **OK**.
2. In Trackmania's setup window, click **Copy OBS link**.
3. Back in OBS, click in the **URL** box, delete what's there and press **Ctrl+V**.
4. Set **Width 1920** and **Height 1080**. Click **OK**.
5. Right-click the new source > **Transform** > **Fit to screen**.

In Trackmania's window, click **Show a test picture in OBS**. A green "connected" banner
should appear in OBS. The window also says **OBS is connected**.

## 3. Choose what you see

Open the window any time: **F3 > Plugins > Stream-Only HUD**.

- Untick **On my screen** to hide something from yourself. Viewers still see it.
- Untick **On stream** too to hide it from everyone.
- The inputs, gear and speed boxes from the **Dashboard** plugin are in the same list.
- Press **F7** during a run to see the hidden items yourself; press it again to hide them.
  Change the key (or turn it off) under the list.
- Or click a quick choice: **Hide only the splits from me**, **Hide all times from me**,
  **Show everything normally**.

## If something's wrong

- **Window says "OBS is not connected"**: the Browser source must be in the scene you're
  streaming. Redo step 2.
- **Viewers see things twice**: tick **On my screen** off for that element, or remove any
  other medals plugin window.
- **You can still hear if you're ahead or behind**: that's the checkpoint sound. Turn it
  down in Trackmania's audio settings.
