# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**InterValue** — an iOS interval/workout timer app (SwiftUI + SwiftData, iOS 26.2+). Three tabs: Saved Workouts, Quickstart (default), Settings. Workouts run in a full-screen Active Timer with per-set exercise labels, and background audio. AI generates workouts from selected equipment/goals.

App product and scheme are **InterValue**. "IntervalTrainer" is the old name — it survives only in the bundle id `com.michaelsharon.IntervalTrainer`, which must not change (App Store identity).

## Build / run / ship

All commands run from the repo root. There is no test target — verification is by building and running on device.

**Build + install to a device** (find `<device-id>` with `xcrun devicectl list devices`):
```
xcodebuild -project InterValue.xcodeproj -scheme InterValue -allowProvisioningUpdates \
  -destination "id=<device-id>" -configuration Debug -derivedDataPath build clean build
xcrun devicectl device install app --device <device-id> \
  build/Build/Products/Debug-iphoneos/InterValue.app
```

**TestFlight:** `agvtool next-version -all` to bump build, archive Release to `/tmp/InterValue.xcarchive`, export IPA with `ExportOptions.plist`, upload via `xcrun altool` (needs `APP_STORE_API_KEY_ID` / `APP_STORE_API_ISSUER_ID` env vars + the matching `.p8` key).

## Git branches

Commit work only to a branch whose name matches it. Before the first commit of a task, compare the task to the current branch name (`git branch --show-current`). If they don't match — e.g. a UI fix while on `ai-features` — create a fitting branch off `main` (`fix/<topic>`, `feature/<topic>`) and commit there, carrying any uncommitted changes for other work over untouched. Never commit to `main` directly.

## Architecture

MVVM over SwiftData. Every screen is a `View` + an `@Observable` ViewModel; ViewModels reach SwiftData through the `ModelContext` from the environment.

Single app target, no packages or extensions. Services live in `InterValue/Services/` (`TimerEngine`, `SoundManager`, `DeepLinkManager`, `AIService`); SwiftData `@Model`s (`Workout`, `WorkoutInterval`, `AppSettings`) in `InterValue/Models/`. The project uses file-system synchronized groups — dropping a `.swift` file under `InterValue/` adds it to the target, no pbxproj edit needed.

**Data model** (SwiftData, container declared in `InterValueApp.swift`): `Workout` (sets, work/rest/prepare seconds, category, favorite, icon, optional sound/countdown overrides) has a cascade `@Relationship` to ordered `WorkoutInterval`s (per-set labels). `AppSettings` is a singleton — `ContentView.onAppear` inserts one if the query is empty; read `settingsResults.first`.

**Repeat blocks:** consecutive intervals sharing a `WorkoutInterval.blockIndex` form a block whose rounds and round rest live in `Workout.blocks`. `Workout.sets` counts editor rows, not what the timer plays — anything that counts, times or plays sets goes through `Workout.flattenedSets()`, which unrolls blocks into the flat list `TimerEngine` runs.

**TimerEngine** pre-computes a flat phase sequence at start (`prepare → work/rest per set → finish`, no rest after the last set) and advances through it using **wall-clock time**, so it survives background suspension. Background execution relies on an AVAudioSession `.playback` category (silent `AVAudioEngine` keep-alive in `SoundManager`); skip/pause/resume just move the cursor in the sequence.

**Navigation:** `TabView` (`ContentView`), default tab `.quickstart`. Active Timer is a `.fullScreenCover`; Create Workout is a `.sheet` with its own `NavigationStack`.

**Live Activity:** removed (Oct 2026), along with the empty widget extension target. Re-adding means a new Widget Extension target + `NSSupportsLiveActivities` in `Info.plist`.

## Domain specifics

**AI generation** (`InterValue/Services/AIService.swift`): runs on-device with Apple's `FoundationModels` (Apple Intelligence) — no network, no API key, no usage limit. `GeneratedWorkout`/`GeneratedSetConfig` are `@Generable`, so the model returns typed structs (no JSON parsing). `AIService.unavailableReason` drives the "Generate Workout" button in `CreateWorkoutView`: hidden on devices that can't run Apple Intelligence, shows an alert when it's off or still downloading. The prompt treats difficulty (1–4) and goals as simultaneous constraints; output name is clamped to 40 chars, labels to 32; times are cleared when "Generate Times" is off. Categories and set count are enforced at the call site in `CreateWorkoutView`.

**Secrets:** none. Old OpenRouter/Firebase keys in git history are rotated/dead.

**Sounds** (`InterValue/Resources/Sounds/<SoundName>/`): each sound is a folder with three `.m4a` variants named `"<Name> - once/twice/thrice.m4a"` (single, double, triple ring per transition). Bundled sounds: BoxingBell, DigitalBeep, Kantilan, TempleBlock, TibetanBowl.

**Share / import:** `DeepLinkManager` encodes `[WorkoutDTO]` as URL-safe base64 into `intervalue://import?data=…`; `ContentView.onOpenURL` decodes and presents `ImportWorkoutsView`. `WorkoutDTO` is the Codable transport type separate from the SwiftData `@Model`.
