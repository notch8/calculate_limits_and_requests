# frozen_string_literal: true

require 'calculate_nodes'
require 'nodes/node_group_recommender'
require 'nodes/cached_node'
require 'node_kubernetes'
require 'node_prometheus'

RSpec.describe Nodes::NodeGroupRecommender do
  include_context 'with nodes with access to kubernetes'
  include_context 'with nodes with access to prometheus'

  let(:nodes) { calculator.all_nodes }
  let(:recommender) { described_class.new(nodes) }

  describe '.headers' do
    it 'includes terraform_vars' do
      expect(described_class.headers).to include('terraform_vars')
    end
  end

  describe '#write_csv' do
    it 'produces rows with the correct number of columns' do
      rows = []
      recommender.write_csv(rows)
      data_rows = rows.reject(&:empty?)
      expect(data_rows.first.length).to eq(described_class.headers.length)
    end

    it 'puts terraform_vars only on the top recommendation row per group' do
      rows = []
      recommender.write_csv(rows)

      groups = rows.reject(&:empty?).group_by { |row| row[0] }
      groups.each_value do |group_rows|
        expect(group_rows.first.last).not_to be_nil
        group_rows[1..].each do |row|
          expect(row.last).to be_nil
        end
      end
    end
  end

  describe '#terraform_vars' do
    context 'with a regular node group' do
      it 'generates standard variable names' do
        result = recommender.send(:terraform_vars, 'general-nodegroup', 'm5.xlarge', 3)
        expect(result).to include('node_instance_type = "m5.xlarge"')
        expect(result).to include('desired_size       = 3')
        expect(result).to include('min_size           = 2')
        expect(result).to include('max_size           = 4')
      end

      it 'uses min_size of 1 when desired is 1' do
        result = recommender.send(:terraform_vars, 'general-nodegroup', 't3.medium', 1)
        expect(result).to include('min_size           = 1')
        expect(result).to include('desired_size       = 1')
        expect(result).to include('max_size           = 2')
      end
    end

    context 'with a stateful node group' do
      it 'generates stateful_ prefixed variable names' do
        result = recommender.send(:terraform_vars, 'stateful-nodes', 'r5.large', 2)
        expect(result).to include('stateful_node_instance_type = "r5.large"')
        expect(result).to include('stateful_desired_size       = 2')
        expect(result).to include('stateful_min_size           = 1')
        expect(result).to include('stateful_max_size           = 3')
      end
    end
  end
end
