# yclients

Unofficial Ruby client for the YCLIENTS API.
This project is not affiliated with or endorsed by YCLIENTS.

A thin, framework-independent client for Ruby >= 3.2, using Faraday 2.x.
It handles authentication, HTTP, pagination, and errors. It has no Rails,
ActiveRecord, ActiveSupport, queue, synchronization, or business-rule dependencies.

## Installation

Until the first RubyGems release, add the GitHub repository to your application's
`Gemfile`:

```ruby
gem "yclients", git: "https://github.com/veles-is-coding/yclients-ruby.git", branch: "main"
```

If you are working on the gem locally, use a local checkout instead. Replace the
path with the actual location of the repository:

```ruby
gem "yclients", path: "/path/to/yclients-ruby"
```

After adding either entry, run this command from your application's directory:

```sh
bundle install
```

Bundler loads the gem directly from the selected source; no `.gem` build is needed.

## Configuration

```ruby
require "yclients"

api = Yclients::Client.new(
  partner_token: ENV.fetch("YCLIENTS_PARTNER_TOKEN"),
  user_token: ENV["YCLIENTS_USER_TOKEN"],
  base_url: "https://api.yclients.com/api/v1",
  timeout: 10,
  open_timeout: 5,
  logger: nil
)
```

The client sends `Accept: application/vnd.yclients.v2+json` and
`Authorization: Bearer <partner_token>, User <user_token>` automatically.
Without a user token it sends only the Bearer component. Timeouts are in seconds.
There is no global configuration or token setter. Configuration copies and freezes
credential strings. Each transport reuses one Faraday client with separate
request parameters, headers, and bodies. The default `net_http` adapter does not
keep TCP connections open between requests.

```ruby
base = Yclients::Client.new(partner_token: ENV.fetch("YCLIENTS_PARTNER_TOKEN"))
user_api = base.with_user_token(ENV.fetch("YCLIENTS_USER_TOKEN"))
# base keeps its original partner-only authentication.
```

The user token identifies a user and their permissions; `company_id` selects the
company for each request. See [the user authentication example](examples/user_authentication.rb).

For multiple tenants, keep each tenant's user token and list of company IDs
together in your application. One tenant can represent an organization with
multiple YCLIENTS branches. The [multi-tenant example](examples/multi_tenant.rb)
uses user tokens from environment variables and sample company ID arrays.
Replace the sample IDs with your branches; in an application, load these lists
from each tenant's stored settings. Tenant authorization and company ownership
checks belong to the application.

Instances can be shared between threads. A supplied logger or custom transport
must itself support concurrent use. Responses are ordinary Ruby data owned by
the caller; sharing and mutating the same response needs application coordination.

## Resources

```ruby
api.companies.list(my: 1, page: 1, per_page: 100)
api.companies.retrieve(company_id: 123)

api.clients.search(company_id: 123, filters: [], page: 1, per_page: 100)
api.clients.retrieve(company_id: 123, client_id: 456)

api.services.list(company_id: 123, staff_id: nil, category_id: nil)
api.services.retrieve(company_id: 123, service_id: 789)

api.service_categories.list(company_id: 123)

api.staff.list(company_id: 123)
api.staff.retrieve(company_id: 123, staff_id: 789)

api.records.list(company_id: 123, start_date: nil, end_date: nil,
                 staff_id: nil, client_id: nil, page: 1, per_page: 300)
api.records.retrieve(company_id: 123, record_id: 789)

api.permissions.retrieve(company_id: 123, groups: ["settings"])
```

Companies accept additional YCLIENTS query filters. Client search accepts the
documented filter array and additional body fields such as `fields`, `operation`,
`order_by`, and `order_by_direction`. The specification's empty `filters: {}` is
accepted as an alias for `[]`; nonempty hashes are rejected rather than guessed.

```ruby
api.clients.search(
  company_id: 123,
  filters: [{ type: "id", state: { value: [456] } }],
  fields: ["id", "name"]
)
```

Client search uses `POST /company/{company_id}/clients/search` with `page_size`.
Records and companies use `page` and `count`. Services and staff use the current
`/company/{company_id}/services/` and `/company/{company_id}/staff/` routes.
Permissions map `groups` to `group_permissions[]`.

These adapters follow the [official REST reference](https://developers.yclients.com/ru/)
and, for permission groups, the [Apiary reference](https://yclientsru.docs.apiary.io/reference/5/0/0).
Live verification is still required before release. Endpoint size limits apply;
client search rejects `per_page > 200` (the documented maximum), and records default to 300.

## Authentication endpoint

```ruby
result = base.auth.authorize(login: "test-account-login", password: "test-account-password")
token = result.user_token
authenticated = base.with_user_token(token) if token
```

Passwords and credentials are not cached or logged. Authorization does not mutate
the client. Accounts with 2FA can receive a challenge instead of a token:
`result.user_token` is then `nil`, and `result.data` preserves the challenge.
Completing a 2FA challenge is not supported by the current resource API.

## Responses and pagination

```ruby
response = api.records.retrieve(company_id: 123, record_id: 789)
response.data[:id]
response.meta
response.status
response.headers["content-type"]
response.payload # complete parsed JSON, including unknown envelope fields
```

JSON keys are recursively symbolized. Nested hashes, arrays, scalars, booleans,
and nulls are preserved. Dates in responses remain strings. Resource methods
accept `Date`, `Time`, `DateTime`, and strings as date parameters: dates serialize
to `YYYY-MM-DD`, times to ISO 8601. The gem does not apply a timezone policy.

```ruby
page = api.records.list(company_id: 123, page: 1, per_page: 300)
page.items
page.next_page?

api.records.each_page(company_id: 123) do |batch|
  puts batch.items.length
end

records = api.records.each(company_id: 123, start_date: Date.new(2025, 1, 1), end_date: Date.today)
records.lazy.select { |record| record[:client] }.take(100).each { |record| puts record[:id] }
```

`records`, `clients`, and `companies` provide `each` and `each_page`, returning an
Enumerator without a block. They request one page at a time and stop immediately
when the consumer stops. Memory use is bounded by a page unless the caller collects
the results. There is no `all` method.

Client search uses `meta.total_count` as the documented overall result count.
Companies use this field when supplied and otherwise use page length. Records
always use page length: their reference describes `total_count` ambiguously as
the number of records on the page, so it is not used to stop iteration.
A full page indicates that another page may exist; a short or empty page stops
this fallback. An exactly full final page therefore needs one extra empty-page
request. `meta.count` is not treated as a global total. Original metadata is
preserved unchanged in all responses. Live verification of records metadata
remains a release requirement.
Services and staff return a Page representing one unpaginated collection, with
`next_page? == false`. The gem cannot make a changing dataset into a snapshot.

## Errors and retries

```ruby
begin
  api.records.retrieve(company_id: 123, record_id: 789)
rescue Yclients::RateLimitError => error
  retry_after = error.response_headers["retry-after"]
  # Schedule a later application-level attempt if appropriate.
rescue Yclients::ApiError => error
  warn "YCLIENTS HTTP #{error.status}"
end
```

```
Yclients::Error
  ConfigurationError
  TransportError
    ConnectionError
    TimeoutError
  ResponseError
    ParseError
  ApiError
    AuthenticationError  # 401
    ForbiddenError       # 403
    NotFoundError        # 404
    ValidationError      # 400, 422
    RateLimitError       # 429
    ServerError          # 5xx
```

API errors expose `status`, `method` (symbol), `path`, `response_body` (raw string),
`response_headers`, and `details` (parsed `meta`). HTTP 200 with `success: false`
also raises ApiError. Non-JSON error pages keep their HTTP error classification;
invalid JSON on a successful response raises ParseError. Error messages omit
response contents; diagnostic fields may contain personal data and must be handled
by the application accordingly.

Only GET and HEAD retry, at most twice, after connection failures, timeouts, or
HTTP 429/502/503/504. Backoff includes jitter: 0.25-0.5 seconds before the first
retry and 0.5-1 second before the second. `Retry-After` remains available to the
caller; the built-in bounded policy does not wait for arbitrarily long values.
POST, PUT, PATCH, and DELETE never retry automatically, including POST client search.
Timeouts apply to each attempt. There is no distributed or process-wide rate limiter.

## Logging and transport customization

By default nothing is logged. With a logger supporting `info`, the client emits
method, sanitized path, status, duration in seconds, and retry count for each attempt.
Unknown path segments and identifiers become `:redacted`. Headers, query values,
bodies, credentials, passwords, and network exception messages are never logged.
A logger failure does not change the HTTP result or cause a retry.

For tests or an alternate HTTP implementation, pass a transport factory:

```ruby
api = Yclients::Client.new(
  partner_token: "test-token",
  transport: ->(configuration) { MyTransport.new(configuration) }
)
```

It must return an object implementing `request(method, path, params: {}, body: nil)`
and returning `Yclients::Response`. The factory is called again for derived tenant
clients. A replacement transport owns HTTP authentication, normalization, errors,
timeouts, and retries; resource classes never depend directly on Faraday.

## Development and release validation

To work on the gem itself, run these commands from the repository root:

```sh
bundle install
bundle exec rspec
bundle exec rubocop
bundle exec rake signatures
bundle exec rake
```

To build the distributable `.gem` package:

```sh
gem build yclients.gemspec
```

The gem ships RBS signatures in `sig/` for the client, resources, responses,
errors, and custom transport interface. Load the `date` standard library
signatures when using them with a type checker. `rake signatures` validates the
declarations; it does not statically type-check the Ruby implementation.
The default Rake task includes this validation in CI.

Formatting uses `rubocop-shopify` 2.18 with RuboCop 1.90. Shopify 3.x requires
Ruby >= 3.3; the 2.x preset keeps development compatible with our Ruby 3.2 minimum.
RuboCop stays below 1.91 because that version removed a cop referenced by the
2.x preset. The project configuration only sets the target Ruby version and
excludes vendored dependencies.

The regular suite uses WebMock with network access disabled and excludes
`spec/integration`. The fixture suite uses sanitized examples from the official
reference; [fixture provenance](spec/fixtures/README.md) distinguishes them from
live captures. CI tests Ruby 3.2, 3.3, 3.4, and 4.0 without API secrets.

The RubyGems API returned HTTP 404 for both `yclients` and `yclients-ruby` on
2026-10-05; neither name was found, and neither has been reserved by this project.
Recheck immediately before publishing. Live test-account responses and sanitized
captures are still missing, so 0.1.0 remains unreleased.

Run live contracts explicitly against a dedicated test account:

Copy `.env.example` to `.env.local` and fill in the test account credentials.
From the repository root, load the file before running the suite:

```sh
set -a
source .env.local
set +a
bundle exec rspec spec/integration
```

`.env.local` is ignored by Git. Keep actual credentials out of fixtures and commits.

Missing credentials produce explicit pending examples. Retrieval checks require
clients, services, staff, and records in the test account; client pagination needs
at least two clients. Records default to the past month; override with
`YCLIENTS_START_DATE` and `YCLIENTS_END_DATE`. Optional `YCLIENTS_LOGIN` and
`YCLIENTS_PASSWORD` enable `/auth` checks. The suite reads data and performs search;
it does not create business entities or save response bodies.

Live contracts currently run locally using the command above. No release
readiness claim is made until live contracts and sanitized test-account captures
have been reviewed. See [examples](examples/) and [CHANGELOG](CHANGELOG.md).

Finance, payroll, goods, loyalty, analytics, webhook receivers and registration,
and application synchronization are outside v0.1. Supported operations are exposed
through resource methods; adding another endpoint requires a resource adapter.
The gem follows SemVer: patches preserve the public API; 0.x can evolve before 1.0.

## License

[MIT](LICENSE.txt).
