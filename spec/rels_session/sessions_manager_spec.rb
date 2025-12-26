# frozen_string_literal: true

RSpec.describe RelsSession::SessionsManager do
  meta = {
    ip: "212.139.254.49",
    browser: "Chrome",
    os: "Mac",
    app_version: nil,
    device_name: "",
    device_type: "desktop",
    installation_id: nil,
    course_id: nil,
    client_platform: nil,
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
    let(:session_data) { {} }
    let(:device_os_name) { nil }
    let(:device_type) { nil }
    let(:detected_device_name) { nil }
    let(:device_detector) do
      instance_double(
        DeviceDetector,
        name: "Chrome",
        os_name: device_os_name,
        device_name: detected_device_name,
        device_type: device_type
      )
    end
    let(:session_double) do
      instance = double(id: active_session_id)
      allow(instance).to receive(:[]) { |key| session_data[key] }
      allow(instance).to receive(:[]=) { |key, value| session_data[key] = value }
      instance
    end
    let(:request_headers) do
      {
        "AppVersion" => "1.0.0",
        "X-DEVICE" => "iPhone 15",
        "X-INSTALLATION-ID" => "install-123",
        "X-COURSE-ID" => "course-789"
      }
    end
    let(:request) do
      double(
        user_agent: "Chrome",
        ip: "212.139.254.49",
        remote_ip: "10.20.30.40",
        env: {},
        headers: request_headers,
        session: session_double
      )
    end
    let(:user_sessions_instance) { double(add: nil) }

    before do
      allow(DeviceDetector).to receive(:new).and_return(device_detector)
      allow(RelsSession::UserSessions).to receive(:new).and_return(user_sessions_instance)
      allow(Time).to receive(:zone).and_return(Time)
    end

    it "logs user out of all sessions" do
      described_class.record_authenticated_request(user, request, expires_after: 45)
      expect(RelsSession::UserSessions).to have_received(:new).with(user.uuid, expires_after: 45)
    end

    it "logs token authenticated user" do
      expect(session_double).to receive(:[]=).with(:meta, hash_including(:ip))
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      meta_hash = {
        browser: "Chrome",
        ip: "10.20.30.40",
        app_version: "1.0.0",
        device_name: "iPhone 15",
        device_type: nil,
        installation_id: "install-123",
        course_id: "course-789",
        client_platform: "ios_app",
        public_session_id: active_session_id.public_id,
        created_at: now,
        updated_at: now,
        os: nil,
        session_key_type: :token
      }
      meta_instance = instance_double(RelsSession::SessionMeta, to_h: meta_hash)
      allow(RelsSession::SessionMeta).to receive(:new).and_return(meta_instance)
      expect(RelsSession::SessionMeta).to receive(:new).with(**meta_hash)
      described_class.record_authenticated_request(
        user, request,
        expires_after: 45,
        session_key_type: :token,
        sign_in_at: now
      )
    end

    context "when course id header is missing" do
      before do
        request_headers.delete("X-COURSE-ID")
        session_data["course_uuid"] = "course-from-session"
      end

      it "falls back to the session for course ids" do
        described_class.record_authenticated_request(user, request)
        expect(session_data[:meta][:course_id]).to eq("course-from-session")
      end
    end

    context "when remote_ip is missing" do
      before do
        allow(request).to receive(:remote_ip).and_return(nil)
      end

      it "falls back to request.ip" do
        described_class.record_authenticated_request(user, request, session_key_type: :token)
        expect(session_data[:meta][:ip]).to eq("212.139.254.49")
      end
    end

    context "when installation id header indicates android" do
      let(:device_os_name) { "Android" }
      let(:request_headers) do
        super().merge("X-DEVICE" => "Android 14")
      end

      it "tags the client_platform as android_app" do
        described_class.record_authenticated_request(user, request)
        expect(session_data[:meta][:client_platform]).to eq("android_app")
      end
    end

    context "when device is mobile web" do
      let(:device_type) { "smartphone" }
      let(:request_headers) do
        super().dup.tap { |headers| headers.delete("X-INSTALLATION-ID") }
      end

      it "tags the client_platform as mobile_web" do
        described_class.record_authenticated_request(user, request)
        expect(session_data[:meta][:client_platform]).to eq("mobile_web")
      end
    end

    context "when device is desktop web" do
      let(:request_headers) do
        super().dup.tap { |headers| headers.delete("X-INSTALLATION-ID") }
      end

      it "tags the client_platform as web" do
        described_class.record_authenticated_request(user, request)
        expect(session_data[:meta][:client_platform]).to eq("web")
      end
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
