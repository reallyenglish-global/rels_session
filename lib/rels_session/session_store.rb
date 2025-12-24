# frozen_string_literal: true

module RelsSession
  # Drop in session store for Reallyenglish rails apps.
  class SessionStore < ActionDispatch::Session::AbstractSecureStore
    CLIENT_APPLICATIONS = %w[Rex Turtle Wfb N2r].freeze

    DEFAULT_OPTIONS = {
      key: "rels_session",
      expires_after: 2 * 7 * 24 * 60 * 60
    }.freeze

    SECURE_STORE_CACHE_TTL = 60 # seconds

    def self.sessions
      instance.list_sessions
    end

    def self.instance
      @instance ||= new(nil)
    end

    def initialize(app, options = {})
      options = DEFAULT_OPTIONS.merge(options)

      # private, public, both
      @sid_type = options.fetch(:sid_type, :both).to_sym

      @redis = redis

      @ttl = options.fetch(:expires_after)
      @namespace = RelsSession.namespace

      super
    end

    def find_session(_, session_id)
      unless session_id && (session = get_session(session_id))
        session_id = generate_sid
        session = "{}"
      end

      [session_id, JSON.parse(session)]
    end

    def find_sessions(_, session_ids)
      return [] if session_ids.empty?

      session_key_map = {}
      session_ids.each do |session_id|
        session_key_map[session_id] = store_keys(session_id)
      end
      keys = session_key_map.values.flatten

      key_value_map = {}
      @redis.then do |r|
        next if keys.empty?

        r.mget(*keys).each_with_index do |value, index|
          next unless value

          key_value_map[keys[index]] = value
        end
      end

      session_ids.map do |session_id|
        json = session_key_map.fetch(session_id).lazy.map { |key| key_value_map[key] }.find(&:itself)
        json ? JSON.parse(json) : {}
      end
    end

    def write_session(_, session_id, session, _)
      keys = store_keys(session_id)

      if session
        keys.each do |key|
          @redis.then { |r| r.set(key, session.to_json, ex: @ttl) }
        end
      else
        @redis.then { |r| r.del(*keys) }
      end

      session_id
    end

    def delete_session(_, session_id, _)
      @redis.then do |r|
        r.del(*store_keys(session_id))
      end

      generate_sid
    end

    # Drop in session store for Reallyenglish rails apps.
    def list_sessions
      sessions = []
      pattern = "#{@namespace}:2::*"
      @redis.then do |r|
        cursor = "0"
        begin
          cursor, keys = r.scan(cursor, match: pattern, count: 5)
          sessions += keys
        end while cursor != "0"
      end
      sessions
    end

    private

    def redis
      @redis ||= RelsSession.redis
    end

    def application_name
      Settings.session_store.application_name || Rails.application.class.name.split("::").first
    end

    def get_session(session_id)
      @redis.then do |r|
        r.mget(*store_keys(session_id)).compact.first
      end
    end

    def store_key(id)
      [@namespace, id].join(":")
    end

    def store_keys(session_id)
      ids =
        if use_private_id?
          [session_id.private_id]
        elsif use_public_id?
          [session_id.public_id]
        elsif secure_store?
          # SessionId#private_id and #public_id
          [session_id.private_id, session_id.public_id]
        else
          # Favour lookup on public_key until secure_store suported_by_all?
          [session_id.public_id, session_id.private_id]
        end

      ids.map { |id| store_key(id) }
    end

    def secure_store?
      cache_valid = @secure_store_cached_at &&
                    (Time.now - @secure_store_cached_at) < SECURE_STORE_CACHE_TTL

      if cache_valid && !@secure_store_cached_value.nil?
        return @secure_store_cached_value
      end

      flag_key = secure_store_flag_key

      unless use_private_id?
        @redis.then do |r|
          r.set(flag_key, Time.now.to_i, ex: SECURE_STORE_CACHE_TTL, nx: true)
        end
      end

      cached_value = @redis.then { |r| r.exists?(flag_key) }
      @secure_store_cached_value = cached_value
      @secure_store_cached_at = Time.now
      cached_value
    end

    def secure_store_flag_key
      [@namespace, Rack::Session::SessionId::ID_VERSION, "secure_store_enabled"].join(":")
    end

    def use_private_id?
      @sid_type == :private_id
    end

    def use_public_id?
      @sid_type == :public_id
    end

    def use_both?
      @sid_type == :both
    end

    def shared_context_key
      [@namespace, Rack::Session::SessionId::ID_VERSION, "active_applications"].join(":")
    end
  end
end
