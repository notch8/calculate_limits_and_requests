# frozen_string_literal: true

require 'calculate_nodes'
require 'node_kubernetes'
require 'node_prometheus'

RSpec.describe CalculateNodes do
  include_context 'with nodes with access to kubernetes'
  include_context 'with nodes with access to prometheus'

  it 'can be instantiated' do
    expect { described_class.new(cluster: cluster) }.not_to raise_error
  end

  describe 'generating a CSV' do
    it 'can generate a csv' do
      path = calculator.write_csv
      expect(File.exist?(path)).to be(true)
    end
  end
end
