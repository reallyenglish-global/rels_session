# frozen_string_literal: true

RSpec.describe RelsSession::Stats do
  subject(:stats) { described_class.new(redis: RelsSession.redis, namespace: RelsSession.namespace) }

  describe "#increment_total_sessions/#decrement_total_sessions" do
    it "tracks totals and last updated timestamp" do
      stats.increment_total_sessions(2)
      stats.decrement_total_sessions(1)

      data = stats.totals
      expect(data[:total_sessions]).to eq(1)
      expect(data[:last_updated_at]).to be_within(1).of(Time.now)
    end
  end

  describe "#reconcile!" do
    it "recomputes totals from actual session keys" do
      redis_double = instance_double("Redis")
      allow(redis_double).to receive(:scan).and_return(["0", ["#{RelsSession.namespace}:2:abc", "#{RelsSession.namespace}:2:def"]])
      allow(redis_double).to receive(:multi).and_yield(double(set: true))
      allow(redis_double).to receive(:get).and_return("2", Time.now.to_i.to_s)
      proxy = Object.new
      proxy.define_singleton_method(:then) { |&blk| blk.call(redis_double) }
      stats_with_proxy = described_class.new(redis: proxy, namespace: RelsSession.namespace)

      stats_with_proxy.reconcile!

      expect(stats_with_proxy.totals[:total_sessions]).to eq(2)
    end
  end
end
