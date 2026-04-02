# frozen_string_literal: true

RSpec.shared_context 'with nodes with access to prometheus', prometheus: :metadata do
  let(:cpu_95_prometheus_client) { Nodes::PrometheusClient.new(quantile: 0.95, compute_type: 'cpu') }
  let(:cpu_99_prometheus_client) { Nodes::PrometheusClient.new(quantile: 0.99, compute_type: 'cpu') }
  let(:memory_90_prometheus_client) { Nodes::PrometheusClient.new(quantile: 0.90, compute_type: 'memory') }
  let(:memory_95_prometheus_client) { Nodes::PrometheusClient.new(quantile: 0.95, compute_type: 'memory')  }
  let(:memory_99_prometheus_client) { Nodes::PrometheusClient.new(quantile: 0.99, compute_type: 'memory')  }
  let(:max_memory_prometheus_client) { Nodes::PrometheusClient.new(quantile: nil, compute_type: 'memory') }

  before do
    allow(Nodes::PrometheusClient).to receive(:new).and_call_original
    allow(Nodes::PrometheusClient).to receive(:new).with(quantile: 0.95,
                                                         compute_type: 'cpu')
                                                   .and_return(cpu_95_prometheus_client)
    allow(Nodes::PrometheusClient).to receive(:new).with(quantile: 0.99,
                                                         compute_type: 'cpu')
                                                   .and_return(cpu_99_prometheus_client)
    allow(Nodes::PrometheusClient).to receive(:new).with(quantile: 0.90,
                                                         compute_type: 'memory').and_return(memory_90_prometheus_client)
    allow(Nodes::PrometheusClient).to receive(:new).with(quantile: 0.95,
                                                         compute_type: 'memory')
                                                   .and_return(memory_95_prometheus_client)
    allow(Nodes::PrometheusClient).to receive(:new).with(quantile: 0.99,
                                                         compute_type: 'memory')
                                                   .and_return(memory_99_prometheus_client)
    allow(Nodes::PrometheusClient).to receive(:new).with(quantile: nil,
                                                         compute_type: 'memory')
                                                   .and_return(max_memory_prometheus_client)
    allow(cpu_95_prometheus_client).to receive(:`)
      .with(/curl/)
      .and_return(File.read(File.open('spec/fixtures/nodes/prometheus_95_cpu.json')))
    allow(cpu_99_prometheus_client).to receive(:`)
      .with(/curl/)
      .and_return(File.read(File.open('spec/fixtures/nodes/prometheus_99_cpu.json')))
    allow(memory_90_prometheus_client).to receive(:`)
      .with(/curl/)
      .and_return(File.read(File.open('spec/fixtures/empty_response.json')))
    allow(memory_95_prometheus_client).to receive(:`)
      .with(/curl/)
      .and_return(File.read(File.open('spec/fixtures/nodes/prometheus_95_mem.json')))
    allow(memory_99_prometheus_client).to receive(:`)
      .with(/curl/)
      .and_return(File.read(File.open('spec/fixtures/nodes/prometheus_99_mem.json')))
    allow(max_memory_prometheus_client).to receive(:`)
      .with(/curl/)
      .and_return(File.read(File.open('spec/fixtures/nodes/prometheus_max_mem.json')))
  end
end
