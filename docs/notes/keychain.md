# Keychain - KeychainTokenStorage 분석과 자격증명 저장의 규칙

> 2026-07-11, CoreStorage를 구현하며 정리한 노트.
> 관련 소스: [KeychainTokenStorage.swift](../../Projects/Core/CoreStorage/Sources/KeychainTokenStorage.swift) / [TokenStorage.swift](../../Projects/Core/CoreStorage/Sources/TokenStorage.swift)

`KeychainTokenStorage` 68줄을 뜯어보며 나온 질문들을 정리했습니다. 왜 UserDefaults가 아니라 Keychain인가, `kSecClassGenericPassword`와 service/account는 무엇인가, delete 후 add는 왜인가, 그리고 접근성 상수 한 줄에 담긴 보안 결정은 무엇인가.

Keychain은 암호화되는 UserDefaults가 아니라 자격증명을 위한 시스템 서비스입니다. 설계의 핵심도 저장 코드가 아니라 정책 선언에 있습니다. 이 아이템을 언제 읽을 수 있고 어디까지 따라가는지를 상수 하나로 선언하면 나머지는 OS와 Secure Enclave가 맡습니다.

이 레포가 고른 `AfterFirstUnlockThisDeviceOnly`는 백그라운드 네트워킹은 되게 하고 기기를 옮기면 재로그인을 강제하는, 토큰의 표준 답입니다.

---

## 실물 뜯어보기

### UserDefaults에서 Keychain으로

전편인 Clean 버전은 토큰을 UserDefaults에 저장했습니다. 이 레포는 미루지 않고 바꿨습니다. 근거는 저장 형식의 차이 그 자체입니다.

| | UserDefaults | Keychain |
|---|---|---|
| 실체 | 앱 샌드박스의 평문 plist | 시스템 보안 데이터베이스 (암호화, SEP 연계) |
| 읽히는 경로 | 탈옥, 로컬 백업 추출, 포렌식 도구 | 기기 잠금/정책을 뚫어야 함 |
| 삭제 시점 | 앱 삭제와 함께 | 앱 삭제 후에도 잔존하는 것이 통상 동작 (공식 보장은 아님) |
| 용도 | 설정값, 플래그 | 자격증명 (토큰/비밀번호/키) |

여기서 "앱을 지웠는데 로그인이 살아 있다"는 현상이 나옵니다. 키체인 잔존은 문서화된 보장이 아니라 관찰되는 일반적인 동작입니다. 재설치를 초기화로 기대하는 사용자와 어긋날 수 있으니, 실무에서는 첫 실행 플래그를 UserDefaults에 두고 감지해 키체인을 명시적으로 비웁니다. 두 저장소의 삭제 시점 차이를 역이용하는 방법입니다.

### 아이템 식별 - 기본키 역할의 baseQuery

```swift
private var baseQuery: [String: Any] {
    [
        kSecClass as String: kSecClassGenericPassword,     // 아이템 클래스
        kSecAttrService as String: service,                // "com.seonghun.gitsearchmicro"
        kSecAttrAccount as String: account,                // "github.access_token"
    ]
}
```

키체인 아이템 클래스는 5종입니다. `genericPassword`는 범용 비밀로 API 토큰의 관례적 자리고, `internetPassword`는 서버와 프로토콜 메타를 포함하며, 나머지는 `certificate`, `key`, `identity`입니다.

genericPassword의 유일성은 service와 account의 조합이 결정합니다. 같은 조합으로 add하면 `errSecDuplicateItem`이 납니다. store에서 delete를 먼저 하는 이유이기도 합니다.

init 파라미터로 열어 둔 덕에 데모 앱이 `account: "demo.auth.token"`으로 본 앱과 다른 슬롯을 쓸 수 있습니다. 실제로 [FeatureAuthDemoApp](../../Projects/Feature/FeatureAuth/Demo/Sources/FeatureAuthDemoApp.swift)이 그렇게 씁니다.

### store - delete 후 add, 그리고 정책 선언

```swift
public func store(_ token: String) {
    SecItemDelete(baseQuery as CFDictionary)              // 있으면 지우고
    var query = baseQuery
    query[kSecValueData as String] = Data(token.utf8)     // 값은 항상 Data
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(query as CFDictionary, nil)                // 새로 넣는다
}
```

SecItemUpdate 경로는 존재를 확인하고 분기해야 해서 코드가 배로 늘어납니다. 토큰 저장은 로그인 순간뿐인 저빈도 작업이라 단순함을 샀습니다. 주석에도 명시한 결정입니다. delete와 add 사이의 이론상 빈틈은 로그인 플로우 특성상 동시 store가 없어 실질적으로 무해합니다.

값은 항상 Data입니다. `Data(token.utf8)`이 가장 원초적인 직렬화의 실물입니다.

접근성은 add 시점에 선언합니다. 저장 후에 바꾸려면 아이템을 다시 써야 합니다. 정책은 저장할 때 정해집니다.

### 접근성 스펙트럼 - 진짜 보안 설계는 이 한 줄

`kSecAttrAccessible`의 선택지는 두 축입니다. 언제 읽을 수 있나, 그리고 기기를 따라가나.

| 언제 축 | 의미 | 어울리는 것 |
|---|---|---|
| `WhenUnlocked` | 화면이 잠기면 접근 불가 | 가장 엄격 - 포그라운드 전용 데이터 |
| `AfterFirstUnlock` | 재부팅 후 첫 잠금해제 이후엔 항상 접근 | 백그라운드 네트워킹이 필요한 토큰의 표준 |
| `WhenPasscodeSetThisDeviceOnly` | 패스코드 설정 기기에서만 존재 가능 | 최고 민감 (패스코드 해제 시 아이템 삭제) |

| 기기 축 | 의미 |
|---|---|
| (기본) | 암호화 백업/기기 이전에 포함 |
| `ThisDeviceOnly` | 백업/이전 제외 - 새 기기 = 재로그인 강제 |

이 레포의 `AfterFirstUnlockThisDeviceOnly`는 잠금 중 백그라운드 요청은 되게 하고, 기기가 바뀌면 자격증명이 따라가지 않게 합니다. 접근성 선택은 보안 강도를 높이는 문제가 아니라 앱의 동작 요구에 맞추는 문제입니다.

막히는 메커니즘도 알아 둘 만합니다. 화면이 잠기는 순간 해당 보호 클래스의 복호화 키가 메모리에서 내려갑니다. 잠금 중 `SecItemCopyMatching`은 `errSecInteractionNotAllowed`로 실패하고, 앱 입장에서는 토큰이 없으니 로그아웃된 것처럼 보이는 침묵 실패가 됩니다. 백그라운드 fetch, 푸시를 받고 깨어난 처리, 잠긴 채 도는 background URLSession이 전부 이 실패를 겪는 지점입니다.

**정직하게 짚으면 이 앱은 지금 WhenUnlocked여도 안 터집니다.** GitSearch에는 현재 백그라운드 네트워킹이 없습니다. `WhenUnlocked`로 저장해도 당장은 아무 문제가 없고 보안 강도는 오히려 한 단계 높습니다. 잠기면 즉시 재보호되기 때문입니다. 그래도 AfterFirstUnlock을 쓴 이유는 이게 나중에 터지는 종류의 함정이어서입니다. 백그라운드 기능을 추가하는 순간 가끔씩만 로그인이 풀리는, 재현하기 어려운 버그로 돌아옵니다. 접근성은 저장 시점에 고정되므로 나중에 조용히 어긋나는 것보다 처음부터 토큰의 관례적 표준을 쓰는 편이 낫다고 봤습니다. 트레이드오프가 있는 선택이지 공짜가 아닙니다.

ThisDeviceOnly의 논거를 토큰 입장에서 다시 쓰면 이렇습니다. 토큰이 백업을 타고 다른 기기로 복원되면 그 자체가 유출이고, 어차피 재로그인하면 재발급되는 값이라 백업에 태울 이유가 없습니다. 잃어도 다시 만들 수 있는 자격증명은 기기에 묶습니다.

### retrieve와 clear, 그리고 생략된 OSStatus

```swift
let status = SecItemCopyMatching(query as CFDictionary, &result)
guard status == errSecSuccess, let data = result as? Data else { return nil }
```

retrieve만 status를 확인하고 store와 clear는 반환값인 OSStatus를 버립니다. 교보재로서의 단순화입니다. 실무라면 이렇게 하면 안 됩니다.

store의 `SecItemAdd` 실패를 침묵하면 로그인했는데 다음 실행에 풀려 있는 미스터리가 됩니다. 디스크 문제나 마이그레이션 직후, 잠금 상태처럼 드문 경우지만 최소한 로깅은 해야 하고 이상적으로는 throws로 전파해야 합니다.

**침묵 실패를 실제로 재현해 봤습니다(2026-07-12, 이 코드베이스).** 호스트 없는 테스트 타겟에서 `store()`를 부르면 에러 없이 조용히 지나가고 `retrieve()`가 nil을 줍니다. OSStatus를 직접 찍어보고서야 `SecItemAdd`가 -34018(`errSecMissingEntitlement`)을 반환한 것이 원인으로 드러났습니다. 같은 코드가 호스트인 Demo 앱을 주입한 타겟에서는 4개 모두 통과했습니다. OSStatus를 버리면 원인 진단이 불가능해진다는 것과, 키체인 테스트에 호스트가 필수라는 것을 동시에 보여 준 실험입니다. CoreStorage의 Tests와 HostedTests를 분리한 근거이기도 합니다.

대표 상태값은 성공인 `errSecSuccess`(0), retrieve에서는 정상 경로인 `errSecItemNotFound`(-25300), delete-first가 회피하는 `errSecDuplicateItem`(-25299), 접근성 위반 시점의 접근인 `errSecInteractionNotAllowed`(-25308)입니다.

### Sendable과 동기 API

Sendable이 성립하는 근거는 세 가집니다. 저장 프로퍼티가 전부 let이고, 실제 상태는 시스템인 Keychain이 보유하며, SecItem API 자체가 스레드 안전합니다. class여도 상태의 위치를 물으면 증명이 성립하는 사례입니다.

동기 API로 둔 이유는 키체인 조회가 로컬이라 빠르기 때문입니다. 덕분에 `AuthTokenInterceptor.adapt`가 동기로 남았고 prepareRequest 전체를 네트워크 없이 테스트할 수 있게 됐습니다. 저장소의 동기와 비동기 결정이 파이프라인 설계까지 흐르는 맞물림입니다.

---

## 사용 설명서 - 함수 4개와 상수 사전

키체인 API는 함수 4개가 전부입니다. 대신 모든 것이 딕셔너리로 표현되기 때문에, 실력은 함수가 아니라 딕셔너리에 어떤 키를 넣을 줄 아는가에서 갈립니다.

### CRUD 4함수

| 함수 | 역할 | 형태 |
|---|---|---|
| `SecItemAdd(query, &result)` | 생성 | query에 클래스+식별자+값+정책을 담아 추가. 같은 식별자가 있으면 `errSecDuplicateItem` |
| `SecItemCopyMatching(query, &result)` | 조회 | query로 찾고, `kSecReturn~` 키로 무엇을 돌려줄지 지정 |
| `SecItemUpdate(query, attributesToUpdate)` | 수정 | 첫 인자로 찾고, 둘째 딕셔너리의 키만 갈아끼움 |
| `SecItemDelete(query)` | 삭제 | query에 매칭되는 것 전부 삭제 |

저장에는 두 가지 패턴이 있습니다.

```swift
// 패턴 A: delete -> add (이 레포 방식 - 단순, 저빈도 쓰기에 적합)
SecItemDelete(baseQuery as CFDictionary)
var query = baseQuery
query[kSecValueData as String] = Data(token.utf8)
query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
SecItemAdd(query as CFDictionary, nil)

// 패턴 B: upsert (add 시도 -> 중복이면 update - 고빈도 쓰기/아이템 속성 보존이 필요할 때)
var addQuery = baseQuery
addQuery[kSecValueData as String] = data
let status = SecItemAdd(addQuery as CFDictionary, nil)
if status == errSecDuplicateItem {
    SecItemUpdate(baseQuery as CFDictionary,
                  [kSecValueData as String: data] as CFDictionary)
}
```

조회는 값만 받을 수도, 속성까지 받을 수도, 전체를 나열할 수도 있습니다.

```swift
// 값(Data) 하나만 - 이 레포 방식
var query = baseQuery
query[kSecReturnData as String] = true
query[kSecMatchLimit as String] = kSecMatchLimitOne
var result: AnyObject?
let status = SecItemCopyMatching(query as CFDictionary, &result)
// status == errSecSuccess -> result as? Data / errSecItemNotFound -> 저장된 적 없음(정상 경로)

// 이 앱의 genericPassword 전부 나열 - 디버깅/마이그레이션/"계정 목록"에
var listQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecReturnAttributes as String: true,          // 값 말고 속성(account, 생성일...)을
    kSecMatchLimit as String: kSecMatchLimitAll,   // 전부
]
// result가 String: Any 배열로 온다
```

삭제도 하나만 지우거나 전체를 청소할 수 있습니다.

```swift
SecItemDelete(baseQuery as CFDictionary)                       // service+account 매칭 하나
SecItemDelete([kSecClass as String: kSecClassGenericPassword]  // 이 앱의 genericPassword 전부
              as CFDictionary)                                 // - "재설치 시 초기화" 관례가 이것
```

### 쿼리 딕셔너리 키 사전

딕셔너리에 들어가는 키는 네 가지 역할로 나뉩니다. 식별자인지, 값인지, 정책인지, 반환 지시인지를 구분하면 어떤 조합도 읽을 수 있습니다.

**클래스 - 무엇을 저장하나**

| 값 | 정체 | 어디서 쓰나 |
|---|---|---|
| `kSecClassGenericPassword` | 범용 비밀 (아무 Data) | API 토큰, 앱 자체 비밀번호, 암호화 키 재료. 앱 개발의 90%고 이 레포가 이것 |
| `kSecClassInternetPassword` | 서버 자격증명 (server/protocol/port 메타 포함) | 특정 서버 로그인 저장, 여러 계정과 여러 서버 관리 |
| `kSecClassCertificate` | 인증서 (공개 부분) | 서버 인증서 피닝 재료, 신뢰 평가 |
| `kSecClassKey` | 암호화 키 | SecKey 저장 - 직접 암호화 구현 시 |
| `kSecClassIdentity` | 인증서 + 개인키 쌍 | mTLS(클라이언트 인증서 인증), 문서 서명 - 사내앱/금융에서 등장 |

**식별 속성 - 어느 아이템인가**

| 키 | 의미 | 사용처 |
|---|---|---|
| `kSecAttrService` | genericPassword의 "무슨 서비스의 비밀인가" | 관례상 앱 번들 ID 계열 - 이 레포의 `"com.seonghun.gitsearchmicro"` |
| `kSecAttrAccount` | "누구 혹은 무엇의 계정인가" | 토큰 종류 구분 - 이 레포 `"github.access_token"`, 데모는 `"demo.auth.token"`으로 슬롯 분리 |
| `kSecAttrServer`/`Protocol`/`Port`/`Path` | internetPassword의 서버 좌표 | 서버별 자격증명 구분 |
| `kSecAttrLabel` | 사람이 읽는 이름 | 키체인 뷰어/디버깅에서 알아보기용 (식별에 안 쓰임) |

**값**

| 키 | 의미 | 주의 |
|---|---|---|
| `kSecValueData` | 저장할 실제 바이트 (Data) | 문자열이면 `Data(str.utf8)` - 조회 응답에서 돌려받을 땐 `kSecReturnData`로 요청해야 옴 |
| `kSecValueRef` | SecKey/SecCertificate 같은 객체 참조 | 클래스 key/certificate 계열에서 |

**정책 - 어떻게 보호하나. 저장 시점에 선언한다**

| 키                               | 의미                           | 사용처                                          |
| ------------------------------- | ---------------------------- | -------------------------------------------- |
| `kSecAttrAccessible`            | 언제 읽을 수 있나    | 모든 저장 코드의 필수 결정                          |
| `kSecAttrSynchronizable`        | iCloud Keychain 동기화          | 여러 기기 편의 <-> ThisDeviceOnly와 상호 배타. 토큰은 보통 미사용 |
| `kSecAttrAccessGroup`           | 어느 앱 그룹이 공유하나                | 위젯/익스텐션/같은 팀 다른 앱과 로그인 공유 (entitlement 필요)         |
| `kSecAttrAccessControl`         | 접근에 인증 요구 (SecAccessControl) | Face ID 요구, 패스코드 요구 - 금융/민감 데이터              |
| `kSecUseDataProtectionKeychain` | macOS에서도 iOS식 보호 키체인 사용      | Catalyst/멀티플랫폼                               |

**반환 지시 - 조회에서 뭘 돌려받나**

| 키 | 돌려받는 것 | 사용처 |
|---|---|---|
| `kSecReturnData: true` | 값(Data) | 일반 조회 - 이 레포의 retrieve |
| `kSecReturnAttributes: true` | 속성 딕셔너리 (account, 생성/수정일...) | 목록/디버깅 - 값 없이 메타만 |
| `kSecReturnRef: true` | SecKey 등 객체 참조 | 키/인증서 계열 |
| `kSecMatchLimit` | `One`(기본) / `All`(배열로 전부) | 단건 조회 vs 나열 |

### 접근성 상수 전체 스펙트럼

`kSecAttrAccessible`의 선택지 전부입니다. 아래로 갈수록 엄격합니다.

| 상수 | 읽을 수 있는 시점 | 백업/이전 | 이런 데서 씁니다 |
|---|---|---|---|
| ~~`Always`~~ / ~~`AlwaysThisDeviceOnly`~~ | 항상 (잠금 무관) | 포함/제외 | iOS 12에서 deprecated. 재부팅 직후도 열리는 건 보호가 아니라서 퇴출됐습니다 |
| `AfterFirstUnlock` | 재부팅 후 첫 잠금해제 이후 항상 | 포함 | 백그라운드 네트워킹 토큰인데 기기 이전도 따라가야 할 때 (멀티 기기 UX 우선 서비스) |
| `AfterFirstUnlockThisDeviceOnly` | 위와 같음 | 제외 | 일반적인 API 토큰의 표준답. 백그라운드 갱신 되고, 새 기기면 재로그인. 이 레포의 선택 |
| `WhenUnlocked` | 화면이 잠겨 있지 않을 때만 | 포함 | 포그라운드에서만 쓰는 민감 데이터. 아무것도 안 적으면 이것이 기본값 |
| `WhenUnlockedThisDeviceOnly` | 위와 같음 | 제외 | 위 + 기기 바인딩 |
| `WhenPasscodeSetThisDeviceOnly` | 잠금 해제 중 + 패스코드가 설정된 기기만 | 제외 (유일 조합) | 최고 민감. 사용자가 패스코드를 끄면 아이템이 삭제된다는 게 핵심 동작 |

선택 알고리즘으로 외우면 이렇습니다.

```
백그라운드에서 읽어야 하나?
|- 예 -> AfterFirstUnlock 계열   (WhenUnlocked면 백그라운드 작업이 조용히 실패)
`- 아니오 -> WhenUnlocked 계열
그다음: 새 기기로 따라가도 되나?
|- 자격증명이라 안 됨 -> ThisDeviceOnly 붙임   (대부분의 토큰)
`- 따라가야 UX가 좋음 -> 기본형
극단: 패스코드 없는 기기엔 존재도 못 하게 -> WhenPasscodeSetThisDeviceOnly
```

### OSStatus - 만나게 되는 상태값

| 값 | 코드 | 의미 / 대응 |
|---|---|---|
| `errSecSuccess` | 0 | 성공 |
| `errSecItemNotFound` | -25300 | 없음. retrieve에선 정상 경로(nil 반환), delete에선 무시 가능 |
| `errSecDuplicateItem` | -25299 | add 시 이미 존재. upsert 패턴의 분기점 (이 레포는 delete-first로 회피) |
| `errSecInteractionNotAllowed` | -25308 | 접근성 위반 시점의 접근. 잠금 중에 WhenUnlocked 아이템을 읽으려 함 |
| `errSecAuthFailed` | -25293 | 인증 실패 (SecAccessControl 사용 시) |
| `errSecMissingEntitlement` | -34018 | Access Group/Keychain Sharing entitlement 누락. 익스텐션 공유 설정 실수의 단골 |

---

## 이 레포 너머 - 실무 확장 포인트

| 요구 | 도구 | 요지 |
|---|---|---|
| 여러 앱/익스텐션이 토큰 공유 | Access Group (`kSecAttrAccessGroup` + Keychain Sharing entitlement) | 같은 팀의 앱 그룹이 한 아이템을 공유 - 위젯/익스텐션에서 로그인 재사용 |
| 생체 인증으로 보호 | `SecAccessControl` (`.biometryCurrentSet` 등) + LAContext | 읽기 시점에 Face ID 요구. `biometryCurrentSet`은 지문/얼굴 재등록 시 아이템 무효화 |
| 여러 기기 동기화 | `kSecAttrSynchronizable` (iCloud Keychain) | 편의 <-> "기기에 묶기"와 정반대 방향. ThisDeviceOnly와 상호 배타 |
| 최신 API 표면 | `kSecUseDataProtectionKeychain` (macOS 포함 통일) | Catalyst/macOS까지 iOS식 데이터 보호 키체인으로 |
| 래퍼 라이브러리 | KeychainAccess 등 | CFDictionary 보일러플레이트 제거. 단 접근성과 동기화 정책 결정은 라이브러리가 대신 못 합니다 |

공통 원리는 하나입니다. 키체인 설계는 정책 선언의 조합입니다. 코드는 CRUD 네 줄이고 실력 차이는 상수 선택에서 납니다. 정책 축 네 개를 모으면 이렇습니다.

```
kSecAttrAccessible      -> "언제" 읽을 수 있나        (잠금 상태 기준)
kSecAttrAccessGroup     -> "누가(어느 앱이)" 읽나
kSecAttrAccessControl   -> "어떤 인증 절차를 거쳐야" 읽나
kSecAttrSynchronizable  -> "어느 기기까지" 따라가나
```

토큰의 답은 언제는 AfterFirstUnlock, 누가는 내 앱만이라 기본값, 절차는 없음, 어디까지는 이 기기만입니다. 이 조합이 백그라운드에서 조용히, 내 앱만, 이 기기에서만이라는 토큰의 사용 프로파일을 그대로 옮겨 놓았습니다.

### kSecAttrAccessGroup - 어느 앱들이 공유하나

모든 아이템은 접근 그룹에 소속됩니다. 지정하지 않으면 기본 그룹인 `팀ID.번들ID`, 즉 그 앱 전용입니다. GitSearch의 토큰을 GitSearch만 읽는 이유입니다. 위젯과 익스텐션은 별도 프로세스에 별도 샌드박스라 본 앱의 기본 그룹이 보이지 않습니다. 공유하려면 두 단계가 필요합니다.

```
1. 본 앱 + 익스텐션 둘 다 Keychain Sharing capability
   -> entitlements에 keychain-access-groups: ["팀ID.com.seonghun.gitsearch.shared"]
2. 저장/조회 쿼리에 그룹 명시
   query[kSecAttrAccessGroup as String] = "팀ID.com.seonghun.gitsearch.shared"
```

위젯이나 Notification Service Extension이 인증 API를 직접 호출하거나, 같은 Team ID의 다른 앱 사이에서 SSO를 할 때 씁니다. entitlement 없이 그룹을 지정하면 `errSecMissingEntitlement`(-34018)가 납니다. 같은 Team ID끼리만 가능해서 타사 앱과는 원천적으로 안 됩니다.

위젯이라고 무조건 키체인을 공유해야 하는 건 아닙니다. 위젯이 본 앱이 만들어 둔 표시 데이터만 보여 준다면 App Group 공유 컨테이너로 충분합니다. `UserDefaults(suiteName:)`이나 공유 파일 말입니다. 축이 다릅니다. 일반 데이터 공유는 App Group, 자격증명 공유는 Keychain access group입니다. 그리고 위젯이 잠금 중 타임라인을 갱신할 수 있으므로, 공유한 토큰의 접근성이 WhenUnlocked면 위젯 갱신이 침묵 실패합니다. 앞에서 본 함정이 위젯에서 재현되는 자리입니다.

### kSecAttrAccessControl - 읽는 순간의 인증 요구

`kSecAttrAccessible`의 강화판입니다. 접근성을 포함하면서 인증 요구를 얹기 때문에 둘 중 하나만 씁니다.

```swift
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,   // 접근성을 품고
    .biometryCurrentSet,                               // 인증 요구를 얹음
    &error
)
query[kSecAttrAccessControl as String] = access as Any  // Accessible "대신" 이걸
```

이후 `SecItemCopyMatching`이 시스템 Face ID 시트를 띄우는 블로킹 호출이 됩니다. 통과해야 Data가 나옵니다.

| 플래그 | 요구 | 사용처 |
|---|---|---|
| `.userPresence` | 생체 또는 패스코드 | 일반 본인 확인 - 메모 잠금 |
| `.biometryAny` | 등록된 아무 생체 | 생체 강제 |
| `.biometryCurrentSet` | 지금 등록된 생체만. 재등록 시 아이템 무효화 | 금융급. 공격자가 자기 지문을 추가 등록하는 우회를 차단 |
| `.devicePasscode` | 패스코드만 | 생체 실패 폴백 명시 |
| `.and` / `.or` | 플래그 조합 | 다중 요구 (생체 그리고 패스코드) |

송금 직전 재인증, 비밀번호 관리자 항목 열람, 앱 잠금 마스터 키처럼 꺼내는 행위가 드물고 민감한 값에만 씁니다.

토큰에 안 쓰는 이유는 분명합니다. 토큰은 요청마다 인터셉터가 조용히 읽는 값이라, 매 API 호출마다 Face ID가 뜨면 앱이 성립하지 않습니다. 더 안전한데 생략한 게 아니라 용도가 다른 축입니다.

---

## 정리

토큰은 Keychain에 `kSecClassGenericPassword`로 저장하고 service와 account 조합을 키로 씁니다. UserDefaults는 평문 plist라 자격증명에는 부적합합니다.

접근성은 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`입니다. 재부팅 후 첫 잠금해제 이후엔 백그라운드 네트워킹이 되면서, 백업과 기기 이전에는 따라가지 않아 새 기기에서 재로그인을 강제합니다.

갱신은 저빈도 작업이라 SecItemUpdate 분기 대신 delete 후 add로 단순화했습니다. 실무 코드라면 OSStatus를 확인해 저장 실패를 침묵시키지 않는 것까지가 완성입니다.

앱 삭제 후 키체인 잔존은 보장된 동작이 아닙니다. 재설치를 로그아웃으로 처리해야 한다면 첫 실행 감지로 명시적으로 비웁니다.

몇 가지를 덧붙입니다.

Keychain의 암호화는 Data Protection 체계를 따릅니다. 파일 암호화와 같은 클래스 키 계층을 쓰고 Secure Enclave가 키를 보호합니다. 접근성 상수가 곧 보호 클래스 선택입니다.

WhenUnlocked가 더 안전한데 안 쓴 이유는 잠금 중 백그라운드 요청이 실패하기 때문입니다. 보안 강도가 아니라 동작 요구와의 매칭 문제입니다.

토큰의 iCloud 동기화는 `kSecAttrSynchronizable`로 가능하지만 ThisDeviceOnly와 배타적입니다. 기기에 묶기를 포기하는 결정이라 자격증명에는 보통 쓰지 않습니다.

생체 보호까지 걸려면 SecAccessControl에 `biometryCurrentSet`을 씁니다. 읽기 시점에 Face ID를 요구하고 생체를 재등록하면 무효화됩니다.

---

## 참고 자료

**공식 문서**
- [Keychain services - Apple](https://developer.apple.com/documentation/security/keychain-services) - 전체 개요
- [Restricting keychain item accessibility - Apple](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility) - 접근성 스펙트럼의 공식 정의
- [Item class keys and values - Apple](https://developer.apple.com/documentation/security/item-class-keys-and-values) - 5종 클래스
- [Sharing access to keychain items among a collection of apps - Apple](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps) - Access Group
- [SecAccessControl - Apple](https://developer.apple.com/documentation/security/secaccesscontrol) - 생체 보호
- 표기 주의: 앱 삭제 후 잔존은 공식 문서화되지 않은 통상 동작이라 보장으로 취급하면 안 됩니다

**이 레포의 실물 코드**: [`KeychainTokenStorage.swift`](../../Projects/Core/CoreStorage/Sources/KeychainTokenStorage.swift)(본체) / [`TokenStorage.swift`](../../Projects/Core/CoreStorage/Sources/TokenStorage.swift)(계약) / [`FeatureAuthDemoApp.swift`](../../Projects/Feature/FeatureAuth/Demo/Sources/FeatureAuthDemoApp.swift)(account 분리 사용례) / [`AuthTokenInterceptor.swift`](../../Projects/Core/CoreNetwork/Sources/Pipeline/AuthTokenInterceptor.swift)(동기 retrieve의 소비자)

**관련 노트**: [swift6-sendable](swift6-sendable.md) - 상태의 위치 논증
