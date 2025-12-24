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

## Performance considerations

- `SessionStore#secure_store?` caches membership checks for 60 seconds to avoid an extra `SMEMBERS` round-trip on every session read/write and persists a Redis flag (`<namespace>:<id_version>:secure_store_enabled`) so each process can quickly check readiness.
- `SessionsManager.active_sessions` now tolerates string-keyed JSON payloads and fills in default values before instantiating `SessionMeta`, preventing unnecessary exceptions when metadata is sparse.
- When scanning Redis (`list_sessions`, `UserSessions.list`), the default `count` is 50 (override with `RELS_SESSION_SCAN_COUNT`) to cut round trips; tune it if you operate in much larger clusters.
- `SessionsManager` reuses the memoized `RelsSession.store` and leverages `SessionStore#find_sessions` to fetch all of a user’s sessions in a single Redis round-trip.
- `SessionStore#peek_session` returns the raw JSON payload and avoids parsing when callers only need metadata summaries.
- `RedisPool#with` uses jittered exponential backoff when reconnecting to Redis to reduce coordinated sleeps across threads.
- `SessionStore#write_session` pipelines mirrored key updates and `#find_sessions` deduplicates keys before `MGET`, trimming Redis chatter.
- `secure_store?` only rewrites the enablement flag once per TTL to avoid hot loops when public IDs are in heavy use.

### Additional tuning ideas

- Batch logout flows (`SessionsManager#logout_all_sessions`) by pipelining the `DEL`/`SREM` operations.
- Parse session JSON with `symbolize_names: true` when possible so downstream callers do less conversion.
- Expose streaming enumerators for `list_sessions`/`UserSessions.list` when callers only need aggregate data.
- Consider providing an opt-in pipeline for logout operations that need to touch dozens of keys.
- Batch logout flows (`SessionsManager#logout_all_sessions`) by pipelining the `DEL`/`SREM` operations.
- Parse session JSON with `symbolize_names: true` when possible so downstream callers do less conversion.
- Expose streaming enumerators for `list_sessions`/`UserSessions.list` when callers only need aggregate data.

## Working with AI assistants

See `AGENTS.md` for instructions that describe how automated agents should gather context, run tests, and validate changes in this repository.
