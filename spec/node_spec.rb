# frozen_string_literal: true

require 'prometheus'
require 'kubernetes'
RSpec.describe Node do
  include_context 'with access to prometheus'
  include_context 'with access to kubernetes'

  let(:node_hash) do
    {
      spec: {
        providerID: 'aws:///us-west-2a/i-09bd87854f37b962d'
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

  let(:node) { described_class.new(node_hash) }

  it 'has a node name matching Rancher' do
    expect(node.name).to eq('ip-10-0-4-243.us-west-2.compute.internal')
  end

  it 'has the aws provider id' do
    expect(node.provider_id).to eq('i-09bd87854f37b962d')
  end

  it 'has the node_group' do
    expect(node.node_group).to eq('large-al2023-3')
  end

  it 'can map to the current cpu size' do
    expect(node.cpu_capacity_current).to eq(4)
  end

  it 'can map to the current memory size' do
    expect(node.memory_capacity_current).to eq('15992744')
  end

  it 'can pull in the ninety_five_in_millicores from prometheus' do
    expect(node.ninety_five_in_millicores).to eq('')
  end

  it 'has the current instance_type' do
    expect(node.instance_type).to eq('m5.xlarge')
  end

  it 'has an identifier that maps to prometheus' do
    expect(node.prometheus_identifier).to eq('10.0.4.243:9100')
  end
end
