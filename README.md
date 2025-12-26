# RelsSession

Shared session store, metadata and helper APIs for ReallyEnglish applications. The gem exposes `ActionDispatch` storage compatible with `Rack::Session::SessionId`, and utilities to introspect and manage user sessions that are persisted in Redis.

## Key features

- `RelsSession::SessionStore` — drop-in Rails session store backed by Redis with dual public/private session id support.
- `RelsSession::SessionMeta` — typed metadata persisted with each session.
- `RelsSession::SessionsManager` — helper object that can list, revoke and record active sessions per user.
- `RelsSession::SessionStoreConfigSchema` — Dry Schema that can be plugged into `Config` to enforce settings at boot.

## Installation

Add the gem to your Rails application:

```ruby
# Gemfile
gem "rels_session", github: "reallyenglish-global/rels-session"
```

Run `bundle install`, then configure Rails to use the store:

```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store(RelsSession::SessionStore)
```

## Configuration

The gem expects a global `Settings.session_store` object (for example via the [`config`](https://github.com/rubyconfig/config) gem) that describes the Redis cluster and the canonical application name.

```ruby
# config/settings.yml
session_store:
  application_name: Turtle
  redis_options:
    url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/4" } %>
    namespace: "rels:session"
  connection_pool_options:
    size: 20
    timeout: 5
```

You can reuse the schema to validate the structure early:

```ruby
# config/initializers/config.rb
Config.setup do |config|
  config.schema do
    required(:session_store).hash(RelsSession::SessionStoreConfigSchema)
  end
end
```

### Optional environment variables

- `RELS_SESSION_SCAN_COUNT` — overrides the number of keys fetched per SCAN iteration (default `50`).
- `RELS_SESSION_SERIALIZER` — choose `json` (default) or `oj` to control how session payloads are encoded and decoded. The Oj serializer is optional; set the env var only if you want the faster C-backed implementation.

## Managing sessions

Recording an authenticated request from a controller:

```ruby
RelsSession::SessionsManager.record_authenticated_request(
  current_user,
  request,
  session_key_type: :cookie,
  expires_after: 2.weeks,
  sign_in_at: Time.zone.now
)
```

`record_authenticated_request` enriches the session metadata with the mobile headers we already emit from the apps (`AppVersion`, `X-INSTALLATION-ID`, `X-DEVICE`, `X-COURSE-ID`) and will fall back to `session["course_uuid"]`/`session["course_id"]` when those headers are absent. It also sets `client_platform` to `ios_app`, `android_app`, `mobile_web`, or `web` so downstream dashboards can quickly segment where a session originated. Consumers of `SessionMeta` can rely on these attributes being present (or `nil`) when displaying active sessions or debugging login issues.

Listing active sessions for a user:

```ruby
RelsSession::SessionsManager.active_sessions(current_user).each do |session|
  puts "Session #{session.public_session_id} from #{session.ip}"
end
```

Revoking a specific session id:

```ruby
RelsSession::SessionsManager.logout_session(current_user, params[:session_id])
```

## Development

1. Install dependencies with `bin/setup`.
2. Make sure a Redis instance is available (default `REDIS_URL=redis://localhost:6379/4`).
3. Run the test suite via `bundle exec rspec`.
4. Use `bin/console` for an interactive sandbox.

The specs flush the configured Redis database before and after each example, so keep a dedicated DB for development/testing.

### Testing feature branches in an app

Before cutting a release, point your downstream Rails app at the feature branch to exercise the changes end-to-end:

```ruby
# Gemfile
gem "rels_session", github: "reallyenglish-global/rels-session", branch: "feat/session-stats"
```

Run `bundle install`, then execute your app’s test suite and any manual smoke tests. Once satisfied, revert to the main branch reference (or a tagged release) and publish the gem.

### Runtime stats

To avoid scanning Redis for basic counts, the gem maintains lightweight counters under `<namespace>:stats:*`. You can access them via:

```ruby
RelsSession.stats.totals
# => { total_sessions: 42, last_updated_at: 2024-06-01 12:34:56 +0000 }
```

Counters update automatically when sessions are added or removed through `UserSessions`.
For reconciliation, call `RelsSession.reconcile_stats!` (e.g., via a periodic job or manual trigger) to rescan Redis and rebuild totals when needed.

## Performance considerations

- `SessionStore#secure_store?` caches membership checks for 60 seconds to avoid an extra `SMEMBERS` round-trip on every session read/write and persists a Redis flag (`<namespace>:<id_version>:secure_store_enabled`) so each process can quickly check readiness.
- `SessionsManager.active_sessions` now tolerates string-keyed JSON payloads and fills in default values before instantiating `SessionMeta`, preventing unnecessary exceptions when metadata is sparse.
- When scanning Redis (`list_sessions`, `UserSessions.list`), the default `count` is 50 (override with `RELS_SESSION_SCAN_COUNT`) to cut round trips; tune it if you operate in much larger clusters.
- `SessionsManager` reuses the memoized `RelsSession.store` and leverages `SessionStore#find_sessions` to fetch all of a user’s sessions in a single Redis round-trip.
- `SessionStore#peek_session` returns the raw JSON payload and avoids parsing when callers only need metadata summaries.
- `RedisPool#with` uses jittered exponential backoff when reconnecting to Redis to reduce coordinated sleeps across threads.
- `SessionStore#write_session` pipelines mirrored key updates and `#find_sessions` deduplicates keys before `MGET`, trimming Redis chatter.
- `secure_store?` only rewrites the enablement flag once per TTL to avoid hot loops when public IDs are in heavy use.
- `SessionsManager#logout_all_sessions` removes session keys in bulk via `SessionStore#delete_sessions`, reducing the number of Redis calls.
- `SessionStore.list_sessions` and `UserSessions.list` accept `stream: true` to yield keys lazily for large scans.
- `SessionsManager.logout_sessions(user, ids)` combines `delete_sessions` with pipelined `SREM`s via `UserSessions#remove_all` for targeted bulk logouts.
- `RelsSession.store` is a shared singleton, so processes reuse the same connection pool and secure-store cache instead of instantiating new stores.
- All Redis hot paths (writes, deletes, session fetches) now use pipelining or bulk commands to minimize round trips.
- `RedisPool#with` instruments retries with jitter and short-lived circuit breaking to protect the app when Redis is unavailable.
- `RelsSession.stream_sessions(batch_size: 100) { |meta| ... }` streams all session metadata in batches, which is useful for dashboards that need to inspect every active session without building huge arrays in memory. Tune `batch_size` (defaults to `RELS_SESSION_SCAN_COUNT`) to balance throughput vs. latency.

### Additional tuning ideas

- Consider storing session payloads with a faster encoder (e.g., MessagePack) or optional compression for very large sessions.
- Explore client-side caching (per-thread or per-request) for `find_session` to reduce duplicate Redis reads in hot code paths.
- Turn on Redis client-side caching or replica reads when your deployment supports it to reduce cross-process latency.
- Emit aggregated metrics (counts per namespace/app) so dashboards don’t need to run `SCAN` in production.
- Use `RELS_SESSION_SCAN_COUNT` to tune SCAN behavior per environment; lowering it reduces per-iteration cost, raising it speeds up large scans.

## Working with AI assistants

See `AGENTS.md` for instructions that describe how automated agents should gather context, run tests, and validate changes in this repository.
