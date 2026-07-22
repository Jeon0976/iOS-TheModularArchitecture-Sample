[한국어](README.md) | **English**

# TheModularArchitecture-Sample
> An iOS sample application built on TMA (The Modular Architecture) with Tuist local plugins.
> Successor to [iOS-CleanArchitecture-Sample](https://github.com/Jeon0976/iOS-CleanArchitecture-Sample) - the same app restructured from layer-oriented (horizontal slicing) to feature-oriented (vertical slicing) modules.

### Features
- Sign in with GitHub (OAuth)
- GitHub user search with results list (pagination + avatar image cache)
- Profile view (cache-first + refresh) and logout

### Environment
- Tuist 4.133.1 - DSL built from 4 local plugins, version pinned via mise
- Swift 6.0 (Strict Concurrency `complete`), iOS 16.0

---

## Why Build It Again

The starting point of this project is the pair of drawbacks written down in the previous (Clean Architecture) README:

> - **Module bloat**: as the service grows, each layer module grows excessively large.
> - **Limited test granularity**: as features expand, it becomes hard to run isolated tests per screen or per feature.

With layer slicing, changing a single "search" behavior means touching three modules - Presentation, Domain, and Data - at once. This repo solves that by changing the slicing direction.

| | Clean Architecture (previous) | Micro Feature Architecture (this repo) |
|:-----|:-------------------------|:------------------------------------|
| Slicing direction | Horizontal - Presentation / Domain / Data layer modules | Vertical - FeatureSearch / FeatureAuth / FeatureProfile feature modules |
| Where "search" code lives | Scattered across 3 layer modules | Entirely inside `FeatureSearch` |
| Cross-feature communication | Direct references to Domain types | Interface targets (protocols) only |
| Dependency assembly | DIContainer register/resolve (runtime) | Constructor injection in App (compile time) |
| Adding a new feature | Modify 3 layer modules | Add 1 module, existing modules untouched |
| Per-feature test & run | Hard - layers are entangled | Per-feature Tests + standalone Demo app |

The important point: Micro Feature does not throw Clean away - it **wraps** it. Inside each feature module the code is still split into Composition / Domain / Data / Presentation. Only *between* features do modules talk through Interfaces.

---

## Module Structure

<img src="graph.png">

8 modules, 31 targets.

```bash
Projects/
|-- Shared/SharedKit          # Bottom layer commons - AppError hierarchy, utilities
|-- Core/
|   |-- CoreNetwork           # URLSession networking + interceptor/monitor pipeline
|   |-- CoreStorage           # TokenStorage contract + Keychain implementation
|   `-- CoreDesignSystem      # Base (MVVM/Coordinator/ManagedTask) + shared UI components
|-- Feature/
|   |-- FeatureSearch         # User search - pagination + image cache
|   |-- FeatureAuth           # GitHub OAuth - the owner of the token
|   `-- FeatureProfile        # My profile - the only cross-feature dependency (Auth Interface)
`-- App/GitSearchApp          # Composition Root - the only place implementations meet
```

### 5 Targets per Feature

Every feature is made of the same five targets.

| Target | Product | Role |
|------|------|------|
| `{Feature}Interface` | Framework | Public contract - protocols and transfer models only |
| `{Feature}` | Framework | Implementation - Composition / Domain / Data / Presentation inside |
| `{Feature}Testing` | Framework | Stubs & Mocks - reused by Tests and Demo |
| `{Feature}Tests` | Unit tests | Unit tests |
| `{Feature}Demo` | App | Standalone demo - DEV (offline mock) / PROD (real API) |

### Three Dependency Rules

1. Features depend on each other **through Interfaces only**
   - implementation targets never see each other.
2. Only **App** may import implementations (`{Feature}ServingImpl`).
3. Lower layers (Core/Shared) know nothing about upper layers (Feature).

These rules are enforced by build settings, not by documentation. For example, FeatureProfile depends only on FeatureAuth's **Interface**, so code referencing an implementation type simply does not compile.

```swift
// Projects/Feature/FeatureProfile/Project.swift - implementation target dependencies
.implements(
    module: .feature(.FeatureProfile),
    dependencies: [
        .feature(target: .FeatureProfile, type: .interface),
        .shared(target: .SharedKit),
        .core(target: .CoreNetwork),
        .core(target: .CoreDesignSystem),
        .feature(target: .FeatureAuth, type: .interface)   // the only cross-feature dependency
    ]
),
```

### Implementation Notes

Detailed notes written while building each module live in [docs/](docs/README.en.md) - [interceptor pipeline](docs/notes/인터셉터-파이프라인.md), [idempotency & retry](docs/notes/멱등-재시도.md), [ManagedTask](docs/notes/managedtask.md), [owner pattern](docs/notes/owner-패턴.md), [Keychain](docs/notes/keychain.md), [image pipeline](docs/notes/이미지-파이프라인.md), [weak let](docs/notes/weak-let-생성자-주입.md), and a [Swift 6 deep dive](docs/notes/swift6-sendable.md) (8 notes, bodies in Korean). Each note links back to the actual source files in this repo.

---

## Tuist Tooling

The price of vertical slicing is target count (3 features x 5 targets). That boilerplate is folded away by 4 local plugins and a DSL.

| Plugin | Role |
|----------|------|
| EnvironmentPlugin | Global environment - deployment target, Swift settings, bundle ID rules |
| DependencyPlugin | `ModulePaths` module registry + `.feature(target:type:)` dependency helpers |
| ConfigurationPlugin | DEV/PROD build configurations + secrets include path |
| TemplatesPlugin | `tuist scaffold` templates - Feature (5 targets) & Module (generic) |

- **`Project.module` factory**: each module's `Project.swift` consists only of `.interface / .implements / .testing / .tests / .demo` target factory calls. One file reads out all five targets and the dependency graph.
- **Automatic schemes**: 8 module schemes + 12 run schemes (5 demos and the main app, each with `-DEV` / `-PROD`) are generated by the DSL.
- **Adding a new feature**: `tuist scaffold Feature --name Starred` -> add one case to `ModulePaths.Feature` -> `tuist generate`. The workspace iterates `ModulePaths.allCases`, so no other edits are needed and existing feature modules stay untouched.

### Running a Feature on Its Own (Demo)

| Run scheme | DEV | PROD |
|-----------|-----|------|
| `FeatureSearchDemo` | Offline mock session | Real search API (unauthenticated) |
| `FeatureAuthDemo` | Offline mock session | Real OAuth (keys required) |
| `FeatureProfileDemo` | Offline mock session | Real profile (token required) |
| `CoreDesignSystemDemo` | Shared component demo | Same as DEV |
| `CoreStorageDemo` | Storage behavior check + hosted-test host | Same as DEV |
| `GitSearchApp` | Main app (Debug) | Main app (Release) |

A DEV demo is the real screen logic with only the network session swapped for a mock from the Testing target. Pagination and screen transitions run on real code - no server, no token.

---

## Architecture Notes

### Composition Root - Constructor Injection

The entire app is assembled in one place, `AppContainer`. Instead of registering/resolving through a container, dependencies are injected through initializers.

```swift
// Projects/App/GitSearchApp/Sources/AppContainer.swift (abridged)
let tokenStorage = KeychainTokenStorage()
let session = NetworkSession(
    interceptors: [
        AuthTokenInterceptor(tokenStorage: tokenStorage),  // attaches the token automatically
        TransientErrorRetryInterceptor()                   // retries transient errors (idempotent requests only)
    ],
    monitors: [NetworkLogger()]
)

let auth = FeatureAuthServingImpl(session: session, tokenStorage: tokenStorage, credentials: credentials)
self.search  = FeatureSearchServingImpl(session: session)
self.profile = FeatureProfileServingImpl(session: session, auth: auth)   // shares the Auth instance
```

A missing dependency is a **compile error**, not a runtime crash.

### Feature Boundary - Logout Split Three Ways

Logout is one action with three jobs, and each job has a different owner.

| Job | Owner | How |
|-------|------|------|
| Delete the token | FeatureAuth | Delegated via the `onLogout` closure |
| Clear the user cache | FeatureProfile | Its own UseCase (`ClearCachedUserUseCase`) |
| Switch screens | App | `actions.profileDidLogout()` |

In the previous version, the first two were lumped into a single `UserUseCase.logout()`. Slicing by feature makes "whose job is this?" line up with module boundaries.

### OAuth Deep Link Flow

`SceneDelegate` receives the `findusername://` callback and forwards it through `AppFlowCoordinator -> auth.handleOAuthCallback(url)`. Parsing the code (URLComponents), exchanging and storing the token are all internal to FeatureAuth - App only relays the URL.

### Pros

- **Feature-level isolation**: test per feature (Tests) and run a feature alone (Demo) - the previous version's "limited test granularity" is resolved.
- **Predictable change scope**: search code lives only in FeatureSearch. Fixing one feature touches one module.
- **Build parallelism**: features don't know each other, so they build in parallel.
- **Visible coupling**: a cross-feature dependency shows up as a single `.interface` line in `Project.swift`.

### Cons

- **More targets**: 8 modules, 31 targets - scaffolding cuts the creation cost, but the structure itself has a learning curve.
- **Interface contract management**: when a contract changes, dependent features and Testing stubs must be updated together.
- **Overkill for small apps**: for a three-screen app this is a lot of machinery. This repo accepts that because its purpose is learning the structure.

---

## Improvements over the Clean Version

Beyond the slicing direction, porting the app was a chance to fix what felt lacking in the previous version.

| Item | Clean (previous) | This repo |
|------|-------------|---------|
| Dependency assembly | DIContainer register/resolve - a missing registration is found at runtime | Composition Root constructor injection - a missing dependency is a compile error |
| Token storage | UserDefaults | Keychain implementation + contract tests & hosted tests |
| Token usage | UseCase pulls the token and passes it as a parameter | An interceptor attaches it to requests - call sites don't know the token exists |
| UseCase granularity | One `GithubTokenUseCase` with 4 verbs | Split per verb - Auth 4 / Profile 3 / Search 2 |
| Logout | UseCase deletes token + user cache together | Split three ways - token to Auth, cache to Profile, navigation to App |
| Concurrency | Swift 5, unstructured `Task { }` | Swift 6 strict `complete`, `ManagedTask` (re-entry & deinit cancellation rules), Sendable boundaries |
| Errors | Separate Error types per layer | `AppError` hierarchy wrapping + user-facing messages separated |

---

## Feature Details

### GitHub Auth (FeatureAuth)
- The Interface contract has 4 members: `isLoggedIn` / `makeLoginViewController` / `handleOAuthCallback` / `logout`.
- Auth URL generation > external browser > deep-link callback > code exchange > Keychain storage - all of it ends inside the feature.
- If OAuth keys (Client ID/Secret) are missing, the app shows **setup instructions** instead of an error - clone and run without being blocked.

### User Search (FeatureSearch)
- `SearchUsersUseCase` handles paginated search; `FetchProfileUseCase` handles avatar images.
- Images are served through a cache, and Repository tests verify that a cache hit makes no network call.

### Profile (FeatureProfile)
- Two read paths: `FetchUserUseCase` (cache-first) and `RefreshUserUseCase` (cache-bypassing) - prevents values from freezing for the whole session on re-entry or pull-to-refresh.
- The living example of the only cross-feature dependency (Auth Interface), and the protagonist of the three-way logout split.

### Tests (24)
- **Contract tests**: the in-memory Mock and the real Keychain implementation pass the same `TokenStorage` test suite. Keychain needs a host app, so those run in a separate `CoreStorageHostedTests` target.
- **Recording stub**: `StubNetworkRequesting` supports result injection and request recording (`requestedEndpoints`), so tests verify which endpoint the Repository called and how many times.
- 5 behavior tests for `ManagedTask` (re-entry cancellation / single flight) live in Core.

---

## Getting Started

```bash
mise install                                    # installs Tuist 4.133.1
cp Secrets.xcconfig.template Secrets.xcconfig   # (optional) OAuth keys - builds & runs without them
tuist install
tuist generate                                  # generates the workspace + opens Xcode
tuist test                                      # 24 tests
```

- To try the OAuth login, create a GitHub OAuth App and fill `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` in `Secrets.xcconfig` (callback: `findusername://callback`). The real key file is gitignored; only the template is committed.
- Secrets flow into the app via xcconfig > build settings > Info.plist `$(VAR)` > `Bundle`. Features receive values without knowing where they came from.

## Tech Stack

- Async: Swift Concurrency (Domain/Data) + Combine (Presentation MVVM Input/Output)
- Patterns: MVVM, Coordinator (actions delegation), Composition Root constructor injection
- Networking: hand-rolled URLSession + interceptor (token attach / retry) / monitor (logging) pipeline
- Storage: Keychain (behind the TokenStorage contract)
- Modularization: Tuist 4.133.1 local plugins + scaffold templates
