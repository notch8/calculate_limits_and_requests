# frozen_string_literal: true

require 'prometheus'
RSpec.describe Memory do
  include_context 'with access to prometheus'
  let(:current_resources) do
    { requests: { cpu: '100m', memory: '1Gi' }, limits: { cpu: '1', memory: '2Gi' } }
  end
  let(:memory) { described_class.new(current_resources:, identifier: '1234', type: :rails_app) }

  it 'can be instantiated' do
    expect(memory).to be_an_instance_of(described_class)
  end

  context 'with large values from prometheus' do
    let(:quantile_mock) { instance_double(Memory::Quantile, ninety_five_in_mi: 27_221, ninety_nine_in_mi: 31_772) }

    before do
      allow(Memory::Quantile).to receive(:new).and_return(quantile_mock)
    end

    it 'comes up with a reasonable recommendation' do
      expect(memory.limit.display).to eq('40Gi')
      expect(memory.request.display).to eq('32Gi')
    end
  end

  context 'with memory values from kubernetes' do
    it 'translates between human readable k8s memory vals and numeric ones' do
      expect(described_class.string_to_mebibytes(string: '')).to be_nil
    end

    it 'translates from strings that are already in mM' do
      expect(described_class.string_to_mebibytes(string: '256Mi')).to eq(256)
    end

    it 'translates from strings that are in Gi to Mi' do
      expect(described_class.string_to_mebibytes(string: '4Gi')).to eq(4096)
    end
  end

  context 'when rounding memory values' do
    it 'rounds to factors of 2' do
      expect(described_class.round(mebibytes: 1000)).to eq(1024)
    end

    it 'always rounds up' do
      expect(described_class.round(mebibytes: 30)).to eq(32)
    end

    it 'goes by fractions of a Gibibyte after 1024' do
      expect(described_class.round(mebibytes: 1050)).to eq(1536)
      expect(described_class.round(mebibytes: 6000)).to eq(6144)
    end

    it 'comes up with sufficiently large numbers' do
      expect(described_class.round(mebibytes: 27_221)).to eq(27_648)
    end
  end

  describe '#mebibytes_to_string' do
    it 'keeps them as Mi for smaller numbers' do
      expect(described_class.mebibytes_to_string(mebibytes: 32)).to eq('32Mi')
    end

    it 'conversts to Gi for larger numbers' do
      expect(described_class.mebibytes_to_string(mebibytes: 6144)).to eq('6Gi')
      expect(described_class.mebibytes_to_string(mebibytes: 27_648)).to eq('27Gi')
    end
  end
end
