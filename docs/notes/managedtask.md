# Structured vs Unstructured Task - 동기 진입점에서 `Task {}`를 안전하게 쓰는 법 (ManagedTask)

> [!NOTE]
> 2026-07-10, CoreDesignSystem을 구현하며 정리한 학습 노트다 (노트 톤 그대로 옮김).
> 관련 소스: [ManagedTask.swift](../../Projects/Core/CoreDesignSystem/Sources/Base/ManagedTask.swift) / [ManagedTaskTests.swift](../../Projects/Core/CoreDesignSystem/Tests/ManagedTaskTests.swift)

> [!IMPORTANT]
> **다루는 질문** - 이 레포의 ViewModel들은 왜 `Task {}`를 직접 들고 있지 않고 `ManagedTask`라는 상자에 담는가? Swift 공식 권장은 "가능하면 structured"인데 왜 `Task {}`(unstructured)를 쓰는가?
>
> - **structured(구조화)** = async 함수 안에서 `async let`/`TaskGroup`으로 만들어 부모 함수에 묶이는 작업
> - **unstructured(비구조화)** = `Task {}`로 만들어 아무에게도 안 묶이는 작업
> - **한 줄 결론**: structured concurrency가 주는 보장(수명 묶기/자동 취소/완료 대기)은 **async 함수 안에서만** 성립한다.
> - UIKit의 viewDidLoad/버튼 핸들러는 동기 함수라서 async 작업을 시작할 방법이 `Task {}`뿐이고, 이렇게 시작한 작업은 **아무에게도 묶이지 않은 채 남는다**. 문제는 `Task {}`를 쓴 것이 아니라 **그 작업을 방치하는 것** - 방치하지 않기 위한 수동 규칙 5가지를 타입 하나로 못박은 것이 `ManagedTask`다.

---

## 1. TL;DR

| 질문 | 답 |
|---|---|
| structured vs unstructured | structured = async 함수 **안에서** 만든 자식 작업(`async let`, `TaskGroup`) - 부모에 묶여 수명/취소가 자동. unstructured = `Task {}` - 어디서든 시작 가능하지만 **아무에게도 안 묶인다** |
| 왜 ViewModel은 unstructured를 쓰나 | 버튼 핸들러/viewDidLoad는 **동기 함수**라 await를 못 쓴다. async를 시작할 유일한 방법이 `Task {}` - 여기서는 차선이 아니라 **정석 진입점** |
| unstructured Task를 방치하면 | 1) 화면이 닫혀도 계속 돈다 2) 연타하면 이전 요청이 계속 돈다 3) 늦게 도착한 옛 응답이 새 화면을 덮는다 |
| ManagedTask는 뭔가 | unstructured Task를 관리하는 수동 규칙 5가지(핸들 보관/재진입 취소/deinit 취소/취소 후 결과 무시/CancellationError 침묵)를 클래스 하나에 넣은 보관함. `replace`(이전 요청을 취소하고 교체)와 `runIfIdle`(진행 중이면 새 요청 무시) 두 가지 동작 제공 |
| SwiftUI라면 | 뷰가 시작하는 작업은 `.task` modifier가 대신 관리한다(뷰 사라지면 자동 취소). 다만 뷰 밖(Store/ViewModel)에서 작업을 시작하는 구조라면 SwiftUI라도 같은 관리가 필요하다 - TCA cancellable이 그 사례 (6절, 7-2절) |

---

## 2. Structured vs Unstructured - 쉬운 버전

### 2-1. Structured: 함수 스코프에 갇힌 작업

```swift
func loadDashboard() async throws -> Dashboard {
    async let user = fetchUser()        // 자식 1
    async let repos = fetchRepos()      // 자식 2
    return try await Dashboard(user: user, repos: repos)
}   // <- 이 함수는 자식 둘이 끝나기 전에 절대 리턴하지 않는다
```

`async let`과 `TaskGroup`으로 만든 작업은 **그걸 만든 함수의 자식**이다. 그래서:

- **수명**: 함수가 끝나기 전에 자식이 반드시 정리된다 (기다리거나 취소되거나) - 정리되지 않고 남는 작업이 없다
- **취소**: 부모가 취소되면 자식도 자동 취소 - [Task.cancel() 공식 문서](https://developer.apple.com/documentation/swift/task/cancel()): *"It cancels any child tasks and task groups of the task"*
- **에러**: 자식의 throw가 부모로 자연 전파

이 세 가지가 **언어가 자동으로 주는 보장**이다. WWDC21 [Explore structured concurrency](https://developer.apple.com/videos/play/wwdc2021/10134/)가 이 모델의 공식 소개.

### 2-2. Unstructured: 아무에게도 묶이지 않는다

```swift
func fetchUser() {          // 동기 함수 (버튼 핸들러라고 치자)
    Task {                  // <- 시작은 여기서 하지만...
        let user = try await useCase.execute()
        render(user)
    }
}   // <- 함수는 Task를 기다리지 않고 즉시 리턴한다. Task는 혼자 남는다
```

`Task {}`로 만든 작업은 **아무에게도 묶여 있지 않다**(영어 문헌은 orphaned task라 부른다). 시작한 함수가 리턴해도, 화면이 닫혀도, 계속 돈다. [Swift 공식 문서(The Swift Programming Language)의 표현](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/): unstructured task는 유연성을 주는 대신 *완료 대기/취소 같은 정확성 보장을 개발자가 직접 책임진다*.

> [!TIP] Task {} vs Task.detached
> `Task {}`는 그래도 **actor 격리/우선순위/TaskLocal은 상속**한다(@MainActor 안에서 만들면 MainActor에서 돈다). `Task.detached`는 그것마저 상속하지 않아 쓸 일이 거의 없다.

---

## 3. UIKit 경계 문제 - 왜 unstructured가 "정석"인가

공식 권장은 분명히 "가능하면 structured"다. 그런데 **structured를 쓰려면 이미 async 함수 안에 있어야 한다.** 

```swift
override func viewDidLoad()                  // 동기
@objc func buttonTapped(_ sender: UIButton)  // 동기
func tableView(_:cellForRowAt:) -> UITableViewCell  // 동기
```

전부 동기 함수다. 이 안에서 `await`는 컴파일 에러고 `async let`도 못 쓴다. **동기 함수에서 async 작업을 시작할 방법은 `Task {}`(와 `Task.detached`)뿐이다** - 이것이 unstructured Task가 존재하는 이유다. 이 경계에서 `Task {}`는 차선이 아니라 정석 진입점이다.

즉 진짜 질문은 "`Task {}`를 써도 되나?"가 아니라 **"이렇게 시작한 작업을 누가 책임지나?"**다.

---

## 4. unstructured Task를 방치하면 생기는 사고 3가지

GitSearch 검색 화면 기준으로:

1. **화면이 닫혀도 계속 돈다** - 검색 중에 뒤로가기 -> 요청은 계속 진행, 응답 도착, (심하면) 죽은 화면의 상태를 건드린다. 
2. **연타하면 이전 요청이 계속 돈다** - "swift" 검색 -> 바로 "swiftui" 검색. 첫 요청을 취소하지 않으면 두 요청이 모두 끝까지 실행되고, rate limit(비인증 10 req/min)만 불필요하게 소모된다.
3. **늦은 응답이 새 화면을 덮는다 (stale response)** - 2번의 연장전. "swift" 응답이 "swiftui" 응답보다 **늦게** 도착하면, 화면은 "swiftui"를 검색했는데 결과는 "swift"가 표시된다. 검색 화면에서 흔히 겪는 버그다.

### 4-1. 직접 지켜야 했던 수동 규칙 5가지

ManagedTask가 없다면 ViewModel마다 이 규칙을 직접 지켜야 한다:

```swift
private var fetchTask: Task<Void, Never>?                        // 1) 핸들 보관

private func fetchUser() {
    fetchTask?.cancel()                                          // 2) 재진입 시 이전 취소
    fetchTask = Task {
        do {
            let user = try await fetchUserUseCase.execute()
            guard !Task.isCancelled else { return }              // 4) 취소 후 결과 무시
            userSubject.send(user)
        } catch is CancellationError {                           // 5) 취소는 조용히 종료
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorSubject.send(error)
        }
    }
}

deinit { fetchTask?.cancel() }                                   // 3) 화면 죽으면 취소
```

1)~5) 중 하나라도 빠지면 4절의 사고가 재현되는데, **컴파일러는 아무것도 잡아주지 않는다.** 사람이 지키는 규약은 언젠가 깨진다.

---

## 5. ManagedTask - 규칙을 타입으로

[`CoreDesignSystem/Sources/Base/ManagedTask.swift`](../../Projects/Core/CoreDesignSystem/Sources/Base/ManagedTask.swift) 실물(요약). 1)~5)를 클래스 하나에 넣었다:

```swift
@MainActor
public final class ManagedTask {
    private var task: Task<Void, Never>?                       // 1) 핸들 보관
    private var generation = 0

    deinit { task?.cancel() }                                   // 3) - 소유자 deinit에서 자동으로 이어진다

    /// 교체 실행 - 이전 작업 취소 후 새 작업 시작 (검색: 새 요청이 이전 요청을 대체)
    public func replace(
      	onError: ((Error) -> Void)? = nil,
      	operation: @escaping @MainActor () async throws -> Void
   	) {
        task?.cancel()                                          // 2)
        start(onError: onError, operation: operation)
    }

    /// single-flight - 진행 중이면 무시 (페이징: 중복 시작 방지)
    public func runIfIdle(...) { guard task == nil else { return }; start(...) }

    private func start(...) {
        generation &+= 1
        let startedGeneration = generation
        task = Task { [weak self] in
            do { try await operation() }
            catch is CancellationError { }                      // 5)
            catch { if !Task.isCancelled { onError?(error) } }  // 5)'(취소 직후 실패도 침묵)
            // 교체되지 않은 최신 작업일 때만 슬롯 반납 - 이미 교체된 이전 작업이
            // 새 작업의 핸들을 지우는 레이스 방지 (generation 비교)
            if let self, self.generation == startedGeneration { self.task = nil }
        }
    }
}
```

사용하는 쪽 (ProfileViewModel 실물 - deinit이 사라졌다):

```swift
private let fetchTask = ManagedTask()

private func fetchUser() {
    fetchTask.replace(with: self, onError: { owner, error in
        owner.errorSubject.send(error)
    }) { owner in
        let user = try await owner.fetchUserUseCase.execute()
        guard !Task.isCancelled else { return }   // 4)만 본문에 남는다 - "무엇이 반영인지"는 본문만 안다
        owner.userSubject.send(user)
    }
}
```

`with: self`/`owner`는 호출부의 `[weak self]`+`guard let`까지 걷어내 주는 owner 오버로드다 - 상세는 [owner-패턴](owner-패턴.md) 노트 참고.

### 5-0. `generation` 비교가 막는 레이스 - 타임라인으로 

`generation` 비교가 없다고 치면(완료 시 무조건 `task = nil`이라 치면):

```
t0: replace(A 요청)        -> task 슬롯 = A
t1: replace(B 요청)        -> A.cancel() 호출, task 슬롯 = B
t2: A의 클로저가 뒤늦게 완료  <- cancel()은 취소 표시만 세울 뿐, A의 클로저는 끝까지 실행된다
    A가 마지막 줄에서 task = nil 실행   (!) 그 시점 슬롯에 든 B의 핸들이 지워진다
t3: B는 여전히 실행 중인데 핸들이 없다 - deinit이 와도, cancel()을 불러도 B를 취소할 방법이 없다.
    runIfIdle은 "슬롯이 비었다"고 판단 -> B가 도는 중에 C를 또 시작한다 (single-flight 붕괴)
```

핸들을 잃은 작업은 **더는 취소할 수 없다** - 이 레이스가 위험한 진짜 이유다. 그래서 슬롯을 비우는 조건이 "**아직 교체되지 않은 작업일 때만**"이다: 시작 시점의 `generation` 값(let)을 캡처해 두고, 완료 시 현재 값과 일치할 때만 슬롯을 비운다.

### 5-0-1. deinit 취소가 자동으로 되는 이유

VM이 `let fetchTask = ManagedTask()`로 들고만 있으면, VM 해제 -> ManagedTask 해제 -> deinit의 `task?.cancel()` -> URLSession까지 자동으로 이어진다. **VM은 deinit을 한 줄도 쓰지 않는다.**

이 연쇄의 전제가 `start`의 `[weak self]`다. Task가 ManagedTask를 강하게 잡으면 작업이 도는 동안 ManagedTask가 해제되지 않아 VM이 죽어도 deinit이 불리지 않는다. `[weak self]`가 이 고리를 끊는다. 

### 5-1. 설계 디테일 3가지

- **규칙 4(`guard !Task.isCancelled`)만 호출부에 남는 이유** - "취소됐으면 결과를 반영하지 마라"에서 *무엇이 반영인지*(subject에 보낼지, 상태를 바꿀지)는 작업 본문만 안다. ManagedTask가 대신할 수 있는 것은 취소 뒤처리(에러 침묵)까지다.
- **`generation` 비교가 있는 이유** - 5-0절의 레이스 때문이다. "자기 Task 핸들을 캡처해서 비교"하는 방식은 Sendable 클로저 안에서 var 캡처를 바꾸는 코드가 되어 Swift 6이 거부한다. 그래서 시작 시점의 `generation` 값(let)을 캡처해 비교한다.
- **deinit의 `task?.cancel()`이 컴파일되는 이유** - deinit에서 금지되는 것은 격리된 **메서드/계산 프로퍼티 호출**이고, **저장 프로퍼티 직접 접근은 허용**된다. deinit 시점엔 이 객체를 참조하는 곳이 하나뿐이라 동시 접근이 있을 수 없다는 것을 컴파일러가 알기 때문이다(SE-0327, Swift 6.3 실측). 그래서 `nonisolated(unsafe)` 없이 평범한 `private var task`로 충분하다.

### 5-2. 취소는 어디까지 내려가나

`ManagedTask.cancel()` 한 번이면 취소가 끝까지 내려간다. Task에 취소 표시가 서고, await 체인(UseCase -> Repository)을 따라 `URLSession.data(for:)`까지 전달된다. URLSession의 async API는 취소를 감지하도록 구현돼 있어서 **진행 중인 HTTP 요청을 소켓 레벨에서 끊고** `URLError(.cancelled)`를 던지며, CoreNetwork가 이를 `CancellationError`로 정규화해 ManagedTask의 catch에서 조용히 끝난다.

---

## 6. SwiftUI와의 대비

SwiftUI에는 같은 문제에 대한 **프레임워크 차원의 답**이 이미 있다

```swift
SomeView()
    .task(id: query) {                    // 뷰가 사라지면 자동 취소,
        await viewModel.search(query)     // id(query)가 바뀌면 이전 것 취소 후 재시작
    }
```

`.task` modifier는 **뷰가 시작하는 작업**의 수명을 뷰 수명에 묶어 준다 - 뷰가 사라지면 자동 취소, `id`가 바뀌면 replace와 같은 동작까지. UIKit에는 이런 modifier가 없으니, ManagedTask는 그 빈자리를 직접 만든 셈이다.

다만 `.task`가 커버하는 것은 거기까지다. SwiftUI라도 뷰 밖(별도 Store/ViewModel, MVI류 구조)에서 작업을 시작하면 같은 수명 관리 문제가 그대로 남는다 - TCA가 `cancellable(id:cancelInFlight:)`를 따로 만든 이유가 정확히 이것이다(7-2절).

이 대비가 문제의 본질을 보여 준다: structured든 `.task`든 ManagedTask든, 관건은 하나 - **"비동기 작업의 수명을 누가 무엇에 묶어 주는가."** structured는 함수 스코프에, `.task`는 뷰 수명에, ManagedTask는 소유 객체(ViewModel) 수명에 묶는다. 묶이지 않은 채 방치된 작업만이 버그다.

---

## 7. 직접 만드는 게 일반적인가 - RxSwift/Combine/TCA와 비교

RxSwift에는 DisposeBag, Combine에는 `Set<AnyCancellable>`이 있는데, Swift Concurrency에는 대응하는 표준 부품이 없다. ManagedTask는 그 빈자리를 채운 타입이다.

### 7-1. 세대마다 있던 부품 - 그리고 공백

"비동기 작업을 화면 수명에 묶고, 재진입 시 취소한다"는 문제의 표준 답의 흐름:

```
RxSwift 시대:     DisposeBag           구독을 가방에 - 가방이 죽으면 전부 해지
Combine 시대:     Set<AnyCancellable>  같은 발상, 1st-party (VM들의 cancellables가 이것)
Concurrency 시대:  (공백)               <- 애플이 표준 컨테이너를 안 줬다
```

Swift Concurrency에는 DisposeBag/CancelBag에 해당하는 **표준 그릇이 없다.** UIKit에서 `Task {}`를 쓰는 순간 5규칙(4-1절)이 필요한데 담을 곳이 없어서, 실무는 둘로 갈린다 - 1) 각자 만든다(TaskBag/CancelBag/SingleTask... 이름은 제각각, 열어보면 거의 같은 모양) 2) VM마다 복붙한다(흔하지만, 흔한 것과 좋은 것은 다르다).

### 7-2. 같은 동작이 TCA에는 정식 API로 있다

Point-Free의 TCA에는 같은 동작이 **정식 API**로 있다: 

```swift
.cancellable(id: SearchID.self, cancelInFlight: true)   // <- 정확히 replace와 같은 동작
.cancel(id: SearchID.self)                               // <- cancel
```

`cancelInFlight: true` 하나가 "진행 중인 같은 ID를 취소하고 대체" - ManagedTask.replace와 글자만 다른 같은 개념이다. "이전 요청 취소 후 교체, single-flight 같은 실행 방식을 이름 붙은 부품으로 만든다"는 접근이 업계에서 이미 쓰이고 있다는 뜻이다.

> [!TIP] 한 줄 정리
> 비동기 작업을 화면 수명에 묶는 문제는 DisposeBag -> Set&lt;AnyCancellable&gt;로 이어져 온 표준 부품들인데, Swift Concurrency에는 그 표준 그릇이 없다. SwiftUI는 뷰가 시작하는 작업 한정으로 .task(id:)가 채워 주지만 UIKit에는 없어서, TCA의 cancellable(id:cancelInFlight:)과 같은 동작을 ManagedTask라는 작은 타입으로 만들었다 - 발명이 아니라 세대 교체기의 공백을 메운 것.

## 8. 검증 - ManagedTaskTests의 계약 5개

ManagedTask는 ViewModel들과 셀 이미지 로더가 공통으로 쓰는 기반 부품이다. 특히 `generation` 비교 같은 레이스 방어는 나중에 "무조건 task = nil"로 단순화해 버리기 쉬운 부분이라, 그렇게 고치는 순간 테스트가 바로 실패하도록 동작 5가지를 테스트로 고정했다 ([`ManagedTaskTests.swift`](../../Projects/Core/CoreDesignSystem/Tests/ManagedTaskTests.swift), 전부 통과):

| 계약 | 검증 방법의 핵심 |
|---|---|
| replace는 이전 작업을 취소하고, 취소는 onError로 새지 않는다 | 10초 sleep이 취소로 깨지는지 + onError 미호출 확인 |
| runIfIdle은 진행 중이면 무시 | **continuation을 밸브로** - "진행 중"을 결정적으로 유지 |
| **늦은 완료가 새 핸들을 안 지운다** (5-0절 레이스) | continuation **두 개**로 "이전 작업이 새 작업 진행 중에 늦게 완료"되는 순서를 강제 -> isRunning 여전히 true |
| 일반 에러는 onError로 전달 | throw -> 전달 확인 |
| **취소 후 늦은 실패도 침묵** (`if !Task.isCancelled` 분기) | cancel()로 깃발부터 -> resume -> 비-취소 에러 throw -> onError 미호출 |

이 테스트를 만들며 얻은 교훈 2개:

1. **주석이 검증을 주장해도 믿지 마라** - 초기 테스트 하나가 "generation 검증"이라는 주석을 달고 있었지만, 실제로는 새 작업이 먼저 끝나는 순서라 **generation 로직을 깨뜨려도 통과**하는 구조였다. 레이스 테스트는 완료 순서를 테스트가 쥐어야(continuation) 성립한다.
2. **mutation 검증** - 테스트가 정말 회귀를 잡는지 보려면 `generation` 비교 조건을 잠깐 지우고 돌려 빨간불을 눈으로 확인하라. 키체인 -34018 실측과 같은 부류의 "직접 보는 증명".

---

## 9. 정리

- structured concurrency의 보장은 async 함수 안에서만 성립한다. UIKit의 진입점(viewDidLoad, 버튼 핸들러)은 동기 함수라 async를 시작할 방법이 `Task {}`뿐이고, 이 경계에서 unstructured는 차선이 아니라 정석 진입점이다.
- 대신 structured가 자동으로 주던 보장(수명 묶기/재진입 취소/취소 후 결과 무시)이 사라진다. 그 규칙을 ManagedTask라는 타입으로 복원해 컴파일 타임에 강제되게 했다.
- SwiftUI였다면 뷰가 시작하는 작업은 `.task(id:)` modifier가 프레임워크 차원에서 관리해 줬을 것이다. 이 설계가 푸는 문제의 본질이 "수명을 누가 묶는가"라는 뜻이다.

보충 정리:
- **Task.detached와의 차이** - 격리/우선순위 상속 여부 (2-2절 TIP).
- **취소하면 네트워크도 실제로 끊기나** - 끊긴다. URLSession의 async API가 취소에 반응하게 구현돼 있다 (5-2절).
- **deinit에서 task?.cancel()이 되는 이유** - 저장 프로퍼티 직접 접근 허용, SE-0327의 참조 유일성 (5-1절).
- **replace와 runIfIdle을 나눈 이유** - 검색은 새 요청이 이전 요청을 대체해야 하고, 페이징은 진행 중이면 새로 시작하지 말아야 한다. 동작이 다른데 API가 하나면 호출부가 실수한다.
- **직접 만든 타입의 검증** - 계약 5개 테스트 (8절). 특히 5-0절의 레이스는 continuation 두 개로 완료 순서를 강제해 검증했다.
- **이런 걸 만드는 게 일반적인가** - RxSwift/Combine에는 표준 부품(DisposeBag, `Set<AnyCancellable>`)이 있었는데 Concurrency에는 없고, TCA의 cancelInFlight가 같은 동작이다 (7절). SwiftUI의 뷰 주도 작업은 `.task`가 대신한다 (6절).
---

## 10. 참고 자료

**공식 문서**
- [Concurrency - The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) - Unstructured Concurrency 절: 유연성과 개발자 책임, 부모->자식 자동 취소
- [Task.cancel() - Apple](https://developer.apple.com/documentation/swift/task/cancel()) - 취소의 3효과(깃발/핸들러/자식 취소)
- [Explore structured concurrency in Swift - WWDC21 10134](https://developer.apple.com/videos/play/wwdc2021/10134/) - structured 우선 원칙, Task 계층
- [task(id:priority:_:) - Apple](https://developer.apple.com/documentation/swiftui/view/task(id:priority:_:)) - SwiftUI의 프레임워크 차원 해법 (id 변경/뷰 소멸 시 자동 취소)

**참조 구현 (역사적 근거)**
- [TCA - Effect.cancellable(id:cancelInFlight:)](https://github.com/pointfreeco/swift-composable-architecture) - replace와 같은 동작의 업계 검증 실물
- RxSwift DisposeBag / Combine `Set<AnyCancellable>` - "수명에 묶인 취소 가방"의 앞 세대들

**이 레포의 실물 코드**
- [`ManagedTask.swift`](../../Projects/Core/CoreDesignSystem/Sources/Base/ManagedTask.swift) - 본체 (owner 오버로드 포함)
- [`ManagedTaskTests.swift`](../../Projects/Core/CoreDesignSystem/Tests/ManagedTaskTests.swift) - 계약 5개 검증
- [`ProfileViewModel.swift`](../../Projects/Feature/FeatureProfile/Sources/Presentation/ProfileViewModel.swift) - 가장 단순한 사용례
- [`SearchUserViewModel.swift`](../../Projects/Feature/FeatureSearch/Sources/Presentation/SearchUserViewModel.swift) - replace(검색)/runIfIdle(페이징) 두 동작 동시 사용

**관련 노트**: [owner-패턴](owner-패턴.md) - 호출부의 [weak self]까지 걷어내는 owner 오버로드 / [swift6-sendable](swift6-sendable.md) - 이 레포의 Sendable 경계 지도
