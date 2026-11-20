# ADR-0011: Mocks live in a `CurrencyCoreTestSupport` target

- Status: Accepted · Date: 2026-11-20

## Context
ADR-0002 allows mocks only in tests, but both the core tests and (later) the app tests need
`MockRateProvider` and `MockHTTPClient`.

## Decision
A separate library target `CurrencyCoreTestSupport` holds the mocks. Only test targets depend on it;
the app target never links it (verified with `otool -L` in Phase 2).

## Consequences
- One shared set of mocks, no duplication, and no mock code in the shipped binary.
