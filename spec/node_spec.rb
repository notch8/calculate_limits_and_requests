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
      metadata: {
        labels: {
          'eks.amazonaws.com/nodegroup': 'large-al2023-3'
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
end
