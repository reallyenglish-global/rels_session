# frozen_string_literal: true

RSpec.describe RelsSession::SessionStore do
  let(:store) { described_class.new(nil, {}) }
  let(:active_session_id) { Rack::Session::SessionId.new(SecureRandom.hex) }

  let(:write_session) {
    store.write_session(nil, active_session_id, { 'test' => 'figs' }, nil)
  }
  let(:find_session) {
    store.find_session(nil, active_session_id)
  }

  describe '#write_session' do
    it 'returns the active_session_id' do
      expect(write_session).to eq(active_session_id)
    end
  end

  describe '#find_session' do
    before do
      write_session
    end

    it 'returns the session as a hash with string keys' do
      expect(find_session.first).to eq(active_session_id)
      expect(find_session.last).to eq(
        { 'test' => 'figs' }
      )
    end
  end

  describe '#delete_session' do
    before do
      write_session
    end

    it 'removes the session and returns a new id' do
      expect {
        store.delete_session(nil, active_session_id, nil)
      }.to change{
        store.find_session(nil, active_session_id).first
      }.from(
        active_session_id
        )
    end
  end
end
