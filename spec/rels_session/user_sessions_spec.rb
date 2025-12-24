# frozen_string_literal: true

RSpec.describe RelsSession::UserSessions do
  let(:user) { double(uuid: SecureRandom.uuid) }

  let(:instance) { described_class.new(user.uuid) }
  let(:instance_with_options) { described_class.new(user.uuid, expires_after: 45) }
  let(:session_id) { SecureRandom.hex }

  describe "#initialize" do
    it "sets the ttl" do
      expect(instance_with_options.instance_variable_get(:@ttl)).to eq(45)
    end
  end

  describe "#add" do
    subject(:add) { instance.add(session_id.dup) }

    it "adds the session to the list" do
      expect { add }.to change(instance, :list)
        .from([])
        .to([session_id])

      expect { add }.not_to change(instance, :list)
    end
  end

  describe "#remove" do
    subject(:remove) { instance.remove(session_id) }

    before do
      instance.add(session_id.dup)
    end

    it "removes the session" do
      expect { remove }.to change(instance, :list)
        .from([session_id])
        .to([])

      expect { remove }.not_to change(instance, :list)
    end

    context "with multiple session ids" do
      let(:session_id) { [SecureRandom.hex, SecureRandom.hex] }

      before do
        instance.add(session_id.dup << SecureRandom.hex)
      end

      it "removes multiple sessions" do
        expect { remove }.to change { instance.list.size }
          .from(3)
          .to(1)
        expect { remove }.not_to change(instance, :list)
      end
    end
  end

  describe "#remove_all" do
    let(:session_ids) { [SecureRandom.hex, SecureRandom.hex] }

    before do
      session_ids.each { |id| instance.add(id.dup) }
    end

    it "removes multiple sessions with a single pipelined call" do
      instance.remove_all(session_ids)
      expect(instance.list).to be_empty
    end
  end
end
