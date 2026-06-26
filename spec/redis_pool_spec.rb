# frozen_string_literal: true

require "spec_helper"
require "redis"
require_relative "../lib/redis_pool"

RSpec.describe RedisPool do
  let(:pool_options) { { size: 2, timeout: 5 } }
  let(:redis_options) { { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") } }
  subject(:redis_pool) { described_class.new(pool_options, redis_options) }

  describe "pool configuration" do
    it "passes pool options to ConnectionPool" do
      pool = redis_pool.instance_variable_get(:@pool)
      expect(pool.size).to eq(2)
    end
  end

  describe "#with" do
    it "successfully sets and gets a key" do
      redis_pool.with do |redis|
        redis.set("test-key", "test-value")
        expect(redis.get("test-key")).to eq("test-value")
      end
    end

    it "retries on RedisClient::CannotConnectError with jittered backoff" do
      called = false
      allow_any_instance_of(Redis).to receive(:set).and_wrap_original do |original, *args|
        unless called
          called = true
          raise RedisClient::CannotConnectError, "Simulated connection loss"
        end
        original.call(*args)
      end

      allow_any_instance_of(RedisPool).to receive(:rand).and_return(0.1)

      expect do
        redis_pool.with { |redis| redis.set("retry-test-key", "retry-value") }
      end.not_to raise_error
    end

    it "raises error after max retries exceeded" do
      allow_any_instance_of(Redis).to receive(:set).and_raise(RedisClient::CannotConnectError,
                                                              "Simulated total failure")

      expect do
        redis_pool.with { |redis| redis.set("fail-test-key", "fail-value") }
      end.to raise_error(RedisClient::CannotConnectError)
    end
  end

  describe "circuit breaker" do
    it "stays open and rejects calls within the backoff window" do
      allow_any_instance_of(Redis).to receive(:set).and_raise(RedisClient::CannotConnectError,
                                                              "Simulated total failure")
      allow_any_instance_of(RedisPool).to receive(:rand).and_return(0.1)

      2.times do
        expect { redis_pool.with { |redis| redis.set("key", "val") } }.to raise_error(RedisClient::CannotConnectError)
      end

      expect { redis_pool.with { |redis| redis.set("key", "val") } }.to raise_error(RuntimeError, /circuit open/)
    end
  end

  describe "method delegation" do
    it "delegates Redis commands through the pool via method_missing" do
      redis_pool.set("delegated-key", "delegated-value")
      expect(redis_pool.get("delegated-key")).to eq("delegated-value")
    end

    it "responds to Redis methods" do
      expect(redis_pool).to respond_to(:set)
      expect(redis_pool).to respond_to(:get)
    end

    it "does not respond to unknown methods" do
      expect(redis_pool).not_to respond_to(:nonexistent_method)
    end
  end
end
