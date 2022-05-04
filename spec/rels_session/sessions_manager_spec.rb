# frozen_string_literal: true

RSpec.describe RelsSession::SessionsManager do

  meta = {
    ip: '212.139.254.49',
    browser: 'Chrome',
    os: "Mac",
    device_name: '',
    device_type: "desktop",
    public_session_id: SecureRandom.hex,
    session_key_type: :cookie,
    created_at: Time.new,
    updated_at: Time.new
  }

  let(:user) { double(:uuid => SecureRandom.uuid) }
  let(:active_session_id) { Rack::Session::SessionId.new(SecureRandom.hex) }
  let(:active_session_meta) { meta }

  let(:session_store) {
    RelsSession::SessionStore.new(
      nil,
      {}
    )
  }

  let(:instance) { described_class.new(user) }

  before do
    setup_sessions
  end

  describe "#active_sessions" do
    subject(:active_sessions) { instance.active_sessions }

    it 'lists all active sessions' do
      expect(active_sessions.size).to eq 1
    end

    context 'sessions have been removed' do
      before do
        session_store.delete_session(nil, active_session_id, {})
      end

      it 'lists all active sessions' do
        expect(active_sessions.size).to eq 0
      end
    end
  end

  describe "#logout_all_sessions" do
    subject(:logout_all_sessions) { instance.logout_all_sessions }

    it 'logs user out of all sessions' do
      expect { logout_all_sessions }.to change { instance.active_sessions.size }.from(1).to(0)
    end
  end

  describe "#logout_session(sessions_id)" do
    subject(:logout_session) { instance.logout_session(active_session_id) }

    it 'logs user out active sessions' do
      expect { logout_session }.to change { instance.active_sessions.size }.from(1).to(0)
    end
  end

  def setup_sessions
    devise_session = { 'meta' => active_session_meta.to_h }

    session_store.write_session(nil, active_session_id, devise_session, nil)

    RelsSession::UserSessions.new(user.uuid)
      .add(SecureRandom.hex)

    RelsSession::UserSessions.new(user.uuid)
      .add(active_session_id.public_id)
  end
end
