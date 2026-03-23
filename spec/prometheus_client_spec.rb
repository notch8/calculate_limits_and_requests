# frozen_string_literal: true

require 'prometheus'

RSpec.describe PrometheusClient do
  context 'with access to prometheus' do
    include_context 'with access to prometheus'

    it 'defaults to pod resources' do
      expect(cpu_95_prometheus_client.resource_type).to eq('pod')
    end

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

    describe 'node resources' do
      it 'can be instantiated with node resource and cpu' do
        command = <<~YAML.chomp
          quantile_over_time(0.95, (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))[10d:5m])
        YAML
        node_client = described_class.new(quantile: 0.95, compute_type: 'cpu', resource_type: 'node')
        expect(node_client.quantile_query_string).to eq(command)
      end

      it 'can be instantiated with node resource and memory' do
        command = <<~YAML.chomp
          quantile_over_time(0.95, (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))[10d:1m])
        YAML
        node_client = described_class.new(quantile: 0.95, compute_type: 'memory', resource_type: 'node')
        expect(node_client.quantile_query_string).to eq(command)
      end
    end
  end

  context 'without prometheus forwarded' do
    it 'raises an error' do
      expect do
        described_class.new(quantile: 0.99, compute_type: 'cpu').response
      end.to raise_error(PrometheusClientError, /Empty response from Prometheus/)
    end
  end
end
