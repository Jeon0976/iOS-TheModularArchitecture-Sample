[한국어](README.md) | **English**

# Implementation Notes (docs/notes)

These are study notes written while building each module, migrated into the repo. **Note bodies are in Korean** (they keep the original informal note register). 

## CoreNetwork

| Note | Covers | Date |
|---|---|---|
| [Interceptor pipeline](notes/인터셉터-파이프라인.md) | Hooks, default implementations, retry decision rules, three growth paths (vs Alamofire) | 2026-07-10 |
| [Idempotency & retry](notes/멱등-재시도.md) | Idempotency as an endpoint-declared fact, retry as pipeline policy - why it is not an interceptor, the OR-combination trap | 2026-07-10 |

## CoreDesignSystem

| Note | Covers | Date |
|---|---|---|
| [ManagedTask](notes/managedtask.md) | Structured vs unstructured Task - encoding 5 cancellation rules into a type at synchronous entry points | 2026-07-10 |
| [Owner pattern](notes/owner-패턴.md) | Removing repeated `[weak self]` with sink(with:)/ManagedTask(with:) (the withUnretained idiom) | 2026-07-15 |

## CoreStorage

| Note | Covers | Date |
|---|---|---|
| [Keychain](notes/keychain.md) | A close read of KeychainTokenStorage - the security decision in one accessibility constant | 2026-07-11 |

## FeatureSearch

| Note | Covers | Date |
|---|---|---|
| [Image pipeline](notes/이미지-파이프라인.md) | Two-tier cache, downsampling, off-main decode, prefetch - 4 defenses and race scenarios (vs WWDC18) | 2026-07-15 |

## FeatureProfile

| Note | Covers | Date |
|---|---|---|
| [weak let & constructor injection](notes/weak-let-생성자-주입.md) | actions as private weak let - distinguishing the two cycles (retain vs construction) | 2026-07-15 |

## Across all modules - Swift 6

| Note | Covers | Date |
|---|---|---|
| [Sendable tour + Swift 6 deep dive](notes/swift6-sendable.md) | Why Sendable is everywhere, and how far it needs to go - strict modes, nonisolated, sending, region isolation | 2026-07-10 (expanded 2026-07-21) |
