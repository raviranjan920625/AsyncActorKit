# AsyncActorKit

A production-quality iOS reference application demonstrating **every major Swift Concurrency feature** through a real 5-day weather forecast app powered by the OpenWeather RapidAPI.

---

## Architecture

```
AsyncActorKit/
├── App/
│   └── AsyncActorKitApp.swift        @main entry — pure SwiftUI, no SwiftData
│
├── Presentation/
│   ├── ContentView.swift             Root TabView (.task {} lifecycle)
│   ├── WeatherDashboardView.swift    Minimalist dark-mode dashboard
│   ├── AsyncImageGridView.swift      TaskGroup icon fan-out demo
│   └── WeatherViewModel.swift        @Observable @MainActor, Task cancellation
│
├── Domain/
│   ├── Actors/
│   │   ├── WeatherActor.swift        Core actor — reentrancy & isolation demo
│   │   ├── CacheActor.swift          Thread-safe generic LRU cache
│   │   └── LocationActor.swift       CLLocationManager → AsyncStream bridge
│   ├── Models/
│   │   ├── WeatherResponse.swift     Codable model tree + DailyForecast aggregation
│   │   └── AppError.swift            Typed error hierarchy (Sendable)
│   └── Protocols/
│       └── WeatherRepositoryProtocol.swift
│
├── Data/
│   ├── Repositories/
│   │   └── WeatherRepository.swift   Memory → Disk → Network cascade
│   ├── Network/
│   │   ├── NetworkSession.swift      async/await URLSession wrapper
│   │   └── RetryPolicy.swift         Actor-isolated exponential backoff
│   └── Bridge/
│       └── LegacyBridge.swift        withCheckedThrowingContinuation demo
│
├── Infrastructure/
│   ├── RapidAPIClient.swift          OpenWeather RapidAPI client
│   ├── DiskCacheService.swift        Async file I/O actor
│   └── LoggerActor.swift             @globalActor + os.Logger
│
└── Tests/
    ├── ActorTests.swift              Isolation, LRU eviction, reentrancy
    ├── ConcurrencyTests.swift        TaskGroup, cancellation, continuations
    └── MockNetworkSession.swift      Async protocol mock
```

---

## Swift Concurrency Features Demonstrated

| Feature | Where |
|---|---|
| `actor` — mutable state isolation | `WeatherActor`, `CacheActor`, `DiskCacheService`, `RetryPolicy` |
| `@globalActor` | `LoggerActor` |
| `async / await` | Every layer — networking, cache, repository |
| Suspension points & reentrancy | `WeatherActor.fetchForecast` (annotated) |
| `Task` + `.cancel()` | `WeatherViewModel.loadTask` |
| `Task.isCancelled` / `CancellationError` | `WeatherViewModel.performLoad` |
| `withTaskGroup` (fan-out) | `AsyncImageGridView`, `WeatherViewModel.runConcurrencyDemo` |
| `withThrowingTaskGroup` | `ConcurrencyTests` |
| `AsyncStream` + bridge | `LocationActor.locationStream()` |
| `withCheckedThrowingContinuation` | `LegacyBridge.fetchData(from:)`, `LocationActor.requestCurrentLocation` |
| `withCheckedContinuation` | `LegacyBridge.fetchDataOrEmpty(from:)` |
| `@Observable` macro | `WeatherViewModel` |
| `@MainActor` | `WeatherViewModel` |
| `Sendable` conformance | All models, errors, mocks |
| Protocol-based async mocking | `NetworkSessionProtocol`, `MockNetworkSession` |
| `Task.sleep(for:)` (typed Duration) | `RetryPolicy` |
| `nonisolated` delegate bridge | `LocationActor` CLLocationManagerDelegate |

---

## API

**Endpoint:** `GET https://open-weather13.p.rapidapi.com/fivedaysforcast`

```
latitude  = 23.344100   (Ranchi default)
longitude = 85.309600
lang      = EN
```

Default coordinates are Ranchi, India. Pull-to-refresh fetches fresh data (clears both memory and disk caches first).

---

## Running the App

1. Open `AsyncActorKit.xcodeproj` in Xcode 16+
2. Select an iOS 17+ simulator
3. **Product → Run** (`⌘R`)

> No additional configuration needed — the RapidAPI key is already embedded in `RapidAPIClient.swift`.

### Adding New Source Files to Xcode

The Swift files created by this generator live on disk but need to be added to the Xcode project target:

1. In Xcode's Project Navigator, right-click a folder group
2. Choose **Add Files to "AsyncActorKit"…**
3. Select the new `.swift` files

---

## Running Tests

```bash
# All tests
xcodebuild test -scheme AsyncActorKit -destination 'platform=iOS Simulator,name=iPhone 16'

# Integration tests (require network)
INTEGRATION_TESTS=1 xcodebuild test -scheme AsyncActorKit \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or in Xcode: **Product → Test** (`⌘U`)

---

## UI Overview

### Dashboard Tab

```
┌─────────────────────────────────────┐
│  📍 New York, US                    │
│                                     │
│          18°                        │  ← Hero card — live temp
│       overcast clouds               │
│  💧 72%  💨 14 km/h  🌧 20%        │
├─────────────────────────────────────┤
│  5-DAY FORECAST                     │
│  [Wed][Thu][Fri][Sat][Sun]          │  ← Horizontal strip (tap to select)
├─────────────────────────────────────┤
│  HOURLY                             │
│  [12a][3a][6a][9a][12p]…            │  ← Scrollable hourly slots
├─────────────────────────────────────┤
│  DETAILS                            │
│  💧 Humidity  💨 Wind               │  ← 2-col metrics grid
│  🌧 Rain %    🌡 Range              │
├─────────────────────────────────────┤
│  ACTOR DIAGNOSTICS                  │
│  Last fetch: 20:01 | Active: 0      │  ← Live actor state
└─────────────────────────────────────┘
```

### Demos Tab

- **TaskGroup Icon Fetch** — taps a button to concurrently fetch 12 weather icons, shows elapsed time
- **Swift Concurrency Concepts** — inline glossary of every pattern used

---

## Key Design Decisions

**Why actors instead of `DispatchQueue`?**  
Actors provide compile-time isolation guarantees; the Swift compiler rejects unsafe cross-actor access at build time. `DispatchQueue` provides only runtime protection.

**Why `@Observable` instead of `ObservableObject`?**  
`@Observable` (iOS 17+) tracks only the specific properties accessed during a view's render pass, eliminating spurious redraws. It also removes the need for `@Published` boilerplate.

**Cache-first strategy**  
The repository tries memory → disk → network. This means the UI is never blocked by a cold-start network call when cached data is available, and the disk layer survives app restarts.

**Task cancellation**  
`WeatherViewModel` stores the load `Task` and cancels it before starting a new fetch. This prevents stale responses from racing against newer requests — a common SwiftUI bug.

---

## Requirements

| | Minimum |
|---|---|
| iOS | 17.0 |
| Xcode | 16.0 |
| Swift | 5.10 |
| macOS (build host) | 14 Sonoma |
