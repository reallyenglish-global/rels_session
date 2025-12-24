# frozen_string_literal: true

RSpec.describe RelsSession::SessionsManager do
  meta = {
    ip: "212.139.254.49",
    browser: "Chrome",
    os: "Mac",
    device_name: "",
    device_type: "desktop",
    public_session_id: SecureRandom.hex,
    session_key_type: :cookie,
    created_at: Time.new,
    updated_at: Time.new
  }

  let(:user) { double(uuid: SecureRandom.uuid) }
  let(:active_session_id) { Rack::Session::SessionId.new(SecureRandom.hex) }
  let(:active_session_meta) { meta }
  let(:devise_session) { { "meta" => active_session_meta.to_h } }

  let(:session_store) do
    RelsSession::SessionStore.new(
      nil,
      {}
    )
  end

  let(:instance) { described_class.new(user) }

  before do
    setup_sessions
  end

  describe "#initialize" do
    it "reuses the singleton session store" do
      expect(instance.instance_variable_get(:@session_store)).to be(RelsSession.store)
    end
  end

  describe "#active_sessions" do
    subject(:active_sessions) { instance.active_sessions }

    it "lists all active sessions" do
      expect(active_sessions.size).to eq 1
    end

    context "sessions have been removed" do
      before do
        session_store.delete_session(nil, active_session_id, {})
      end

      it "lists all active sessions" do
        expect(active_sessions.size).to eq 0
      end
    end
  end

  describe "#logout_all_sessions" do
    subject(:logout_all_sessions) { instance.logout_all_sessions }

    it "logs user out of all sessions" do
      expect { logout_all_sessions }.to change { instance.active_sessions.size }.from(1).to(0)
    end
  end

  describe "#logout_session(sessions_id)" do
    subject(:logout_session) { instance.logout_session(active_session_id) }

    it "logs user out active sessions" do
      expect { logout_session }.to change { instance.active_sessions.size }.from(1).to(0)
    end
  end

  describe ".active_sessions" do
    subject(:described_active_sessions) { described_class.active_sessions(user) }

    it "returns session meta objects even when stored with string keys" do
      expect(described_active_sessions).to all(be_a(RelsSession::SessionMeta))
      expect(described_active_sessions.map(&:public_session_id))
        .to include(active_session_meta[:public_session_id])
    end
  end

  describe ".record_authenticated_request" do
    let(:request) do
      double(
        user_agent: "Chrome",
        ip: "212.139.254.49",
        env: { "HTTP_APP_VERSION" => "1.0.0" },
        session: double(id: active_session_id, :[]= => nil)
      )
    end

    it "logs user out of all sessions" do
      allow(RelsSession::UserSessions).to receive(:new).and_return(double(add: nil))
      allow(Time).to receive(:zone).and_return(Time)
      described_class.record_authenticated_request(user, request, expires_after: 45)
      expect(RelsSession::UserSessions).to have_received(:new).with(user.uuid, expires_after: 45)
    end

    it "logs token authenticated user" do
      allow(RelsSession::UserSessions).to receive(:new).and_return(double(add: nil))
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      expect(RelsSession::SessionMeta).to receive(:new).with(
        browser: "Chrome",
        ip: "212.139.254.49",
        app_version: "1.0.0",
        device_name: nil,
        device_type: nil,
        public_session_id: active_session_id.public_id,
        created_at: now,
        updated_at: now,
        os: nil,
        session_key_type: :token
      )
      allow(Time).to receive(:zone).and_return(Time)
      described_class.record_authenticated_request(
        user, request,
        expires_after: 45,
        session_key_type: :token,
        sign_in_at: now
      )
    end
  end

  describe ".logout_sessions" do
    let(:second_session_id) { Rack::Session::SessionId.new(SecureRandom.hex) }

    before do
      session_store.write_session(nil, second_session_id, devise_session, nil)
      RelsSession::UserSessions.new(user.uuid)
                               .add(second_session_id.public_id)
    end

    it "logs out only the provided sessions" do
      described_class.logout_sessions(user, [second_session_id.public_id])
      expect(session_store.find_session(nil, second_session_id).last).to eq({})
      expect(instance.active_sessions.size).to eq(1)
    end
  end

  def setup_sessions
    session_store.write_session(nil, active_session_id, devise_session, nil)

    RelsSession::UserSessions.new(user.uuid)
                             .add(SecureRandom.hex)

    RelsSession::UserSessions.new(user.uuid)
                             .add(active_session_id.public_id)
  end
end
