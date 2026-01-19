# frozen_string_literal: true

require 'prometheus'

RSpec.describe PrometheusClient do
  include_context 'with access to prometheus'
  it 'can change query string based on data' do
    command = <<~YAML.chomp
      quantile_over_time(0.95, rate(container_cpu_usage_seconds_total{container!="",namespace!~"kube-.*"}[5m])[10d:5m])
    YAML
    expect(cpu_95_prometheus_client.quantile_query_string).to eq(command)
  end

  context 'with 99th percentile for cpu' do
    let(:prometheus_client) { described_class.new(quantile: 0.99, compute_type: 'cpu') }

    it 'can change query string based on data' do
      command = <<~YAML.chomp
        quantile_over_time(0.99, rate(container_cpu_usage_seconds_total{container!="",namespace!~"kube-.*"}[5m])[10d:5m])
      YAML
      expect(prometheus_client.quantile_query_string).to eq(command)
    end
  end

  context 'with 95th percentile for memory' do
    let(:prometheus_client) { described_class.new(quantile: 0.95, compute_type: 'memory') }

    it 'can change query string based on data' do
      command = <<~YAML.chomp
        quantile_over_time(0.95, container_memory_working_set_bytes{container!="",namespace!~"kube-.*"}[10d:1m])
      YAML
      expect(prometheus_client.quantile_query_string).to eq(command)
    end
  end

  context 'with 99th percentile for memory' do
    let(:prometheus_client) { described_class.new(quantile: 0.99, compute_type: 'memory') }

    it 'can change query string based on data' do
      command = <<~YAML.chomp
        quantile_over_time(0.99, container_memory_working_set_bytes{container!="",namespace!~"kube-.*"}[10d:1m])
      YAML
      expect(prometheus_client.quantile_query_string).to eq(command)
    end
  end
end
