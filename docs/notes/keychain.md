# Keychain 딥다이브 - KeychainTokenStorage 분석과 iOS 자격증명 저장의 규칙

> [!NOTE]
> 2026-07-11, CoreStorage를 구현하며 정리한 학습 노트다 (노트 톤 그대로 옮김).
> 관련 소스: [KeychainTokenStorage.swift](../../Projects/Core/CoreStorage/Sources/KeychainTokenStorage.swift) / [TokenStorage.swift](../../Projects/Core/CoreStorage/Sources/TokenStorage.swift)

> [!IMPORTANT]
> **다루는 질문** - 이 레포의 `KeychainTokenStorage`(CoreStorage) 68줄을 뜯어보며 나온 질문들
>
> - 왜 UserDefaults가 아니라 Keychain인가? `kSecClassGenericPassword`와 service/account는 뭔가? delete->add는 왜인가?
> - **접근성 상수 한 줄에 담긴 보안 결정**은 무엇인가? 나아가 접근성 스펙트럼/백업과 동기화/생체 보호 등 키체인 관리 전반.
> - **한 줄 결론**: Keychain은 "암호화되는 UserDefaults"가 아니라 **자격증명을 위한 시스템 서비스**다.
> - 설계의 핵심은 저장 코드가 아니라 **정책 선언**이다 - 이 아이템을 1) 언제 읽을 수 있고(접근성) 2) 어디까지 따라가는가(ThisDeviceOnly/동기화)를 상수 하나로 선언하면 나머지는 OS와 Secure Enclave가 맡는다.
> - 이 레포의 `AfterFirstUnlockThisDeviceOnly` = "백그라운드 네트워킹 가능 + 기기 이전 시 재로그인 강제"라는 토큰의 표준 답.

---

## 1. TL;DR

| 질문 | 답 |
|---|---|
| 왜 UserDefaults가 아닌가 | UserDefaults = **평문 plist 파일** (탈옥/백업 추출로 그대로 읽힘). Keychain = 하드웨어(Secure Enclave) 지원 암호화 + 접근 정책을 OS가 강제 |
| 아이템의 "기본키"는 | 클래스(`kSecClassGenericPassword`) + `kSecAttrService` + `kSecAttrAccount` 조합 - `baseQuery`가 모든 연산의 공통 열쇠인 이유 |
| delete->add인 이유 | SecItemUpdate의 "있으면 update/없으면 add" 분기 대비 코드 절반. 토큰 저장은 로그인 순간뿐(저빈도)이라 단순함을 산 트레이드오프 |
| 접근성 상수의 의미 | `AfterFirstUnlock` = 재부팅 후 첫 잠금해제 이후엔 화면 잠겨도 접근(백그라운드 네트워킹) / `ThisDeviceOnly` = 백업/이전 제외(새 기기 = 재로그인) |
| 이 구현에서 생략된 요소 | OSStatus 확인/에러 전파, 접근 그룹(앱 간 공유), 생체 보호(SecAccessControl), iCloud 동기화 판단 |

---

## 2. 실물 뜯어보기 - 68줄의 결정들

### 2-1. 전 -> 후: UserDefaults에서 Keychain으로

전편(Clean 버전)은 토큰을 UserDefaults에 저장했다. 이 레포는 미루지 않고 바꿨다 - 근거는 저장 형식의 차이 그 자체:

| | UserDefaults | Keychain |
|---|---|---|
| 실체 | 앱 샌드박스의 **평문 plist** | 시스템 보안 데이터베이스 (암호화, SEP 연계) |
| 읽히는 경로 | 탈옥, 로컬 백업 추출, 포렌식 도구 | 기기 잠금/정책을 뚫어야 함 |
| 삭제 시점 | 앱 삭제와 함께 | 앱 삭제 후에도 **잔존하는 것이 통상 동작** (공식 보장은 아님 - 첫 실행 감지 시 명시적 clear가 관례) |
| 용도 | 설정값, 플래그 | **자격증명** (토큰/비밀번호/키) |

> [!WARNING] "앱 지웠는데 로그인이 살아있어요"
> 키체인 잔존은 문서화된 보장이 아니라 관찰되는 일반적인 동작이다.
>
> 이 때문에 "재설치 = 초기화"를 기대하는 사용자와 어긋날 수 있어 실무에선 첫 실행 플래그(UserDefaults)로 감지해 키체인을 명시적으로 비우는 패턴으로 위 요구사항을 해결할 수 있다.
>
>  두 저장소의 삭제 시점 차이를 역이용하는 것

### 2-2. 아이템 식별 - baseQuery가 기본키다

```swift
private var baseQuery: [String: Any] {
    [
        kSecClass as String: kSecClassGenericPassword,     // 아이템 클래스
        kSecAttrService as String: service,                // "com.seonghun.gitsearchmicro"
        kSecAttrAccount as String: account,                // "github.access_token"
    ]
}
```

- 키체인 아이템 클래스는 5종: `genericPassword`(범용 비밀 - **API 토큰의 관례적 자리**) / `internetPassword`(서버/프로토콜 메타 포함) / `certificate` / `key` / `identity`
- genericPassword의 유일성은 **service + account 조합**이 결정한다 - 같은 조합으로 add하면 `errSecDuplicateItem`. store에서 delete를 먼저 하는 이유이기도 하다
- init 파라미터로 열어둔 덕에 데모 앱이 `account: "demo.auth.token"`으로 **본 앱과 다른 슬롯**을 쓰는 것도 이 구조의 이득 (실제 [FeatureAuthDemoApp](../../Projects/Feature/FeatureAuth/Demo/Sources/FeatureAuthDemoApp.swift)이 그렇게 쓴다)

### 2-3. store - delete->add와 정책 선언

```swift
public func store(_ token: String) {
    SecItemDelete(baseQuery as CFDictionary)              // 있으면 지우고
    var query = baseQuery
    query[kSecValueData as String] = Data(token.utf8)     // 값은 항상 Data
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(query as CFDictionary, nil)                // 새로 넣는다
}
```

- **delete->add vs SecItemUpdate**: update 경로는 "존재 확인 -> 분기"가 필요해 코드가 배로 늘고 토큰 저장은 로그인 순간뿐인 저빈도 작업 - 단순함을 산 트레이드오프 (주석에 명시된 결정). delete와 add 사이의 이론상 빈틈은 로그인 플로우 특성상(동시 store 없음) 실질 무해
- **`Data(token.utf8)`**: 키체인의 값은 항상 Data - 직렬화 문서에서 본 "가장 원초적인 직렬화(UTF-8)"의 실물
- **접근성은 add 시점에 선언**한다 - 저장 후에 바꾸려면 아이템을 다시 써야 한다. "정책은 저장할 때 정한다"

### 2-4. 접근성 스펙트럼 - 이 한 줄이 이 파일의 진짜 보안 설계

`kSecAttrAccessible`의 선택지는 2축이다: **언제 읽을 수 있나, 기기를 따라가나**.

| 언제 축 | 의미 | 어울리는 것 |
|---|---|---|
| `WhenUnlocked` | 화면이 잠기면 접근 불가 | 가장 엄격 - 포그라운드 전용 데이터 |
| `AfterFirstUnlock` | 재부팅 후 **첫 잠금해제 이후엔 항상** 접근 | **백그라운드 네트워킹이 필요한 토큰의 표준** |
| `WhenPasscodeSetThisDeviceOnly` | 패스코드 설정 기기에서만 존재 가능 | 최고 민감 (패스코드 해제 시 아이템 삭제) |

| 기기 축 | 의미 |
|---|---|
| (기본) | 암호화 백업/기기 이전에 포함 |
| `ThisDeviceOnly` | **백업/이전 제외** - 새 기기 = 재로그인 강제 |

이 레포의 `AfterFirstUnlockThisDeviceOnly`

- "잠금 중 백그라운드 요청은 되게 + 기기가 바뀌면 자격증명은 안 따라가게" 
- **접근성 선택은 보안 강도가 아니라 앱의 동작 요구에 맞추는 문제**다

**막히는 메커니즘**: 화면이 잠기는 순간 해당 보호 클래스의 **복호화 키가 메모리에서 내려간다** - 잠금 중 `SecItemCopyMatching`은 `errSecInteractionNotAllowed`로 실패하고 앱 입장에선 "토큰이 없네? 로그아웃됐나?"라는 **침묵 실패**가 된다. 백그라운드 fetch, 푸시 받고 깨어난 처리, 잠긴 채 도는 background URLSession이 전부 이 실패를 겪는 지점이다.

> [!NOTE] 정직한 현실 체크 - 이 앱은 지금 WhenUnlocked여도 안 터진다
> GitSearch에는 현재 백그라운드 네트워킹이 없다. 그러니 `WhenUnlocked`로 저장해도 **당장은** 아무 문제가 없고 보안 강도는 오히려 한 단계 높다(잠기면 즉시 재보호). 그래도 AfterFirstUnlock을 쓴 이유는 이게 **나중에 터지는 종류의 함정**이기 때문 - 백그라운드 기능을 추가하는 순간 "가끔씩만 로그인이 풀리는" 재현 어려운 버그로 돌아온다. 접근성은 저장 시점에 고정되므로(2-3절), 나중에 조용히 어긋나는 것보다 처음부터 토큰의 관례적 표준을 쓴 것. 트레이드오프가 있는 선택이지 공짜가 아니다.

**ThisDeviceOnly의 논거를 토큰 입장에서 다시 쓰면**: 토큰이 백업을 타고 다른 기기로 복원되면 **그 자체가 유출**이고 어차피 재로그인하면 재발급되는 값이라 백업에 태울 이유가 없다 - "잃어도 다시 만들 수 있는 자격증명은 기기에 묶는다".

### 2-5. retrieve/clear - 그리고 생략된 것 (OSStatus)

```swift
let status = SecItemCopyMatching(query as CFDictionary, &result)
guard status == errSecSuccess, let data = result as? Data else { return nil }
```

retrieve만 status를 확인하고 store/clear는 반환값(OSStatus)을 버린다 - **교보재 단순화**다. 실무 체크리스트:
- store의 `SecItemAdd` 실패(디스크/마이그레이션 직후/잠금 상태 등 드문 케이스)를 침묵하면 "로그인했는데 다음 실행에 풀려 있는" 미스터리가 된다 - 최소한 로깅, 이상적으로는 throws로 전파
- **침묵 실패의 실측 재현 (2026-07-12, 이 코드베이스)**: 호스트 없는 테스트 타겟에서 `store()`를 부르면 - 에러 없이 조용히 지나가고 `retrieve()`가 nil을 준다. OSStatus를 직접 찍어보고서야 `SecItemAdd -> -34018(errSecMissingEntitlement)`이 원인으로 드러났다. 같은 코드가 호스트(Demo 앱) 주입 타겟에서는 4/4 통과 - "OSStatus를 버리면 원인 진단이 불가능해진다"와 "키체인 테스트에 호스트가 필수인 이유"를 동시에 증명한 실험 (CoreStorage의 Tests vs HostedTests 분리 근거)
- 대표 상태값: `errSecSuccess`(0) / `errSecItemNotFound`(-25300 - retrieve에서 정상 경로) / `errSecDuplicateItem`(-25299 - delete-first가 회피하는 것) / `errSecInteractionNotAllowed`(-25308 - 접근성 위반 시점의 접근)

### 2-6. Sendable + 동기 API - 모듈 간 맞물림

- **Sendable 성립 근거**: 저장 프로퍼티 전부 let + **실제 상태는 시스템(Keychain)이 보유** + SecItem API 자체가 스레드 안전. "상태의 위치를 물으면 class여도 증명이 성립"하는 Sendable 실물 투어 3-3절의 사례
- **동기 API인 이유**: 키체인 조회는 로컬이라 빠르다 - 덕분에 `AuthTokenInterceptor.adapt`가 동기로 남았고 prepareRequest 전체가 네트워크 없이 테스트 가능해졌다. 저장소의 동기/비동기 결정이 파이프라인 설계까지 흐르는 맞물림

---

## 3. 사용 설명서 - API 4함수, 그리고 상수 사전

키체인 API는 함수 4개가 전부다. 대신 **모든 것이 딕셔너리(query)로 표현**되기 때문에, 실력은 함수가 아니라 "딕셔너리에 어떤 키를 넣을 줄 아는가"에서 갈린다.

### 3-1. CRUD 4함수

| 함수 | 역할 | 형태 |
|---|---|---|
| `SecItemAdd(query, &result)` | **생성** | query에 클래스+식별자+값+정책을 담아 추가. 같은 식별자가 있으면 `errSecDuplicateItem` |
| `SecItemCopyMatching(query, &result)` | **조회** | query로 찾고, `kSecReturn~` 키로 "뭘 돌려줄지" 지정 |
| `SecItemUpdate(query, attributesToUpdate)` | **수정** | 첫 인자로 찾고, 둘째 딕셔너리의 키만 갈아끼움 |
| `SecItemDelete(query)` | **삭제** | query에 매칭되는 것 전부 삭제 |

**저장 - 두 가지 패턴:**

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

**조회 - 값만 / 속성까지 / 전체 나열:**

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

**삭제 - 하나 vs 전체 청소:**

```swift
SecItemDelete(baseQuery as CFDictionary)                       // service+account 매칭 하나
SecItemDelete([kSecClass as String: kSecClassGenericPassword]  // 이 앱의 genericPassword 전부
              as CFDictionary)                                 // - "재설치 시 초기화" 관례가 이것
```

### 3-2. 쿼리 딕셔너리 키 사전 - 역할별로 전부

딕셔너리에 들어가는 키는 4가지 역할로 나뉜다. **"식별자냐, 값이냐, 정책이냐, 반환 지시냐"**를 구분하면 어떤 조합도 읽을 수 있다.

**1) 클래스 (무엇을 저장하나) - `kSecClass`의 5가지 값**

| 값 | 정체 | 어디서 쓰나 |
|---|---|---|
| `kSecClassGenericPassword` | 범용 비밀 (아무 Data) | **API 토큰, 앱 자체 비밀번호, 암호화 키 재료** - 앱 개발의 90%. 이 레포가 이것 |
| `kSecClassInternetPassword` | 서버 자격증명 (server/protocol/port 메타 포함) | 특정 서버 로그인 저장, 여러 계정x여러 서버 관리 - URL 기반 식별이 필요할 때 |
| `kSecClassCertificate` | 인증서 (공개 부분) | 서버 인증서 피닝 재료, 신뢰 평가 |
| `kSecClassKey` | 암호화 키 | SecKey 저장 - 직접 암호화 구현 시 |
| `kSecClassIdentity` | 인증서 + 개인키 쌍 | **mTLS(클라이언트 인증서 인증)**, 문서 서명 - 사내앱/금융에서 등장 |

**2) 식별 속성 (어느 아이템인가)**

| 키 | 의미 | 사용처 |
|---|---|---|
| `kSecAttrService` | genericPassword의 "무슨 서비스의 비밀인가" | 관례상 앱 번들 ID 계열 - 이 레포의 `"com.seonghun.gitsearchmicro"` |
| `kSecAttrAccount` | "누구/무엇의 계정인가" | 토큰 종류 구분 - 이 레포 `"github.access_token"`, 데모는 `"demo.auth.token"`으로 **슬롯 분리** |
| `kSecAttrServer`/`Protocol`/`Port`/`Path` | internetPassword의 서버 좌표 | 서버별 자격증명 구분 |
| `kSecAttrLabel` | 사람이 읽는 이름 | 키체인 뷰어/디버깅에서 알아보기용 (식별에 안 쓰임) |

**3) 값**

| 키 | 의미 | 주의 |
|---|---|---|
| `kSecValueData` | 저장할 실제 바이트 (Data) | 문자열이면 `Data(str.utf8)` - 조회 응답에서 돌려받을 땐 `kSecReturnData`로 요청해야 옴 |
| `kSecValueRef` | SecKey/SecCertificate 같은 객체 참조 | 클래스 key/certificate 계열에서 |

**4) 정책 (어떻게 보호하나) - 저장 시점에 선언**

| 키                               | 의미                           | 사용처                                          |
| ------------------------------- | ---------------------------- | -------------------------------------------- |
| `kSecAttrAccessible`            | 언제 읽을 수 있나 (3-3절 전체 스펙트럼)    | **모든 저장 코드의 필수 결정**                          |
| `kSecAttrSynchronizable`        | iCloud Keychain 동기화          | 여러 기기 편의 <-> ThisDeviceOnly와 상호 배타. 토큰은 보통 미사용 |
| `kSecAttrAccessGroup`           | 어느 앱 그룹이 공유하나                | 위젯/익스텐션/같은 팀 다른 앱과 로그인 공유 (entitlement 필요)         |
| `kSecAttrAccessControl`         | 접근에 인증 요구 (SecAccessControl) | Face ID 요구, 패스코드 요구 - 금융/민감 데이터              |
| `kSecUseDataProtectionKeychain` | macOS에서도 iOS식 보호 키체인 사용      | Catalyst/멀티플랫폼                               |

**5) 반환 지시 (조회에서 뭘 돌려받나)**

| 키 | 돌려받는 것 | 사용처 |
|---|---|---|
| `kSecReturnData: true` | 값(Data) | 일반 조회 - 이 레포의 retrieve |
| `kSecReturnAttributes: true` | 속성 딕셔너리 (account, 생성/수정일...) | 목록/디버깅 - 값 없이 메타만 |
| `kSecReturnRef: true` | SecKey 등 객체 참조 | 키/인증서 계열 |
| `kSecMatchLimit` | `One`(기본) / `All`(배열로 전부) | 단건 조회 vs 나열 |

### 3-3. 접근성 상수 전체 스펙트럼 - 각각 어디서 쓰나

`kSecAttrAccessible`의 선택지 전부. 아래로 갈수록 엄격하다:

| 상수 | 읽을 수 있는 시점 | 백업/이전 | 이런 데서 쓴다 |
|---|---|---|---|
| ~~`Always`~~ / ~~`AlwaysThisDeviceOnly`~~ | 항상 (잠금 무관) | 포함/제외 | **deprecated (iOS 12)** - 재부팅 직후도 열리는 건 보호가 아니라서 퇴출. "왜 없어졌나"가 핵심 포인트 |
| `AfterFirstUnlock` | 재부팅 후 첫 잠금해제 이후 **항상** | 포함 | 백그라운드 네트워킹 토큰인데 **기기 이전도 따라가야** 할 때 (멀티 기기 UX 우선 서비스) |
| `AfterFirstUnlockThisDeviceOnly` | 위와 같음 | **제외** | **일반적인 API 토큰의 표준답** - 백그라운드 갱신 되고, 새 기기 = 재로그인. 이 레포의 선택 |
| `WhenUnlocked` | 화면이 **잠겨 있지 않을 때만** | 포함 | 포그라운드에서만 쓰는 민감 데이터 - 화면에 표시할 카드번호 마지막 4자리 같은 것. **기본값**(아무것도 안 적으면 이것) |
| `WhenUnlockedThisDeviceOnly` | 위와 같음 | 제외 | 위 + 기기 바인딩 |
| `WhenPasscodeSetThisDeviceOnly` | 잠금 해제 중 + **패스코드가 설정된 기기만** | 제외 (유일 조합) | 최고 민감 - 금융앱 거래 비밀. **사용자가 패스코드를 끄면 아이템이 삭제**된다는 게 핵심 동작 |

선택 알고리즘으로 외우면:

```
백그라운드에서 읽어야 하나?
|- 예 -> AfterFirstUnlock 계열   (WhenUnlocked면 백그라운드 작업이 조용히 실패)
`- 아니오 -> WhenUnlocked 계열
그다음: 새 기기로 따라가도 되나?
|- 자격증명이라 안 됨 -> ThisDeviceOnly 붙임   (대부분의 토큰)
`- 따라가야 UX가 좋음 -> 기본형
극단: 패스코드 없는 기기엔 존재도 못 하게 -> WhenPasscodeSetThisDeviceOnly
```

### 3-4. OSStatus - 만나게 되는 상태값

| 값 | 코드 | 의미 / 대응 |
|---|---|---|
| `errSecSuccess` | 0 | 성공 |
| `errSecItemNotFound` | -25300 | 없음 - retrieve에선 **정상 경로**(nil 반환), delete에선 무시 가능 |
| `errSecDuplicateItem` | -25299 | add 시 이미 존재 - upsert 패턴의 분기점 (이 레포는 delete-first로 회피) |
| `errSecInteractionNotAllowed` | -25308 | **접근성 위반 시점의 접근** - 잠금 중에 WhenUnlocked 아이템을 읽으려 함. 접근성 선택 실수의 대표 증상 |
| `errSecAuthFailed` | -25293 | 인증 실패 (SecAccessControl 사용 시) |
| `errSecMissingEntitlement` | -34018 | Access Group/Keychain Sharing entitlement 누락 - 익스텐션 공유 설정 실수의 단골 |

---

## 4. 이 레포 너머 - 실무 확장 포인트

| 요구 | 도구 | 요지 |
|---|---|---|
| 여러 앱/익스텐션이 토큰 공유 | **Access Group** (`kSecAttrAccessGroup` + Keychain Sharing entitlement) | 같은 팀의 앱 그룹이 한 아이템을 공유 - 위젯/익스텐션에서 로그인 재사용 |
| 생체 인증으로 보호 | **`SecAccessControl`** (`.biometryCurrentSet` 등) + LAContext | 읽기 시점에 Face ID 요구. `biometryCurrentSet`은 지문/얼굴 재등록 시 아이템 무효화(원격 공격 대비) |
| 여러 기기 동기화 | `kSecAttrSynchronizable` (iCloud Keychain) | 편의 <-> "기기에 묶기"와 정반대 방향 - ThisDeviceOnly와 상호 배타. 토큰은 보통 비동기화가 답 |
| 최신 API 표면 | `kSecUseDataProtectionKeychain` (macOS 포함 통일) | Catalyst/macOS까지 iOS식 데이터 보호 키체인으로 |
| 래퍼 라이브러리 | KeychainAccess 등 | CFDictionary 보일러플레이트 제거 - 단 접근성/동기화 **정책 결정은 라이브러리가 대신 못 한다** |

공통 원리: **키체인 설계 = 정책 선언의 조합**이다. 코드는 CRUD 네 줄이고, 실력 차이는 상수 선택(접근성/동기화/접근 제어)에서 난다. 정책 축 4개를 한 줄로 모으면:

```
kSecAttrAccessible      -> "언제" 읽을 수 있나        (잠금 상태 기준, 3-3절)
kSecAttrAccessGroup     -> "누가(어느 앱이)" 읽나      (4-1절)
kSecAttrAccessControl   -> "어떤 인증 절차를 거쳐야" 읽나 (4-2절)
kSecAttrSynchronizable  -> "어느 기기까지" 따라가나
```

토큰의 답 = 언제(AfterFirstUnlock) + 누가(내 앱만=기본) + 절차(없음) + 어디까지(이 기기만) - 이 조합이 "백그라운드에서 조용히, 내 앱만, 이 기기에서만"이라는 토큰의 사용 프로파일을 그대로 옮겨놓았다.

### 4-1. kSecAttrAccessGroup - "이 아이템을 어느 앱들이 공유하나"

모든 아이템은 접근 그룹에 소속된다. 미지정 시 기본 그룹 = 그 앱 전용(`팀ID.번들ID`) - GitSearch의 토큰을 GitSearch만 읽는 이유. 위젯/익스텐션은 **별도 프로세스/별도 샌드박스**라 본 앱의 기본 그룹이 안 보인다. 공유하려면:

```
1. 본 앱 + 익스텐션 둘 다 Keychain Sharing capability
   -> entitlements에 keychain-access-groups: ["팀ID.com.seonghun.gitsearch.shared"]
2. 저장/조회 쿼리에 그룹 명시
   query[kSecAttrAccessGroup as String] = "팀ID.com.seonghun.gitsearch.shared"
```

- **사용처**: 위젯/Notification Service Extension이 인증 API를 직접 호출, 같은 Team ID의 다른 앱 간 SSO
- **함정**: entitlement 없이 그룹 지정 -> `errSecMissingEntitlement(-34018)` (3-4절). **같은 Team ID끼리만** 가능 - 타사 앱과는 원천 불가
- **위젯이라고 무조건 키체인 공유는 아니다**: 위젯이 "본 앱이 만들어둔 표시 데이터"만 보여주면 **App Group 공유 컨테이너**(`UserDefaults(suiteName:)`/공유 파일)로 충분하다. 축이 다르다 - **일반 데이터 공유 = App Group, 자격증명 공유 = Keychain access group.** 위젯이 잠금 중 타임라인을 갱신할 수 있으므로, 공유한 토큰의 접근성이 WhenUnlocked면 위젯 갱신이 침묵 실패한다(2-4절의 함정이 위젯에서 재현되는 자리)

### 4-2. kSecAttrAccessControl - "읽는 순간 인증을 요구한다"

`kSecAttrAccessible`(언제)의 강화판 - 접근성을 **포함**하면서 인증 요구를 얹는다. 그래서 둘 중 하나만 쓴다:

```swift
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,   // 접근성을 품고
    .biometryCurrentSet,                               // 인증 요구를 얹음
    &error
)
query[kSecAttrAccessControl as String] = access as Any  // Accessible "대신" 이걸
```

이후 `SecItemCopyMatching`이 **시스템 Face ID 시트를 띄우는 블로킹 호출**이 된다 - 통과해야 Data가 나온다.

| 플래그 | 요구 | 사용처 |
|---|---|---|
| `.userPresence` | 생체 **또는** 패스코드 | 일반 본인 확인 - 메모 잠금 |
| `.biometryAny` | 등록된 아무 생체 | 생체 강제 |
| `.biometryCurrentSet` | **지금 등록된** 생체만 - 재등록 시 **아이템 무효화** | 금융급. "공격자가 자기 지문을 추가 등록"하는 우회 차단 |
| `.devicePasscode` | 패스코드만 | 생체 실패 폴백 명시 |
| `.and` / `.or` | 플래그 조합 | 다중 요구 (생체 그리고 패스코드) |

- **사용처**: 송금 직전 재인증, 비밀번호 관리자 항목 열람, 앱 잠금 마스터 키 - **"꺼내는 행위가 드물고 민감한"** 값 전용
- **토큰에 안 쓰는 이유**: 토큰은 요청마다 인터셉터가 조용히 읽는 값 - 매 API 호출마다 Face ID가 뜨면 앱이 성립하지 않는다. "더 안전한데 생략"이 아니라 **용도가 다른 축**

---

## 5. 정리

- 토큰은 Keychain에 `kSecClassGenericPassword`로 저장하고, service+account 조합을 키로 쓴다. UserDefaults는 평문 plist라 자격증명에는 부적합하다.
- 접근성은 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` - 재부팅 후 첫 잠금해제 이후엔 백그라운드 네트워킹이 되면서, 백업/기기 이전에는 따라가지 않아 새 기기에서 재로그인을 강제한다.
- 갱신은 저빈도 작업이라 SecItemUpdate 분기 대신 delete-add로 단순화했다. 실무 코드라면 OSStatus를 확인해 저장 실패를 침묵시키지 않는 것까지가 완성이다.
- 앱 삭제 후 키체인 잔존은 보장된 동작이 아니다. "재설치 = 로그아웃"이 요구라면 첫 실행 감지로 명시적으로 비운다.

보충 정리:
- **Keychain의 암호화 방식** - Data Protection 체계다. 파일 암호화와 같은 클래스 키 계층을 쓰고 Secure Enclave가 키를 보호한다. 접근성 상수가 곧 보호 클래스 선택이다.
- **WhenUnlocked가 더 안전한데 안 쓴 이유** - 잠금 중 백그라운드 요청이 실패한다. 보안 강도가 아니라 동작 요구와의 매칭 문제다 (2-4절).
- **토큰의 iCloud 동기화** - 가능(kSecAttrSynchronizable)하지만 ThisDeviceOnly와 배타다. "기기에 묶기"를 포기하는 결정이라 자격증명엔 보통 쓰지 않는다.
- **생체 보호까지 걸려면** - SecAccessControl + biometryCurrentSet. 읽기 시점에 Face ID를 요구하고, 생체를 재등록하면 무효화된다.
---

## 6. 참고 자료

**공식 문서**
- [Keychain services - Apple](https://developer.apple.com/documentation/security/keychain-services) - 전체 개요
- [Restricting keychain item accessibility - Apple](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility) - 접근성 스펙트럼의 공식 정의
- [Item class keys and values - Apple](https://developer.apple.com/documentation/security/item-class-keys-and-values) - 5종 클래스
- [Sharing access to keychain items among a collection of apps - Apple](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps) - Access Group
- [SecAccessControl - Apple](https://developer.apple.com/documentation/security/secaccesscontrol) - 생체 보호
- 표기 주의: "앱 삭제 후 잔존"은 공식 문서화되지 않은 통상 동작 - 보장으로 취급하지 말 것 (2-1절 WARNING)

**이 레포의 실물 코드**: [`KeychainTokenStorage.swift`](../../Projects/Core/CoreStorage/Sources/KeychainTokenStorage.swift)(본체) / [`TokenStorage.swift`](../../Projects/Core/CoreStorage/Sources/TokenStorage.swift)(계약) / [`FeatureAuthDemoApp.swift`](../../Projects/Feature/FeatureAuth/Demo/Sources/FeatureAuthDemoApp.swift)(account 분리 사용례) / [`AuthTokenInterceptor.swift`](../../Projects/Core/CoreNetwork/Sources/Pipeline/AuthTokenInterceptor.swift)(동기 retrieve의 소비자)

**관련 노트**: [swift6-sendable](swift6-sendable.md) - "상태의 위치" 논증
