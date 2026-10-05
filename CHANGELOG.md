# Changelog

## 0.1.0 (unreleased)

- Add immutable clients with partner/user authentication and tenant derivation.
- Add auth, companies, client search, records, services, staff, and permissions.
- Add JSON responses, page objects, lazy iteration, and date serialization.
- Remove the planned public raw HTTP API; resource adapters use the internal transport directly.
- Add typed errors, per-attempt timeouts, safe GET/HEAD retries, and metadata-only logging.
- Add offline RSpec/WebMock contracts, explicit live tests, Ruby matrix CI, and examples.
- Adopt the Shopify RuboCop preset and format source and tests consistently.
- Use page length for records iteration because the reference's `total_count` meaning is ambiguous.
- Live test-account verification and captured sanitized fixtures remain release requirements.
