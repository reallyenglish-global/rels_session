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
      @session_store = RelsSession::SessionStore.new(nil, {})
    end

    def logout_session(session_id)
      @session_store.delete_session(nil, session_id, nil) if user_sessions.remove(session_id.public_id)
    end

    def logout_all_sessions
      user_session_ids.each do |session_id|
        @session_store.delete_session(nil, session_id, nil)
      end

      user_sessions.clear
    end

    def active_sessions
      sessions.reject(&:empty?)
    end

    def sessions
      user_session_ids.map do |session_id|
        @session_store.find_session(
          nil, session_id
        ).last
      end
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

      def active_sessions(user)
        new(user).active_sessions.map do |session|
          RelsSession::SessionMeta.new(session[:meta].symbolize_keys)
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
