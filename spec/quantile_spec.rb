# frozen_string_literal: true

RSpec.describe Quantile do
  let(:item_hash) do
    {
      metric: {
        container: 'alertmanager', cpu: 'total', endpoint: 'https-metrics',
        image: 'docker.io/rancher/mirrored-prometheus-alertmanager:v0.27.0', instance: '10.0.4.172:10250',
        job: 'kubelet', metrics_path: '/metrics/cadvisor',
        name: 'c03b6ba3fc4ede60862d1cde1662cd41193c4666984ebaa3189a3074886e69ba', namespace: 'cattle-monitoring-system',
        node: 'ip-10-0-4-172.us-west-2.compute.internal', pod: 'alertmanager-rancher-monitoring-alertmanager-0',
        service: 'rancher-monitoring-kubelet'
      },
      value: [1_768_558_462.497, '0.00035376262047532507']
    }
  end
  let(:quantile) { described_class.new(item_hash:) }

  it 'has necessary properties' do
    expect(quantile.namespace).to eq('cattle-monitoring-system')
    expect(quantile.pod).to eq('alertmanager-rancher-monitoring-alertmanager-0')
    expect(quantile.container).to eq('alertmanager')
    expect(quantile.value).to eq(0.00035376262047532507)
  end
end
