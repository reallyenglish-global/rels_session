# frozen_string_literal: true

require "rels_session"
require "debug"

module RelsSession
  class SettingsStruct < Dry::Struct
    attribute :session_store do
      attribute :application_name, RelsSession::Types::String.enum(*RelsSession::SessionStore::CLIENT_APPLICATIONS)
      attribute :redis_options do
        attribute :url, RelsSession::Types::String
        attribute :namespace, RelsSession::Types::String
      end

      attribute? :connection_pool_options do
      end
    end
  end
end

unless defined? Settings
  store_config = {
    application_name: "Turtle",
    redis_options: {
      url: ENV["REDIS_URL"] || "redis://localhost:6379/4",
      namespace: ENV["REDIS_NAMESPACE"] || "test:session:namespace"
    }
  }

  Settings = RelsSession::SettingsStruct.new(
    session_store: RelsSession::SessionStoreConfigSchema.call(store_config).to_h
  )
end

RSpec.configure do |config|
  config.before(:suite) do
    raise "Test redis only" unless RelsSession.namespace == "test:session:namespace"

    RelsSession.redis.then(&:flushall)
  end

  config.append_after(:each) do
    RelsSession.redis.then(&:flushall)
  end
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
