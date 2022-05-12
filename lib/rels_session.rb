# frozen_string_literal: true

require "dry-struct"
require "redis"
require "connection_pool"
require "action_dispatch"

require_relative "rels_session/version"
require_relative "rels_session/types"
require_relative "rels_session/session_store"
require_relative "rels_session/session_meta"
require_relative "rels_session/sessions_manager"
require_relative "rels_session/user_sessions"

# Connect and manage user sessions across RE rails apps.
module RelsSession
  class Error < StandardError; end

  class << self
    DEFAULT_POOL_OPTIONS = {
      size: 20,
      timeout: 5
    }.freeze

    DEFAULT_REDIS_OPTIONS = {
      connect_timeout: 20,
      read_timeout: 1,
      write_timeout: 1,
      reconnect_attempts: 1,
      namespace: "rels:session"
    }.freeze

    DEFAULT_SESSION_OPTIONS = {
      namespace: "rels_session"
    }.freeze

    def redis
      @redis ||= pool
    end

    def namespace
      Settings.session_store.redis_options.namespace || DEFAULT_REDIS_OPTIONS.fetch(:namespace)
    end

    def pool
      ConnectionPool.new(pool_options) do
        ::Redis.new(redis_options)
      end
    end

    def pool_options
      DEFAULT_POOL_OPTIONS.merge(
        Settings.session_store.connection_pool_options || {}
      )
    end

    def redis_options
      opts = DEFAULT_REDIS_OPTIONS.merge(Settings.session_store.redis_options)

      uri = URI(Settings.session_store.redis_options.url)

      if uri.scheme == "redis+sentinel"
        opts[:url] = "redis:/#{uri.path}"
        opts[:sentinels] = [{ host: uri.host, port: uri.port }]
      end

      opts
    end
  end
end
