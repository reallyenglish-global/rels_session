# frozen_string_literal: true

RSpec.describe RelsSession do
  describe ".namespage" do
    subject(:namespace) { described_class.namespace }

    it "is set by the Settings" do
      expect(namespace).to eq("test:session:namespace")
    end
  end

  describe ".redis_options" do
    subject(:redis_options) { described_class.redis_options }

    it "is configured from settings and default values" do
      expect(redis_options.fetch(:connect_timeout)).to eq(20)
      expect(redis_options.fetch(:read_timeout)).to eq(1)
      expect(redis_options.fetch(:reconnect_attempts)).to eq(1)
      expect(redis_options.fetch(:namespace)).to eq("test:session:namespace")
      expect(redis_options.fetch(:url)).to eq(Settings.session_store.redis_options.url)
      expect(redis_options[:sentinels]).to be_nil
    end

    # sentinels are not correctly configured in all environments
    # this tests the workaround
    context "when settings url is sentinel" do
      it "sets the path as the url and adds the sentinels" do
        settings = class_double("Settings").as_stubbed_const

        allow(settings).to receive(:session_store) {
          RelsSession::SettingsStruct.new(
            session_store: {
              application_name: "Turtle",
              redis_options: {
                url: "redis+sentinel://re-redis.re:26379/mymaster/3",
                namespace: "test:session:namespace"
              }
            }
          ).session_store
        }

        expect(redis_options.fetch(:url)).to eq("redis://mymaster/3")
        expect(redis_options[:sentinels]).to eq([{ host: "re-redis.re", port: 26_379 }])
      end
    end
  end

  describe ".store" do
    it "return store instance" do
      expect(described_class.store).to be_a(RelsSession::SessionStore)
    end
  end

  describe ".sessions" do
    it "returns sessions" do
      expect(described_class.sessions).to be_a(Array)
    end
  end
end
