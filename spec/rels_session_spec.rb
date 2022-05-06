# frozen_string_literal: true

RSpec.describe RelsSession do

  describe '.namespage' do
    subject(:namespace) { described_class.namespace }

    it 'is set by the Settings' do
      expect(namespace).to eq('test:session:namespace')
    end
  end
end

