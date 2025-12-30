# frozen_string_literal: true

module RelsSession
  # Struct for RelsSession user sessions meta data.
  class SessionMeta < Dry::Struct
    attribute :ip, Types::String
    attribute :browser, Types::String.optional
    attribute :os, Types::String.optional
    attribute :app_version, Types::String.optional
    attribute :device_name, Types::String.optional
    attribute :device_type, Types::String.optional
    attribute :installation_id, Types::String.optional
    attribute :course_id, Types::Coercible::String.optional
    attribute :client_platform, Types::String.optional
    attribute :public_session_id, Types::Coercible::String
    attribute :session_key_type, Types::Coercible::Symbol.enum(*%i[cookie token])
    attribute :created_at, Types::Params::Time.optional
    attribute :updated_at, Types::Params::Time
  end
end
