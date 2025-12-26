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
            installation_id: nil,
            course_id: nil,
            client_platform: nil,
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

        app_version = request_header(request, "AppVersion", "APP_VERSION", "appversion")
        device_header = request_header(request, "X-DEVICE")
        device_name = device_header || device.device_name
        installation_id = request_header(request, "X-INSTALLATION-ID")
        course_id = request_header(request, "X-COURSE-ID") || session_course_id(session)
        client_platform = determine_client_platform(device, installation_id, device_header)

        meta = RelsSession::SessionMeta.new(
          ip: request_ip(request),
          browser: device.name,
          os: device.os_name,
          app_version: app_version,
          device_name: device_name,
          device_type: device.device_type,
          installation_id: installation_id,
          course_id: course_id,
          client_platform: client_platform,
          public_session_id: session.id.public_id,
          session_key_type: options.fetch(:session_key_type, :cookie),
          created_at: options.fetch(:sign_in_at, nil),
          updated_at: Time.zone.now
        )

        session[:meta] = meta.to_h

        RelsSession::UserSessions.new(user.uuid, options.slice(:expires_after)).add(request.session.id.public_id)
      end

      def record_logout_request(user, request)
        new(user).logout_session(request.session.id)
      end

      private

      def request_header(request, *keys)
        headers = request_headers(request)
        env = request_env(request)

        keys.each do |key|
          header_key = normalize_header_key(key)

          if headers
            value = presence(headers[header_key]) || presence(headers[header_key.downcase]) || presence(headers[header_key.upcase])
            return value if value
          end

          env_key = normalize_env_key(key)
          value = env && presence(env[env_key])
          return value if value
        end

        nil
      end

      def session_course_id(session)
        [
          "course_uuid",
          :course_uuid,
          "course_id",
          :course_id
        ].each do |key|
          value = session_value(session, key)
          return value if value
        end

        nil
      end

      def request_ip(request)
        remote_ip = begin
          request.remote_ip if request.respond_to?(:remote_ip)
        rescue NoMethodError
          nil
        end

        presence(remote_ip) || request.ip
      end

      def session_value(session, key)
        return unless session.respond_to?(:[])

        presence(session[key])
      rescue KeyError, NoMethodError
        nil
      end

      def request_env(request)
        return {} unless request.respond_to?(:env)

        request.env
      rescue NoMethodError
        {}
      end

      def request_headers(request)
        return unless request.respond_to?(:headers)

        request.headers
      rescue NoMethodError
        nil
      end

      def normalize_header_key(key)
        key.to_s.tr("_", "-")
      end

      def normalize_env_key(key)
        normalized = key.to_s.upcase.tr("-", "_")
        normalized.start_with?("HTTP_") ? normalized : "HTTP_#{normalized}"
      end

      def presence(value)
        return nil if value.nil?
        return nil if value.respond_to?(:empty?) && value.empty?

        value
      end

      def determine_client_platform(device, installation_id, device_header)
        if installation_id
          return "ios_app" if ios_device?(device, device_header)
          return "android_app" if android_device?(device, device_header)
          return "mobile_app"
        end

        mobile_types = %w[smartphone tablet phablet]
        return "mobile_web" if mobile_types.include?(device.device_type)

        "web"
      end

      def ios_device?(device, device_header)
        tokens = [device.os_name, device_header]
        tokens.any? { |value| contains_any?(value, %w[ios iphone ipad]) }
      end

      def android_device?(device, device_header)
        tokens = [device.os_name, device_header]
        tokens.any? { |value| contains_any?(value, %w[android]) }
      end

      def contains_any?(value, needles)
        value = presence(value)
        return false unless value

        normalized = value.downcase
        needles.any? { |needle| normalized.include?(needle) }
      end
    end
  end
end
