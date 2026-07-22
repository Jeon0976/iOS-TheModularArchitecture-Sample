
# Sendable

> [!NOTE]
> 2026-07-10에 처음 쓰고 이관하며 Swift 6 심화 절(7절)을 보강한 학습 노트다 (노트 톤 그대로 옮김).
> 관련 소스: [GithubUser.swift](../../Projects/Feature/FeatureSearch/Sources/Domain/Entities/GithubUser.swift) / [NetworkSession.swift](../../Projects/Core/CoreNetwork/Sources/NetworkSession.swift) / [ImageDownsampler.swift](../../Projects/Feature/FeatureSearch/Sources/Presentation/ImageLoading/ImageDownsampler.swift)

> [!IMPORTANT]
> **다루는 질문** - 이 레포를 열면 거의 모든 타입이 `Sendable`을 채택하거나 요구한다.
>
> - Sendable이 뭐고, 왜 "대부분" 채택하게 됐나?
> - 판정 규칙의 일반론은 범위 밖이다 - 그 규칙이 **실제 코드베이스에서 어떤 모습으로 나타나는지**를 파일 단위로 훑는다.
> - **한 줄 결론**: Sendable은 "이 타입의 값은 **동시성 경계(격리 도메인 사이)를 건너도 데이터 레이스가 없다**"는 컴파일 타임 증명이다.
> - 이 앱은 **@MainActor(UI) <-> nonisolated(네트워크)를 값이 끊임없이 왕복하는 구조**라서 경계를 건너는 타입 전부에 증명이 필요했다 - "많이 채택했다"가 아니라 **"경계가 많은 설계라서 증명이 많이 필요했다"**가 정확한 인과다.
> - 채택 자체는 목표가 아니다 - 경계를 안 건너는 타입(ViewController들)은 채택하지 않는다.

---

## 1. TL;DR

| 질문 | 답 |
|---|---|
| Sendable이 뭔가 | [공식 정의](https://developer.apple.com/documentation/swift/sendable): *"A thread-safe type whose values can be shared across arbitrary concurrent contexts without introducing a risk of data races"* - 임의의 동시 컨텍스트로 값을 공유해도 데이터 레이스 위험이 없는 타입. 요구 메서드는 없고, **타입이 조건을 만족하는지를 컴파일러가 검사**한다 |
| 언제 검사받나 | 값이 **격리 경계를 넘는 순간**만 - actor 메서드 인자/반환, @MainActor <-> nonisolated 사이, `Task {}`/`@Sendable` 클로저 캡처 |
| 왜 이 앱은 거의 다 채택? | 1) Swift 6 strict concurrency(경계 검사 상시 가동) 2) UI는 @MainActor, 네트워크는 nonisolated - **모든 요청/응답 값이 경계를 왕복** 3) 계약(protocol)이 Sendable을 상속하면 구현체 전원이 증명 대상 |
| 채택 안 한 것도 있나 | 있다 - ViewController들(경계를 안 넘음, @MainActor 안에서만 삶), ManagedTask(@MainActor 클래스 - 암시적 sendable이라 명시 불필요) |
| @unchecked는 뭔가 | "검사를 끄고 **개발자가 책임**진다"는 선언. 공식 문서: *"You are responsible for the correctness of unchecked sendable types, for example, by protecting all access to its state with a lock or a queue"* - 이 앱은 반드시 근거 주석과 함께만 사용 |

---

## 2. 개념 최소한만 - 증명이 요구되는 순간

Swift 6의 데이터 레이스 방지 전략은 두 부품이다:

1. **격리(isolation)**: 가변 상태를 특정 도메인(actor, @MainActor)에 가둔다 - "상태는 자기 집에서만 만진다"
2. **Sendable**: 도메인 **사이를 이동하는 값**은 "공유해도 안전한 형태"임을 증명한다 - "집 밖으로 나가는 것은 안전한 것만"

검사는 타입 선언이 아니라 **경계 통과 시점**에 일어난다. 이 앱에서 가장 잦은 경계가 바로 이것:

```swift
// SearchUserViewModel (@MainActor) 안에서
let page = try await searchUsersUseCase.execute(query:page:perPage:)
//         ^^^^^ nonisolated 격리 영역으로 나갔다가(요청), 결과를 들고 돌아온다(응답)
//         -> GithubUsersPage가 Sendable이 아니면 이 줄이 컴파일 에러
```

엔티티가 처한 상황이 정확히 이것이다 - 네트워크 Task(백그라운드)에서 만들어져 @MainActor 격리 영역으로 건너온다. Swift 6에서 이 이동은 Sendable 증명 없이는 컴파일되지 않는다.

> [!TIP] "왜 대부분 채택해야 하는지"의 답
> 이 아키텍처에서 **UseCase/Repository/NetworkSession/엔티티/DTO/에러**는 전부 "요청-응답 왕복 경로" 위에 있다. 경로 위의 모든 타입이 경계를 넘으므로 전부 증명 대상이다. 반대로 경로 밖(화면 안)에만 사는 타입은 증명이 필요 없다 - 5절. **어떤 타입이 Sendable을 채택하게 되는지는 코드 스타일이 아니라 아키텍처가 경계를 어디에 뒀는가가 결정한다.**

---

## 3. 실물 투어 1) - 공짜 증명 (컴파일러가 요건을 확인해 주는 것들)

공식 문서의 분류 순서 그대로, 이 코드베이스의 실물을 배치한다.

### 3-1. 값 타입 - struct/enum은 멤버가 전부 Sendable이면 성립

```swift
// FeatureSearch/Domain/Entities/GithubUser.swift
struct GithubUser: Equatable, Hashable, Sendable {
    let id: Int; let name: String; let profilePath: String; let url: URL
}
```

- 공식 요건: *"an enumeration or structure must have only sendable members and associated values"* - Int/String/URL 모두 Sendable이므로 성립. **불변(let)+값 타입이면 증명이 공짜**라는 게 "왜 struct-first인가"의 동시성 측 근거다.
- 명시적으로 `Sendable`을 적는 이유: 암시적 conformance는 **non-public 타입**에만 온다(공식: *"Structures and enumerations that aren't public and aren't marked @usableFromInline"*). 이 워크스페이스는 모듈이 잘게 쪼개져 있어(TMA) public 타입이 많고 public은 **적어야 계약이 된다**. internal이라도 적어두면 "이 타입은 경계를 넘는 용도"라는 의도 문서가 된다.

### 3-2. enum + 연관값 - 타입을 좁혀서 증명을 공짜로 만든 사례

```swift
// CoreNetwork/NetworkTask.swift
public enum NetworkTask: Sendable {
    case requestJSONEncodable(any Encodable & Sendable)   // <- 경계 명시
    case requestParameters(parameters: [String: String], encoding: any ParameterEncoding)
}
```

원본(Clean)은 `[String: Any]`였다 - `Any`는 Sendable 증명이 불가능해서 endpoint가 @MainActor(ViewModel)에서 nonisolated(NetworkSession)로 넘어가는 순간 거부된다. GitHub API 파라미터는 전부 문자열화 가능하므로 `[String: String]`으로 **좁혔다**. 파일 주석의 교훈 그대로: **"타입을 좁히면 동시성 증명이 공짜"**. `any Encodable`도 `any Encodable & Sendable`로 경계를 명시했다.

### 3-3. final class + 전부 let - 참조 타입의 성립 조건 3종 세트

```swift
// CoreNetwork/NetworkSession.swift
public final class NetworkSession: NetworkRequesting, Sendable {
    private let session: URLSession
    private let interceptors: [any RequestInterceptor]   // 전부 let
    ...
}
```

공식 요건 그대로: *"a class must: Be marked **final** / Contain only stored properties that are **immutable and sendable** / Have **no superclass** or have NSObject as the superclass."* - NetworkSession/KeychainTokenStorage가 이 3요건의 교과서 케이스다. KeychainTokenStorage의 주석이 좋은 사고 훈련: "실제 상태는 Keychain(시스템)이 들고 있고, 이 객체는 불변 설정값(service/account)뿐" - **상태의 위치**를 물으면 class여도 증명이 성립한다.

### 3-4. 상태 없는 타입은 struct로 - NetworkLogger

Clean의 `final class NetworkLogger`(상태 없음)를 struct로 바꿨다 - 저장 프로퍼티가 없으니 Sendable이 자동 성립. 주석의 규칙: **"class를 Sendable로 만들려고 고민하기 전에, class일 이유가 있는지부터."**

### 3-5. @Sendable 클로저 - "공유하지 않기"로 우회 (팩토리 클로저 주입)

```swift
// NetworkSession.init
makeDecoder: @Sendable @escaping () -> JSONDecoder = { JSONDecoder() }
```

인스턴스 하나를 세션이 들고 여러 Task에서 공유하는 대신, **"만드는 법"(@Sendable 클로저)을 공유하고 값은 요청마다 새로 만든다** - 공유가 없으면 레이스도 없다. 공식 요건: *"Any values that the function or closure captures must be sendable... sendable closures must use only by-value captures."* non-Sendable 타입을 만났을 때의 3지선다(1) 격리에 가둔다 2) 매번 만든다 3) @unchecked) 중 2)의 실물.

> [!WARNING] 2026-07 검증 업데이트 - JSONDecoder는 이제 Sendable이다
> Swift 6.3.2 SDK에서 직접 컴파일 검증: swift-foundation 재작성으로 JSONDecoder가 가변 설정을 **내부 락으로 보호**해 checked Sendable이 됐다 - `let decoder: JSONDecoder` 직접 저장도 통과한다 ("가변 상태는 락으로 보호해 checked로 만든다"는 방향이 Foundation 자신에 적용된 사례). 그래도 이 패턴이 남는 이유: a) 공유 인스턴스의 설정을 요청 도중 바꾸면 락 덕에 크래시는 없지만 **결과가 타이밍에 좌우되는 논리 레이스**는 남는다(data race 안전 != race condition 안전) - 매번 생성은 이 가능성 자체를 제거 b) 구세대 SDK 호환. 즉 이 패턴은 "필수"에서 "선택"이 됐고, 여기서 남는 교훈은 하나다: **Sendable 판정은 SDK 버전에 따라 바뀐다 - 단정하기 전에 컴파일러에게 물어라.**

@Sendable 요구는 **클로저(캡처)에만** 걸린다는 것도 포인트 - 반환값(JSONDecoder)은 non-Sendable이어도 됐다. 호출한 쪽 격리 영역에서 갓 태어난 값은 어디와도 참조를 공유하지 않아(분리된 region, SE-0414) 그 자리에서 쓰는 데 증명이 필요 없기 때문.

---

## 4. 실물 투어 2) - 계약과 책임

### 4-1. protocol이 Sendable을 상속 - 구현체 전원 소집

```swift
public protocol NetworkRequesting: Sendable { ... }     // CoreNetwork
public protocol NetworkEndpoint: Sendable { ... }
public protocol TokenStorage: Sendable { ... }          // CoreStorage
public protocol RequestInterceptor: Sendable { ... }    // Pipeline
public protocol NetworkEventMonitor: Sendable { ... }
```

계약이 Sendable을 상속하면 **모든 구현체가 증명 대상**이 된다. 왜 계약 레벨에서 못박나 - 이 계약들의 값은 **필연적으로** 경계를 넘기 때문이다: `any NetworkRequesting`은 @MainActor의 조립부(AppContainer)에서 만들어져 Repository들(nonisolated)로 주입되고, endpoint는 ViewModel에서 만들어져 세션으로 넘어간다. "이 계약을 구현하려면 스레드 안전해야 한다"가 **타입 시그니처로 문서화**된 것. 구현하는 쪽(StubNetworkRequesting 같은 테스트 대역까지)이 강제로 같은 규칙을 지키게 되는 것이 부수 효과이자 의도다.

### 4-2. @unchecked Sendable - 검사를 끄되 근거를 남긴다

공식 문서의 책임 조항: *"To declare conformance to Sendable **without any compiler enforcement**, write @unchecked Sendable. **You are responsible for the correctness**... for example, by protecting all access to its state with a lock or a queue."*

이 레포의 @unchecked는 프로덕션 3곳 + 테스트 대역 5곳 - 전부 "가변 상태 + 수동 동기화 + 근거 주석" 패턴이다. 프로덕션 3곳:

| 타입 | 가변 상태 | 동기화 수단 | 성립 근거 |
|---|---|---|---|
| `UserVolatileStorage` (Profile/Data) | user 캐시 | `NSLock` | 모든 접근이 lock으로 직렬화 |
| `InMemoryProfileCache` (Search/Data) | NSCache | NSCache 자체 | 문서가 스레드 안전을 보장하지만 컴파일러는 그걸 모르는 참조 타입 멤버로 본다 - 개발자가 근거를 적고 책임진다 |
| `DiskProfileCache` (Search/Data) | 파일 시스템 | `NSLock`(withLock) | 개별 FileManager 호출은 안전하지만 다단계 쓰기의 불변식은 락이 지킨다 |

테스트 대역 5곳(`StubNetworkRequesting`/`MockTokenStorage`/`RoutingStubSession`/목 세션 2종)도 같은 NSLock 패턴이다 - 대역이라도 프로덕션과 같은 경계를 통과해야 하므로 같은 규칙을 지킨다.

프로젝트 규약이 한 줄로 요약된다: **"근거 없는 @unchecked 금지 - 근거를 적는 것까지가 규약."**

> [!WARNING] @unchecked의 진짜 비용
> 컴파일러 검사가 꺼지는 것은 그 타입 **내부 전체**다. 나중에 누가 lock 없는 프로퍼티를 추가해도 에러가 안 난다. 그래서 @unchecked 타입은 **작게 유지**하는 것이 두 번째 규칙 - 이 레포의 해당 타입들은 전부 한 화면 안에 들어오는 크기다.

---

## 5. 실물 투어 3) - 채택하지 **않은** 것들 (여기가 이해의 완성)

"거의 다 채택"의 반례들이 Sendable의 의미를 오히려 선명하게 한다.

### 5-1. ViewController들 - 경계를 넘지 않는 값

`SearchUserViewController` 등 화면들은 Sendable이 아니다(그리고 될 수도 없다 - UIViewController 상속, 가변 프로퍼티 투성이). **문제가 안 되는 이유**: 이 객체들은 @MainActor 안에서 태어나 살다 죽는다. 값이 경계를 넘지 않으면 증명이 필요 없다 - Sendable은 "모든 타입의 덕목"이 아니라 **여행자의 여권**이다.

### 5-2. @MainActor 클래스 - 암시적으로 이미 sendable

```swift
@MainActor final class SearchUserViewModel { ... }   // Sendable 명시 없음
@MainActor public final class ManagedTask { ... }
```

공식 문서: *"Classes marked with @MainActor are **implicitly sendable**, because the main actor coordinates all access to its state. These classes **can have stored properties that are mutable and nonsendable**."* - 가변 상태가 있어도 성립하는 이유는 "공유해도 안전"의 두 번째 달성 방법(2절의 격리)을 썼기 때문: 상태 접근이 전부 메인 액터로 직렬화되므로 참조 자체는 어디로 건너가도 안전하다. actor가 전부 암시적 Sendable인 것과 같은 원리(공식: *"All actor types implicitly conform to Sendable"*).

즉 이 코드베이스의 진짜 그림은 "전부 Sendable"이 아니라 **이층 구조**다:

```
@MainActor 층 (UI/ViewModel/ManagedTask)  <- 격리로 안전 (암시적 sendable, 가변 OK)
---------- 경계 (모든 요청/응답이 통과) ----------
nonisolated 층 (UseCase/Repo/Network/엔티티) <- Sendable 증명으로 안전 (불변 값 위주)
```

### 5-3. nonisolated(unsafe) - Sendable의 사촌 격 탈출구

`nonisolated(unsafe)`는 Sendable과 짝을 이루는 "격리 검사 끄기"다 (@unchecked가 "타입 검사 끄기"인 것처럼). 같은 규약 적용 - 근거 없이는 금지. 이 레포의 nonisolated(unsafe)는 **0곳**이다 - 후보였던 ManagedTask.task조차 실측(Swift 6.3.2)으로 불필요함이 확인됐다: deinit의 저장 프로퍼티 직접 접근은 허용된다(금지는 격리 *호출*뿐 - 7-2절). 상세는 [managedtask](managedtask.md) 5-1절.

---

## 6. 판정 흐름 요약 - 새 타입을 만들 때

```
이 타입의 값이 격리 경계를 넘는가?
|- 아니오 -> Sendable 불필요 (ViewController 케이스)
`- 예 ->
   |- @MainActor/actor로 격리 가능한가? -> 격리하면 암시적 sendable (ViewModel 케이스)
   |- 값 타입 + 전 멤버 Sendable? -> : Sendable 한 줄 (엔티티/DTO 케이스)
   |    `- 멤버 중 non-Sendable이 있다 -> 타입을 좁힐 수 있나? ([String: Any]->[String: String] 케이스)
   |- class인가? -> final + 전부 let + Sendable 멤버로 만들 수 있나? (NetworkSession 케이스)
   |    `- 애초에 class일 이유가 있나? (NetworkLogger -> struct 케이스)
   |- 공유하지 않고 매번 만들면 되나? -> @Sendable 팩토리 (JSONDecoder 케이스)
   `- 가변 상태 + 수동 동기화가 불가피한가? -> @unchecked + 락 + 근거 주석 + 작게 (캐시/스텁 케이스)
```

---

## 7. Swift 6 심화 - 경계를 다루는 장치들

Sendable은 Swift 6 동시성 장치의 하나일 뿐이다. 이 레포가 함께 쓰는 나머지 장치들을 실물과 같이 정리한다.

### 7-1. strict concurrency 모드 - 검사를 언제 켜나

검사 강도는 3단계다: `minimal`(명시 채택만 검사) -> `targeted`(동시성 코드 중심) -> `complete`(전 코드 전수 검사). 이 레포는 전 타겟에 `SWIFT_STRICT_CONCURRENCY = complete`를 걸었다(EnvironmentPlugin의 `baseSwiftSettings` - 모듈별 예외 없음). 나중에 켜면 마이그레이션 과제가 되지만 처음부터 켜면 격리 오류가 설계 검토 역할을 한다 - "이 상태의 주인이 누구인가"를 코드를 쓰는 시점에 묻게 된다. Swift 6 언어 모드에서는 complete가 기본이다.

- [Migrating to Swift 6 - swift.org](https://www.swift.org/migration/documentation/migrationguide/) - 모드별 의미와 이행 전략

### 7-2. nonisolated async - off-main의 언어 규칙 (SE-0338)

nonisolated async 함수의 본문은 **호출자의 액터가 아니라 협조적 스레드 풀에서 돈다**. @MainActor인 코드가 `await`로 불러도 함수 본문은 메인 밖이다 - 별도 GCD 호출 없이 CPU 작업이 자동으로 off-main이 된다.

- 실물: [`ImageDownsampler.makeImage`](../../Projects/Feature/FeatureSearch/Sources/Presentation/ImageLoading/ImageDownsampler.swift) - 이미지 디코딩이 협조적 풀에서 돌아 스크롤을 막지 않는다 (상세는 [이미지-파이프라인](이미지-파이프라인.md) 5절)
- 버전 단서: **SE-0461**(Swift 6.2)이 이 기본을 "호출자의 액터에서 실행"으로 뒤집는다 - 이후 off-main이 필요한 함수는 `@concurrent`를 명시하는 방향이다. 언어 모드 이행 시 재확인 지점.
- deinit 예외 하나: deinit은 격리 밖에서 돌지만 **저장 프로퍼티 직접 접근은 허용**된다 - deinit 시점엔 참조가 유일해서 배타 접근이 SE-0327의 규칙으로 증명되기 때문. `ManagedTask`의 `deinit { task?.cancel() }`이 합법인 이유다.

- [SE-0338 - Clarify the Execution of Non-Actor-Isolated Async Functions](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md)
- [SE-0461 - Run nonisolated async functions on the caller's actor by default](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)
- [SE-0327 - On Actors and Initialization](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0327-actor-initializers.md)

### 7-3. sending - Sendable 없이 경계 넘기 (SE-0430 / SE-0414)

Sendable이 유일한 통행증은 아니다. **region isolation**(SE-0414)은 컴파일러가 값의 참조 그물(region)을 추적해서 다른 곳과 얽히지 않은 값이라면 non-Sendable이어도 격리 경계를 넘게 해 준다. `sending`(SE-0430)은 그 이양을 함수 시그니처에 표기하는 키워드다 - "이 값을 보내고 나면 보낸 쪽은 다시 만지지 않는다".

```swift
// ImageDownsampler - non-Sendable UIImage를 경계 너머로
static func makeImage(...) async -> sending UIImage?
```

UIImage는 가변 참조 타입이라 Sendable로 만들 수 없다. 그런데 협조적 풀에서 갓 만들어진 UIImage는 어디와도 참조를 공유하지 않으므로, **공유(Sendable)가 아니라 이양(sending)** 으로 @MainActor에 넘긴다. 두 장치는 해법의 축이 다르다 - Sendable은 "공유해도 안전", sending은 "소유를 넘기니 안전".

- [SE-0430 - `sending` parameter and result values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md)
- [SE-0414 - Region based Isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md)

### 7-4. 장치 지도 - 언제 무엇을 쓰나

| 상황 | 장치 | 이 레포의 실물 |
|---|---|---|
| 값이 경계를 자주 왕복한다 | Sendable (불변 값 타입) | 엔티티/DTO/에러 |
| 가변 상태를 한 곳에 가둔다 | @MainActor / actor | ViewModel/ManagedTask |
| CPU 작업을 메인 밖으로 | nonisolated async (SE-0338) | ImageDownsampler |
| non-Sendable 결과물을 반환한다 | sending (SE-0430) | makeImage -> UIImage |
| 수동 동기화가 불가피하다 | @unchecked + 락 + 근거 주석 | 캐시/스텁 (4-2절) |

---

## 8. 정리

- Sendable은 값이 동시성 경계를 넘어도 데이터 레이스가 없다는 컴파일 타임 증명이다. 이 구조는 UI가 @MainActor, 네트워크가 nonisolated라서 모든 요청/응답 값이 경계를 왕복하고, 그 경로 위의 타입(엔티티, DTO, UseCase, Repository, 세션) 전부가 증명 대상이 된다.
- 값 타입은 불변으로 설계해 증명을 공짜로 얻고, protocol에 Sendable을 상속시켜 구현체가 같은 규칙을 강제받게 했다. 반대로 경계를 안 넘는 ViewController는 채택하지 않았고, ViewModel은 @MainActor 격리라 암시적으로 Sendable이 되어 명시가 필요 없다. Sendable이 많아진 건 스타일 문제가 아니라 경계를 어디에 뒀는가의 결과다.
- 가변 상태가 불가피한 캐시류만 @unchecked + 락 + 근거 주석으로 예외를 열되, 타입을 작게 유지해 검사 공백을 최소화했다.

보충 정리:
- **메서드도 없는 프로토콜을 컴파일러가 어떻게 검사하나** - 요구 멤버가 없는 marker protocol이고, 요건은 시그니처가 아니라 타입 구조에 걸린다. conformance를 선언하는 시점에 컴파일러가 저장 프로퍼티들을 검사한다(공식 문서: "semantic requirements that are enforced at compile time"). 같은 파일에서만 선언할 수 있는 것도 그 검사 때문이다.
- **@MainActor 클래스는 가변인데 왜 통과하나** - 격리가 접근을 직렬화하기 때문이다 (5-2절).
- **Any를 못 넘기는 이유** - 전이성: 컨테이너는 내용물까지 Sendable이어야 한다 (3-2절의 [String: Any] 사례).
- **@unchecked 쓰면 끝 아닌가** - 검사가 꺼지는 범위가 타입 내부 전체다. 그래서 "작게 + 근거 주석" 규칙이 따라와야 한다 (4-2절 WARNING).
---

## 9. 참고 자료

**공식 문서**
- [Sendable - Apple Developer Documentation](https://developer.apple.com/documentation/swift/sendable) - 이 문서의 1차 출처. 정의("thread-safe type... without introducing a risk of data races"), 4대 성립 범주(값 타입 / 불변 참조 타입 / 내부 동기화 참조 타입 / @Sendable 함수/클로저), struct/enum/class별 요건, 암시적 conformance 조건(frozen / non-public), @MainActor 클래스의 암시적 sendable, @unchecked 책임 조항, 같은 파일 선언 규칙
- [Concurrency - The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) - Sendable Types 절: 격리 모델 안에서의 위치
- [SE-0302 Sendable and @Sendable closures - Swift Evolution](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md) - 설계 동기 원문
- WWDC22 [Eliminate data races using Swift Concurrency (110351)](https://developer.apple.com/videos/play/wwdc2022/110351/) - "섬과 바다 사이를 건너는 배" 비유의 출처, 격리+Sendable 2부품 모델

**이 레포의 실물 코드**
- 공짜 증명: [`GithubUser.swift`](../../Projects/Feature/FeatureSearch/Sources/Domain/Entities/GithubUser.swift), [`NetworkTask.swift`](../../Projects/Core/CoreNetwork/Sources/NetworkTask.swift)(타입 좁히기), [`NetworkSession.swift`](../../Projects/Core/CoreNetwork/Sources/NetworkSession.swift)(final+let, @Sendable 팩토리), [`NetworkLogger.swift`](../../Projects/Core/CoreNetwork/Sources/Pipeline/NetworkLogger.swift)(class->struct)
- 계약: [`NetworkRequesting.swift`](../../Projects/Core/CoreNetwork/Sources/NetworkRequesting.swift), [`TokenStorage.swift`](../../Projects/Core/CoreStorage/Sources/TokenStorage.swift), [`RequestInterceptor.swift`](../../Projects/Core/CoreNetwork/Sources/Pipeline/RequestInterceptor.swift)
- 책임: [`UserStorage.swift`](../../Projects/Feature/FeatureProfile/Sources/Data/UserStorage.swift), [`InMemoryProfileCache.swift`](../../Projects/Feature/FeatureSearch/Sources/Data/Cache/InMemoryProfileCache.swift)/[`DiskProfileCache.swift`](../../Projects/Feature/FeatureSearch/Sources/Data/Cache/DiskProfileCache.swift), [`StubNetworkRequesting.swift`](../../Projects/Core/CoreNetwork/Testing/Sources/StubNetworkRequesting.swift)(@unchecked 실물)
- 반례: ViewController들(불필요), ViewModel들(@MainActor 암시)

**관련 노트**
- [managedtask](managedtask.md) - unstructured Task의 취소 규칙, deinit 격리 예외의 실물
- [이미지-파이프라인](이미지-파이프라인.md) - nonisolated async/sending이 실전에서 맞물리는 자리
- [owner-패턴](owner-패턴.md) - 비-Sendable owner가 격리 안에 머물러 컴파일되는 원리
