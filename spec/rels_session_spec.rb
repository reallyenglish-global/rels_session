# frozen_string_literal: true

RSpec.describe RelsSession::SessionStore do
  describe '#new' do
    subject(:new) { described_class.new(Settings.to_hash) }

    describe '.redis' do
      subject(:redis) { new.redis }

      it 'returns redis instance' do
        expect(redis).not_to be nil
      end
    end
  end
end
