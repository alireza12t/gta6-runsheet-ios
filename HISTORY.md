# Runsheet iOS: handover

Native SwiftUI version of the Runsheet web app (`GTA6-Guide/app`). Repo: https://github.com/alireza12t/gta6-runsheet-ios

## Where it stands (Nov 22, 2026, version 1.0.0)
- Builds clean with Xcode 27.2 under Swift 6 strict concurrency. Deployment target iOS 18.0.
- Checked in the iOS 18.6 simulator ("Runsheet iPhone 16 Pro", created for this project). Every tab, the Run screen, the place sheet, the loading screen and the lock screen Live Activity were screenshotted in light and dark. Shots are in `docs/screenshots`.
- Live tap test: Build my run, then Done, next, advanced the run and updated the Live Activity.
- 6 unit tests pass: data decodes (574 places, category counts match), board rules, run size and done rules, route visits every stop once, progress survives a relaunch, an unreadable save file is moved aside.
- Live checks in the simulator: swipe to mark found, Checklist "Map" jumps to the pin, pan, pinch zoom, search, About screen (light and dark).

## Update, Nov 22 evening (from the web app's review fixes)
- Map now uses the game's map art tiles (copied from `GTA6-Guide/app/tiles`, zoom -2 to 4) with our borders and labels from `basemap.json`. Alireza approved publishing the art. It blocks an App Store version.
- 1,342 places from the new `places.json` (descriptions, "near" text, gta6tracker and GTA Wiki links). The lazy "buildings" layer (`data/more/`) and place photos from the web app are not ported.
- Pin bubbles below zoom 4 (or on crowded screens), labels drawn above them, a ring on the selected pin, pin kept above the card, map buttons move up while a card is open.
- Richer pin card: progress, where, description or category help, next nearest unfound, source links. Buttons update in place.
- Run: route fits above the card, "3 done, 11 skipped", Coming up folds behind a tap, stop name has a fixed height so the buttons don't move.
- Checklist keeps rows in place when you tick them (re-sorted when you open it or change category).
- Route distance uses true scale (y times 3313/2560), like route.js.
- Contrast: lighter selected segment in dark mode, deeper orange button fill in light mode, footnotes in the darker grey. 44 pt tap targets on the theme, info, chapter and Map buttons.
- Signing team 58WM5RF23G set in `project.yml`. Built and installed on Alireza's iPhone 17 Pro with `devicectl`.
- Unit tests were not re-run after this update (simulator kept off to save RAM). README screenshots for Plan, Guide, Checklist and dark mode are from before the map change.

## Update 2, Nov 22 night (rest of the web commits)
- Pins carry their category icon (SF Symbols standing in for the web's drawn icons, map in `CategoryUI.swift`). Found pins show a tick.
- Buildings and structures (about 3,200, `More/more/`, from the web's `data/more/`) load per map square, only while on screen and from zoom 2.
- Map Filters: a Filters button opens a grouped panel with switches, found counts, Show all / Hide all per group, Clear all and Hide found. The row shows what's on as removable chips.
- Plan "Collect tonight" and the Checklist use one category button that opens a grouped picker. Guide rows have icons.
- Pin card has the category icon in its header. Photos from the web pin card are still not ported.
- 6 unit tests pass. Installed on Alireza's iPhone 17 Pro.

## Decisions made
- **Loading screen** reuses the gta6-countdown animation (SVG path parser, neon trace, colour rising from the bottom, LOADING percent), but traces our Leonida outline and a route line. The countdown drew the GTA VI logo, which is Rockstar's trademark, and the brief says no Rockstar logos. To go back to the logo, copy `GTALogo.swift` and `LogoData.swift` from gta6-countdown, but that brings a trademark into a public repo.
- **Storage** is one JSON file (`Application Support/Runsheet/state.json`), not SwiftData. It's small and easy to migrate. Missing fields fall back to defaults, and a bad file is moved aside, never deleted.
- **Map** is drawn with Canvas from `outline.json`. The canvas view is `Animatable`, so camera moves and the route draw animate frame by frame.
- **Run screen** opens with the iOS 18 zoom transition from the button you tapped (Plan, Map, Checklist or Resume).
- Rules ported from `app.js`: board status order, route row at 2.5, cash row last, 5/10/15/22 stops for 20/40/60/90 minutes, start at the waypoint or Vice City, "Done, next" never marks cash or repeatable tasks done, "route on screen" capped at the 60 nearest.

## Open items
- [ ] Panning the map while a place sheet is open doesn't move the map. Close the sheet first, or look at `presentationBackgroundInteraction`.
- [ ] Not tapped through yet: "Route what's on screen" and the run complete card. Both build fine and use the same code as the Plan run.
- [ ] Search matches place names only, like the web app. Searching a category name ("mural") finds nothing.
- [ ] Re-run the unit tests and retake the README screenshots with the new map.
- [ ] Port place photos (the web loads them from gta6tracker.org) if wanted.
- [ ] The web's pin lift on hover isn't ported (no hover on iPhone). The tapped pin grows and gets a ring instead.
- [ ] **Liquid Glass not seen yet in a screenshot** (it should show on the iPhone 17 Pro). Only iOS 18 simulator runtimes exist on this Mac (runtimes stay uninstalled on purpose), so the screenshots show the material fallback. Run it once on an iOS 26 device or simulator and check the glass search bar, map buttons, chips and run card.
- [ ] Dynamic Island layouts are written but not screenshotted. The iPhone 16 Pro simulator shows the lock screen version only while locked.
- [ ] Run sizes are stop counts, not timed drives, same as the web app.
- [ ] Mission list says "of 91", copied from the web app. Update both if the total changes.
- [ ] No App Store submission (not planned). Signing team is unset.
- [ ] If the web app's data changes, copy the five JSON files from `GTA6-Guide/app/data` into `Runsheet/Resources` again.
