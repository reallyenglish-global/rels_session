# frozen_string_literal: true

module RelsSession
  class Stats
    def initialize(redis: RelsSession.redis, namespace: RelsSession.namespace)
      @redis = redis
      @namespace = namespace
    end

    def increment_total_sessions(by = 1)
      delta = by.to_i
      return if delta <= 0

      @redis.then do |r|
        r.multi do |m|
          m.incrby(total_sessions_key, delta)
          m.set(last_updated_key, Time.now.to_i)
        end
      end
    end

    def decrement_total_sessions(by = 1)
      delta = by.to_i
      return if delta <= 0

      @redis.then do |r|
        r.multi do |m|
          m.decrby(total_sessions_key, delta)
          m.set(last_updated_key, Time.now.to_i)
        end
      end
    end

    def totals
      @redis.then do |r|
        total = r.get(total_sessions_key)
        updated = r.get(last_updated_key)
        {
          total_sessions: [total.to_i, 0].max,
          last_updated_at: updated && Time.at(updated.to_i)
        }
      end
    end

    def reconcile!
      total_keys = 0
      pattern = "#{@namespace}:2::*"

      @redis.then do |r|
        cursor = "0"
        begin
          cursor, keys = r.scan(cursor, match: pattern, count: RelsSession.scan_count)
          total_keys += keys.size
        end while cursor != "0"

        r.multi do |m|
          m.set(total_sessions_key, total_keys)
          m.set(last_updated_key, Time.now.to_i)
        end
      end
    end

    private

    attr_reader :redis, :namespace

    def total_sessions_key
      [namespace, "stats", "total_sessions"].join(":")
    end

    def last_updated_key
      [namespace, "stats", "last_updated_at"].join(":")
    end
  end
end
