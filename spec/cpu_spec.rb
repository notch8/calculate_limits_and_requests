# frozen_string_literal: true

require 'prometheus'
RSpec.describe Cpu do
  include_context 'with access to prometheus'
  let(:current_resources) do
    { requests: { cpu: '100m', memory: '1Gi' }, limits: { cpu: '1', memory: '2Gi' } }
  end
  let(:cpu) { described_class.new(current_resources:, identifier: '1234', type: :rails_app) }

  it 'can be instantiated' do
    expect(cpu).to be_an_instance_of(described_class)
  end

  context 'with large values from prometheus' do
    let(:quantile_mock) { instance_double(Cpu::Quantile, ninety_five_in_millicores: 8_000, ninety_nine_in_millicores: 9_250) }

    before do
      allow(Cpu::Quantile).to receive(:new).and_return(quantile_mock)
    end

    it 'comes up with a reasonable recommendation' do
      expect(cpu.limit.recommended).to eq(14_000)
      expect(cpu.limit.display).to eq('14')
      expect(cpu.request.recommended).to eq(10_500)
      expect(cpu.request.display).to eq('10.5')
    end
  end

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
