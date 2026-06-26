# frozen_string_literal: true

RSpec.describe RelsSession::SessionMeta do
  let(:valid_attrs) do
    {
      ip: "192.168.1.1",
      browser: nil,
      os: nil,
      app_version: nil,
      device_name: nil,
      device_type: nil,
      installation_id: nil,
      course_id: nil,
      client_platform: nil,
      public_session_id: "abc123",
      session_key_type: :cookie,
      created_at: nil,
      updated_at: Time.now
    }
  end

  describe "required attributes" do
    it "builds with minimum required attrs" do
      meta = described_class.new(valid_attrs)
      expect(meta.ip).to eq("192.168.1.1")
      expect(meta.public_session_id).to eq("abc123")
      expect(meta.session_key_type).to eq(:cookie)
      expect(meta.updated_at).to be_a(Time)
    end

    it "raises Dry::Struct::Error when ip is missing" do
      expect { described_class.new(valid_attrs.except(:ip)) }.to raise_error(Dry::Struct::Error)
    end

    it "raises Dry::Struct::Error when public_session_id is missing" do
      expect { described_class.new(valid_attrs.except(:public_session_id)) }.to raise_error(Dry::Struct::Error)
    end

    it "raises Dry::Struct::Error when session_key_type is missing" do
      expect { described_class.new(valid_attrs.except(:session_key_type)) }.to raise_error(Dry::Struct::Error)
    end

    it "raises Dry::Struct::Error when updated_at is missing" do
      expect { described_class.new(valid_attrs.except(:updated_at)) }.to raise_error(Dry::Struct::Error)
    end
  end

  describe "optional attributes" do
    it "allows nil for browser" do
      meta = described_class.new(valid_attrs.merge(browser: nil))
      expect(meta.browser).to be_nil
    end

    it "allows nil for os" do
      meta = described_class.new(valid_attrs.merge(os: nil))
      expect(meta.os).to be_nil
    end

    it "allows nil for app_version" do
      meta = described_class.new(valid_attrs.merge(app_version: nil))
      expect(meta.app_version).to be_nil
    end

    it "allows nil for device_name" do
      meta = described_class.new(valid_attrs.merge(device_name: nil))
      expect(meta.device_name).to be_nil
    end

    it "allows nil for device_type" do
      meta = described_class.new(valid_attrs.merge(device_type: nil))
      expect(meta.device_type).to be_nil
    end

    it "allows nil for installation_id" do
      meta = described_class.new(valid_attrs.merge(installation_id: nil))
      expect(meta.installation_id).to be_nil
    end

    it "allows nil for course_id" do
      meta = described_class.new(valid_attrs.merge(course_id: nil))
      expect(meta.course_id).to be_nil
    end

    it "allows nil for client_platform" do
      meta = described_class.new(valid_attrs.merge(client_platform: nil))
      expect(meta.client_platform).to be_nil
    end

    it "allows nil for created_at" do
      meta = described_class.new(valid_attrs.merge(created_at: nil))
      expect(meta.created_at).to be_nil
    end
  end

  describe "type coercion" do
    it "coerces public_session_id to string" do
      meta = described_class.new(valid_attrs.merge(public_session_id: :a_symbol))
      expect(meta.public_session_id).to eq("a_symbol")
    end

    it "coerces session_key_type to symbol" do
      meta = described_class.new(valid_attrs.merge(session_key_type: "token"))
      expect(meta.session_key_type).to eq(:token)
    end

    it "raises error for invalid session_key_type" do
      expect { described_class.new(valid_attrs.merge(session_key_type: :invalid)) }.to raise_error(Dry::Struct::Error)
    end

    it "coerces course_id to string" do
      meta = described_class.new(valid_attrs.merge(course_id: 123))
      expect(meta.course_id).to eq("123")
    end

    it "coerces updated_at from string" do
      time = Time.now
      meta = described_class.new(valid_attrs.merge(updated_at: time.to_s))
      expect(meta.updated_at).to be_a(Time)
    end

    it "coerces created_at from string" do
      time = Time.now
      meta = described_class.new(valid_attrs.merge(created_at: time.to_s))
      expect(meta.created_at).to be_a(Time)
    end
  end
end
