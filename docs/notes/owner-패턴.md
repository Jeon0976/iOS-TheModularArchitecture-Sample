# withUnretained 패턴 - `sink(with:)`/`ManagedTask(with:)`로 `[weak self]` 반복 제거

> [!NOTE]
> 2026-07-15, [weak self] 보일러플레이트를 owner 패턴으로 걷어내며 정리한 노트
> 관련 소스: [Publisher+SinkWith.swift](../../Projects/Core/CoreDesignSystem/Sources/Extensions/Publisher+SinkWith.swift) / [ManagedTask.swift](../../Projects/Core/CoreDesignSystem/Sources/Base/ManagedTask.swift)

> [!IMPORTANT]
> **다루는 질문** - 모든 ViewModel/VC가 `.sink { [weak self] in guard let self else ... }`와 `task.replace(onError: { [weak self] ... }) { [weak self] ... }`를 복붙하고 있었다.
>
> - RxSwift 스타일의 `Publisher+SinkWith` 구현을 이식해 이 보일러플레이트를 걷어냈다.
> - **한 줄 결론**: 이건 RxSwift 6의 **`withUnretained` 패턴**이다 - `subscribe(with:)`를 Combine의 `sink(with:)`로 그대로 옮긴 것.

---

## 1. TL;DR

| 질문 | 답 |
|---|---|
| 뭐라 부르나 | **withUnretained 패턴** (RxSwift 원조) - 이 레포에서는 `sink(with:)`, "owner 패턴" |
| 무엇을 하나 | `[weak self]+guard`를 확장에 가두고, 호출부엔 **살아있음이 보장된 `owner`**를 파라미터로 relay |
| 메모리 동작 | 바뀌지 않는다 - 여전히 weak 캡처 + guard. 문법만 줄었지 참조 관계는 그대로 |
| Task까지 확장 | `ManagedTask.replace(with:)`/`runIfIdle(with:)` |
| Swift 6 통과 이유 | owner가 **`@MainActor` 안에서만** 동작 |

---

## 2. 문제 - 모든 sink/Task마다 반복되는 코드

```swift
// 전(before): 모든 sink에 반복되는 코드 두 가지
.sink { [weak self] query in           // 반복 1: weak 캡처
    self?.searchUsers(query: query)     // 반복 2: 옵셔널 체이닝(또는 guard let self)
}
.store(in: &cancellables)

// Task도 마찬가지 - replace의 onError/operation 양쪽에 [weak self]+guard 두 번
searchTask.replace(onError: { [weak self] error in
    guard let self else { return }      // guard 1
    self.send(self.lastStableState)
    self.errorSubject.send(error)
}) { [weak self] in
    guard let self else { return }      // guard 2
    ...
}
```

이 코드는 **모든 ViewModel/VC가 매 sink/매 Task마다** 반복한다. 사람이 지키는 규칙이라 언젠가 빠뜨린다 - `ManagedTask`가 만들어진 이유(수동 규칙 5가지 복붙)와 같은 부류의 문제다.

---

## 3. 해법 - 실제 코드

### 3-1. [`Publisher+SinkWith.swift`](../../Projects/Core/CoreDesignSystem/Sources/Extensions/Publisher+SinkWith.swift) (CoreDesignSystem)
```swift
extension Publisher where Failure == Never {
    /// object를 weak로 캡처해, 살아있을 때만 receiveValue(owner, output)를 호출한다.
    public func sink<Object: AnyObject>(
        with object: Object,
        receiveValue: @escaping (Object, Self.Output) -> Void
    ) -> AnyCancellable {
        sink { [weak object] output in
            guard let object else { return }      // 규칙을 여기 한 곳에 가둔다
            receiveValue(object, output)          // 살아있으면 owner를 첫 인자로
        }
    }

    /// 위와 같되 구독을 cancellables에 바로 저장 (.store(in:) 생략).
    public func sink<Object: AnyObject>(
        with object: Object,
        in cancellables: inout Set<AnyCancellable>,
        receiveValue: @escaping (Object, Self.Output) -> Void
    ) {
        sink(with: object, receiveValue: receiveValue).store(in: &cancellables)
    }
}
```

> [!NOTE] 왜 `Failure == Never` 전용인가
> 이 앱은 에러를 Combine completion으로 흘리지 않고 상태/이벤트(Subject)로 전달한다. 그래서 모든 Publisher가 `Failure == Never`고, `receiveCompletion`을 받는 오버로드를 만들 필요가 없었다. RxSwift의 `subscribe(with:)`에 `onError:`가 있는 것은 Rx 스트림이 에러로 끝날 수 있기 때문인데, 이 앱에는 그 경우 자체가 없다.

### 3-2. `ManagedTask`의 owner 오버로드 (같은 규칙을 Task에)
```swift
public func replace<Owner: AnyObject>(
    with owner: Owner,
    onError: ((Owner, Error) -> Void)? = nil,
    operation: @escaping @MainActor (Owner) async throws -> Void
) {
    task?.cancel()
    start(
        onError: onError.map { handler in
            { [weak owner] error in guard let owner else { return }; handler(owner, error) }
        },
        operation: { [weak owner] in guard let owner else { return }; try await operation(owner) }
    )
}
// runIfIdle(with:)도 동일 구조. 기존 non-owner 오버로드는 그대로 공존한다.
```
onError/operation **양쪽 모두** owner를 weak로 잡아 relay한다. non-owner `start`에 위임하므로 `generation` 번호/취소 침묵 같은 기존 규칙은 하나도 안 바뀐다.

---

## 4. 출처 - RxSwift 6의 withUnretained가 원조

| 이름 | 출처 | 죽었을 때 |
|---|---|---|
| `subscribe(with: obj, onNext:onError:...)` | **RxSwift 6** (2021) | 핸들러 스킵 |
| `withUnretained(_:)` 연산자 | RxSwift 6 -> `Observable<(Object, Element)>` | **스트림 complete** |
| `withUnretained` | **CombineExt** (Combine 포팅) | 스킵/complete |
| `sink(with:)` / "owner 패턴" | **이 레포** | 스킵 (`guard let object else { return }`) |

```swift
// RxSwift                                    // Combine (이 레포)
observable                                    publisher
    .subscribe(with: self) { owner, v in          .sink(with: self, in: &bag) { owner, v in
        owner.handle(v)                               owner.handle(v)
    }                                             }
    .disposed(by: disposeBag)
```
`subscribe`<->`sink`, `disposeBag`<->`cancellables`, `disposed(by:)`<->`store(in:)`. 이름만 다르고 동작 규칙은 같다 - **`sink(with:)`는 RxSwift `subscribe(with:)`를 Combine으로 그대로 옮긴 것**이다. RxSwift에는 스트림 중간에서 `(객체, 값)` 튜플로 바꿔 주는 `withUnretained` *연산자*도 따로 있는데(객체가 해제되면 스트림 종료), 그 형태는 가져오지 않았다.

> [!TIP] `ManagedTask(with:)`는 RxSwift 범위 밖
> Task는 RxSwift가 아니라 Swift 구조적 동시성이다. "owner 주입"이라는 **같은 아이디어를 RxSwift가 안 다루는 Task 클로저에까지 넓힌** 게 이 이식의 확장분이다.

---

## 5. Before / After (SearchUserViewModel 실물)

```swift
// AS-IS
input.searchUser
    .filter { !$0.isEmpty }
    .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
    .sink { [weak self] query in self?.searchUsers(query: query) }
    .store(in: &cancellables)

searchTask.replace(onError: { [weak self] error in
    guard let self else { return }
    self.send(self.lastStableState)
    self.errorSubject.send(error)
}) { [weak self] in
    guard let self else { return }
    let firstPage = paginator.begin(query: query)
    let page = try await searchUsersUseCase.execute(query: query, page: firstPage, perPage: paginator.perPage)
    guard !Task.isCancelled else { return }
    paginator.apply(page)
    send(page.users.isEmpty ? .empty : .loaded(users: page.users, isPagingNext: false))
}

// TO-BE - [weak self]/guard let self 소멸, self 멤버는 owner.
input.searchUser
    .filter { !$0.isEmpty }
    .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
    .sink(with: self, in: &cancellables) { owner, query in owner.searchUsers(query: query) }

searchTask.replace(with: self, onError: { owner, error in
    owner.send(owner.lastStableState)
    owner.errorSubject.send(error)
}) { owner in
    let firstPage = owner.paginator.begin(query: query)
    let page = try await owner.searchUsersUseCase.execute(query: query, page: firstPage, perPage: owner.paginator.perPage)
    guard !Task.isCancelled else { return }
    owner.paginator.apply(page)
    owner.send(page.users.isEmpty ? .empty : .loaded(users: page.users, isPagingNext: false))
}
```

> [!NOTE] `query` 같은 지역 변수는 그대로 캡처된다
> owner로 바뀌는 건 **self 멤버**뿐이다. 클로저 밖의 지역 변수(`query`)나 `guard !Task.isCancelled`(취소 후 반영 방지는 본문 책임) 같은 건 그대로 유지된다.

---

## 6. 왜 Swift 6 strict concurrency에서 컴파일되나

`Owner: AnyObject`는 **Sendable이 아니다**. 그런데도 제네릭 오버로드가 통과하는 이유:

- `ManagedTask`가 **`@MainActor`** 이고, `operation`이 **`@MainActor (Owner) async throws -> Void`** 다. 즉 owner를 만지는 클로저가 전부 MainActor에 격리돼 있다.
- `start`의 `Task { }`는 `@MainActor` 컨텍스트에서 생성되므로 **MainActor 실행자를 물려받는다** - operation은 메인에서 돈다.
- 따라서 Sendable이 아닌 `owner`가 **격리 경계를 넘는 일이 없다.** 캡처(`[weak owner]`)해서 MainActor 안에서만 쓴다. Swift 6이 Sendable을 요구하는 건 값이 **액터 사이를 건널 때**뿐이라 여긴 요구가 발생하지 않는다.
- **핵심은 `operation`의 `@MainActor`다.** 이게 없거나 `Task.detached`였다면, Sendable이 아닌 owner가 다른 격리 영역으로 넘어가게 되어 컴파일 에러가 났을 것이다.

`sink(with:)`는 더 단순하다 - Combine `sink(receiveValue:)`를 감싼 것뿐이고 `object` 캡처는 격리를 넘지 않는 평범한 캡처라 Sendable 요구가 없다.

---

## 7. 바뀌지 않는 것

메모리 동작은 그대로다 - 여전히 `[weak owner]` + `guard`고, owner는 클로저가 실행되는 동안만 강참조로 잡혔다 풀린다(`guard let self`와 완전히 같다). 순환 참조도 없다. 취소/`generation` 방어도 non-owner `start`에 위임하므로 그대로다. 즉 문법이 줄었을 뿐 새로운 수명 관리 방식이 아니다 - `[weak self]`가 사라진 게 아니라 **API 안쪽으로 이사**한 것이다.

---

## 8. 어디에 쓰고, 어디에 안 쓰나

- **잘 맞는 곳**: `sink`/Task operation/onError처럼 **반환값이 없는 마지막 단계의 클로저** - "owner가 해제됐으면 그냥 건너뛴다"로 충분하다.
- **안 맞는 곳**: `filter`처럼 **값을 돌려주는 연산자** - owner가 해제됐을 때 무엇을 반환할지(true? false?)가 정해지지 않는다. 그래서 `.filter { [weak self] in self?.paginator.hasNextPage ?? false }` 한 곳은 **일부러 안 바꿨다** (`?? false`가 그 답을 이미 코드로 보여 준다).
- 이식 결과: sink 14곳 + ManagedTask 6곳 = **20곳** 전환. 남은 `[weak self]` 4곳은 전부 sink/Task가 아닌 **UIKit 콜백**(DiffableDataSource cellProvider, `textFieldShouldSearch`, 알럿 액션) + 위 filter 하나.

덧붙여, "클로저가 self를 캡처하는 대신 파라미터로 전달받는" 방향은 Apple API에도 있다 - iOS 17의 `registerForTraitChanges(_:handler:)`가 핸들러 첫 인자로 `(self: Self, _)`를 넘겨주는 것이 같은 발상이다.

---

## 9. 참고 자료

**공식 문서/참조 구현**
- [Publisher.sink(receiveValue:) - Apple Developer Documentation](https://developer.apple.com/documentation/combine/publisher/sink(receivevalue:)) - 감싸는 대상의 원형
- [SE-0302 - Sendable and @Sendable closures](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md) - Sendable 요구가 "경계를 넘을 때"만 발생하는 근거
- [SE-0316 - Global actors (@MainActor)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md) - owner가 격리 안에 머무는 장치
- [RxSwift 6 - subscribe(with:)/withUnretained](https://github.com/ReactiveX/RxSwift) - 원조 API (RxSwift 6.0, 2021)
- [CombineExt - withUnretained](https://github.com/CombineCommunity/CombineExt) - Combine 포팅의 선례

**이 레포의 실물 코드**
- [`Publisher+SinkWith.swift`](../../Projects/Core/CoreDesignSystem/Sources/Extensions/Publisher+SinkWith.swift) - `Failure == Never` 전용 sink(with:) 2형
- [`ManagedTask.swift`](../../Projects/Core/CoreDesignSystem/Sources/Base/ManagedTask.swift) - replace(with:)/runIfIdle(with:) owner 오버로드

**관련 노트**: [managedtask](managedtask.md) - ManagedTask의 태생 (unstructured Task의 취소 규칙 5종)
