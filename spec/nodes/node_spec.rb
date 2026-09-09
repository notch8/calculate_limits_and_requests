# frozen_string_literal: true

require 'nodes/node'
require 'node_kubernetes'
require 'node_prometheus'
require 'calculate_nodes'
RSpec.describe Node do
  include_context 'with nodes with access to kubernetes'
  include_context 'with nodes with access to prometheus'
  let(:node_hash) do
    {
      spec: {
        providerID: 'aws:///us-west-2a/i-09bd87854f37b123a'
      },
      status: {
        addresses: [
          {
            address: '10.0.4.243',
            type: 'InternalIP'
          },
          {
            address: '35.22.22.22',
            type: 'ExternalIP'
          }
        ],
        capacity: {
          cpu: '4',
          memory: '15992744Ki'
        }
      },
      metadata: {
        labels: {
          'eks.amazonaws.com/nodegroup': 'large-al2023-3',
          'node.kubernetes.io/instance-type': 'm5.xlarge'
        },
        name: 'ip-10-0-4-243.us-west-2.compute.internal'
      }
    }.transform_keys(&:to_sym)
  end

  let(:node) { described_class.new(node_hash, cluster: cluster) }

  it 'has a node name matching Rancher' do
    expect(node.name).to eq('ip-10-0-4-243.us-west-2.compute.internal')
  end

  it 'has the aws provider id' do
    expect(node.provider_id).to eq('i-09bd87854f37b123a')
  end

  it 'has the node_group' do
    expect(node.node_group).to eq('large-al2023-3')
  end

  it 'can map to the current cpu size' do
    expect(node.cpu_capacity_current).to eq(4)
  end

  it 'can map to the current memory size' do
    expect(node.memory_capacity_current).to eq(16_384)
  end

  it 'has the current instance_type' do
    expect(node.instance_type).to eq('m5.xlarge')
  end

  it 'has an identifier that maps to prometheus' do
    expect(node.prometheus_identifier).to eq('10.0.4.243:9100')
  end

  it 'has the 95th cpu quantile' do
    expect(node.ninety_five_in_millicores).to eq(1299.3753714987188)
  end

  it 'has the 99th cpu quantile' do
    expect(node.ninety_nine_in_millicores).to eq(1311.0666666669695)
  end

  it 'has the 95th memory quantile' do
    expect(node.ninety_five_in_mebibytes).to eq(6449.775892479292)
  end

  it 'has the 99th memory quantile' do
    expect(node.ninety_nine_in_mebibytes).to eq(6553.980076174507)
  end
end
