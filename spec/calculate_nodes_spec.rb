# frozen_string_literal: true

require 'calculate_nodes'
require 'node_kubernetes'
require 'node_prometheus'

RSpec.describe CalculateNodes do
  include_context 'with nodes with access to kubernetes'
  include_context 'with nodes with access to prometheus'
  it 'can be instantiated' do
    expect { described_class.new }.not_to raise_error
  end

  describe 'generating a CSV' do
    it 'can generate a csv' do
      calculator.write_csv
      expect(File.exist?('node-right-sizing-output.csv')).to be(true)
    end
  end
end
