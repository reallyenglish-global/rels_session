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
end
