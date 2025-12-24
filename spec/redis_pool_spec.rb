# spec/redis_pool_spec.rb
require 'spec_helper' # or rails_helper if inside Rails
require 'redis'
require_relative '../lib/redis_pool' # adjust path

RSpec.describe RedisPool do
  let(:pool_options) { { size: 2, timeout: 5 } }
  let(:redis_options) { { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') } }
  subject(:redis_pool) { described_class.new(pool_options, redis_options) }

  describe "#with" do
    it "successfully sets and gets a key" do
      redis_pool.with do |redis|
        redis.set('test-key', 'test-value')
        expect(redis.get('test-key')).to eq('test-value')
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

      expect {
        redis_pool.with { |redis| redis.set('retry-test-key', 'retry-value') }
      }.not_to raise_error
    end

    it "raises error after max retries exceeded" do
      allow_any_instance_of(Redis).to receive(:set).and_raise(RedisClient::CannotConnectError, "Simulated total failure")

      expect {
        redis_pool.with { |redis| redis.set('fail-test-key', 'fail-value') }
      }.to raise_error(RedisClient::CannotConnectError)
    end
  end
end
