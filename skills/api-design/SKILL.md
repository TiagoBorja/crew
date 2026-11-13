---
name: api-design
description: Guidance for resource modelling, status codes and error model, pagination, versioning and compatibility of web APIs and events. Use when designing or changing an API contract, reviewing one, or deciding whether a change is breaking.
tags: [api, design]
---

# API design

## Start from the consumer
- Write down who calls this, with what goal, and the two or three most common calls. Design for those first.
- Draft the contract (schema or examples) before implementing. Review it as a document.

## Resource modelling
- Use nouns for resources, plural and consistent: `/orders`, `/orders/{id}`, `/orders/{id}/items`.
- Keep nesting shallow (one or two levels); expose independent resources at the top level with filters.
- Operations that are not CRUD: model as a sub-resource or action resource (`POST /orders/{id}/cancellation`) and document idempotency.
- IDs are opaque strings; never expose sequential internal keys if enumeration matters.
- Use consistent field names, casing and types across the API. Timestamps in ISO 8601 with time zone (UTC preferred); money as integer minor units plus currency code; no ambiguous booleans or magic strings (use documented enums).

## Methods and status codes
| Intent | Method | Success |
|---|---|---|
| read | GET (safe, cacheable) | 200 |
| create | POST | 201 + Location header |
| replace | PUT (idempotent) | 200 or 204 |
| partial update | PATCH | 200 or 204 |
| delete | DELETE (idempotent) | 204 |
| accepted for async work | POST | 202 + status resource |

Client errors: 400 malformed, 401 unauthenticated, 403 forbidden, 404 not found (also to hide existence), 409 conflict, 412 precondition failed, 422 semantically invalid, 429 rate limited. Server errors: 500, 502, 503 (with Retry-After), 504. Never return 200 with an error body.

## Error model
One shape everywhere, for example:
```json
{ "error": { "code": "order_not_found", "message": "No order with that id.", "details": [{"field": "id", "issue": "unknown"}], "request_id": "abc123" } }
```
- Stable machine-readable `code`, human-readable `message`, optional per-field details, a correlation id.
- No stack traces, internal hostnames, SQL or secrets in errors.

## Collections
- Pagination always, with a default and a maximum page size. Prefer cursor-based (opaque cursor) for large or changing data; offset/limit is acceptable for small stable sets.
- Return total counts only if cheap, or provide them on request.
- Filtering and sorting via documented query parameters with allow-listed fields; stable default order.

## Idempotency and concurrency
- Make retries safe: idempotency keys for non-idempotent POSTs; PUT and DELETE idempotent.
- Optimistic concurrency with ETag / If-Match or a version field to avoid lost updates.

## Versioning and compatibility
- Choose one scheme (path `/v1`, header or media type) and apply it everywhere.
- **Compatible (non-breaking):** adding optional request fields, adding response fields, adding endpoints, adding enum values only if consumers are documented to tolerate unknowns.
- **Breaking:** removing or renaming fields, changing types or meaning, making optional fields required, tightening validation, changing status codes or error codes, changing defaults, removing enum values.
- Consumers must ignore unknown fields (tolerant reader). Producers must not rely on it for breaking changes.
- Deprecate before removing: announce, add a deprecation signal, set a date, monitor usage.
- Events follow the same rules: schema versions, additive evolution, a documented ordering and delivery guarantee (at-least-once means consumers must be idempotent).

## Security and operations
- Authenticate and authorise every endpoint (see skill:security-checklist). Rate-limit. Validate all input.
- Document timeouts, limits (body size, page size) and retry guidance.
- Include a request id in responses and logs.

## Deliverables
A schema (OpenAPI, JSON Schema or equivalent), examples for success and each error, a changelog entry, and a compatibility statement: breaking or not, and for whom.
