# frozen_string_literal: true

module RelsSession
  # Add and remove user sessions, outside of rails app. Used by session_store
  class UserSessions
    def self.list(stream: false)
      pattern = "#{RelsSession.namespace}:user_sessions:*"

      if stream
        return enum_for(:list, stream: true) unless block_given?

        RelsSession.redis.then do |r|
          cursor = "0"
          begin
            cursor, keys = r.scan(cursor, match: pattern, count: RelsSession.scan_count)
            keys.each { |key| yield key }
          end while cursor != "0"
        end
        return
      end

      sessions = []
      RelsSession.redis.then do |r|
        cursor = "0"
        begin
          cursor, keys = r.scan(cursor, match: pattern, count: RelsSession.scan_count)
          sessions.concat(keys)
        end while cursor != "0"
      end
      sessions
    end

    def initialize(user_uuid, options = {})
      @key = [RelsSession.namespace, "user_sessions", user_uuid].join(":")
      @redis = RelsSession.redis
      # Two weeks by default
      @ttl = options.fetch(:expires_after, 2 * 7 * 24 * 60 * 60)
    end

    def add(session_id)
      @redis.then do |r|
        r.multi do |m|
          m.sadd?(key, session_id)
          m.expire(key, @ttl)
        end
      end
    end

    def remove(session_id)
      @redis.then { |r| r.srem(key, session_id) }
    end

    def list
      @redis.then { |r| r.smembers(key) }
    end

    def clear
      @redis.then { |r| r.del(key) }
    end

    private

    attr_reader :key
  end
end
