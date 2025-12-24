class RedisPool
  MAX_RETRIES = 3
  BACKOFF_BASE = 0.5 # seconds
  BACKOFF_MAX = 5 # seconds

  def initialize(pool_options, redis_options)
    @pool = ConnectionPool.new(pool_options) do
      ::Redis.new(redis_options)
    end
  end

  def with
    retries = 0

    @pool.with do |redis|
      begin
        yield(redis)
      rescue RedisClient::FailoverError, RedisClient::CannotConnectError => e
        retries += 1
        if retries <= MAX_RETRIES
          warn "[RedisPool] Redis connection lost: #{e.class} #{e.message}. Reconnecting (attempt #{retries})..."
          sleep jitter_backoff(retries)
          reconnect(redis)
          retry
        else
          raise e
        end
      end
    end
  end

  private

  def reconnect(redis)
    redis.close # Properly close the broken connection
    # No need to create new object — ConnectionPool will reinitialize next checkout
  end

  def jitter_backoff(retries)
    base = [BACKOFF_BASE * (2**(retries - 1)), BACKOFF_MAX].min
    rand(base..(base + BACKOFF_BASE))
  end

  def method_missing(method, *args, **kwargs, &block)
    with do |redis|
      redis.public_send(method, *args, **kwargs, &block)
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    ::Redis.instance_methods.include?(method_name) || super
  end
end
