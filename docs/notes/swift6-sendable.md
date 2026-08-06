
# Sendable - 이 레포의 동시성 경계 지도

> 2026-07-10, Swift 6 관련 노트
> 관련 소스: [GithubUser.swift](../../Projects/Feature/FeatureSearch/Sources/Domain/Entities/GithubUser.swift) / [NetworkSession.swift](../../Projects/Core/CoreNetwork/Sources/NetworkSession.swift) / [ImageDownsampler.swift](../../Projects/Feature/FeatureSearch/Sources/Presentation/ImageLoading/ImageDownsampler.swift)

이 레포를 열면 거의 모든 타입이 `Sendable`을 채택하거나 요구합니다. Sendable이 뭐고 왜 이렇게 많이 붙었는지를 정리합니다. 판정 규칙을 전부 설명하기보다 이 코드베이스에서 실제로 어떻게 썼는지를 파일 단위로 봅니다.

Sendable은 타입의 값을 다른 동시성 컨텍스트로 전달해도 데이터 레이스 위험이 없도록 컴파일러가 검사하는 프로토콜입니다. 이 앱은 @MainActor로 격리된 UI와 nonisolated인 네트워크 사이로 값이 자주 오가는 구조라서, 요청과 응답에 쓰이는 타입 대부분이 Sendable을 만족해야 했습니다.

모든 타입에 붙이는 것이 목표는 아닙니다. ViewController처럼 @MainActor 안에서만 쓰는 타입에는 필요하지 않습니다.

---

## Sendable 검사가 필요한 순간

Swift 6는 데이터 레이스를 막기 위해 크게 두 가지를 씁니다. 격리는 가변 상태에 접근할 수 있는 실행 컨텍스트를 actor나 @MainActor로 제한합니다. Sendable은 서로 다른 동시성 컨텍스트 사이에서 전달되는 값이 안전한지 컴파일러가 검사합니다.

검사는 타입 선언이 아니라 경계 통과 시점에 일어납니다. 이 앱에서 가장 잦은 경계가 이것입니다.

```swift
// SearchUserViewModel (@MainActor) 안에서
let page = try await searchUsersUseCase.execute(query:page:perPage:)
//         ^^^^^ nonisolated 격리 영역으로 나갔다가(요청), 결과를 들고 돌아온다(응답)
//         -> GithubUsersPage가 Sendable이 아니면 이 줄이 컴파일 에러
```

엔티티도 같은 과정을 거칩니다. 네트워크 작업에서 만들어진 값이 @MainActor의 ViewModel로 전달되기 때문에, Swift 6에서는 해당 타입이 Sendable을 만족해야 합니다.

왜 대부분 채택해야 하는지의 답이 여기 있습니다. 이 아키텍처에서 UseCase, Repository, NetworkSession, 엔티티, DTO, 에러는 전부 요청과 응답이 오가는 경로에 있습니다. 반대로 화면 안에서만 쓰는 타입은 그렇지 않습니다. 어떤 타입에 Sendable이 필요한지는 동시성 영역을 어떻게 나눴는지가 정합니다.

---

## 실제 코드에서 적용한 방식

### 값 타입 - 멤버가 모두 Sendable인 struct와 enum

```swift
// FeatureSearch/Domain/Entities/GithubUser.swift
struct GithubUser: Equatable, Hashable, Sendable {
    let id: Int; let name: String; let profilePath: String; let url: URL
}
```

공식 요건은 열거형이나 구조체의 멤버와 연관값이 모두 sendable이어야 한다는 것입니다. Int, String, URL이 모두 Sendable이므로 `GithubUser`도 별도 동기화 없이 채택할 수 있습니다. 불변 값 타입을 우선해서 쓰면 Sendable 요구사항을 만족하기가 수월합니다.

암시적 conformance는 non-public 타입에만 적용됩니다. 공식 문서가 public이 아니고 `@usableFromInline`도 아닌 구조체와 열거형이라고 못 박아 두었습니다. 이 워크스페이스는 모듈이 잘게 나뉘어 있어 public 타입이 많으므로 `Sendable`을 명시해야 합니다. internal 타입에도 적어 두면 이 타입이 동시성 영역 사이에서 전달된다는 의도를 코드에 남길 수 있습니다.

### enum과 연관값 - 범용 타입을 구체적인 타입으로

```swift
// CoreNetwork/NetworkTask.swift
public enum NetworkTask: Sendable {
    case requestJSONEncodable(any Encodable & Sendable)   // <- 경계 명시
    case requestParameters(parameters: [String: String], encoding: any ParameterEncoding)
}
```

기존 구현에서는 파라미터 타입으로 `[String: Any]`를 썼습니다. 하지만 `Any`는 Sendable 여부를 컴파일러가 확인할 수 없어서 endpoint를 @MainActor의 ViewModel에서 nonisolated인 NetworkSession으로 전달할 수 없습니다. GitHub API의 파라미터는 모두 문자열로 표현할 수 있으므로 `[String: String]`으로 바꿨습니다. `any Encodable` 역시 `any Encodable & Sendable`로 제한했습니다. 범용 타입이 꼭 필요하지 않다면 구체적인 타입을 쓰는 편이 동시성 검사에도 유리합니다.

### final class와 let - 참조 타입이 채택하는 조건

```swift
// CoreNetwork/NetworkSession.swift
public final class NetworkSession: NetworkRequesting, Sendable {
    private let session: URLSession
    private let interceptors: [any RequestInterceptor]   // 전부 let
    ...
}
```

공식 문서에 따르면 class는 final이어야 하고, 저장 프로퍼티가 모두 불변이며 Sendable이어야 하고, superclass가 없거나 NSObject여야 합니다. `NetworkSession`과 `KeychainTokenStorage`가 이 조건을 만족합니다. 특히 KeychainTokenStorage가 직접 들고 있는 값은 service와 account 같은 불변 설정뿐이고 실제 데이터는 시스템 Keychain에 저장됩니다. 참조 타입을 검토할 때는 가변 상태를 어디에서 관리하는지부터 확인하면 됩니다.

### 상태 없는 타입은 struct로

기존의 `NetworkLogger`는 상태가 없는 `final class`였습니다. struct로 바꾸면 저장 프로퍼티가 없기 때문에 자연스럽게 Sendable 조건을 만족합니다. 참조 의미가 필요하지 않은 타입이라면 class에 동기화 방식을 덧붙이기 전에 값 타입으로 바꿀 수 있는지 먼저 확인할 만합니다.

### @Sendable 클로저 - 인스턴스 대신 팩토리 주입

```swift
// NetworkSession.init
makeDecoder: @Sendable @escaping () -> JSONDecoder = { JSONDecoder() }
```

세션이 인스턴스 하나를 여러 Task에서 공유하는 대신, 생성 클로저를 주입하고 요청마다 새 인스턴스를 만듭니다. 공유되는 가변 상태가 없으므로 데이터 레이스를 피할 수 있습니다. 공식 문서도 @Sendable 클로저가 캡처하는 값은 Sendable이어야 하며 값 캡처만 써야 한다고 설명합니다. non-Sendable 타입을 다뤄야 한다면 특정 actor에 격리하거나, 매번 새로 만들거나, 동기화를 직접 보장하고 @unchecked를 쓰는 방법이 있습니다. 이 코드는 두 번째를 택했습니다.

**2026-07 검증 업데이트.** Swift 6.3.2 SDK에서 컴파일해 본 결과, swift-foundation으로 다시 작성된 JSONDecoder는 가변 설정을 내부 락으로 보호하며 checked Sendable을 채택합니다. 따라서 `let decoder: JSONDecoder`를 직접 저장해도 컴파일됩니다. 다만 요청 처리 중 공유 인스턴스의 설정을 바꾸면 데이터 레이스는 막더라도 결과가 실행 순서에 따라 달라질 수 있습니다. 요청마다 생성하면 이런 상황을 피할 수 있고 구형 SDK와도 호환됩니다. 이 패턴은 이제 필수가 아니라 선택에 가깝습니다. SDK에 따라 Sendable 채택 여부가 달라질 수 있으므로 실제 지원 환경에서 컴파일해 확인해야 합니다.

@Sendable 요구사항은 클로저와 클로저가 캡처한 값에 적용됩니다. 반환값은 별개의 문제입니다. 호출한 영역에서 새로 생성한 값이 다른 곳과 참조를 공유하지 않는다면, region isolation(SE-0414)에 따라 그 자리에서 쓸 수 있습니다.

---

## protocol과 @unchecked Sendable

### protocol이 Sendable을 상속하면

```swift
public protocol NetworkRequesting: Sendable { ... }     // CoreNetwork
public protocol NetworkEndpoint: Sendable { ... }
public protocol TokenStorage: Sendable { ... }          // CoreStorage
public protocol RequestInterceptor: Sendable { ... }    // Pipeline
public protocol NetworkEventMonitor: Sendable { ... }
```

protocol이 Sendable을 상속하면 모든 구현체도 Sendable을 만족해야 합니다. 위 protocol들은 실제로 동시성 영역을 넘나드는 타입을 표현하므로 선언에서부터 이 요구사항을 명시했습니다. `any NetworkRequesting`은 @MainActor의 `AppContainer`에서 만들어져 nonisolated인 Repository에 주입되고, endpoint는 ViewModel에서 만들어져 NetworkSession으로 전달됩니다. 테스트용 `StubNetworkRequesting`도 같은 조건을 따라야 하므로 실제 구현과 테스트 대역 사이의 차이도 줄어듭니다.

### @unchecked Sendable - 검사를 끄되 근거는 남기기

공식 문서는 `@unchecked Sendable`을 쓰면 컴파일러 검사가 적용되지 않으며, 락이나 큐로 상태 접근을 보호하는 책임이 개발자에게 있다고 설명합니다.

이 레포에서는 프로덕션 코드 3곳과 테스트 대역 5곳에서 씁니다. 모두 가변 상태를 수동으로 동기화하며 왜 안전한지 주석으로 남겨 두었습니다. 프로덕션 코드의 사용처는 다음과 같습니다.

| 타입 | 가변 상태 | 동기화 수단 | 안전성 근거 |
|---|---|---|---|
| `UserVolatileStorage` (Profile/Data) | user 캐시 | `NSLock` | 모든 접근이 lock으로 직렬화 |
| `InMemoryProfileCache` (Search/Data) | NSCache | NSCache 자체 | NSCache는 문서상 스레드 안전하지만 컴파일러가 이를 확인할 수 없어 주석으로 근거를 남김 |
| `DiskProfileCache` (Search/Data) | 파일 시스템 | `NSLock`(withLock) | 개별 FileManager 호출은 안전하지만 다단계 쓰기의 불변식은 락이 지킵니다 |

테스트 대역 5곳(`StubNetworkRequesting`, `MockTokenStorage`, `RoutingStubSession`, 목 세션 2종)도 NSLock으로 상태 접근을 보호합니다. 테스트 코드도 프로덕션 코드와 같은 동시성 영역을 오가기 때문입니다.

`@unchecked Sendable`을 쓸 때는 동기화 방식과 안전하다고 판단한 근거를 반드시 주석으로 남깁니다. 이 선언을 붙이면 컴파일러는 그 타입 내부의 동시성 안전성을 더 이상 검사하지 않습니다. 나중에 락으로 보호하지 않은 프로퍼티를 추가해도 오류가 나지 않습니다. 그래서 해당 타입의 역할과 크기를 작게 유지합니다.

---

## 채택하지 않은 것들

모든 타입에 Sendable이 필요한 것은 아닙니다. 채택하지 않은 사례도 함께 봅니다.

### ViewController - 경계를 넘지 않는 값

`SearchUserViewController` 같은 화면 객체는 Sendable이 아닙니다. UIViewController를 상속하고 가변 프로퍼티도 많이 갖기 때문에 Sendable로 만들 필요도, 만들 이유도 없습니다. 이 객체들은 생성부터 해제까지 @MainActor 안에서만 쓰이므로 다른 동시성 영역으로 전달되지 않습니다.

### @MainActor 클래스 - 암시적으로 이미 sendable

```swift
@MainActor final class SearchUserViewModel { ... }   // Sendable 명시 없음
@MainActor public final class ManagedTask { ... }
```

공식 문서에 따르면 @MainActor class는 메인 액터가 모든 상태 접근을 조정하기 때문에 암시적으로 Sendable입니다. 가변 프로퍼티나 non-Sendable 프로퍼티가 있어도 접근이 메인 액터로 직렬화됩니다. 모든 actor 타입이 암시적으로 Sendable을 채택하는 것과 같은 원리입니다.

이 코드베이스는 크게 두 영역으로 나뉩니다.

```
@MainActor 영역 (UI/ViewModel/ManagedTask)  <- 메인 액터로 격리 (암시적 Sendable, 가변 상태 허용)
---------- 경계 (모든 요청/응답이 통과) ----------
nonisolated 영역 (UseCase/Repo/Network/엔티티) <- Sendable을 만족하는 불변 값 위주
```

### nonisolated(unsafe) - 쓰지 않은 이유

`nonisolated(unsafe)`를 쓰면 격리 검사를 직접 해제할 수 있습니다. `@unchecked Sendable`과 마찬가지로 안전성을 컴파일러 대신 개발자가 책임져야 하므로, 이 레포에서는 명확한 근거 없이는 쓰지 않습니다. 현재 쓴 곳은 없습니다.

후보였던 `ManagedTask.task`도 Swift 6.3.2에서 컴파일해 확인한 결과 필요하지 않았습니다. deinit에서는 저장 프로퍼티에 직접 접근할 수 있고 제한되는 것은 격리된 메서드 호출이기 때문입니다. 자세한 내용은 [managedtask](managedtask.md) 노트의 설계 디테일에 정리했습니다.

---

## 새 타입을 만들 때 확인할 순서

```
이 타입의 값이 격리 경계를 넘는가?
|- 아니오 -> Sendable 불필요 (ViewController 케이스)
`- 예 ->
   |- @MainActor/actor로 격리 가능한가? -> 격리하면 암시적 Sendable (ViewModel 케이스)
   |- 값 타입 + 전 멤버 Sendable? -> : Sendable 한 줄 (엔티티/DTO 케이스)
   |    `- 멤버 중 non-Sendable이 있다 -> 타입을 좁힐 수 있나? ([String: Any]->[String: String] 케이스)
   |- class인가? -> final + 전부 let + Sendable 멤버로 만들 수 있나? (NetworkSession 케이스)
   |    `- 애초에 class일 이유가 있나? (NetworkLogger -> struct 케이스)
   |- 공유하지 않고 매번 만들면 되나? -> @Sendable 팩토리 (JSONDecoder 케이스)
   `- 가변 상태 + 수동 동기화가 불가피한가? -> @unchecked + 락 + 근거 주석, 타입은 작게 유지 (캐시/스텁 케이스)
```

---

## 함께 사용한 Swift 6 동시성 기능

Sendable 외에도 Swift 6의 동시성 검사를 구성하는 기능이 몇 가지 더 있습니다. 이 레포에서 쓴 사례를 기준으로 정리합니다.

### strict concurrency 모드

검사 강도는 세 단계입니다. `minimal`은 명시적으로 채택한 코드 위주고, `targeted`는 동시성 코드 중심이며, `complete`는 전체 코드를 검사합니다. 이 레포는 모든 타겟에 `SWIFT_STRICT_CONCURRENCY = complete`를 적용했습니다. 설정은 EnvironmentPlugin의 `baseSwiftSettings`에 있고 모듈별 예외는 두지 않았습니다. 프로젝트 초기에 이 옵션을 켜 두면 격리 오류를 발견할 때마다 상태를 어느 타입과 actor가 관리해야 하는지 함께 검토할 수 있습니다. Swift 6 언어 모드에서는 complete가 기본입니다.

- [Migrating to Swift 6 - swift.org](https://www.swift.org/migration/documentation/migrationguide/) - 모드별 의미와 이행 전략

### nonisolated async - off-main의 언어 규칙 (SE-0338)

SE-0338 규칙에서 nonisolated async 함수의 본문은 호출자의 actor가 아니라 협조적 스레드 풀에서 실행됩니다. @MainActor 코드가 `await`로 호출해도 함수 본문은 main actor 밖에서 실행되므로, 별도의 GCD 호출 없이 CPU 작업을 분리할 수 있습니다.

[`ImageDownsampler.makeImage`](../../Projects/Feature/FeatureSearch/Sources/Presentation/ImageLoading/ImageDownsampler.swift)가 그 예입니다. 이미지 디코딩이 협조적 스레드 풀에서 실행되어 스크롤을 막지 않습니다. 자세한 내용은 [이미지 파이프라인](이미지-파이프라인.md) 노트에 있습니다.

다만 SE-0461(Swift 6.2)에서는 기본 동작이 호출자의 actor에서 실행하는 쪽으로 바뀝니다. 이후 언어 모드에서 main actor 밖의 실행이 필요하다면 `@concurrent`를 명시해야 하므로 마이그레이션할 때 다시 확인해야 합니다.

deinit은 격리 밖에서 실행되지만 저장 프로퍼티에는 직접 접근할 수 있습니다. deinit 시점에는 해당 참조에 배타적으로 접근할 수 있다는 SE-0327의 규칙이 적용됩니다. 따라서 `ManagedTask`의 `deinit { task?.cancel() }`은 허용됩니다.

- [SE-0338 - Clarify the Execution of Non-Actor-Isolated Async Functions](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md)
- [SE-0461 - Run nonisolated async functions on the caller's actor by default](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)
- [SE-0327 - On Actors and Initialization](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0327-actor-initializers.md)

### sending - Sendable이 아닌 값을 전달하기 (SE-0430 / SE-0414)

Sendable이 아닌 값도 조건에 따라 다른 격리 영역으로 전달할 수 있습니다. region isolation(SE-0414)은 컴파일러가 값의 참조 관계를 추적해 다른 곳과 공유되지 않는 값인지 판단합니다. `sending`(SE-0430)은 값을 전달한 뒤 호출한 쪽에서 다시 쓰지 않는다는 조건을 함수 시그니처에 표시합니다.

```swift
// ImageDownsampler - non-Sendable UIImage를 호출한 쪽으로 전달
static func makeImage(...) async -> sending UIImage?
```

UIImage는 가변 참조 타입이므로 Sendable을 채택할 수 없습니다. 하지만 협조적 스레드 풀에서 새로 만든 UIImage가 다른 곳과 참조를 공유하지 않는다면 `sending` 결과로 @MainActor에 전달할 수 있습니다. Sendable은 여러 동시성 영역에서 값을 공유할 수 있음을 나타내고, sending은 기존 영역에서 더 이상 쓰지 않는 조건으로 값을 넘긴다는 차이가 있습니다.

- [SE-0430 - `sending` parameter and result values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md)
- [SE-0414 - Region based Isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md)

### 상황별 선택

| 상황 | 장치 | 이 레포의 사용 예 |
|---|---|---|
| 값이 경계를 자주 왕복합니다 | Sendable (불변 값 타입) | 엔티티/DTO/에러 |
| 가변 상태를 한 곳에 가둡니다 | @MainActor / actor | ViewModel/ManagedTask |
| CPU 작업을 메인 밖으로 | nonisolated async (SE-0338) | ImageDownsampler |
| non-Sendable 결과물을 반환합니다 | sending (SE-0430) | makeImage -> UIImage |
| 수동 동기화가 불가피합니다 | @unchecked + 락 + 근거 주석 | 캐시/스텁 |

---

## 정리

Sendable은 타입의 값을 다른 동시성 컨텍스트로 전달해도 안전한지 컴파일러가 확인할 수 있게 합니다. 이 앱은 UI가 @MainActor, 네트워크가 nonisolated로 동작하므로 요청과 응답에 포함되는 엔티티와 DTO, UseCase, Repository, 세션 대부분이 Sendable을 만족해야 합니다.

값 타입은 가능한 한 불변으로 만들고, 동시성 영역을 오가는 protocol은 Sendable을 상속하도록 했습니다. 반대로 ViewController는 @MainActor 안에서만 쓰므로 채택하지 않았고, ViewModel은 @MainActor에 격리되어 있어 Sendable을 명시할 필요가 없습니다.

가변 상태가 필요한 캐시와 테스트 대역에서는 `@unchecked Sendable`과 락을 썼습니다. 이 경우 동기화 근거를 주석으로 남기고 타입을 작게 유지해 개발자가 직접 확인해야 하는 범위를 줄였습니다.

두 가지를 덧붙입니다. 요구 멤버도 없는 프로토콜을 컴파일러가 어떻게 검사하는지 궁금할 수 있습니다. Sendable은 요구 멤버가 없는 마커 프로토콜이고, 채택을 선언할 때 컴파일러가 타입의 저장 프로퍼티를 검사합니다. 공식 문서도 컴파일 타임에 강제되는 요구사항이라고 적어 두었습니다. 같은 파일에서만 채택을 선언할 수 있는 것도 이 검사와 관련이 있습니다.

그리고 `Any`를 넘길 수 없는 이유는 컬렉션이 Sendable이려면 그 안에 들어가는 값도 Sendable이어야 하기 때문입니다. 앞의 `[String: Any]` 사례가 그것입니다.

---

## 참고 자료

**공식 문서**
- [Sendable - Apple Developer Documentation](https://developer.apple.com/documentation/swift/sendable) - 이 문서의 주요 출처. 정의, 값 타입과 참조 타입의 채택 조건, 암시적 conformance 조건(frozen / non-public), @MainActor class의 암시적 Sendable, @unchecked 사용 시 책임, 같은 파일 선언 규칙
- [Concurrency - The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) - Sendable Types 절: 격리 모델 안에서의 위치
- [SE-0302 Sendable and @Sendable closures - Swift Evolution](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md) - 설계 동기 원문
- WWDC22 [Eliminate data races using Swift Concurrency (110351)](https://developer.apple.com/videos/play/wwdc2022/110351/) - 격리와 Sendable을 함께 설명하는 세션

**이 레포의 관련 코드**
- 기본 채택 사례: [`GithubUser.swift`](../../Projects/Feature/FeatureSearch/Sources/Domain/Entities/GithubUser.swift), [`NetworkTask.swift`](../../Projects/Core/CoreNetwork/Sources/NetworkTask.swift)(타입 좁히기), [`NetworkSession.swift`](../../Projects/Core/CoreNetwork/Sources/NetworkSession.swift)(final+let, @Sendable 팩토리), [`NetworkLogger.swift`](../../Projects/Core/CoreNetwork/Sources/Pipeline/NetworkLogger.swift)(class->struct)
- protocol: [`NetworkRequesting.swift`](../../Projects/Core/CoreNetwork/Sources/NetworkRequesting.swift), [`TokenStorage.swift`](../../Projects/Core/CoreStorage/Sources/TokenStorage.swift), [`RequestInterceptor.swift`](../../Projects/Core/CoreNetwork/Sources/Pipeline/RequestInterceptor.swift)
- 수동 동기화: [`UserStorage.swift`](../../Projects/Feature/FeatureProfile/Sources/Data/UserStorage.swift), [`InMemoryProfileCache.swift`](../../Projects/Feature/FeatureSearch/Sources/Data/Cache/InMemoryProfileCache.swift)/[`DiskProfileCache.swift`](../../Projects/Feature/FeatureSearch/Sources/Data/Cache/DiskProfileCache.swift), [`StubNetworkRequesting.swift`](../../Projects/Core/CoreNetwork/Testing/Sources/StubNetworkRequesting.swift)(@unchecked 사용 예)
- 채택하지 않은 사례: ViewController들(불필요), ViewModel들(@MainActor로 암시적 채택)

**관련 노트**
- [managedtask](managedtask.md) - unstructured Task의 취소 규칙과 deinit 격리 예외
- [이미지 파이프라인](이미지-파이프라인.md) - nonisolated async와 sending을 함께 사용
- [owner 패턴](owner-패턴.md) - 비-Sendable owner가 격리 안에 머물러 컴파일되는 원리
