# frozen_string_literal: true

require 'calculate_nodes'
require 'node_prometheus'
RSpec.describe Nodes::PrometheusClient do
  context 'with nodes with access to prometheus' do
    include_context 'with nodes with access to prometheus'
    it 'can change query string based on data' do
      command = <<~YAML.chomp
        quantile_over_time(0.95, (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))[10d:5m])
      YAML
      expect(cpu_95_prometheus_client.quantile_query_string).to eq(command)
    end

    context 'with 99th percentile for cpu' do
      let(:prometheus_client) { described_class.new(quantile: 0.99, compute_type: 'cpu') }

      it 'can change query string based on data' do
        command = <<~YAML.chomp
          quantile_over_time(0.99, (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))[10d:5m])
        YAML
        expect(prometheus_client.quantile_query_string).to eq(command)
      end
    end

    context 'with 95th percentile for memory' do
      let(:prometheus_client) { described_class.new(quantile: 0.95, compute_type: 'memory') }

      it 'can change query string based on data' do
        command = <<~YAML.chomp
          quantile_over_time(0.95, (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))[10d:1m])
        YAML
        expect(prometheus_client.quantile_query_string).to eq(command)
      end
    end

    context 'with 99th percentile for memory' do
      let(:prometheus_client) { described_class.new(quantile: 0.99, compute_type: 'memory') }

      it 'can change query string based on data' do
        command = <<~YAML.chomp
          quantile_over_time(0.99, (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))[10d:1m])
        YAML
        expect(prometheus_client.quantile_query_string).to eq(command)
      end
    end

    context 'with an empty response' do
      let(:prometheus_client) { described_class.new(quantile: 0.90, compute_type: 'memory') }

      it 'raises an error' do
        expect do
          prometheus_client.response_json
        end.to raise_error(Nodes::PrometheusEmptyDataError,
                           /Original curl command was: curl -s/)
      end
    end
  end

  context 'without prometheus forwarded' do
    it 'raises an error' do
      expect do
        described_class.new(quantile: 0.99, compute_type: 'cpu').response
      end.to raise_error(Nodes::PrometheusClientError, /Empty response from Prometheus/)
    end
  end
end
