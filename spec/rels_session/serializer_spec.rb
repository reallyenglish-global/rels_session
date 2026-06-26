# frozen_string_literal: true

RSpec.describe RelsSession::Serializers do
  describe ".for" do
    it "returns a JsonSerializer for :json" do
      expect(described_class.for(:json)).to be_a(RelsSession::Serializers::JsonSerializer)
    end

    it "returns an OjSerializer for :oj" do
      expect(described_class.for(:oj)).to be_a(RelsSession::Serializers::OjSerializer)
    end

    it "accepts a string name" do
      expect(described_class.for("json")).to be_a(RelsSession::Serializers::JsonSerializer)
    end

    it "raises ArgumentError for an unsupported serializer" do
      expect { described_class.for(:yaml) }.to raise_error(ArgumentError, /Unsupported serializer/)
    end
  end

  shared_examples "a serializer" do
    let(:payload) { { "foo" => "bar", "num" => 42 } }

    describe "#dump" do
      it "serializes a hash to a string" do
        result = serializer.dump(payload)
        expect(result).to be_a(String)
        expect(result).to include("bar")
      end

      it "handles nested hashes" do
        nested = { "a" => { "b" => [1, 2] } }
        result = serializer.dump(nested)
        expect(result).to be_a(String)
      end

      it "handles empty hashes" do
        expect(serializer.dump({})).to be_a(String)
      end
    end

    describe "#load" do
      it "deserializes a string to a hash" do
        dumped = serializer.dump(payload)
        expect(serializer.load(dumped)).to eq(payload)
      end

      it "round-trips complex data" do
        complex = { "string" => "hello", "int" => 1, "float" => 1.5, "array" => [1, 2], "nested" => { "key" => "val" } }
        expect(serializer.load(serializer.dump(complex))).to eq(complex)
      end
    end
  end

  describe RelsSession::Serializers::JsonSerializer do
    let(:serializer) { described_class.new }
    it_behaves_like "a serializer"
  end

  describe RelsSession::Serializers::OjSerializer do
    let(:serializer) { described_class.new }
    it_behaves_like "a serializer"
  end
end
