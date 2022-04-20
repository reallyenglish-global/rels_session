class RelsSession::UserSessions
  def initialize(user_uuid)
    @key = [RelsSession.namespace, 'user_sessions', user_uuid].join(":")
    @redis = RelsSession.redis
    @ttl = 2.weeks
  end

  def add(session_id)
    @redis.then do |r|
      r.multi do |m|
        m.sadd(key, session_id)
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
    @redis.then {|r| r.del(key) }
  end

  private

  attr_reader :key
end
