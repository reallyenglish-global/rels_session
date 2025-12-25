# AI Agent Guide

This document gives automated contributors the minimum information they need to work effectively inside `rels_session`.

## Project map

- `lib/rels_session.rb` wires the gem together and exposes configuration helpers (`redis`, `store`, `namespace`, etc.).
- `lib/rels_session/session_store.rb` is the custom Rails session store; it talks directly to Redis and is latency sensitive.
- `lib/rels_session/sessions_manager.rb` provides helpers to record/logout/list sessions for a `user`.
- `lib/rels_session/user_sessions.rb` maintains the Redis set of public session ids per user.
- `lib/redis_pool.rb` wraps `connection_pool` and handles reconnection.
- Specs live under `spec/`; `spec/spec_helper.rb` bootstraps Redis and Settings for tests.

## Environment & setup

1. Use Ruby `>= 3.0.2`.
2. Ensure a Redis server is running and reachable via `REDIS_URL` (tests default to `redis://localhost:6379/4`; `spec/redis_pool_spec.rb` hits `redis://localhost:6379/0`).
3. Run `bin/setup` to install dependencies.
4. Feature work often requires the Oj gem; `RELS_SESSION_SERIALIZER=oj` switches the serializer.

## Development workflow

- Run `bundle exec rspec` before sending changes; specs flush the configured Redis DB before/after each example.
- Prefer adding or updating tests for any behavioural change (`spec/rels_session/...`).
- Use `bin/console` for manual exploration.
- Keep code Ruby-style guide compliant (Rubocop is available but not enforced in CI; run `bundle exec rubocop` when touching Ruby files).

## Coding guidelines

- Respect the `SessionStoreConfigSchema` contract when changing configuration.
- `SessionsManager` expects `user` objects to expose `uuid`.
- `RelsSession.redis` returns a `RedisPool`; prefer calling Redis commands on the pool directly instead of reimplementing pooling logic.
- Redis keys are namespaced via `RelsSession.namespace`; update specs + docs when adding new prefixes.
- `SessionMeta` serialises via JSON — preserve string keys or explicitly symbolize before consuming.

## Testing expectations

- Tests rely on a clean Redis DB; never point specs at a shared production database.
- Integration-style updates should add an RSpec example demonstrating the scenario.
- When touching Redis reconnect behaviour, extend `spec/redis_pool_spec.rb`.
- After session-related changes, consider reconciling stats by calling `RelsSession.reconcile_stats!` in tests or scripts when appropriate.

## Working style for AI agents

- Gather context with `rg`, `ls`, and targeted file reads; avoid dumping large files into the conversation.
- Explain any non-trivial change in commit messages or PR descriptions; include reproduction steps for bugs.
- Default to non-destructive commands; never wipe user changes.
- When unsure about configuration or new features, add guidance to `README.md` and update this file so future agents have the context you just learned.
