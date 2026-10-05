# Fixture provenance

`reference/*.json` comes from response examples in the OpenAPI document embedded at
https://developers.yclients.com/ (retrieved 2026-10-05; the embedded OpenAPI was
confirmed identical at https://developers.yclients.com/ru/). Names and descriptive text
were replaced with `Example`; contact fields and external identifiers were cleared.
These are **documentation examples, not captured live responses**.

The fixtures preserve the documented structure, including string service IDs,
null clients, nested records, empty arrays, and endpoint-specific metadata.

Before publishing 0.1.0, run the live suite against a dedicated test account and
add sanitized captures with their endpoint, capture date, and sanitization notes.
Do not commit access tokens, passwords, real names, phone numbers, email addresses,
URLs containing secrets, or production account data.
