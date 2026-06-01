# frozen_string_literal: true

require 'calculate_nodes'
require 'nodes/all_nodes'
require 'node_kubernetes'
require 'node_prometheus'

RSpec.describe Nodes::AllNodes do
  include_context 'with nodes with access to kubernetes'
  include_context 'with nodes with access to prometheus'

  describe '#current_pod_counts' do
    it 'returns an array of hashes' do
      expect(described_class.current_pod_counts(cluster: cluster)).to be_an_instance_of(Array)
      expect(described_class.current_pod_counts(cluster: cluster).size).to eq(7)
      expect(described_class.current_pod_counts(cluster: cluster).first.keys).to match_array(%i[node pod_count])
    end
  end

  describe '#container_resources' do
    it 'returns an array of hashes' do
      resources = described_class.container_resources(cluster: cluster)
      expect(resources).to be_an_instance_of(Array)
      expect(resources.size).to be_an_instance_of(Integer)
      expect(resources.size).to be > 0
      expect(resources.first.keys).to match_array(%i[node cpu_millicores memory_mib])
      expect(resources.first[:cpu_millicores]).to eq(1_000)
    end
  end

  describe '#sum_of_resources_by_node' do
    it 'returns an array of hashes - one per node' do
      resources = described_class.sum_of_resources_by_node(cluster: cluster)
      expect(resources).to be_an_instance_of(Array)
      expect(resources.size).to eq(14)
      expect(resources.first.keys).to match_array(%i[node cpu_millicores memory_mib])
      expect(resources.first[:cpu_millicores]).to eq(3490)
    end
  end
end
