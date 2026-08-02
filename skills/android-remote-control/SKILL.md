---
name: android-remote-control
description: >
  Use this skill when controlling an Android device through the Android Remote
  Control MCP server — reading the screen, navigating apps and home screen,
  opening URLs in Chrome, tapping/typing/scrolling, managing files in device
  storage, checking device settings (including ADB / wireless debugging state),
  taking photos, reading notifications, or any task that requires interacting
  with a physical Android phone or tablet from the host. Triggers on requests
  like "check my Android phone", "open a website on the device", "read what's
  on the screen", "go to developer options", "enable USB debugging", "check
  if ADB is enabled", "take a photo from the phone", "list files on the
  device", or any task involving an Android device managed via the
  android-remote-control MCP tools.
---

# Android Remote Control

Control a physical Android device via the Android Remote Control MCP server.
The device runs an accessibility-service-based MCP app — it does NOT require
ADB or root. All interaction happens through MCP tool calls that map to
accessibility actions, gestures, intents, and file/storage APIs.

## Orientation

Run the following before proceeding to confirm the MCP server is connected and
discover available storage and apps:

```
android_list_storage_locations
android_list_apps filter=user
android_get_screen_state
```

## How to read a page (screen state)

Call `android_get_screen_state`. This returns:

- `screen: <w>x<h> density:<n> orientation:<landscape|portrait>`
- One block per window, each with `pkg`, `title`, `activity`, `focused`
- A flat node table: `node_id | class | text | desc | res_id | bounds | flags`
- A `hierarchy:` section showing node nesting via indentation

Flags: `on`=onscreen, `off`=offscreen, `clk`=clickable, `lclk`=longClickable,
`foc`=focusable, `scr`=scrollable, `edt`=editable, `ena`=enabled.

### Pagination

Large screens split into pages of 200 nodes. The response includes a
`page:N/total` line and a `cursor`. Call again with that `cursor` to fetch the
next page. Stop as soon as the needed node is found — do not fetch every page.

### Screenshots

`include_screenshot=true` can ONLY be requested on page 1 (no cursor). The
screenshot is a low-resolution image attachment. Use it when the node tree is
insufficient (custom views, Canvas, game UI, Samsung One UI preferences).

### Find a specific element

```
android_find_nodes by="text" value="Settings"
android_find_nodes by="resource_id" value="com.android.chrome:id/url_bar"
android_find_nodes by="content_desc" value="Chrome"
android_find_nodes by="class_name" value="android.widget.EditText"
```

`exact_match=false` (default) matches contains, case-insensitive.
`exact_match=true` matches exactly.

### Retrieve full text

`android_get_node_details` with one or more `node_ids` returns full untruncated
text and description — use when the node table shows `...truncated`.

### Wait for an element

```
android_wait_for_node by="text" value="Example Domain" timeout=10000
```

### Wait for UI to settle

```
android_wait_for_idle timeout=5000
```

Returns when the screen stops changing (similarity-based). Some pages never go
fully idle (animations, feeds); use a lower `match_percentage` (e.g. 95) or rely
on `wait_for_node` instead. Action tools already wait for their gesture to
complete before returning — only call `wait_for_idle` when confirming a
transition.

## Go to home screen

```
android_press_home
```

Then call `android_get_screen_state` to see launcher icons. Tap an icon with
`android_tap_node` (uses node_id from the tree).

## Go to Chrome

Two approaches:

**Via `open_app` (preferred — launches the app directly):**
```
android_open_app package_id="com.android.chrome"
```

**Via home screen tap (if the app icon is visible on the launcher):**
```
android_press_home
android_get_screen_state
# Find the Chrome icon node, then:
android_tap_node node_id="<chrome_icon_node_id>"
```

After launching, call `android_get_screen_state` to see Chrome's UI. On a new
tab the URL bar has `res_id=com.android.chrome:id/url_bar` (toolbar) or
`com.android.chrome:id/search_box_text` (large centered search box on the
new tab page).

### Chrome toolbar resource IDs

| Element | resource_id | content_desc |
|---------|-------------|--------------|
| URL bar | `com.android.chrome:id/url_bar` | - |
| Home button | `com.android.chrome:id/home_button` | "Open the home page" |
| New tab button | `com.android.chrome:id/optional_toolbar_button` | "New tab" |
| Tab switcher | `com.android.chrome:id/tab_switcher_button` | "See N tabs" |
| 3-dot menu | `com.android.chrome:id/menu_button` | "Customize and control Google Chrome" |
| Voice search | `com.android.chrome:id/mic_button` | "Start voice search" |
| Google Lens | `com.android.chrome:id/lens_camera_button` | "Search with your camera using Google Lens" |

On the new-tab page there is also a large centered search box:
`com.android.chrome:id/search_box_text`.

## Go to a website using Chrome

**Via `open_uri` (preferred — navigates directly, no manual typing):**
```
android_open_uri uri="https://example.com" package_name="com.android.chrome"
```

The optional `package_name` forces Chrome to handle the URI. Without it,
Android may offer a chooser or use a different default browser.

**Via the URL bar (manual typing):**
```
android_find_nodes by="resource_id" value="com.android.chrome:id/url_bar"
android_click_node node_id="<url_bar_node_id>"
android_type_append_text node_id="<url_bar_node_id>" text="https://example.com"
android_press_key key="ENTER"
```

**Via clipboard paste into the URL bar (two methods):**

Method 1 — Chrome auto-detects clipboard URLs. When the URL bar is focused and
the clipboard contains a URL, Chrome shows a "Link you copied" suggestion in
the omnibox dropdown. Tap it:
```
android_set_clipboard text="https://example.com"
android_find_nodes by="resource_id" value="com.android.chrome:id/url_bar"
android_click_node node_id="<url_bar_node_id>"
android_find_nodes by="text" value="Link you copied"
android_click_node node_id="<link_you_copied_node_id>"
```

Method 2 — long-press the URL bar to bring up the Paste popup:
```
android_set_clipboard text="https://example.com"
android_find_nodes by="resource_id" value="com.android.chrome:id/url_bar"
android_click_node node_id="<url_bar_node_id>"
# Re-find the node (ID may change after focus):
android_find_nodes by="resource_id" value="com.android.chrome:id/url_bar"
android_long_click_node node_id="<url_bar_node_id>"
android_find_nodes by="text" value="Paste"
# click_node may fail on the popup; use tap_node instead:
android_tap_node node_id="<paste_node_id>"
android_press_key key="ENTER"
```

After navigation, call `android_get_screen_state` or `android_find_nodes` to
verify the page loaded. For slow pages, use `android_wait_for_node` with a
known page text (e.g. `value="Example Domain"`).

### Reading page content

When a page loads in Chrome, the WebView content is exposed as a single
`WebView` node whose `text` field contains a flattened text dump of the page
(headings, links, and body text concatenated). This is often truncated in the
node table — call `android_get_node_details` to retrieve the full text.

For pages with many text elements (news feeds, articles), individual `View`
and `TextView` nodes may also appear, each containing a paragraph or heading.
Use `android_find_nodes by="text" value="..."` to locate specific content.

Scrolling a web page uses the same `android_scroll` tool — the scroll targets
the focused scrollable container (the WebView).

### Chrome 3-dot menu

Tap the menu button (`com.android.chrome:id/menu_button`) to open a popup with:
- Top row: Forward, Bookmark, Download, Page info, Refresh
- Menu items: New tab, New Incognito tab, Add tab to new group, History,
  Delete browsing data, Downloads, Bookmarks, Recent tabs

Each menu item has a `resource_id` like `com.android.chrome:id/new_tab_menu_id`,
`com.android.chrome:id/open_history_menu_id`, etc.

Press `android_press_back` to dismiss the menu without selecting.

### Chrome tab switcher

Tap the tab switcher button (`com.android.chrome:id/tab_switcher_button`,
content_desc "See N tabs") to open a grid view of all open tabs. Each tab card
has:
- A title TextView (`com.android.chrome:id/tab_title`) whose `text` is the
  page title and `content_desc` is `<title>, Tab`
- A close button (`com.android.chrome:id/action_button`) with content_desc
  `Close <title> tab`

To switch to a tab, tap its card (`FrameLayout` containing the title). To
close a tab, tap its close button. Press `android_press_back` to return to
the current tab without switching.

The tab count is visible in the tab switcher button's content_desc: "See 8
tabs". Use this to monitor how many tabs are open.

### Refresh / reload a page

Open the 3-dot menu and tap "Refresh" (`com.android.chrome:id/button_five`),
or use `android_open_uri` with the same URL to force a reload.

### Opening other URI types

`android_open_uri` also handles `tel:`, `mailto:`, `geo:`, `content://`,
deep links, and app schemes (e.g. `whatsapp://send?phone=...`). Pass
`package_name` to force a specific app, and `mime_type` for content URIs.

## Go to Android Settings and check ADB (USB debugging) state

### Open Developer Options

```
android_send_intent type="activity" action="android.settings.APPLICATION_DEVELOPMENT_SETTINGS"
```

This opens the Developer Options screen directly.

### Other useful settings intents

| Action | Opens |
|--------|-------|
| `android.settings.APPLICATION_DEVELOPMENT_SETTINGS` | Developer Options |
| `android.settings.SETTINGS` | Main Settings |
| `android.settings.WIFI_SETTINGS` | Wi-Fi settings |
| `android.settings.BLUETOOTH_SETTINGS` | Bluetooth |
| `android.settings.LOCATION_SOURCE_SETTINGS` | Location |
| `android.settings.APP_NOTIFICATION_SETTINGS` | Notification settings |

### Check if USB debugging is enabled

Once in Developer Options, scroll to the "Debugging" section and look for the
"USB debugging" toggle:

```
android_scroll direction="down" amount="large"
android_find_nodes by="text" value="USB debugging"
```

**Critical Samsung One UI gotcha:** On Samsung devices running One UI, the
"USB debugging" toggle row is a custom preference view that is **NOT exposed
in the accessibility tree**. `find_nodes` will return empty, and the node tree
will show a visual gap between the "Debugging" section header and "Revoke USB
debugging authorizations" where the toggle sits. To see it, request a
screenshot:

```
android_get_screen_state include_screenshot=true
```

### Reading the toggle state

If the toggle IS visible in the tree, look for a `Switch` child node in the
same row. Its text will be "On" or "Off".

If the toggle is NOT in the tree (Samsung), use a screenshot to identify:
- Toggle ON: appears blue/green with text "On"
- Toggle OFF: appears gray with text "Off"

### Enable or disable USB debugging

If the row is visible in the tree, tap the row (not just the switch) to toggle:

```
android_click_node node_id="<usb_debugging_row_node_id>"
```

If a confirmation dialog appears, find and tap "OK" or "Allow":
```
android_find_nodes by="text" value="OK"
android_click_node node_id="<ok_button_node_id>"
```

If the row is NOT in the tree (Samsung), tap at the approximate coordinates of
the gap between the "Debugging" header and "Revoke USB debugging
authorizations":

```
android_get_screen_state
# Note the bounds of "Debugging" header and "Revoke..." row
# The USB debugging toggle sits in the vertical gap between them
# Tap at the midpoint of that gap, on the right side (where the toggle is):
android_tap x="<switch_x>" y="<gap_center_y>"
```

To **disable**, repeat the same tap — toggles flip state on each tap. Confirm
by taking a screenshot or re-reading the tree.

### Wireless debugging (Android 11+)

Wireless debugging is a separate sub-page entry below USB debugging in
Developer Options. Find "Wireless debugging" in the tree:

```
android_find_nodes by="text" value="Wireless debugging"
```

Tap the row to open the Wireless debugging detail page, which shows the IP
address and port, and a toggle to enable/disable it.

### Verify developer options is enabled

The master "Developer options" toggle at the top of the screen
(`res_id=com.android.settings:id/sesl_switchbar_switch`) must be ON. If it is
OFF, developer settings are hidden and all toggles are inactive.

## File and storage operations

### List storage locations

```
android_list_storage_locations
```

Returns built-in locations (Downloads, Pictures, Movies, Music) with their
`location_id`, path, available bytes, and read/write/delete permissions.

### List files

```
android_list_files location_id="builtin:downloads"
android_list_files location_id="builtin:downloads" path="subfolder"
android_list_files location_id="builtin:downloads" offset=0 limit=200
```

Returns `name`, `path`, `is_directory`, `size`, `last_modified`, `mime_type`.

### Read a file

```
android_read_file location_id="builtin:downloads" path="notes.txt"
android_read_file location_id="builtin:downloads" path="notes.txt" offset=1 limit=200
```

Returns content with line numbers. Max 200 lines per call.

### Write a file

```
android_write_file location_id="builtin:downloads" path="folder/file.txt" content="hello"
```

Creates parent directories automatically. Overwrites existing content.

### Append to a file

```
android_append_file location_id="builtin:downloads" path="folder/file.txt" content="more text"
```

### Find and replace in a file

```
android_file_replace location_id="builtin:downloads" path="file.txt" old_string="foo" new_string="bar"
android_file_replace location_id="builtin:downloads" path="file.txt" old_string="foo" new_string="bar" replace_all=true
```

### Delete a file

```
android_delete_file location_id="builtin:downloads" path="folder/file.txt"
```

Cannot delete directories — only files.

### Share a file via temporary web URL

```
android_share_file_via_web location_id="builtin:downloads" path="doc.pdf"
```

Returns a temporary URL (expires 1h, multiple fetches allowed). Use
`web_fetch` to read the file content, or give the URL to the user as a
download link. Limited to 64 MB.

### Download a file from a URL

```
android_download_from_url location_id="builtin:downloads" path="downloaded.txt" url="https://example.com/file.txt"
```

HTTP downloads and unverified HTTPS must be explicitly allowed in the MCP
app settings (toggle on the Storage tab).

## Notifications

```
android_notification_list
android_notification_open notification_id="<id>"
android_notification_dismiss notification_id="<id>"
android_notification_action action_id="<id>"
android_notification_reply action_id="<id>" text="reply text"
android_notification_snooze notification_id="<id>" duration_ms=600000
```

`notification_open` fires the content intent (opens the app). `notification_action`
fires an action button. `notification_reply` replies to messaging notifications
that accept text (check `accepts_text` in the notification list).

Pull down the shade directly:
```
android_open_notifications
android_open_quick_settings
```

## Other device capabilities

### Installed apps

```
android_list_apps filter="all"            # all apps
android_list_apps filter="user"           # user-installed only
android_list_apps filter="system"         # system apps
android_list_apps filter="user" name_query="chrome"
```

Returns `package_id`, `name`, `version_name`, `version_code`, `is_system`.

### Launch an app

```
android_open_app package_id="com.android.chrome"
```

### Kill a background app

```
android_close_app package_id="com.example.app"
```

For a hung foreground app, press home first, then close.

### GPS location

```
android_get_location                        # last known (fast, possibly stale)
android_get_location fresh_fix=true         # fresh GPS (up to 10 seconds)
```

Returns `latitude`, `longitude`, `accuracy_meters`, `street` (if geocoding
available). Requires ACCESS_FINE_LOCATION and Google Play Services.

### Cameras

```
android_list_cameras
android_list_camera_photo_resolutions camera_id="0"
android_list_camera_video_resolutions camera_id="0"
android_take_camera_photo camera_id="0"              # returns base64 JPEG inline
android_save_camera_photo camera_id="0" location_id="builtin:downloads" path="photo.jpg"
android_save_camera_video camera_id="0" location_id="builtin:downloads" path="video.mp4" duration=10
```

Camera 0 = back, 1 = front. `take_camera_photo` returns inline (max 1920x1080).
`save_camera_photo` saves to storage (full resolution available).

### Device logs

```
android_get_device_logs
android_get_device_logs level="E" last_lines=50
android_get_device_logs tag="MCP:ServerService" since="2024-01-15T10:30:00"
android_get_device_logs package_name="com.example.app"
```

### Clipboard

```
android_set_clipboard text="hello"
android_get_clipboard
```

### Shared content (content shared TO the MCP app via Android Share)

```
android_get_shared_content
```

Read-once. Text returned inline; images return a download URL; other files
return a fetch URL.

## Interaction reference

### Tap / click

```
android_click_node node_id="<id>"          # accessibility ACTION_CLICK
android_tap_node node_id="<id>"            # coordinate-based tap within node bounds
android_tap x=500 y=800                    # tap at exact coordinates
android_double_tap x=500 y=800
android_long_click_node node_id="<id>"      # accessibility long click
android_long_press x=500 y=800 duration=1000
```

### Type text

```
android_type_append_text node_id="<field_id>" text="hello"
android_type_insert_text node_id="<field_id>" text="hello" offset=0
android_type_replace_text node_id="<field_id>" search="foo" new_text="bar"
android_type_clear_text node_id="<field_id>"
```

All type tools use natural InputConnection typing (indistinguishable from
keyboard input). Max 2000 chars per call; for longer text, call multiple
times — subsequent calls continue at the cursor position.

### Keyboard

```
android_press_key key="ENTER"
android_press_key key="BACK"
android_press_key key="DEL"
android_press_key key="HOME"
android_press_key key="TAB"
android_press_key key="SPACE"
android_dismiss_keyboard                          # close on-screen keyboard
```

`android_press_back` is the global accessibility back action (preferred over
`press_key key="BACK"` for navigation).

### Navigation

```
android_press_home            # home screen
android_press_back           # back button
android_press_recents        # recent apps
```

### Scroll

```
android_scroll direction="down" amount="medium"
android_scroll direction="up" amount="small"
android_scroll direction="left" amount="large"
android_scroll direction="right" amount="medium"
android_scroll_to_node node_id="<id>"
```

Amounts: `small`, `medium`, `large`. Random variance is applied for natural
gesture appearance.

### Gestures

```
android_swipe x1=0 y1=500 x2=0 y2=1000 duration=300
android_pinch center_x=960 center_y=600 scale=2.0     # zoom in
android_pinch center_x=960 center_y=600 scale=0.5     # zoom out
android_custom_gesture paths=[[{"x":0,"y":0,"time":0},{"x":500,"y":500,"time":500}]]
```

## Gotchas

- **Custom views missing from the accessibility tree.** The screen state note
  says: "certain elements are custom and will not be properly reported." On
  Samsung One UI, the "USB debugging" toggle in Developer Options is a custom
  preference view that does NOT appear in the node tree — `find_nodes` returns
  empty and there is a visible gap in the layout where the row should be. Use
  `include_screenshot=true` to see it, or tap the approximate coordinates of
  the gap. Other Samsung preference rows may have the same issue.

- **`append_file` adds NO newline separator.** The appended text is
  concatenated directly to the end of existing content with no `\n`. Always
  prepend `\n` in the content if a new line is needed: `content="\nappended"`.

- **`list_files` on a nonexistent path returns empty, not an error.** An empty
  `files` array with `total_count: 0` means either the directory is empty OR it
  does not exist — there is no way to distinguish via the API. Use a parent
  listing to confirm the path exists.

- **`read_file` on a nonexistent file returns a clear error:**
  `File not found: <path> in location '<location_id>'`.

- **`write_file` overwrites silently.** No prompt — existing content is
  replaced. Read first if merging is needed.

- **`file_replace` replaces the first occurrence by default.** Pass
  `replace_all=true` to replace every occurrence. Fails if `old_string` is not
  found or matches multiple times without `replace_all`.

- **Screenshots can only be requested on page 1.** `include_screenshot=true`
  works only when `cursor` is omitted. If paginating, capture the screenshot on
  the first call.

- **`wait_for_idle` may never return on animated pages.** Feeds, carousels,
  and loading spinners keep the screen changing. Use `wait_for_node` instead,
  or pass a lower `match_percentage` (e.g. 95) and a timeout.

- **Node IDs are stable within a single screen snapshot but invalidate on
  navigation or re-snapshot.** After any navigation, scroll, or state change,
  call `android_get_screen_state` or `android_find_nodes` to get fresh node
  IDs before interacting. Stale node IDs will cause actions to fail or hit the
  wrong element.

- **`find_nodes` with `exact_match=false` (default) matches contains,
  case-insensitive.** Searching "debug" will match "Debugging", "USB debugging",
  and "Revoke USB debugging authorizations". Use `exact_match=true` when
  targeting a specific label.

- **The on-screen keyboard covers elements after typing.** Type tools leave
  the keyboard open. Call `android_dismiss_keyboard` before tapping elements
  that may be hidden behind it.

- **The Samsung keyboard is fully exposed in the a11y tree.** When the
  keyboard is open, every individual key appears as a `ViewGroup` node with
  the key label as its `content_desc` (e.g. `desc="q"`, `desc="Go"`, `desc="Space bar"`).
  This inflates the node count significantly. To find non-keyboard elements,
  filter by `class_name` (e.g. `android.widget.TextView`, `android.widget.EditText`)
  or `resource_id` to avoid matching keyboard keys.

- **`click_node` may fail on popup/overlay elements; use `tap_node` instead.**
  The Chrome paste popup (after long-pressing the URL bar) returns
  `ACTION_CLICK failed on node` when using `click_node`. The same node works
  with `tap_node` (coordinate-based tap within the node bounds). Prefer
  `tap_node` for any overlay, popup, or floating menu element.

- **Chrome auto-detects clipboard URLs in the omnibox.** When the URL bar is
  focused and the clipboard contains a URL, Chrome shows a "Link you copied"
  suggestion at the top of the omnibox dropdown. Tapping it navigates
  directly — no paste needed. This is the fastest way to open a URL that was
  copied programmatically via `android_set_clipboard`.

- **Node IDs change when focus shifts.** After clicking the URL bar to focus
  it, the URL bar's `node_id` changes (the tree is rebuilt with the focused
  state). Re-run `android_find_nodes` before interacting with the same element
  after a focus change.

- **WebView page content is a single flattened text node.** Chrome renders
  page content as one `WebView` node whose `text` is all visible page text
  concatenated (headings, links, body). The node table truncates this — use
  `android_get_node_details` for the full text. Individual paragraph/heading
  `View` nodes may also appear but are not guaranteed.

- **`open_uri` with a plain `android.settings.DEVELOPER_SETTINGS` URI fails
  with "No app found to handle URI."** Use `android_send_intent` with
  `type="activity"` and `action="android.settings.APPLICATION_DEVELOPMENT_SETTINGS"`
  instead — intents handle settings actions that URIs cannot.

- **The MCP server runs as a foreground notification.** It appears in the
  notification list as "MCP Server Running" (ongoing, not clearable). Closing
  or force-stopping this notification kills the MCP server and all
  `android_*` tools stop responding.

- **`list_cameras` does not report flash support reliably on all devices.**
  Both front and back cameras here report `has_flash: false` — verify by
  testing with `flash_mode: "on"` and checking the result.

- **`get_location` without `fresh_fix` may return a stale position.** For
  accurate current location, pass `fresh_fix=true` and allow up to 10 seconds.
  Street address may be null if reverse geocoding is unavailable.

- **`download_from_url` requires explicit opt-in for HTTP and unverified
  HTTPS.** Toggle "Allow HTTP Downloads" and "Allow Unverified HTTPS" in the
  MCP app's Storage settings before downloading from non-HTTPS or
  self-signed sources.

- **`save_camera_video` max duration is 30 seconds.** For longer recordings,
  record multiple clips.

- **Device log timestamps do not include the year.** Filtering across year
  boundaries (e.g. December to January) may be inaccurate.

## Workflow

1. **Confirm MCP is connected:** `android_list_storage_locations` (returns
   quickly and confirms the server is responsive).
2. **Read the current screen:** `android_get_screen_state` (without screenshot
   first; add `include_screenshot=true` only if the tree is insufficient).
3. **Navigate:** `android_press_home` / `android_press_back` / `android_open_app`
   / `android_open_uri` / `android_send_intent`.
4. **Interact:** `android_find_nodes` → `android_click_node` or
   `android_tap_node` → `android_type_append_text` if input is needed.
5. **Verify:** `android_get_screen_state` or `android_find_nodes` after every
   navigation or interaction to confirm the expected state.
