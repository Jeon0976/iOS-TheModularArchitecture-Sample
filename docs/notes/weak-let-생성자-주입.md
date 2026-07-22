
# 의존성 주입과 weak let - actions를 private weak let + 생성자 주입으로, 그리고 두 개의 순환

> [!NOTE]
> 2026-07-15, 3개 피처의 actions 주입을 정리하며 쓴 학습 노트다 (노트 톤 그대로 옮김).
> 관련 소스: [ProfileViewModel.swift](../../Projects/Feature/FeatureProfile/Sources/Presentation/ProfileViewModel.swift) / [SearchUserViewModel.swift](../../Projects/Feature/FeatureSearch/Sources/Presentation/SearchUserViewModel.swift) / [LoginViewModel.swift](../../Projects/Feature/FeatureAuth/Sources/Presentation/LoginViewModel.swift)

> [!IMPORTANT]
> **다루는 질문**
> - `actions`를 왜 `private weak let` + 생성자 주입으로 바꿨나?
> - 그런데 `weak let`이 되긴 되나? (weak는 보통 var를 요구하지 않나)
> - 프로퍼티 주입과 생성자 주입, 여기선 왜 생성자 주입이 맞나?
>
> **한 줄 결론**: `actions`는 App이 생성 시점에 한 번 꽂아주고 그 뒤로 바뀌지 않는다 - 캡슐화(`private`) + 불변 바인딩(`let`) + 순환 회피(`weak`)가 전부 맞아떨어지는 `private weak let`이 답이고, 값을 넣는 통로는 init 하나로 좁혀 **생성자 주입**을 강제한다.
> - `weak let`은 이 툴체인(Swift 6.3.2)에서 실제로 컴파일된다 - 바인딩은 불변이지만 대상이 해제되면 ARC가 nil로 만든다(zeroing).
> - 흔한 오해 하나: **weak는 retain 순환을 풀고, 프로퍼티 주입은 생성 순환을 푼다.** 둘은 다른 층위의 문제고, 이 코드엔 생성 순환이 없어서 생성자 주입이 깔끔하게 성립했다.

---

## 1. TL;DR

| 질문 | 답 |
|---|---|
| 왜 `weak`? | `actions`(Coordinator)는 feature보다 오래 사는 back-reference. 자식->부모 역참조를 strong으로 잡으면 retain 순환. weak로 끊는다. |
| 왜 `let`? | 주입 후 재배선이 없다. 바인딩을 동결해 "중간에 누가 갈아끼웠나"라는 상태 공간을 제거. |
| 왜 `private`? | 이름조차 밖에서 안 보이게 해 **캡슐화**를 더한다. (생성자 주입을 *강제*하는 건 `private`가 아니라 아래 `let` - set-after-init을 막는 건 불변성이다.) |
| `weak let`이 되나? | 된다(이 툴체인 6.3.2 컴파일 확인, exit 0). 단 반드시 Optional. 언어 이론 심층(제로잉 메커니즘/버전 지형)은 이 노트 범위 밖. |
| 왜 생성자 주입? | nil-창(주입 깜빡) 제거 + 캡슐화 + 이미 생성자 주입 중인 `useCase`와 일관. |
| 두 순환? | retain 순환(런타임 메모리, weak가 해결) vs 생성 순환(닭-달걀, 주입 시점이 해결). weak는 후자를 안 푼다. |

---

## 2. weak let - 불변 바인딩 + ARC nil-zeroing

`private weak let actions: XxxCoordinatorActions?`에서 세 수식어가 각자 다른 일을 한다.

- `weak` - 참조 강도. `actions`를 강하게 잡지 않아 back-reference가 retain 순환을 만들지 않는다. 대상이 해제되면 이 참조는 자동으로 nil이 된다.
- `let` - 바인딩 불변. "이 프로퍼티가 **어느 객체를 가리키나**"를 한 번 정하면 못 바꾼다.
- `private` - 가시성. 선언 타입(및 같은 파일 확장) 밖에서는 이름 자체가 안 보인다.

**핵심 구분** - `let`이 동결하는 건 *바인딩*(어느 객체를 가리키나)이지 *관찰값*(그 대상이 아직 살아있나)이 아니다. 그래서 `weak let`이어도 대상이 죽으면 관찰값은 nil로 바뀐다. 이 두 축이 직교한다는 점이 `weak let`이 성립하는 이유의 전부다.

**컴파일/런타임 근거 (툴체인 Swift 6.3.2, `-swift-version 6`, arm64 시뮬레이터)**
- `private weak let x: T?` + init 대입은 `-typecheck` exit 0. (실측)
- `weak`를 non-optional에 붙이면 에러: "'weak' variable should have optional type" -> `weak let`은 **반드시 Optional**.
- 런타임: 마지막 강한 참조를 nil로 놓은 뒤 `weak let`의 관찰값이 nil로 zeroing됨을 precondition 통과(exit 0)로 확인. `alive: true, zeroedToNil: true`.

**SE 근거** - `weak let`을 허용한 제안은 **SE-0481 `weak let`**, 상태는 제안서 status 필드 원문 기준 **Implemented (Swift 6.3)**. 그 이전에는 `weak`가 mutable 변수(var)를 강제했다.

> [!NOTE] 언어 이론은 여기서 깊이 파지 않는다
> zeroing이 사이드테이블에서 어떻게 일어나는지, Sendable 재설계에서 `weak var`->`@unchecked` 강제가 왜 사라졌는지, strong/unowned/weak `let` 3형제 대비, 클로저 캡처 불변화 플래그 - 이 언어 이론 축은 별도 주제라 여기서는 깊이 다루지 않는다. 이 문서는 "왜 이 코드 조직에서 이 패턴을 쓰나"라는 DI 아키텍처 축만 본다.

---

## 3. 프로퍼티 주입 vs 생성자 주입

리팩터 전, 세 ViewModel의 의존성 주입 방식이 **엇갈려 있었다**.

- `useCase`류(예: `searchUsersUseCase`, `fetchProfileUseCase`) - 처음부터 **생성자 주입**.
- `actions`만 - **프로퍼티 주입**(조립측에서 `viewModel.actions = actions`로 사후 대입). Clean 아키텍처 이식 과정에서 남은 흔적이다.

이 불일치는 두 가지를 낳는다.

1. **nil-창(window of nil)** - 프로퍼티 주입은 "객체 생성 완료 ~ actions 대입" 사이에 `actions == nil`인 유효하지 않은 상태가 존재한다. 그사이 `actions`를 쓰는 코드가 돌면 조용히 아무 일도 안 일어난다. 게다가 조립측에서 대입 한 줄을 깜빡하면 컴파일은 통과하고 런타임에 무력화된다.
2. **캡슐화 누수** - 프로퍼티 주입이 가능하려면 setter가 외부에 열려 있어야 한다(`var` + 비-private). 즉 아무나 나중에 갈아끼울 수 있다는 표면적을 남긴다.

**생성자 주입의 이점** - init 파라미터로만 받으면 (a) 객체가 존재하는 모든 순간 `actions`가 이미 확정돼 nil-창이 사라지고, (b) 주입을 깜빡하면 컴파일 에러라 실수가 불가능하며, (c) 이미 생성자 주입 중인 `useCase`와 방식이 일관된다.

**생성자 주입을 강제하는 건 `let`, `private`는 그 위에 캡슐화를 더한다** - set-after-init(사후 대입)을 막는 건 **불변성(`let`)**이다. 실제로 비-private `internal weak let`이어도 외부 대입은 `cannot assign to property: 'actions' is a 'let' constant`로 막힌다 - `let`만으로 생성자 주입이 강제된다는 실측. `private`는 여기에 **이름 은닉**(`'actions' is inaccessible due to 'private' protection level` - 읽기조차 불가)을 더해 캡슐화를 완성할 뿐이다. 값을 넣는 통로가 init 파라미터 하나로 좁혀지는 효과는 이 둘의 합이되, 강제의 뿌리는 `let`이다.

---

## 4. 두 개의 순환

여기가 이 문서의 핵심이다. "weak라서 프로퍼티 주입을 써야 하는 것 아니냐"는 오해를 정면으로 교정한다. **순환은 두 종류가 있고, 각각 해결 도구가 다르다.**

| 축 | (a) retain 순환 | (b) 생성 순환 (chicken-egg) |
|---|---|---|
| 정체 | **런타임 메모리** 문제 | **초기화 순서** 문제 |
| 증상 | A<->B가 서로 strong -> 강한참조 카운트가 0이 안 됨 -> 둘 다 해제 안 됨(누수) | A의 init이 B를 요구하고 B의 init이 A를 요구 -> "누가 먼저 존재하나"가 성립 안 함 |
| 해결 도구 | **참조 강도** - 한쪽을 `weak`/`unowned`로 | **주입 시점** - 한쪽을 부분 생성 후 프로퍼티 주입(2단계 초기화) |
| weak가 푸나? | 예 | **아니오** - weak로 바꿔도 "생성 시점에 상대가 아직 없다"는 그대로 |

두 문제가 직교한다는 게 요점이다. `weak`는 위 칸(메모리 강도)만 건드리고 아래 칸(존재 순서)은 못 푼다. 반대로 프로퍼티 주입(2단계 초기화)은 아래 칸을 풀지만 위 칸과는 무관하다.

**그래서 생기는 경계** - 만약 생성 순환이 *실재*한다면 순수 생성자 주입만으로는 못 풀고 한쪽에 프로퍼티 주입(`var`)이 필요해질 수 있다. 즉 `private weak let` + 생성자 주입 패턴은 **생성 순환이 없는** 경우에만 성립한다.

**이 코드엔 생성 순환이 없다** - GitSearch에서 배선 방향은 명확히 단방향이다. App(흐름 관리자)이 `actions`(Coordinator 구현)와 coordinator를 **먼저** 만들고 그 `actions`를 팩토리에 넘긴다. 팩토리(`FeatureSearchServingImpl.makeSearchEntryViewController(actions:)`)는 넘어온 `actions`를 ViewModel init에 그대로 전달할 뿐 ViewModel이 `actions`를 만들지 않는다. 부모가 자식을 만들면서 이미 존재하는 self(계열 객체)를 넘겨주므로 "App<->VM이 서로를 생성 시점에 요구"하는 닭-달걀이 애초에 발생하지 않는다.

정리하면: **retain 순환 방지**를 위해 `weak`가 필요했고(자식->부모 역참조), **생성 순환은 없으므로** 프로퍼티 주입이 필요 없어 생성자 주입이 깔끔하게 성립했다. 두 결정은 서로 독립이다.

---

## 5. 리팩터 실물 - 3피처 actions

세 ViewModel(Search / Auth / Profile)이 동일 패턴을 공유한다: `private weak let actions: XxxCoordinatorActions?` 선언 + init 파라미터 주입 + `self.actions = actions` 저장. 조립측은 프로퍼티 대입을 삭제하고 init 인자로 전달하도록 바꿨다.

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

소비처는 그대로 위임만 한다.

- Search: `owner.actions?.searchNeedsLogin()` (로그인 화면 복귀 요청)
- Auth: `owner.actions?.authDidLogin()` (토큰 교환 성공 후) - `LoginViewModel.swift`
- Profile: `actions?.profileDidLogout()` (로그아웃 3단계 중 화면 전환) - `ProfileViewModel.swift`

`XxxCoordinatorActions`는 `AnyObject` 계열 위임 프로토콜(=weak 캡처 대상)이며, Clean의 `SearchUserCoordinator`가 "화면 push 팩토리 + `FeatureSearchCoordinatorActions`(App 구현)" 두 계약으로 증발한 자리다.

---

## 6. 왜 이게 개선인가 - weak냐 unowned냐 + 정직한 비용

**개선 요약**
- **불변 바인딩** - `let`으로 "actions가 중간에 바뀌었나"라는 상태 공간 자체를 제거. 추론이 단순해진다.
- **nil-창 제거(단, init 시점에 한정)** - 생성자 주입이라 객체가 존재하는 모든 순간 actions가 *주입은 돼 있다*. 주입 깜빡은 컴파일 에러. (다만 아래 '정직한 비용' 1번 - weak라 런타임엔 nil이 될 수 있어 "항상 non-nil"은 아니다.)
- **캡슐화** - `private` + `let`이라 외부에서 갈아끼울 표면이 없다.
- **일관성** - `useCase`와 동일하게 전부 생성자 주입.
- **retain 순환 안전** - `weak`로 자식->부모 역참조를 끊음. 대상 해제 시 ARC가 자동 zeroing.

### weak냐 unowned냐 - 언어 이론이 아니라 DI 결정이다

부모(App/coordinator)가 자식(VM)보다 오래 산다는 건 4절의 전제다 - 교과서적으로는 **`unowned`가 후보**가 되는 상황이다(대상이 늘 더 오래 살면 unowned가 Optional/zeroing 비용을 아낀다). 그런데도 `weak`를 고른 근거:
- **조기 해제를 관용**하려는 것. coordinator 흐름이 재구성되거나 화면이 먼저 정리되는 경계에서 actions가 먼저 사라져도, `weak`는 조용히 nil이 되어 **크래시 없이** 위임을 건너뛴다. `unowned`면 그 순간 접근이 **크래시**다.
- 위임 호출부가 이미 `actions?....`(옵셔널 체이닝)이라 nil이어도 아무 일 없이 지나간다.

즉 "부모가 더 오래 산다"는 성립하지만 그 수명 보장을 **크래시로 강제(unowned)하기보다 nil로 관용(weak)** 하는 안전 우선의 선택이다. 이건 순수 언어 이론이 아니라 이 아키텍처의 DI 결정이다.

### 정직한 비용

1. **Optional 강제 비용** - `weak`는 반드시 Optional이라, 필수 의존성인데도 타입이 `XxxCoordinatorActions?`가 된다. 생성자 주입의 핵심 이점인 "**required를 타입으로 못 박기**"를 weak가 무력화한다 - 모든 소비처가 `actions?.`를 쓰고, 컴파일러는 "항상 있음"을 정적으로 보장 못 한다. **툴체인 버전과 무관한 상시 비용**이다.
2. **unowned 대비 런타임 비용** - weak 참조는 사이드테이블 zeroing 때문에 `unowned`보다 접근/해제에 약간의 오버헤드가 있다.
3. **최신 Swift 요구** - `weak let`은 SE-0481(이 툴체인 6.3.2에서 확인)이 필요하다. 구버전 지원 시 fallback은 `private weak var`(바인딩 불변성만 포기; 생성자 주입/캡슐화/retain 안전은 유지). 즉 저하돼도 우아하다.

---

## 7. 참고 자료

**공식 문서**
- [SE-0481 - `weak let`](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0481-weak-let.md) - status 필드 원문 "Implemented (Swift 6.3)". `weak let` 허용의 근거.
- [Automatic Reference Counting - The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/) - weak 참조의 자동 nil-zeroing.
- [Access Control - The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/) - `private`의 렉시컬 스코프 가시성.

**이 레포의 실물 코드**
- [`ProfileViewModel.swift`](../../Projects/Feature/FeatureProfile/Sources/Presentation/ProfileViewModel.swift) / [`SearchUserViewModel.swift`](../../Projects/Feature/FeatureSearch/Sources/Presentation/SearchUserViewModel.swift) / [`LoginViewModel.swift`](../../Projects/Feature/FeatureAuth/Sources/Presentation/LoginViewModel.swift) - `private weak let actions` 선언/init/소비처
- [`FeatureSearchServingImpl.swift`](../../Projects/Feature/FeatureSearch/Sources/Composition/FeatureSearchServingImpl.swift) - 팩토리 시그니처/생성자 주입 전환

검증 툴체인: Apple Swift 6.3.2, `-swift-version 6`, arm64 시뮬레이터. `weak let` typecheck exit 0, 런타임 nil-zeroing 관찰.

---

## 8. 관련 노트

- [owner-패턴](owner-패턴.md) - 호출부의 weak 캡처를 걷어내 주는 관용구 (이 노트가 "보관"의 weak라면, 그쪽은 "캡처"의 weak)
- [swift6-sendable](swift6-sendable.md) - Sendable 경계와 weak의 관계
