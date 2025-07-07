# frozen_string_literal: true

RSpec.describe RelsSession::SessionStore do
  let(:store) { described_class.new(nil, {}) }
  let(:active_session_id) { Rack::Session::SessionId.new(SecureRandom.hex) }

  let(:write_session) do
    store.write_session(nil, active_session_id, { "test" => "figs" }, nil)
  end
  let(:find_session) do
    store.find_session(nil, active_session_id)
  end

  describe "#write_session" do
    it "returns the active_session_id" do
      expect(write_session).to eq(active_session_id)
    end
  end

  context "when a session exists" do
    before do
      write_session
    end

    describe "#find_session" do
      it "returns the session as a hash with string keys" do
        expect(find_session.first).to eq(active_session_id)

        session = find_session.last
        expect(session).to eq(
          "test" => "figs"
        )
      end
    end

    describe "#delete_session" do
      it "removes the session and returns a new id" do
        expect do
          store.delete_session(nil, active_session_id, nil)
        end.to change {
          store.find_session(nil, active_session_id).first
        }.from(active_session_id)
      end
    end

    describe "#list_sessions" do
      it "returns sessions" do
        expect(store.list_sessions).to eq([[RelsSession.namespace, active_session_id.private_id].join(":")])
      end
    end

    describe "#sessions" do
      it "returns sessions" do
        expect(described_class.sessions).to eq([[RelsSession.namespace, active_session_id.private_id].join(":")])
      end
    end
  end
end
