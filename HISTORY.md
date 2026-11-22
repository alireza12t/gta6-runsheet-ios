# Runsheet iOS: handover

Native SwiftUI version of the Runsheet web app (`GTA6-Guide/app`). Repo: https://github.com/alireza12t/gta6-runsheet-ios

## Where it stands (Nov 22, 2026, version 1.0.0)
- Builds clean with Xcode 27.2 under Swift 6 strict concurrency. Deployment target iOS 18.0.
- Checked in the iOS 18.6 simulator ("Runsheet iPhone 16 Pro", created for this project). Every tab, the Run screen, the place sheet, the loading screen and the lock screen Live Activity were screenshotted in light and dark. Shots are in `docs/screenshots`.
- Live tap test: Build my run, then Done, next, advanced the run and updated the Live Activity.
- 6 unit tests pass: data decodes (574 places, category counts match), board rules, run size and done rules, route visits every stop once, progress survives a relaunch, an unreadable save file is moved aside.
- Live checks in the simulator: swipe to mark found, Checklist "Map" jumps to the pin, pan, pinch zoom, search, About screen (light and dark).

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
- [ ] **Liquid Glass not seen yet.** Only iOS 18 simulator runtimes exist on this Mac (runtimes stay uninstalled on purpose), so the screenshots show the material fallback. Run it once on an iOS 26 device or simulator and check the glass search bar, map buttons, chips and run card.
- [ ] Dynamic Island layouts are written but not screenshotted. The iPhone 16 Pro simulator shows the lock screen version only while locked.
- [ ] Map labels can sit under pins when zoomed out. Consider hiding region labels under dense pins, or clustering pins.
- [ ] Run sizes are stop counts, not timed drives, same as the web app.
- [ ] Mission list says "of 91", copied from the web app. Update both if the total changes.
- [ ] No App Store submission (not planned). Signing team is unset.
- [ ] If the web app's data changes, copy the five JSON files from `GTA6-Guide/app/data` into `Runsheet/Resources` again.
