---
name: security-checklist
description: Practical checklist for input validation, injection, authentication and authorization, secrets, dependencies and logging hygiene. Use when writing or reviewing code that handles untrusted input, credentials, user data or external calls.
tags: [security, review]
---

# Security checklist

Treat all data crossing a trust boundary (HTTP, files, queues, environment, third-party APIs, user-controlled database content) as untrusted.

## Input validation
- Validate on the server side at the boundary: type, length, range, format, allowed values. Prefer allow-lists over deny-lists.
- Normalise before validating (decode, trim, canonicalise paths) and validate the normalised form.
- Reject early with a safe error; never echo raw input into error messages unescaped.
- File uploads: check size, type by content not extension, store outside the web root, generate server-side names.

## Injection
- **SQL / query languages:** parameterised queries or a query builder only; never concatenate input into queries.
- **OS commands:** avoid shells; pass argument arrays; never interpolate input into a command string.
- **Templates / HTML:** use contextual auto-escaping; avoid raw-HTML sinks; sanitise rich text with a maintained library.
- **Paths:** resolve and verify the result stays within the intended base directory (no `..` traversal, no symlink escape).
- **Deserialisation:** do not deserialise untrusted data into arbitrary types; prefer plain data formats with schema validation.
- **Outbound requests (SSRF):** restrict target hosts and schemes for user-supplied URLs; block internal address ranges.
- **Logs / headers:** strip newlines from input written to logs and headers.

## Authentication
- Use the platform's or a well-maintained library's mechanisms; do not invent crypto or session schemes.
- Passwords stored only as salted, slow hashes (argon2, bcrypt, scrypt). Constant-time comparison for secrets and tokens.
- Sessions and tokens: expiry, rotation on privilege change, invalidation on logout, secure and HttpOnly cookie flags, SameSite set.
- Rate-limit and lock out repeated failures; avoid account enumeration in messages.

## Authorization
- Check on every request, server side, for the specific resource, not just the route. Deny by default.
- Guard against insecure direct object references: verify the caller owns or may access the id they supply.
- Separate roles and scopes; least privilege for service accounts and tokens.
- Do not rely on hidden UI elements or client-supplied role fields.

## Secrets
- No secrets in code, tests, fixtures, logs, URLs, error messages, images or commit history. Reference them by name from environment variables or a secret store.
- If a secret is found, do not repeat its value: report the location and recommend rotation.
- Keep local env files out of version control; provide an example file with placeholders.

## Data protection
- Use TLS for all network traffic; verify certificates; do not disable verification to "make it work".
- Encrypt sensitive data at rest where required; minimise what is collected and retained.
- Do not put personal data in logs, analytics events, URLs or caches without need.

## Dependencies and supply chain
- Add dependencies deliberately (maintained, licence compatible, needed). Pin versions or use lock files.
- Run the ecosystem's audit command and report findings by severity.
- Be wary of install scripts, typosquatted names and unpinned build actions or base images.

## Web specifics
- CSRF protection for state-changing requests that use cookie auth.
- Security headers: Content-Security-Policy, X-Content-Type-Options, frame protections, strict transport security.
- CORS: explicit origins, no wildcard with credentials.
- Output encoding for the context (HTML, attribute, URL, script).

## Logging and errors
- Log security events (login failure, permission denial, validation anomalies) with ids, not payloads.
- Never log secrets, tokens, full card numbers or personal data. Return generic errors to clients; keep detail in logs.

## Reporting
Tag findings `[critical]`, `[major]`, `[minor]` with location, exploit scenario in one sentence, and a fix. Say what was not examined.
