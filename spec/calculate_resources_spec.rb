# frozen_string_literal: true

require 'prometheus'
require 'kubernetes'

RSpec.describe 'calculating resources' do
  include_context 'with access to prometheus'
  include_context 'with access to kubernetes'

  describe CalculateResources do
    describe 'creating pod items' do
      it 'can generate an array of items' do
        expect(calculator.pod_items.first).to be_an_instance_of(Item)
      end
    end

    describe 'combining pod items with quantiles' do
      it 'can assign values to Item' do
        item = calculator.pod_items.first
        item.containers.first.cpu_99_quantile_c
        quantile = item.containers.first.cpu_95_quantile_c
        expect(quantile).to eq(0.0011895495658745458)
        expect(item.containers.first.identifier).to eq('7a92c63742675dc745a4eb1533e4d9c5b848661c70713dc76a321bd06ad8fb90')
        expect(item.owner_name).to eq('loki')
      end
    end

    describe 'generating a CSV' do
      it 'can generate a csv' do
        calculator.write_csv
      end
    end

    describe 'getting memory maximums' do
      it 'can get the memory maximums from Prometheus' do
        item = calculator.pod_items.first
        memory_max = item.containers.first.memory_max
        expect(memory_max).to eq(27_238_400)
      end
    end
  end

  describe PrometheusClient do
    it 'can change query string based on data' do
      expect(cpu_95_prometheus_client.quantile_query_string).to eq('quantile_over_time(0.95, rate(container_cpu_usage_seconds_total{container!="",namespace!~"kube-.*"}[5m])[10d:5m])')
    end

    context '99th percentile for cpu' do
      let(:prometheus_client) { PrometheusClient.new(quantile: 0.99, compute_type: 'cpu') }

      it 'can change query string based on data' do
        expect(prometheus_client.quantile_query_string).to eq('quantile_over_time(0.99, rate(container_cpu_usage_seconds_total{container!="",namespace!~"kube-.*"}[5m])[10d:5m])')
      end
    end

    context '95th percentile for memory' do
      let(:prometheus_client) { PrometheusClient.new(quantile: 0.95, compute_type: 'memory') }

      it 'can change query string based on data' do
        expect(prometheus_client.quantile_query_string).to eq('quantile_over_time(0.95, container_memory_working_set_bytes{container!="",namespace!~"kube-.*"}[10d:1m])')
      end
    end

    context '99th percentile for memory' do
      let(:prometheus_client) { PrometheusClient.new(quantile: 0.99, compute_type: 'memory') }

      it 'can change query string based on data' do
        expect(prometheus_client.quantile_query_string).to eq('quantile_over_time(0.99, container_memory_working_set_bytes{container!="",namespace!~"kube-.*"}[10d:1m])')
      end
    end
  end

  describe Item do
    let(:item_json) do
      {
        spec: {
          containers: [
            {
              name: 'hyrax-worker',
              resources: {
                requests: { cpu: '100m', memory: '1Gi' },
                limits: { cpu: '1', memory: '2Gi' }
              }
            }
          ]
        },
        status: {
          containerStatuses: [
            { containerID: 'containerd://362ceb96e7974476a747003788070192bb53a8c32422dc098780e76404f5ecc9' }
          ]

        },
        metadata: {
          namespace: 'crash-world-cake-friends',
          name: 'crash-world-cake-friends-hyrax-auxiliary-worker-7fc9bc9796-',
          ownerReferences: [
            kind: 'ReplicaSet',
            name: 'crash-world-cake-friends-hyrax-auxiliary-worker-7fc9bc9796'
          ]
        }

      }
    end

    it 'has a bunch of things available on it' do
      item = described_class.new(item_json)

      expect(item.namespace).to eq('crash-world-cake-friends')
      expect(item.owner_kind).to eq('ReplicaSet')
      expect(item.owner_name).to eq('crash-world-cake-friends-hyrax-auxiliary-worker')
      expect(item.containers.first).to be_an_instance_of(Container)
      expect(item.containers.first.identifier).to eq('362ceb96e7974476a747003788070192bb53a8c32422dc098780e76404f5ecc9')
    end
  end

  describe Quantile do
    let(:item_hash) do
      {
        metric: { container: 'alertmanager', cpu: 'total', endpoint: 'https-metrics',
                  id: '/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-podeeb64709_3248_435c_b910_db0b8d5e390e.slice/cri-containerd-c03b6ba3fc4ede60862d1cde1662cd41193c4666984ebaa3189a3074886e69ba.scope', image: 'docker.io/rancher/mirrored-prometheus-alertmanager:v0.27.0', instance: '10.0.4.172:10250', job: 'kubelet', metrics_path: '/metrics/cadvisor', name: 'c03b6ba3fc4ede60862d1cde1662cd41193c4666984ebaa3189a3074886e69ba', namespace: 'cattle-monitoring-system', node: 'ip-10-0-4-172.us-west-2.compute.internal', pod: 'alertmanager-rancher-monitoring-alertmanager-0', service: 'rancher-monitoring-kubelet' }, value: [1_768_558_462.497, '0.00035376262047532507']
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

  describe ConversionService do
    context 'with cpu values from kubernetes' do
      it 'translates between human readable k8s cpu vals and numeric ones' do
        expect(described_class.k8s_cpu_to_millicores('')).to be_nil
      end

      it 'can handle numbers with millicores on them' do
        expect(described_class.k8s_cpu_to_millicores('100m')).to eq(100)
      end
    end

    context 'with memory values from kubernetes' do
      it 'translates between human readable k8s memory vals and numeric ones' do
        expect(described_class.k8s_memory_to_mi('')).to be_nil
      end

      it 'translates from strings that are already in mM' do
        expect(described_class.k8s_memory_to_mi('256Mi')).to eq(256)
      end

      it 'translates from strings that are in Gi to Mi' do
        expect(described_class.k8s_memory_to_mi('4Gi')).to eq(4096)
      end
    end
  end
end
