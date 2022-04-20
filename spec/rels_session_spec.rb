# frozen_string_literal: true

RSpec.describe RelsSession do
  it "has a version number" do
    expect(RelsSession::VERSION).not_to be nil
  end

  describe '.namespage' do
    subject(:namespace) { described_class.namespace }

    it 'defaults to rels:session' do
      expect(namespace).to eq('rels:session')
    end
  end
end
