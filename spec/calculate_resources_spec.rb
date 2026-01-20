# frozen_string_literal: true

require 'prometheus'
require 'kubernetes'

RSpec.describe CalculateResources do
  include_context 'with access to prometheus'
  include_context 'with access to kubernetes'

  describe 'creating pod items' do
    it 'can generate an array of items' do
      expect(calculator.all_pods.first).to be_an_instance_of(Pod)
    end
  end

  describe 'combining pod items with quantiles' do
    it 'can assign values to Item' do
      item = calculator.all_pods.first
      item.containers.first.cpu.quantile.ninety_nine_in_cores
      quantile = item.containers.first.cpu.quantile.ninety_five_in_cores
      expect(quantile).to eq(0.0011895495658745458)
      expect(item.containers.first.identifier)
        .to eq('7a92c63742675dc745a4eb1533e4d9c5b848661c70713dc76a321bd06ad8fb90')
      expect(item.owner_name).to eq('loki')
    end
  end

  describe 'generating a CSV' do
    it 'can generate a csv' do
      calculator.write_csv
      expect(File.exist?('right-sizing-output.csv')).to be(true)
    end
  end

  describe 'getting memory maximums' do
    it 'can get the memory maximums from Prometheus' do
      item = calculator.all_pods.first
      memory_max = item.containers.first.memory.max.in_bytes
      expect(memory_max).to eq(27_238_400)
    end
  end
end
