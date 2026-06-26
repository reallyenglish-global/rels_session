# frozen_string_literal: true

RSpec.describe RelsSession::SessionIntrospection do
  describe ".normalize_stage" do
    it "returns the symbol for :anonymous" do
      expect(described_class.normalize_stage(:anonymous)).to eq(:anonymous)
    end

    it "returns the symbol for :authenticated" do
      expect(described_class.normalize_stage(:authenticated)).to eq(:authenticated)
    end

    it "returns the symbol for :in_course" do
      expect(described_class.normalize_stage(:in_course)).to eq(:in_course)
    end

    it "accepts a string" do
      expect(described_class.normalize_stage("authenticated")).to eq(:authenticated)
    end

    it "raises ArgumentError for unknown stages" do
      expect { described_class.normalize_stage(:bogus) }.to raise_error(ArgumentError, /Unknown session stage/)
    end
  end

  describe ".stage" do
    it "returns :anonymous for nil payload" do
      expect(described_class.stage(nil)).to eq(:anonymous)
    end

    it "returns :anonymous for empty payload" do
      expect(described_class.stage({})).to eq(:anonymous)
    end

    it "returns :authenticated when signed in without a course" do
      payload = { "warden.user.user.key" => [[1], "salt"] }
      expect(described_class.stage(payload)).to eq(:authenticated)
    end

    it "returns :in_course when signed in with a course_id" do
      payload = { "warden.user.user.key" => [[1], "salt"], "course_id" => "42" }
      expect(described_class.stage(payload)).to eq(:in_course)
    end

    it "returns :in_course when signed in with a course_uuid" do
      payload = { "warden.user.user.key" => [[1], "salt"], "course_uuid" => "abc-def" }
      expect(described_class.stage(payload)).to eq(:in_course)
    end

    it "finds course_id in meta sub-hash" do
      payload = { "warden.user.user.key" => [[1], "salt"], "meta" => { "course_id" => "99" } }
      expect(described_class.stage(payload)).to eq(:in_course)
    end

    it "uses symbol key for warden" do
      payload = { "warden.user.user.key": [[1], "salt"] }
      expect(described_class.stage(payload)).to eq(:authenticated)
    end
  end

  describe ".course_id" do
    it "returns nil for nil payload" do
      expect(described_class.course_id(nil)).to be_nil
    end

    it "returns nil for empty payload" do
      expect(described_class.course_id({})).to be_nil
    end

    it "returns the course_id from the top-level" do
      expect(described_class.course_id({ "course_id" => "7" })).to eq("7")
    end

    it "returns the course_uuid from the top-level" do
      expect(described_class.course_id({ "course_uuid" => "abc" })).to eq("abc")
    end

    it "prefers course_id over course_uuid" do
      result = described_class.course_id({ "course_id" => "1", "course_uuid" => "2" })
      expect(result).to eq("1")
    end

    it "returns course_id from meta sub-hash" do
      payload = { "meta" => { "course_id" => "42" } }
      expect(described_class.course_id(payload)).to eq("42")
    end

    it "returns nil when meta is not a hash" do
      payload = { "meta" => "just a string" }
      expect(described_class.course_id(payload)).to be_nil
    end

    it "handles symbol keys" do
      expect(described_class.course_id({ course_id: "99" })).to eq("99")
    end
  end

  describe ".signed_in?" do
    it "returns false for nil payload" do
      expect(described_class.signed_in?(nil)).to be false
    end

    it "returns false for empty payload" do
      expect(described_class.signed_in?({})).to be false
    end

    it "returns true when warden.user.user.key is present (string key)" do
      payload = { "warden.user.user.key" => [[1], "salt"] }
      expect(described_class.signed_in?(payload)).to be true
    end

    it "returns true when warden.user.user.key is present (symbol key)" do
      payload = { :"warden.user.user.key" => [[1], "salt"] }
      expect(described_class.signed_in?(payload)).to be true
    end

    it "returns false when warden key is empty" do
      payload = { "warden.user.user.key" => [] }
      expect(described_class.signed_in?(payload)).to be false
    end

    it "returns false when warden key is nil" do
      payload = { "warden.user.user.key" => nil }
      expect(described_class.signed_in?(payload)).to be false
    end
  end

  describe ".meta_payload" do
    it "returns the meta hash" do
      payload = { "meta" => { "course_id" => "42" } }
      expect(described_class.meta_payload(payload)).to eq("course_id" => "42")
    end

    it "returns nil when meta is absent" do
      expect(described_class.meta_payload({})).to be_nil
    end

    it "handles symbol keys" do
      payload = { meta: { course_id: "42" } }
      expect(described_class.meta_payload(payload)).to eq(course_id: "42")
    end
  end

  describe ".fetch_value" do
    it "fetches with string key" do
      expect(described_class.fetch_value({ "foo" => "bar" }, :foo)).to eq("bar")
    end

    it "fetches with symbol key" do
      expect(described_class.fetch_value({ foo: "bar" }, :foo)).to eq("bar")
    end

    it "prefers string key over symbol key" do
      expect(described_class.fetch_value({ "foo" => "string", foo: "symbol" }, :foo)).to eq("string")
    end

    it "returns nil when key is absent" do
      expect(described_class.fetch_value({}, :missing)).to be_nil
    end

    it "returns nil for nil" do
      expect(described_class.fetch_value(nil, :foo)).to be_nil
    end

    it "returns nil for objects not responding to []" do
      obj = Object.new
      expect(described_class.fetch_value(obj, :foo)).to be_nil
    end

    it "returns nil when KeyError is raised" do
      obj = double("weird")
      allow(obj).to receive(:[]).and_raise(KeyError)
      expect(described_class.fetch_value(obj, :foo)).to be_nil
    end
  end

  describe ".presence" do
    it "returns the value for a non-empty string" do
      expect(described_class.presence("hello")).to eq("hello")
    end

    it "returns nil for nil" do
      expect(described_class.presence(nil)).to be_nil
    end

    it "returns nil for empty string" do
      expect(described_class.presence("")).to be_nil
    end

    it "returns nil for empty array" do
      expect(described_class.presence([])).to be_nil
    end

    it "returns the value for a populated array" do
      expect(described_class.presence([[1], "salt"])).to eq([[1], "salt"])
    end
  end
end
