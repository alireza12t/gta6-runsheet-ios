# Runsheet for iPhone

An unofficial GTA VI companion, built natively in SwiftUI. Plan a session from your chapter, character, in-game time and how long you can play, find what's left on a map of 1,342 places, and run it stop by stop with a Live Activity on your lock screen.

It's the native version of the Runsheet web app. All your progress stays on your iPhone. No account, no server.

- **Web version:** https://alireza12t.github.io/gta6-runsheet/
- **Web version source:** https://github.com/alireza12t/gta6-runsheet

Made by **Alireza Toghiani**.

> Not affiliated with Rockstar Games or Take-Two Interactive. Fan-made guide. Map art © Rockstar Games, via the GTA Wiki. No Rockstar logos or fonts.

| Plan | Live board | Map | Place |
|---|---|---|---|
| ![Plan](docs/screenshots/plan-light.png) | ![Live board](docs/screenshots/board-light.png) | ![Map](docs/screenshots/map-light.png) | ![Place](docs/screenshots/place-light.png) |

| Run | Lock screen | Guide | Checklist |
|---|---|---|---|
| ![Run](docs/screenshots/run-light.png) | ![Live Activity](docs/screenshots/live-activity.png) | ![Guide](docs/screenshots/guide-light.png) | ![Checklist](docs/screenshots/checklist-light.png) |

Dark mode:

| Plan | Map | Run | Missions |
|---|---|---|---|
| ![Plan dark](docs/screenshots/plan-dark.png) | ![Map dark](docs/screenshots/map-dark.png) | ![Run dark](docs/screenshots/run-dark.png) | ![Missions dark](docs/screenshots/missions-dark.png) |

Loading screen:

| Trace | Fill |
|---|---|
| ![Loading trace](docs/screenshots/loading-trace.png) | ![Loading fill](docs/screenshots/loading-fill.png) |

## What it does
- **Plan.** Pick chapter, Jason or Lucia, day or night, and 20 to 90 minutes. The live board shows what's open right now, like a departure board: blue is live now, amber is closing, green is ready, grey is money. Each line shows how many sources agree.
- **Run.** A route through the nearest unfound places (nearest neighbour, then 2-opt, measured at true map scale), drawn on the map as it starts. The finish card counts done and skipped stops. Done and Skip move you along, with haptics. The Live Activity and Dynamic Island show the next stop and a progress line.
- **Map.** The game's map art as tiles, with our own area borders and labels on top, drawn with SwiftUI Canvas. Pinch, pan, double tap. Pins carry category icons and close ones group into numbered bubbles when zoomed out. A Filters panel turns categories on by group, and about 3,200 buildings load square by square as you zoom in. Tap a pin for details, the next nearest unfound spot, waypoint and mark found, or route whatever is on screen (up to 60 stops).
- **Guide.** Collectible progress, missions by chapter, Strangers & Freaks, money rules and ways to earn, cheats and trophies.
- **Checklist.** Every collectible and money spot, picked from a grouped category list. Swipe right to mark found, swipe left to see it on the map.

## Build it
Needs Xcode 26 or newer. The app runs on iOS 18 and up. On iOS 26 it uses native Liquid Glass (`glassEffect`, glass tab bar and buttons); on iOS 18 it falls back to materials.

1. Open `Runsheet.xcodeproj`.
2. Pick a simulator, or set your own team under Signing & Capabilities for a real iPhone.
3. Run.

The project file comes from `project.yml`. If you change targets or settings, regenerate it with:

```bash
xcodegen generate
```

Run the tests with `Cmd+U`, or:

```bash
xcodebuild test -project Runsheet.xcodeproj -scheme Runsheet -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Launch arguments for screenshots
`-RSSkipLoading`, `-RSTab map|guide|checklist`, `-RSGuide missions|money|cheats`, `-RSPlace <id>`, `-RSDemoRun`, `-RSRunSteps <n>`, `-RSScrollBoard`, `-RSHoldLoading <0..1>`. Add `-RSEphemeral` so nothing is saved, and `-RSDemoFound` to tick a sample of places.

## How it's put together
| Folder | What's in it |
|---|---|
| `Runsheet/Data` | Codable models for the bundled JSON, the route solver, saved state, and the store with the plan board rules |
| `Runsheet/Screens` | Plan, Map (Canvas map and gestures), Run, Guide, Checklist, About |
| `Runsheet/Design` | Colours, Liquid Glass with a material fallback, tags, chips, the progress line |
| `Runsheet/Loading` | The launch animation |
| `RunsheetWidgets` | The Live Activity and Dynamic Island |
| `Shared` | The Live Activity attributes, used by both targets |
| `Runsheet/Resources` | `places.json`, `basemap.json` (borders, labels, which tiles exist), `guide.json`, `tonight.json`, `money.json`, `outline.json` |
| `Tiles/tiles` | Map art tiles, zoom -2 to 4, same files as the web app |

Progress is a single JSON file in Application Support. If it can't be read, the app moves it aside and starts fresh. It never deletes it.

## Credits
- **Map locations** come from [gta6tracker.org](https://gta6tracker.org), which builds on the GTA Wiki (CC BY-SA). They're marked unverified in the app, exactly as the data says. The location data keeps its CC BY-SA terms.
- **Plan items, missions, cheats and money tips** are hand-written from guide summaries. No payout numbers are shown, because none are confirmed.
- **Map art** © Rockstar Games, via the GTA Wiki. It's in this repo for the fan app and the web version only, which also means this app can't go on the App Store as is. Area borders and labels are our own and approximate.
- **The loading animation** is adapted from [gta6-countdown](https://github.com/alireza12t/gta6-countdown) (MIT). It traces the Leonida outline instead of the game's logo.
- Design inspired by Flighty's departure-board layout. No Flighty assets are used.

## Made by
**Alireza Toghiani**

- Website: https://alireza12t.github.io/
- GitHub: [@alireza12t](https://github.com/alireza12t)
- X: [@DevMvRick](https://x.com/DevMvRick)
- YouTube: [@DevMvRick](https://www.youtube.com/@DevMvRick)
- Instagram: [@devmvrick](https://www.instagram.com/devmvrick)
- LinkedIn: [alireza12t](https://www.linkedin.com/in/alireza12t)

If you find a wrong location or a missing item, open an issue.

## License
The app code is MIT licensed, see [LICENSE](LICENSE). The location data in `places.json` is CC BY-SA, from the GTA Wiki via gta6tracker.org.

Grand Theft Auto and GTA are trademarks of Take-Two Interactive. This project isn't endorsed by or connected to Rockstar Games or Take-Two Interactive.
