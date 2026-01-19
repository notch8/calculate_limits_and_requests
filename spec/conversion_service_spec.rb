# frozen_string_literal: true

require 'prometheus'
require 'kubernetes'

RSpec.describe ConversionService do
  include_context 'with access to prometheus'
  include_context 'with access to kubernetes'

  context 'with cpu values from kubernetes' do
    it 'translates between human readable k8s cpu vals and numeric ones' do
      expect(described_class.k8s_cpu_to_millicores('')).to be_nil
    end

    it 'can handle numbers with millicores on them' do
      expect(described_class.k8s_cpu_to_millicores('100m')).to eq(100)
    end
  end

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
end
