# frozen_string_literal: true

module RelsSession
  # Drop in session store for Reallyenglish rails apps.
  class SessionStore < ActionDispatch::Session::AbstractSecureStore
    CLIENT_APPLICATIONS = %w[Rex Turtle WmApi Wfb N2r].freeze

    DEFAULT_OPTIONS = {
      key: "rels_session",
      expires_after: 2 * 7 * 24 * 60 * 60
    }.freeze

    def initialize(app, options = {})
      options = DEFAULT_OPTIONS.merge(options)

      # private, public, both
      @use_private_id = options.fetch(:sid_type, :both) == :private_id

      @redis = redis

      unless use_private_id?
        @redis.then do |r|
          r.sadd(
            shared_context_key, application_name
          )
        end
      end

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
      return [session_id.private_id] if use_private_id?

      # SessionId#private_id and #public_id
      ids = [session_id.private_id, session_id.public_id]

      # Favour lookup on public_key until secure_store suported_by_all?
      ids.reverse! unless secure_store?

      ids.map { |id| store_key(id) }
    end

    def secure_store?
      using_secure_store = @redis.then { |r| r.smembers(shared_context_key) }
      (CLIENT_APPLICATIONS - using_secure_store).empty?
    end

    def use_private_id?
      @use_private_id
    end

    def shared_context_key
      [@namespace, Rack::Session::SessionId::ID_VERSION, "active_applications"].join(":")
    end
  end
end
