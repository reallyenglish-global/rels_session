module RelsSession
  class SessionMeta < Dry::Struct
    attribute :ip, Types::String
    attribute :browser, Types::String.optional
    attribute :os, Types::String.optional
    attribute :device_name, Types::String.optional
    attribute :device_type, Types::String.optional
    attribute :public_session_id, Types::Coercible::String
    attribute :session_key_type, Types::Coercible::Symbol.enum(*%i/cookie token/)
    attribute :created_at, Types::Params::Time
    attribute :updated_at, Types::Params::Time
  end
end
