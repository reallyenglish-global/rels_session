# frozen_string_literal: true

require_relative "rels_session/version"
require_relative 'rels_session/session_store'
require_relative 'rels_session/session_meta'
require_relative 'rels_session/sessions_manager'
require_relative 'rels_session/user_sessions'

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
      namespace: 'rels:session'
    }.freeze

    DEFAULT_SESSION_OPTIONS = {
      namespace: 'rels_session'
    }.freeze

    def namespace
      DEFAULT_REDIS_OPTIONS.fetch(:namespace)
    end
  end
end
