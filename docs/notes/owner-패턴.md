# owner 패턴 - sink(with:)와 ManagedTask(with:)로 [weak self] 반복 제거

> 2026-07-15, [weak self] 보일러플레이트를 owner 패턴으로 걷어내며 정리한 노트
> 관련 소스: [Publisher+SinkWith.swift](../../Projects/Core/CoreDesignSystem/Sources/Extensions/Publisher+SinkWith.swift) / [ManagedTask.swift](../../Projects/Core/CoreDesignSystem/Sources/Base/ManagedTask.swift)

모든 ViewModel과 VC가 `.sink { [weak self] in guard let self else ... }`와 `task.replace(onError: { [weak self] ... }) { [weak self] ... }`를 복붙하고 있었습니다. RxSwift 스타일의 `Publisher+SinkWith` 구현을 이식해 이 보일러플레이트를 걷어냈습니다.

이름을 붙이자면 RxSwift 6의 withUnretained 패턴입니다. `subscribe(with:)`를 Combine의 `sink(with:)`로 그대로 옮긴 것입니다. `[weak self]`와 guard를 확장 안에 가두고, 호출부에는 살아 있음이 보장된 `owner`를 파라미터로 넘깁니다. 메모리 동작은 바뀌지 않습니다. 여전히 weak 캡처에 guard고, 문법만 줄었지 참조 관계는 그대로입니다.

---

## 문제 - 모든 sink와 Task마다 반복되는 코드

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

이 코드는 모든 ViewModel과 VC가 매 sink마다, 매 Task마다 반복합니다. 사람이 지키는 규칙이라 언젠가 빠뜨립니다. `ManagedTask`가 만들어진 이유와 같은 부류의 문제입니다.

---

## 해법

### Publisher+SinkWith

[`Publisher+SinkWith.swift`](../../Projects/Core/CoreDesignSystem/Sources/Extensions/Publisher+SinkWith.swift)에 CoreDesignSystem의 확장으로 넣었습니다.

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

`Failure == Never` 전용으로 만든 이유가 있습니다. 이 앱은 에러를 Combine completion으로 흘리지 않고 상태나 이벤트 Subject로 전달합니다. 그래서 모든 Publisher가 `Failure == Never`고 `receiveCompletion`을 받는 오버로드를 만들 필요가 없었습니다. RxSwift의 `subscribe(with:)`에 `onError:`가 있는 것은 Rx 스트림이 에러로 끝날 수 있기 때문인데, 이 앱에는 그 경우 자체가 없습니다.

### ManagedTask의 owner 오버로드

같은 규칙을 Task에도 적용했습니다.

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

onError와 operation 양쪽 모두 owner를 weak로 잡아 넘깁니다. non-owner `start`에 위임하므로 `generation` 번호나 취소 침묵 같은 기존 규칙은 하나도 바뀌지 않습니다.

---

## 출처 - RxSwift 6의 withUnretained

| 이름 | 출처 | 죽었을 때 |
|---|---|---|
| `subscribe(with: obj, onNext:onError:...)` | RxSwift 6 (2021) | 핸들러 스킵 |
| `withUnretained(_:)` 연산자 | RxSwift 6 -> `Observable<(Object, Element)>` | 스트림 complete |
| `withUnretained` | CombineExt (Combine 포팅) | 스킵/complete |
| `sink(with:)` | 이 레포 | 스킵 (`guard let object else { return }`) |

```swift
// RxSwift                                    // Combine (이 레포)
observable                                    publisher
    .subscribe(with: self) { owner, v in          .sink(with: self, in: &bag) { owner, v in
        owner.handle(v)                               owner.handle(v)
    }                                             }
    .disposed(by: disposeBag)
```

`subscribe`와 `sink`, `disposeBag`과 `cancellables`, `disposed(by:)`와 `store(in:)`이 짝을 이룹니다. 이름만 다르고 동작 규칙은 같습니다. `sink(with:)`는 RxSwift `subscribe(with:)`를 Combine으로 그대로 옮긴 것입니다. RxSwift에는 스트림 중간에서 객체와 값의 튜플로 바꿔 주는 `withUnretained` 연산자도 따로 있는데(객체가 해제되면 스트림이 종료됩니다), 그 형태는 가져오지 않았습니다.

`ManagedTask(with:)`는 RxSwift 범위 밖입니다. Task는 RxSwift가 아니라 Swift 구조적 동시성입니다. owner를 주입한다는 같은 아이디어를 RxSwift가 다루지 않는 Task 클로저까지 넓힌 것이 이 이식의 확장분입니다.

---

## Before와 After (SearchUserViewModel 실물)

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

owner로 바뀌는 것은 self 멤버뿐입니다. 클로저 밖의 지역 변수인 `query`나, 취소 후 반영을 막는 `guard !Task.isCancelled`는 그대로 유지됩니다.

---

## 왜 Swift 6 strict concurrency에서 컴파일되나

`Owner: AnyObject`는 Sendable이 아닙니다. 그런데도 제네릭 오버로드가 통과합니다.

`ManagedTask`가 `@MainActor`이고 `operation`이 `@MainActor (Owner) async throws -> Void`입니다. owner를 만지는 클로저가 전부 MainActor에 격리돼 있다는 뜻입니다. `start`의 `Task { }`도 `@MainActor` 컨텍스트에서 생성되므로 MainActor 실행자를 물려받아 operation이 메인에서 돕니다.

따라서 Sendable이 아닌 `owner`가 격리 경계를 넘는 일이 없습니다. `[weak owner]`로 캡처해서 MainActor 안에서만 씁니다. Swift 6이 Sendable을 요구하는 것은 값이 액터 사이를 건널 때뿐이라 여기서는 그 요구가 발생하지 않습니다.

관건은 `operation`의 `@MainActor`입니다. 이게 없거나 `Task.detached`였다면 Sendable이 아닌 owner가 다른 격리 영역으로 넘어가게 되어 컴파일 에러가 났을 것입니다.

`sink(with:)`는 더 단순합니다. Combine `sink(receiveValue:)`를 감싼 것뿐이고 `object` 캡처는 격리를 넘지 않는 평범한 캡처라 Sendable 요구가 없습니다.

---

## 바뀌지 않는 것

메모리 동작은 그대로입니다. 여전히 `[weak owner]`에 guard고, owner는 클로저가 실행되는 동안만 강참조로 잡혔다 풀립니다. `guard let self`와 완전히 같습니다. 순환 참조도 없습니다. 취소와 `generation` 방어도 non-owner `start`에 위임하므로 그대로입니다.

문법이 줄었을 뿐 새로운 수명 관리 방식이 아닙니다. `[weak self]`가 사라진 게 아니라 API 안쪽으로 이사한 것입니다.

---

## 어디에 쓰고 어디에 안 쓰나

**잘 맞는 곳.** `sink`와 Task operation, onError처럼 반환값이 없는 마지막 단계의 클로저입니다. owner가 해제됐으면 그냥 건너뛴다는 처리로 충분합니다.

**안 맞는 곳.** `filter`처럼 값을 돌려주는 연산자입니다. owner가 해제됐을 때 true를 반환할지 false를 반환할지가 정해지지 않습니다. 그래서 `.filter { [weak self] in self?.paginator.hasNextPage ?? false }` 한 곳은 일부러 바꾸지 않았습니다. `?? false`가 그 답을 이미 코드로 보여 줍니다.

이식 결과는 sink 14곳에 ManagedTask 6곳, 모두 20곳 전환입니다. 남은 `[weak self]` 4곳은 전부 sink나 Task가 아닌 UIKit 콜백입니다. DiffableDataSource cellProvider, `textFieldShouldSearch`, 알럿 액션, 그리고 위의 filter 하나입니다.

덧붙이면, 클로저가 self를 캡처하는 대신 파라미터로 전달받는 방향은 Apple API에도 있습니다. iOS 17의 `registerForTraitChanges(_:handler:)`가 핸들러 첫 인자로 `(self: Self, _)`를 넘겨주는 것이 같은 발상입니다.

---

## 참고 자료

**공식 문서/참조 구현**
- [Publisher.sink(receiveValue:) - Apple Developer Documentation](https://developer.apple.com/documentation/combine/publisher/sink(receivevalue:)) - 감싸는 대상의 원형
- [SE-0302 - Sendable and @Sendable closures](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md) - Sendable 요구가 경계를 넘을 때만 발생하는 근거
- [SE-0316 - Global actors (@MainActor)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md) - owner가 격리 안에 머무는 장치
- [RxSwift 6 - subscribe(with:)/withUnretained](https://github.com/ReactiveX/RxSwift) - 원조 API (RxSwift 6.0, 2021)
- [CombineExt - withUnretained](https://github.com/CombineCommunity/CombineExt) - Combine 포팅의 선례

**이 레포의 실물 코드**
- [`Publisher+SinkWith.swift`](../../Projects/Core/CoreDesignSystem/Sources/Extensions/Publisher+SinkWith.swift) - `Failure == Never` 전용 sink(with:) 2형
- [`ManagedTask.swift`](../../Projects/Core/CoreDesignSystem/Sources/Base/ManagedTask.swift) - replace(with:)/runIfIdle(with:) owner 오버로드

**관련 노트**: [managedtask](managedtask.md) - ManagedTask의 태생 (unstructured Task의 취소 규칙 5종)
