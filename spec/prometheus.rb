# frozen_string_literal: true

RSpec.shared_context 'with access to prometheus', prometheus: :metadata do
  let(:cpu_95_prometheus_client) { PrometheusClient.new(quantile: 0.95, compute_type: 'cpu', resource_type: 'pod') }
  let(:cpu_99_prometheus_client) { PrometheusClient.new(quantile: 0.99, compute_type: 'cpu') }
  let(:memory_95_prometheus_client) { PrometheusClient.new(quantile: 0.95, compute_type: 'memory')  }
  let(:memory_99_prometheus_client) { PrometheusClient.new(quantile: 0.99, compute_type: 'memory')  }
  let(:max_memory_prometheus_client) { PrometheusClient.new(quantile: nil, compute_type: 'memory') }
  let(:node_cpu_95_prometheus_client) do
    PrometheusClient.new(quantile: 0.95, compute_type: 'cpu', resource_type: 'node')
  end

  before do
    allow(PrometheusClient).to receive(:new).and_call_original
    allow(PrometheusClient).to receive(:new).with(quantile: 0.95,
                                                  compute_type: 'cpu', resource_type: 'pod')
                                            .and_return(cpu_95_prometheus_client)
    allow(PrometheusClient).to receive(:new).with(quantile: 0.99,
                                                  compute_type: 'cpu').and_return(cpu_99_prometheus_client)
    allow(PrometheusClient).to receive(:new).with(quantile: 0.95,
                                                  compute_type: 'memory').and_return(memory_95_prometheus_client)
    allow(PrometheusClient).to receive(:new).with(quantile: 0.99,
                                                  compute_type: 'memory').and_return(memory_99_prometheus_client)
    allow(PrometheusClient).to receive(:new).with(quantile: nil,
                                                  compute_type: 'memory').and_return(max_memory_prometheus_client)
    allow(cpu_95_prometheus_client).to receive(:`)
      .with(/curl/)
      .and_return(File.read(File.open('spec/fixtures/prometheus_95_cpu_sanitized.json')))
    allow(cpu_99_prometheus_client).to receive(:`)
      .with(/curl/)
      .and_return(File.read(File.open('spec/fixtures/prometheus_99_cpu_sanitized.json')))
    allow(memory_95_prometheus_client).to receive(:`)
      .with(/curl/)
      .and_return(File.read(File.open('spec/fixtures/prometheus_95_mem_sanitized.json')))
    allow(memory_99_prometheus_client).to receive(:`)
      .with(/curl/)
      .and_return(File.read(File.open('spec/fixtures/prometheus_99_mem_sanitized.json')))
    allow(max_memory_prometheus_client).to receive(:`)
      .with(/curl/)
      .and_return(File.read(File.open('spec/fixtures/prometheus_max_mem_sanitized.json')))
    allow(PrometheusClient).to receive(:new).with(quantile: 0.95,
                                                  compute_type: 'cpu', resource_type: 'node')
                                            .and_return(node_cpu_95_prometheus_client)
    allow(node_cpu_95_prometheus_client).to receive(:`)
      .with(/curl/)
      .and_return(File.read(File.open('spec/fixtures/nodes_prometheus_95_cpu.json')))
  end
end
