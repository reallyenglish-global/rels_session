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

  describe "serializer configuration" do
    around do |example|
      original = RelsSession.serializer
      example.run
    ensure
      RelsSession.serializer = :json
    end

    it "round-trips sessions using the Oj serializer" do
      RelsSession.serializer = :oj
      write_session
      expect(find_session.last).to eq("test"=> "figs")
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
          "test"=> "figs"
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

    describe "#delete_sessions" do
      it "removes multiple sessions in a single call" do
        second_session_id = Rack::Session::SessionId.new(SecureRandom.hex)
        store.write_session(nil, second_session_id, { "another" => "value" }, nil)

        store.delete_sessions(nil, [active_session_id, second_session_id])

        expect(store.list_sessions).to be_empty
      end
    end

    describe "#list_sessions" do
      it "returns sessions" do
        expect(store.list_sessions).to eq([[RelsSession.namespace, active_session_id.private_id].join(":")])
      end

      it "yields sessions when streaming" do
        keys = []
        store.list_sessions(stream: true) { |key| keys << key }
        expect(keys).to eq([[RelsSession.namespace, active_session_id.private_id].join(":")])
      end

      it "respects custom batch size when streaming via API" do
        RelsSession.stream_sessions(batch_size: 1) do |session|
          expect(session["test"]).to eq("figs")
        end
      end

      it "filters streamed sessions by stage" do
        in_course_id = Rack::Session::SessionId.new(SecureRandom.hex)
        signed_in_payload = {
          "warden.user.user.key" => [[SecureRandom.random_number(10)], "token"],
          "course_id" => "course-123",
          "meta" => { "course_id" => "course-123" }
        }
        store.write_session(nil, in_course_id, signed_in_payload, nil)

        anonymous_ids = []
        RelsSession.stream_sessions(stage: :anonymous) do |session|
          anonymous_ids << session["course_id"]
        end
        expect(anonymous_ids).to eq([nil])

        course_ids = []
        RelsSession.stream_sessions(stage: :in_course, batch_size: 1) do |session|
          course_ids << session["course_id"]
        end
        expect(course_ids).to eq(["course-123"])
      end

      it "raises when stream filtering uses an unknown stage" do
        expect do
          RelsSession.stream_sessions(stage: :bogus) { |_| }
        end.to raise_error(ArgumentError)
      end
    end

    describe "#sessions" do
      it "returns sessions" do
        expect(described_class.sessions).to eq([[RelsSession.namespace, active_session_id.private_id].join(":")])
      end
    end

    describe "#peek_session" do
      it "returns the raw stored json string" do
        expect(store.peek_session(nil, active_session_id)).to eq({ "test" => "figs" }.to_json)
      end
    end

    describe "#find_sessions" do
      it "returns sessions for the provided ids" do
        second_session_id = Rack::Session::SessionId.new(SecureRandom.hex)
        store.write_session(nil, second_session_id, { "another" => "value" }, nil)

        result = store.find_sessions(nil, [active_session_id, second_session_id])

        expect(result).to eq(
          [
            { "test"=> "figs" },
            { "another"=> "value" }
          ]
        )
      end
    end
  end

  describe "#secure_store?" do
    it "caches redis membership checks for a short period" do
      store = described_class.new(nil, {})
      redis = instance_double("Redis")
      allow(redis).to receive(:then).and_yield(redis)
      allow(redis).to receive(:set)
      allow(redis).to receive(:exists?).and_return(true)

      store.instance_variable_set(:@redis, redis)
      session_id = instance_double(
        Rack::Session::SessionId,
        private_id: SecureRandom.hex,
        public_id: SecureRandom.hex
      )

      store.send(:store_keys, session_id)
      store.send(:store_keys, session_id)

      expect(redis).to have_received(:set).once
      expect(redis).to have_received(:exists?).once
    end
  end

  describe "#find_sessions" do
    it "uses a single mget call for all session ids" do
      store = described_class.new(nil, {})
      redis = instance_double("Redis")
      allow(redis).to receive(:then).and_yield(redis)
      allow(redis).to receive(:set)
      allow(redis).to receive(:exists?).and_return(true)
      store.instance_variable_set(:@redis, redis)

      session_id_a = Rack::Session::SessionId.new(SecureRandom.hex)
      session_id_b = Rack::Session::SessionId.new(SecureRandom.hex)

      allow(store).to receive(:store_keys).with(session_id_a).and_return(%w[key:a key:a])
      allow(store).to receive(:store_keys).with(session_id_b).and_return(%w[key:b key:b])

      expect(redis).to receive(:mget).with("key:a", "key:b").once.and_return(
        ['{"test": "figs"}', '{"another": "value"}']
      )

      result = store.find_sessions(nil, [session_id_a, session_id_b])

      expect(result).to eq(
        [
          { "test"=> "figs" },
          { "another"=> "value" }
        ]
      )
    end
  end
end
