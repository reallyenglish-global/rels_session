module RelsSession
  class SessionStore < ActionDispatch::Session::AbstractSecureStore
    CLIENT_APPLICATIONS = %w/Rex Turtle WmApi Wfb N2r/

    DEFAULT_OPTIONS = {
      key: 'rels_session',
      expires_after: 2.hours
    }

    def initialize(app, options = {})
      options = DEFAULT_OPTIONS.merge(options)
      @redis = AuthService.redis

      @redis.then do |r|
        r.sadd(shared_context_key, Rails.application.class.name.split("::").first)
      end

      @ttl = options.fetch(:expires_after)
      @namespace = AuthService.namespace

      super
    end

    def find_session(_, session_id)
      unless session_id && (session = get_session(session_id))
        session_id = generate_sid
        session = '{}'
      end

      [session_id, JSON.parse(session).deep_symbolize_keys.with_indifferent_access]
    end

    def write_session(_, session_id, session, _)
      keys = store_keys(session_id)

      if session
        keys.each do |key|
          @redis.then { |r| r.set(key, session.to_json, ex: @ttl) }
        end
      else
        @redis.then {|r| r.del(*keys) }
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

    def get_session(session_id)
      @redis.then do |r|
        r.mget(*store_keys(session_id)).compact.first
      end
    end

    def store_key(id)
      [@namespace, id].join(':')
    end

    def store_keys(session_id)
      ids = [session_id.private_id, session_id.public_id]

      # Favour lookup on public_key until secure_store suported_by_all?
      ids.reverse unless secure_store?

      ids.map {|id| store_key(id)}
    end

    def secure_store?
      using_secure_store = @redis.then {|r| r.smembers(shared_context_key)}
      (CLIENT_APPLICATIONS - using_secure_store).empty?
    end

    def shared_context_key
      [@namespace, Rack::Session::SessionId::ID_VERSION, "active_applications"].join(':')
    end
  end
end
