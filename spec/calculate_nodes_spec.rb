# frozen_string_literal: true

require 'calculate_nodes'
require 'prometheus'
require 'kubernetes'

RSpec.describe CalculateNodes do
  include_context 'with access to prometheus'
  include_context 'with access to kubernetes'
  it 'can be instantiated' do
    expect { described_class.new }.not_to raise_error
  end

  describe 'generating a CSV' do
    it 'can generate a csv' do
      node_calculator.write_csv
      expect(File.exist?('node-right-sizing-output.csv')).to be(true)
    end
  end
end
