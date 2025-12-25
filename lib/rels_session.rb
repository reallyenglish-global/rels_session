# frozen_string_literal: true

require "bigdecimal"
require "dry-struct"
require "dry-schema"
require "redis"
require "connection_pool"
require "mutex_m"
require "base64"
require "action_dispatch"
require "oj"

require_relative "redis_pool"
require_relative "rels_session/version"
require_relative "rels_session/types"
require_relative "rels_session/session_store"
require_relative "rels_session/session_meta"
require_relative "rels_session/sessions_manager"
require_relative "rels_session/user_sessions"
require_relative "rels_session/serializer"
require_relative "rels_session/stats"

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

    DEFAULT_SCAN_COUNT = 50
    DEFAULT_SERIALIZER = :json

    def redis
      @redis ||= pool
    end

    def store
      SessionStore.instance
    end

    def namespace
      Settings.session_store.redis_options.namespace || DEFAULT_REDIS_OPTIONS.fetch(:namespace)
    end

    def sessions
      SessionStore.sessions
    end

    def stream_sessions(batch_size: scan_count=DEFAULT_SCAN_COUNT)
      raise ArgumentError, "block required" unless block_given?

      store = SessionStore.instance
      batch = []

      process_batch = lambda do |keys|
        next if keys.empty?

        payloads = redis.then { |r| r.mget(*keys) }
        payloads.each do |payload|
          next unless payload
          yield serializer.load(payload)
        end
      end

      store.list_sessions(stream: true) do |key|
        batch << key
        next if batch.size < batch_size

        process_batch.call(batch)
        batch.clear
      end

      process_batch.call(batch)
    end

    def user_sessions
      UserSessions.list
    end

    def pool
      options = redis_options
      options.delete(:namespace)
      RedisPool.new(pool_options, options)
    end

    def scan_count
      count = ENV.fetch("RELS_SESSION_SCAN_COUNT", DEFAULT_SCAN_COUNT).to_i
      return DEFAULT_SCAN_COUNT if count <= 0

      count
    end

    def serializer
      @serializer ||= begin
        backend = ENV.fetch("RELS_SESSION_SERIALIZER", DEFAULT_SERIALIZER).to_sym
        Serializers.for(backend)
      rescue ArgumentError
        Serializers.for(DEFAULT_SERIALIZER)
      end
    end

    def serializer=(backend)
      @serializer =
        if backend.respond_to?(:dump) && backend.respond_to?(:load)
          backend
        else
          Serializers.for(backend)
        end
    end

    def stats
      @stats ||= Stats.new
    end

    def reconcile_stats!
      stats.reconcile!
    end

    def pool_options
      DEFAULT_POOL_OPTIONS.merge(
        Settings.session_store.connection_pool_options || {}
      )
    end

    def redis_options
      opts = DEFAULT_REDIS_OPTIONS.merge(Settings.session_store.redis_options.to_h)

      uri = URI(Settings.session_store.redis_options.url)

      if uri.scheme == "redis+sentinel"
        path = uri.path
        _, name, db = path.split("/")
        opts[:name] = name
        opts[:db] = db
        opts[:url] = "redis:/#{path}"
        opts[:sentinels] = [{ host: uri.host, port: uri.port }]
      end

      opts
    end
  end

  SessionStoreConfigSchema = Dry::Schema.Params do
    optional(:application_name).filled(:string)
    required(:redis_options).hash do
      required(:url).filled(:string)
      required(:namespace).filled(:string)
    end
  end
end
