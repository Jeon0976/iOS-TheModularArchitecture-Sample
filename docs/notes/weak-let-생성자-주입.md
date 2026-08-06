
# actions를 private weak let으로 - 생성자 주입과 두 개의 순환

> 2026-07-15, 3개 피처의 actions 주입을 정리하며 쓴 노트.
> 관련 소스: [ProfileViewModel.swift](../../Projects/Feature/FeatureProfile/Sources/Presentation/ProfileViewModel.swift) / [SearchUserViewModel.swift](../../Projects/Feature/FeatureSearch/Sources/Presentation/SearchUserViewModel.swift) / [LoginViewModel.swift](../../Projects/Feature/FeatureAuth/Sources/Presentation/LoginViewModel.swift)

`actions`를 `private weak let`에 생성자 주입으로 바꿨습니다. 세 가지가 걸렸습니다. 왜 이 조합인가, `weak let`이 되긴 하는가, 프로퍼티 주입과 생성자 주입 중 여기서는 왜 생성자 주입인가.

`actions`는 App이 생성 시점에 한 번 꽂아주고 그 뒤로 바뀌지 않습니다. 캡슐화를 위한 `private`, 불변 바인딩을 위한 `let`, 순환 회피를 위한 `weak`가 전부 맞아떨어집니다. 값을 넣는 통로는 init 하나로 좁혔습니다.

`weak let`은 이 툴체인(Swift 6.3.2)에서 실제로 컴파일됩니다. 바인딩은 불변이지만 대상이 해제되면 ARC가 nil로 만듭니다.

여기서 흔한 오해를 하나 짚고 갑니다. weak는 retain 순환을 풀고 프로퍼티 주입은 생성 순환을 풉니다. 둘은 다른 층위의 문제고, 이 코드엔 생성 순환이 없어서 생성자 주입이 깔끔하게 성립했습니다.

---

## weak let - 불변 바인딩과 ARC nil-zeroing

`private weak let actions: XxxCoordinatorActions?`에서 세 수식어가 각자 다른 일을 합니다.

`weak`는 참조 강도를 정합니다. `actions`를 강하게 잡지 않아 back-reference가 retain 순환을 만들지 않습니다. 대상이 해제되면 이 참조는 자동으로 nil이 됩니다.

`let`은 바인딩을 고정합니다. 이 프로퍼티가 어느 객체를 가리키는지를 한 번 정하면 못 바꿉니다.

`private`는 가시성을 좁힙니다. 선언 타입과 같은 파일의 확장 밖에서는 이름 자체가 안 보입니다.

여기서 구분이 하나 필요합니다. `let`이 동결하는 것은 어느 객체를 가리키느냐는 바인딩이지, 그 대상이 아직 살아 있느냐는 관찰값이 아닙니다. 그래서 `weak let`이어도 대상이 죽으면 관찰값은 nil로 바뀝니다. 이 두 축이 직교한다는 점이 `weak let`이 성립하는 이유의 전부입니다.

실측으로 확인했습니다. 툴체인 Swift 6.3.2, `-swift-version 6`, arm64 시뮬레이터 기준입니다.

- `private weak let x: T?`에 init 대입은 `-typecheck` exit 0
- `weak`를 non-optional에 붙이면 "'weak' variable should have optional type" 에러가 납니다. `weak let`은 반드시 Optional이어야 합니다
- 마지막 강한 참조를 nil로 놓은 뒤 `weak let`의 관찰값이 nil로 zeroing되는 것을 precondition 통과로 확인했습니다. `alive: true, zeroedToNil: true`

근거는 [SE-0481 `weak let`](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0481-weak-let.md)입니다. 제안서 status 필드 원문 기준으로 Implemented (Swift 6.3)입니다. 그 이전에는 `weak`가 mutable 변수를 강제했습니다.

zeroing이 사이드테이블에서 어떻게 일어나는지, Sendable 재설계에서 `weak var`에 대한 `@unchecked` 강제가 왜 사라졌는지, strong과 unowned와 weak의 `let` 대비, 클로저 캡처 불변화 플래그 같은 언어 이론 축은 별도 주제라 여기서 다루지 않습니다. 이 문서는 왜 이 코드 조직에서 이 패턴을 쓰는지, DI 아키텍처 축만 봅니다.

---

## 프로퍼티 주입과 생성자 주입

리팩터 전에는 세 ViewModel의 주입 방식이 엇갈려 있었습니다. `searchUsersUseCase`나 `fetchProfileUseCase` 같은 useCase류는 처음부터 생성자 주입이었는데, `actions`만 프로퍼티 주입이었습니다. 조립측에서 `viewModel.actions = actions`로 사후 대입하는 방식으로, Clean 아키텍처 이식 과정에서 남은 흔적입니다.

이 불일치가 두 가지를 낳습니다.

**nil-창.** 프로퍼티 주입은 객체 생성 완료부터 actions 대입까지 사이에 `actions == nil`인 유효하지 않은 상태가 존재합니다. 그사이 `actions`를 쓰는 코드가 돌면 조용히 아무 일도 일어나지 않습니다. 게다가 조립측에서 대입 한 줄을 깜빡하면 컴파일은 통과하고 런타임에 무력화됩니다.

**캡슐화 누수.** 프로퍼티 주입이 가능하려면 setter가 외부에 열려 있어야 합니다. `var`이면서 비-private이어야 하니 아무나 나중에 갈아끼울 수 있는 표면이 남습니다.

생성자 주입으로 바꾸면 셋이 해결됩니다. 객체가 존재하는 모든 순간 `actions`가 이미 확정돼 nil-창이 사라지고, 주입을 깜빡하면 컴파일 에러라 실수가 불가능하며, 이미 생성자 주입 중인 `useCase`와 방식이 일관됩니다.

생성자 주입을 강제하는 것은 `let`이고 `private`는 그 위에 캡슐화를 더합니다. 사후 대입을 막는 것은 불변성입니다. 실제로 비-private인 `internal weak let`이어도 외부 대입은 `cannot assign to property: 'actions' is a 'let' constant`로 막힙니다. `private`는 여기에 이름 은닉을 더할 뿐입니다. 읽기조차 `'actions' is inaccessible due to 'private' protection level`로 막힙니다. 값을 넣는 통로가 init 파라미터 하나로 좁혀지는 효과는 이 둘의 합이지만, 강제의 뿌리는 `let`입니다.

---

## 두 개의 순환

여기가 이 문서의 핵심입니다. "weak라서 프로퍼티 주입을 써야 하는 것 아니냐"는 오해를 교정합니다. 순환은 두 종류가 있고 각각 해결 도구가 다릅니다.

| 축 | retain 순환 | 생성 순환 (chicken-egg) |
|---|---|---|
| 정체 | 런타임 메모리 문제 | 초기화 순서 문제 |
| 증상 | A와 B가 서로 strong -> 강한참조 카운트가 0이 안 됨 -> 둘 다 해제 안 됨(누수) | A의 init이 B를 요구하고 B의 init이 A를 요구 -> "누가 먼저 존재하나"가 성립 안 함 |
| 해결 도구 | 참조 강도 - 한쪽을 `weak`나 `unowned`로 | 주입 시점 - 한쪽을 부분 생성 후 프로퍼티 주입(2단계 초기화) |
| weak가 푸나 | 예 | 아니오. weak로 바꿔도 "생성 시점에 상대가 아직 없다"는 그대로입니다 |

두 문제가 직교한다는 게 요점입니다. `weak`는 메모리 강도만 건드리고 존재 순서는 못 풉니다. 반대로 프로퍼티 주입은 존재 순서를 풀지만 메모리 강도와는 무관합니다.

그래서 경계가 하나 생깁니다. 생성 순환이 실재한다면 순수 생성자 주입만으로는 못 풀고 한쪽에 프로퍼티 주입이 필요해질 수 있습니다. `private weak let`에 생성자 주입을 붙이는 이 패턴은 생성 순환이 없는 경우에만 성립합니다.

이 코드에는 생성 순환이 없습니다. GitSearch의 배선 방향은 단방향입니다. App이 `actions`(Coordinator 구현)와 coordinator를 먼저 만들고 그 `actions`를 팩토리에 넘깁니다. 팩토리인 `FeatureSearchServingImpl.makeSearchEntryViewController(actions:)`는 넘어온 `actions`를 ViewModel init에 그대로 전달할 뿐 ViewModel이 `actions`를 만들지 않습니다. 부모가 자식을 만들면서 이미 존재하는 객체를 넘겨주므로 App과 VM이 서로를 생성 시점에 요구하는 닭과 달걀 상황이 애초에 생기지 않습니다.

정리하면 retain 순환을 막으려고 `weak`가 필요했고, 생성 순환은 없으므로 프로퍼티 주입이 필요 없어 생성자 주입이 깔끔하게 성립했습니다. 두 결정은 서로 독립입니다.

---

## 리팩터 실물 - 3피처 actions

세 ViewModel(Search, Auth, Profile)이 같은 패턴을 공유합니다. `private weak let actions: XxxCoordinatorActions?` 선언에 init 파라미터 주입, 그리고 `self.actions = actions` 저장입니다. 조립측은 프로퍼티 대입을 삭제하고 init 인자로 전달하도록 바꿨습니다.

### Before (프로퍼티 주입)

```swift
// ViewModel
weak var actions: FeatureSearchCoordinatorActions?

// 조립측 (FeatureSearchServingImpl)
let viewModel = SearchUserViewModel(
    searchUsersUseCase: searchUsersUseCase,
    fetchProfileUseCase: fetchProfileUseCase
)
viewModel.actions = actions        // 사후 대입 - nil-창 + 깜빡 위험
```

### After (private weak let + 생성자 주입)

```swift
// ViewModel - SearchUserViewModel.swift
// weak = 순환 참조 회피, let = 재배선 불가.
// 불변 바인딩이어도 대상이 죽으면 ARC가 nil로 지운다.
private weak let actions: FeatureSearchCoordinatorActions?

init(
    searchUsersUseCase: any SearchUsersUseCase,
    fetchProfileUseCase: any FetchProfileUseCase,
    actions: FeatureSearchCoordinatorActions?
) {
    // ...
    self.actions = actions
}

// 조립측 - FeatureSearchServingImpl.swift
public func makeSearchEntryViewController(
    actions: FeatureSearchCoordinatorActions?      // App이 먼저 만들어 넘겨줌
) -> UIViewController {
    let viewModel = SearchUserViewModel(
        searchUsersUseCase: searchUsersUseCase,
        fetchProfileUseCase: fetchProfileUseCase,
        actions: actions                     // 생성자 주입으로 전환
    )
    return SearchUserViewController(viewModel: viewModel)
}
```

소비처는 그대로 위임만 합니다.

- Search: `owner.actions?.searchNeedsLogin()` (로그인 화면 복귀 요청)
- Auth: `owner.actions?.authDidLogin()` (토큰 교환 성공 후) - `LoginViewModel.swift`
- Profile: `actions?.profileDidLogout()` (로그아웃 3단계 중 화면 전환) - `ProfileViewModel.swift`

`XxxCoordinatorActions`는 `AnyObject` 계열 위임 프로토콜이라 weak 캡처 대상이 됩니다. Clean의 `SearchUserCoordinator`가 화면 push 팩토리와 `FeatureSearchCoordinatorActions`(App 구현) 두 계약으로 증발한 자리입니다.

---

## 왜 이게 개선인가

`let`으로 바인딩을 고정해 "actions가 중간에 바뀌었나"라는 상태 공간 자체를 없앴습니다. 추론이 단순해집니다. 생성자 주입이라 객체가 존재하는 모든 순간 actions가 주입은 돼 있고, 주입을 깜빡하면 컴파일 에러입니다. `private`와 `let` 조합이라 외부에서 갈아끼울 표면이 없고, `useCase`와 방식이 같아졌습니다. `weak`로 자식에서 부모로 가는 역참조를 끊었으니 retain 순환도 안전합니다.

다만 nil-창 제거는 init 시점에 한정됩니다. weak라서 런타임에는 nil이 될 수 있어 "항상 non-nil"은 아닙니다. 아래 비용 항목에서 다시 다룹니다.

### weak냐 unowned냐

부모인 App과 coordinator가 자식인 VM보다 오래 산다는 것은 앞에서 본 전제입니다. 교과서적으로는 `unowned`가 후보가 되는 상황입니다. 대상이 늘 더 오래 살면 unowned가 Optional과 zeroing 비용을 아낍니다. 그런데도 `weak`를 골랐습니다.

조기 해제를 관용하려는 선택입니다. coordinator 흐름이 재구성되거나 화면이 먼저 정리되는 경계에서 actions가 먼저 사라져도, `weak`는 조용히 nil이 되어 크래시 없이 위임을 건너뜁니다. `unowned`면 그 순간 접근이 크래시입니다. 위임 호출부가 이미 `actions?....` 옵셔널 체이닝이라 nil이어도 아무 일 없이 지나갑니다.

"부모가 더 오래 산다"는 성립하지만, 그 수명 보장을 크래시로 강제하기보다 nil로 관용하는 쪽을 택했습니다. 언어 이론이 아니라 이 아키텍처의 DI 결정입니다.

### 정직한 비용

**Optional 강제.** `weak`는 반드시 Optional이라 필수 의존성인데도 타입이 `XxxCoordinatorActions?`가 됩니다. 생성자 주입의 핵심 이점인 required를 타입으로 못 박는 일을 weak가 무력화합니다. 모든 소비처가 `actions?.`를 쓰고 컴파일러는 "항상 있음"을 정적으로 보장하지 못합니다. 툴체인 버전과 무관한 상시 비용입니다.

**런타임 비용.** weak 참조는 사이드테이블 zeroing 때문에 `unowned`보다 접근과 해제에 약간의 오버헤드가 있습니다.

**최신 Swift 요구.** `weak let`은 SE-0481이 필요합니다. 이 툴체인 6.3.2에서 확인했습니다. 구버전을 지원해야 하면 `private weak var`로 내려갑니다. 바인딩 불변성만 포기하고 생성자 주입과 캡슐화, retain 안전은 유지됩니다.

---

## 참고 자료

**공식 문서**
- [SE-0481 - `weak let`](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0481-weak-let.md) - status 필드 원문 "Implemented (Swift 6.3)". `weak let` 허용의 근거
- [Automatic Reference Counting - The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/) - weak 참조의 자동 nil-zeroing
- [Access Control - The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/) - `private`의 렉시컬 스코프 가시성

**이 레포의 실물 코드**
- [`ProfileViewModel.swift`](../../Projects/Feature/FeatureProfile/Sources/Presentation/ProfileViewModel.swift) / [`SearchUserViewModel.swift`](../../Projects/Feature/FeatureSearch/Sources/Presentation/SearchUserViewModel.swift) / [`LoginViewModel.swift`](../../Projects/Feature/FeatureAuth/Sources/Presentation/LoginViewModel.swift) - `private weak let actions` 선언/init/소비처
- [`FeatureSearchServingImpl.swift`](../../Projects/Feature/FeatureSearch/Sources/Composition/FeatureSearchServingImpl.swift) - 팩토리 시그니처/생성자 주입 전환

검증 툴체인: Apple Swift 6.3.2, `-swift-version 6`, arm64 시뮬레이터. `weak let` typecheck exit 0, 런타임 nil-zeroing 관찰.

---

## 관련 노트

- [owner 패턴](owner-패턴.md) - 호출부의 weak 캡처를 걷어내 주는 관용구. 이 노트가 보관하는 쪽의 weak라면 그쪽은 캡처하는 쪽의 weak입니다
- [swift6-sendable](swift6-sendable.md) - Sendable 경계와 weak의 관계
