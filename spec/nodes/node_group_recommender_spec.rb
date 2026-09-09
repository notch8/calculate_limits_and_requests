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

    it 'includes terraform_vars on every recommendation row' do
      rows = []
      recommender.write_csv(rows)

      rows.reject(&:empty?).each do |row|
        expect(row.last).not_to be_nil
        expect(row.last).to include('instance_type')
        expect(row.last).to include('desired_size')
      end
    end
  end

  describe '#find_candidates pod budget' do
    # Build a minimal stub node that satisfies the recommender interface
    def stub_node(pod_count:, daemonset_count:)
      instance_double(Node,
                      instance_type: 'm5.xlarge',
                      node_group: 'test-group',
                      ninety_nine_in_millicores: 500,
                      ninety_nine_in_mebibytes: 1024,
                      allocated_cpu_requests: 400,
                      allocated_memory_requests: 800,
                      current_pod_count: pod_count,
                      daemonset_pod_count: daemonset_count)
    end

    it 'rejects a candidate when daemonsets alone fill every pod slot' do
      # Instance has 17 max_pods (t3.medium), daemonsets use 17 — no room for anything else
      nodes = Array.new(2) { stub_node(pod_count: 17, daemonset_count: 17) }
      rec = described_class.new(nodes)
      instance = { instance_type: 't3.medium', vcpu: 2, memory_mib: 4096,
                   price_per_hour: 0.04, max_pods: 17 }
      allow(rec).to receive(:candidate_instances).and_return([instance])
      rows = []
      rec.write_csv(rows)
      expect(rows.reject(&:empty?)).to be_empty
    end

    it 'accepts a candidate when available slots exceed regular pod count' do
      # 2 nodes, 10 pods each (8 daemonsets + 2 regular), switching to instance with 29 max_pods
      # available_for_regular = 29*2 - 8*2 = 42 > 4 regular pods needed
      nodes = Array.new(2) { stub_node(pod_count: 10, daemonset_count: 8) }
      rec = described_class.new(nodes)
      instance = { instance_type: 'm5.large', vcpu: 2, memory_mib: 8192,
                   price_per_hour: 0.096, max_pods: 29 }
      allow(rec).to receive(:candidate_instances).and_return([instance])
      rows = []
      rec.write_csv(rows)
      expect(rows.reject(&:empty?)).not_to be_empty
    end
  end

  describe '#t3_unlimited_surcharge' do
    let(:t3a_medium) { { instance_type: 't3a.medium', vcpu: 2, memory_mib: 4096, price_per_hour: 0.0376 } }
    let(:m5_xlarge)  { { instance_type: 'm5.xlarge',  vcpu: 4, memory_mib: 16_384, price_per_hour: 0.192 } }

    it 'returns 0 for non-burstable instances' do
      result = recommender.send(:t3_unlimited_surcharge, m5_xlarge, 4, 5000)
      expect(result).to eq(0)
    end

    it 'returns 0 when usage is below baseline' do
      # 6 t3a.medium: baseline = 6 * 2 * 0.20 * 1000 = 2400m; usage 1000m is under
      result = recommender.send(:t3_unlimited_surcharge, t3a_medium, 6, 1000)
      expect(result).to eq(0)
    end

    it 'calculates surcharge for usage above baseline' do
      # 6 t3a.medium: baseline = 2400m, usage = 4754m, surplus = 2354m = 2.354 vCPUs
      # surcharge = 2.354 * 0.05 * 730 = ~85.92
      result = recommender.send(:t3_unlimited_surcharge, t3a_medium, 6, 4754)
      expect(result).to be_within(0.01).of(85.92)
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
