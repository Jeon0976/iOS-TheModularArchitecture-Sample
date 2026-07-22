[한국어](README.md) | [English](README.en.md)

# 구현 노트 (docs/notes)

## CoreNetwork

| 노트 | 다루는 것 | 작성일 |
|---|:--|---|
| [인터셉터 파이프라인](notes/인터셉터-파이프라인.md) | 훅/기본 구현/재시도 결정 규칙/확장 경로 3종 (Alamofire 대응) | 2026-07-10 |
| [멱등성과 재시도](notes/멱등-재시도.md) | 멱등성은 엔드포인트의 선언, 재시도는 파이프라인의 정책 - 왜 인터셉터로 만들지 않았나, OR 결합의 함정 | 2026-07-10 |

## CoreDesignSystem

| 노트 | 다루는 것 | 작성일 |
|---|---|---|
| [ManagedTask](notes/managedtask.md) | structured vs unstructured Task - 동기 진입점 경계에서 필요한 취소 규칙 5가지를 타입으로 | 2026-07-10 |
| [owner 패턴](notes/owner-패턴.md) | sink(with:)/ManagedTask(with:)로 `[weak self]` 반복 제거 (withUnretained 관용구) | 2026-07-15 |

## CoreStorage

| 노트 | 다루는 것 | 작성일 |
|---|---|---|
| [Keychain](notes/keychain.md) | KeychainTokenStorage 분석 - 접근성 상수의 보안 결정, 확장 포인트 | 2026-07-11 |

## FeatureSearch

| 노트 | 다루는 것 | 작성일 |
|---|---|---|
| [이미지 파이프라인](notes/이미지-파이프라인.md) | 2계층 캐시/다운샘플/off-main/prefetch - 방어 4종과 레이스 시나리오 (WWDC18 대비) | 2026-07-15 |

## FeatureProfile

| 노트 | 다루는 것 | 작성일 |
|---|---|---|
| [weak let과 생성자 주입](notes/weak-let-생성자-주입.md) | actions를 private weak let으로 - 두 개의 순환(retain vs 생성) 구분 | 2026-07-15 |

## 전 모듈 공통 - Swift 6

| 노트 | 다루는 것 | 작성일 |
|---|---|---|
| [Sendable](notes/swift6-sendable.md) | Sendable이 왜 이렇게 많은가, 어디까지 필요한가 - strict 모드/nonisolated/sending/region isolation | 2026-07-10 (보강 2026-07-21) |
