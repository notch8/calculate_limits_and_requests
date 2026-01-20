# frozen_string_literal: true

require 'prometheus'
RSpec.describe Cpu do
  let(:current_resources) do
    { requests: { cpu: '100m', memory: '1Gi' }, limits: { cpu: '1', memory: '2Gi' } }
  end
  let(:cpu) { described_class.new(current_resources:) }

  describe Cpu::Request do
    let(:request) { described_class.new(current: '100m', minimum: 100, quantile: 519) }

    it 'can give current request string' do
      expect(request.current_string).to eq('100m')
    end

    it 'can give the current request in millicores' do
      expect(request.current_millicores).to eq(100)
    end
  end

  describe Cpu::Limit do
    let(:limit) { described_class.new(current: '1', minimum: 1_000, quantile: 600) }

    it 'can give current limit string' do
      expect(limit.current_string).to eq('1')
    end
  end

  context 'with cpu values from kubernetes' do
    it 'translates between human readable k8s cpu vals and numeric ones' do
      expect(described_class.string_to_millicores(string: '')).to be_nil
    end

    it 'can handle numbers with millicores on them' do
      expect(described_class.string_to_millicores(string: '100m')).to eq(100)
    end
  end

  describe '#millicores_to_string' do
    it 'adds m to smaller numbers' do
      expect(described_class.millicores_to_string(millicores: 50)).to eq('50m')
    end

    it 'converts to CPUs for large numbers' do
      expect(described_class.millicores_to_string(millicores: 1_000)).to eq('1')
      expect(described_class.millicores_to_string(millicores: 1500)).to eq('1.5')
    end
  end

  context 'when rounding cpu values' do
    it 'rounds up millicores' do
      expect(described_class.round(millicores: 999)).to eq(1_000)
      expect(described_class.round(millicores: 990)).to eq(1_000)
    end

    it 'only rounds up' do
      expect(described_class.round(millicores: 901)).to be > 900
    end

    it 'rounds large values to half-cpus' do
      expect(described_class.round(millicores: 1400)).to eq(1500)
    end
  end
end
