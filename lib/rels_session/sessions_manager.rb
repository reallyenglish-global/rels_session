# frozen_string_literal: true

require "device_detector"

module RelsSession
  # View and manage Reallyenglish user sessions.
  class SessionsManager
    def self.for(user)
      new(user)
    end

    def initialize(user)
      @user = user
      @user_sessions = RelsSession::UserSessions.new(user.uuid)
      @session_store = RelsSession.store
    end

    def logout_session(session_id)
      @session_store.delete_session(nil, session_id, nil) if user_sessions.remove(session_id.public_id)
    end

    def logout_all_sessions
      ids = user_session_ids
      @session_store.delete_sessions(nil, ids)
      user_sessions.remove_all(ids.map(&:public_id))
      user_sessions.clear
    end

    def active_sessions
      sessions.reject(&:empty?)
    end

    def sessions
      session_ids = user_session_ids
      @session_store.find_sessions(nil, session_ids)
    end

    def logout_sessions(session_ids)
      @session_store.delete_sessions(nil, session_ids)
      user_sessions.remove_all(session_ids.map(&:public_id))
    end

    private

    def user_session_ids
      user_sessions.list.map do |public_id|
        Rack::Session::SessionId.new(public_id)
      end
    end

    attr_reader :user, :user_sessions

    class << self
      def logout_all_sessions(user)
        new(user).logout_all_sessions
      end

      def logout_session(user, public_session_id)
        session_id = Rack::Session::SessionId.new(public_session_id)

        new(user).logout_session(session_id)
      end

      def logout_sessions(user, public_session_ids)
        session_ids = Array(public_session_ids).map { |public_id| Rack::Session::SessionId.new(public_id) }
        new(user).logout_sessions(session_ids)
      end

      def active_sessions(user)
        new(user).active_sessions.filter_map do |session|
          meta = session["meta"] || session[:meta]
          next unless meta

          attributes = if meta.respond_to?(:symbolize_keys)
                         meta.symbolize_keys
                       else
                         meta.transform_keys(&:to_sym)
                       end

          with_defaults = {
            ip: nil,
            browser: nil,
            os: nil,
            app_version: nil,
            device_name: nil,
            device_type: nil,
            public_session_id: nil,
            session_key_type: :cookie,
            created_at: nil,
            updated_at: nil
          }.merge(attributes)

          RelsSession::SessionMeta.new(with_defaults)
        end
      end

      def record_authenticated_request(user, request, options = {})
        # nil user_agent blow up specs with DeviceDetector 1.1.0
        # https://github.com/podigee/device_detector/issues/104
        device = DeviceDetector.new(request.user_agent || "")
        session = request.session

        meta = RelsSession::SessionMeta.new(
          ip: request.ip,
          browser: device.name,
          os: device.os_name,
          app_version: request.env["HTTP_APP_VERSION"],
          device_name: device.device_name,
          device_type: device.device_type,
          public_session_id: session.id.public_id,
          session_key_type: options.fetch(:session_key_type, :cookie),
          created_at: options.fetch(:sign_in_at, nil),
          updated_at: Time.zone.now
        )

        session[:meta] = meta

        RelsSession::UserSessions.new(user.uuid, options.slice(:expires_after)).add(request.session.id.public_id)
      end

      def record_logout_request(user, request)
        new(user).logout_session(request.session.id)
      end
    end
  end
end
