# frozen_string_literal: true

RSpec.describe ConversionService do
  context 'with memory values from kubernetes' do
    it 'translates between human readable k8s memory vals and numeric ones' do
      expect(described_class.k8s_memory_to_mi('')).to be_nil
    end

    it 'translates from strings that are already in mM' do
      expect(described_class.k8s_memory_to_mi('256Mi')).to eq(256)
    end

    it 'translates from strings that are in Gi to Mi' do
      expect(described_class.k8s_memory_to_mi('4Gi')).to eq(4096)
    end
  end

  context 'when rounding memory values' do
    it 'rounds to factors of 2' do
      expect(described_class.round_memory(mebibytes: 1000)).to eq(1024)
    end

    it 'always rounds up' do
      expect(described_class.round_memory(mebibytes: 30)).to eq(32)
    end

    it 'goes by fractions of a Gibibyte after 1024' do
      expect(described_class.round_memory(mebibytes: 1050)).to eq(1536)
      expect(described_class.round_memory(mebibytes: 6000)).to eq(6144)
    end
  end

  describe '#memory_to_s' do
    it 'keeps them as Mi for smaller numbers' do
      expect(described_class.memory_to_s(mebibytes: 32)).to eq('32Mi')
    end

    it 'conversts to Gi for larger numbers' do
      expect(described_class.memory_to_s(mebibytes: 6144)).to eq('6Gi')
    end
  end
end
