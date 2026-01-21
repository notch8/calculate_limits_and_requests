# frozen_string_literal: true

require 'prometheus'

RSpec.describe Deployment do
  include_context 'with access to prometheus'

  let(:deployment) { described_class.new(namespace: 'palni-palci-knapsack', owner_name: 'hyku') }
  let(:identifier1) { '362ceb96e7974476a747003788070192bb53a8c32422dc098780e76404f5ecc9' }
  let(:identifier2) { '7a92c63742675dc745a4eb1533e4d9c5b848661c70713dc76a321bd06ad8fb90' }
  let(:identifier3) { 'abc123def456789012345678901234567890abcdef1234567890abcdef123456' }

  let(:container1) do
    Container.new({
                    name: 'hyku',
                    resources: {
                      requests: { cpu: '100m', memory: '1Gi' },
                      limits: { cpu: '1', memory: '2Gi' }
                    }
                  }, identifier1)
  end

  let(:container2) do
    Container.new({
                    name: 'hyku',
                    resources: {
                      requests: { cpu: '200m', memory: '2Gi' },
                      limits: { cpu: '2', memory: '4Gi' }
                    }
                  }, identifier2)
  end

  let(:container3) do
    Container.new({
                    name: 'hyku',
                    resources: {
                      requests: { cpu: '150m', memory: '1536Mi' },
                      limits: { cpu: '1500m', memory: '3Gi' }
                    }
                  }, identifier3)
  end

  let(:redis_container) do
    Container.new({
                    name: 'redis',
                    resources: {
                      requests: { cpu: '50m', memory: '256Mi' },
                      limits: { cpu: '500m', memory: '512Mi' }
                    }
                  }, identifier1)
  end

  describe '#initialize' do
    it 'creates a deployment with namespace and owner_name' do
      expect(deployment.namespace).to eq('palni-palci-knapsack')
      expect(deployment.owner_name).to eq('hyku')
      expect(deployment.containers).to eq([])
    end
  end

  describe '#add_container' do
    it 'adds containers to the deployment' do
      deployment.add_container(container1)
      deployment.add_container(container2)
      expect(deployment.containers.length).to eq(2)
      expect(deployment.containers).to include(container1, container2)
    end
  end

  describe '#primary_type' do
    context 'with a single container type' do
      before do
        deployment.add_container(container1)
        deployment.add_container(container2)
      end

      it 'returns the container type' do
        expect(deployment.primary_type).to eq(:rails_app)
      end
    end

    context 'with mixed container types' do
      before do
        deployment.add_container(container1) # rails_app
        deployment.add_container(redis_container) # cache
      end

      it 'returns the highest priority type' do
        expect(deployment.primary_type).to eq(:rails_app)
      end
    end

    context 'with no containers' do
      it 'returns utility as default' do
        expect(deployment.primary_type).to eq(:utility)
      end
    end
  end

  describe 'max value calculations' do
    before do
      deployment.add_container(container1)
      deployment.add_container(container2)
      deployment.add_container(container3)
    end

    describe '#max_cpu_request_current' do
      it 'returns the maximum CPU request across all containers' do
        # container1: 100m, container2: 200m, container3: 150m
        expect(deployment.max_cpu_request_current).to eq(200)
      end
    end

    describe '#max_cpu_limit_current' do
      it 'returns the maximum CPU limit across all containers' do
        # container1: 1000m, container2: 2000m, container3: 1500m
        expect(deployment.max_cpu_limit_current).to eq(2000)
      end
    end

    describe '#max_memory_request_current' do
      it 'returns the maximum memory request across all containers' do
        # container1: 1024Mi, container2: 2048Mi, container3: 1536Mi
        expect(deployment.max_memory_request_current).to eq(2048)
      end
    end

    describe '#max_memory_limit_current' do
      it 'returns the maximum memory limit across all containers' do
        # container1: 2048Mi, container2: 4096Mi, container3: 3072Mi
        expect(deployment.max_memory_limit_current).to eq(4096)
      end
    end

    describe '#max_cpu_95' do
      it 'returns the maximum 95th percentile CPU across all containers' do
        expect(deployment.max_cpu_95).to be_an_instance_of(Integer)
        expect(deployment.max_cpu_95).to be > 0
      end
    end

    describe '#max_cpu_99' do
      it 'returns the maximum 99th percentile CPU across all containers' do
        expect(deployment.max_cpu_99).to be_an_instance_of(Integer)
        expect(deployment.max_cpu_99).to be > 0
      end
    end

    describe '#max_memory_95' do
      it 'returns the maximum 95th percentile memory across all containers' do
        expect(deployment.max_memory_95).to be_an_instance_of(Integer)
        expect(deployment.max_memory_95).to be > 0
      end
    end

    describe '#max_memory_99' do
      it 'returns the maximum 99th percentile memory across all containers' do
        expect(deployment.max_memory_99).to be_an_instance_of(Integer)
        expect(deployment.max_memory_99).to be > 0
      end
    end

    describe '#max_memory_max' do
      it 'returns the maximum memory usage across all containers' do
        expect(deployment.max_memory_max).to be_an_instance_of(Integer)
        expect(deployment.max_memory_max).to be > 0
      end
    end

    describe '#max_cpu_request_recommended' do
      it 'returns the maximum recommended CPU request' do
        expect(deployment.max_cpu_request_recommended).to be_an_instance_of(Integer)
        # Should be at least the minimum for rails_app (100m)
        expect(deployment.max_cpu_request_recommended).to be >= 100
      end
    end

    describe '#max_cpu_limit_recommended' do
      it 'returns the maximum recommended CPU limit' do
        expect(deployment.max_cpu_limit_recommended).to be_an_instance_of(Integer)
        # Should be at least the minimum for rails_app (1000m)
        expect(deployment.max_cpu_limit_recommended).to be >= 1000
      end
    end

    describe '#max_memory_request_recommended' do
      it 'returns the maximum recommended memory request' do
        expect(deployment.max_memory_request_recommended).to be_an_instance_of(Integer)
        # Should be at least the minimum for rails_app (2048Mi)
        expect(deployment.max_memory_request_recommended).to be >= 2048
      end
    end

    describe '#max_memory_limit_recommended' do
      it 'returns the maximum recommended memory limit' do
        expect(deployment.max_memory_limit_recommended).to be_an_instance_of(Integer)
        # Should be at least the minimum for rails_app (4096Mi)
        expect(deployment.max_memory_limit_recommended).to be >= 4096
      end
    end
  end

  describe 'display methods' do
    before do
      deployment.add_container(container1)
      deployment.add_container(container2)
    end

    describe '#cpu_request_display' do
      it 'formats CPU request as a string' do
        display = deployment.cpu_request_display
        expect(display).to be_a(String)
        expect(display).to match(/^\d+m?$/) # Matches format like "100m" or "1"
      end
    end

    describe '#cpu_limit_display' do
      it 'formats CPU limit as a string' do
        display = deployment.cpu_limit_display
        expect(display).to be_a(String)
        expect(display).to match(/^\d+(\.\d+)?m?$/) # Matches format like "1000m" or "1" or "1.5"
      end
    end

    describe '#memory_request_display' do
      it 'formats memory request as a string' do
        display = deployment.memory_request_display
        expect(display).to be_a(String)
        expect(display).to match(/^\d+(Mi|Gi)$/) # Matches format like "2048Mi" or "2Gi"
      end
    end

    describe '#memory_limit_display' do
      it 'formats memory limit as a string' do
        display = deployment.memory_limit_display
        expect(display).to be_a(String)
        expect(display).to match(/^\d+(Mi|Gi)$/) # Matches format like "4096Mi" or "4Gi"
      end
    end
  end

  describe '#stanza' do
    before do
      deployment.add_container(container1)
      deployment.add_container(container2)
    end

    it 'generates a YAML stanza for deployment configuration' do
      stanza = deployment.stanza
      expect(stanza).to include('resources:')
      expect(stanza).to include('limits:')
      expect(stanza).to include('requests:')
      expect(stanza).to include('memory:')
      expect(stanza).to include('cpu:')
    end

    it 'includes the maximum recommended values' do
      stanza = deployment.stanza
      expect(stanza).to include(deployment.memory_limit_display)
      expect(stanza).to include(deployment.cpu_limit_display)
      expect(stanza).to include(deployment.memory_request_display)
      expect(stanza).to include(deployment.cpu_request_display)
    end
  end

  describe '.headers' do
    it 'returns an array of column headers' do
      headers = described_class.headers
      expect(headers).to be_an(Array)
      expect(headers).to include('namespace', 'owner', 'deployment_type', 'container_count')
      expect(headers).to include('cpu_request_current', 'cpu_limit_current')
      expect(headers).to include('memory_request_current', 'memory_limit_current')
      expect(headers).to include('cpu_95_m', 'cpu_99_m')
      expect(headers).to include('memory_95_mi', 'memory_99_mi', 'memory_max_mi')
      expect(headers).to include('cpu_request_recommended_mi', 'cpu_limit_recommended_m')
      expect(headers).to include('memory_request_recommended_mi', 'memory_limit_recommended_mi')
      expect(headers).to include('stanza')
    end
  end

  describe '#row' do
    before do
      deployment.add_container(container1)
      deployment.add_container(container2)
      deployment.add_container(container3)
    end

    it 'returns an array with all deployment data' do
      row = deployment.row
      expect(row).to be_an(Array)
      expect(row.length).to eq(18) # All columns including stanza
    end

    it 'includes namespace and owner_name' do
      row = deployment.row
      expect(row[0]).to eq('palni-palci-knapsack')
      expect(row[1]).to eq('hyku')
    end

    it 'includes deployment type and container count' do
      row = deployment.row
      expect(row[2]).to eq(:rails_app) # primary_type
      expect(row[3]).to eq(3) # container count
    end

    it 'includes maximum current values' do
      row = deployment.row
      expect(row[4]).to eq(200) # max_cpu_request_current
      expect(row[5]).to eq(2000) # max_cpu_limit_current
      expect(row[6]).to eq(2048) # max_memory_request_current
      expect(row[7]).to eq(4096) # max_memory_limit_current
    end

    it 'includes quantile values' do
      row = deployment.row
      expect(row[8]).to be_an(Integer) # cpu_95
      expect(row[9]).to be_an(Integer) # cpu_99
      expect(row[10]).to be_an(Integer) # memory_95
      expect(row[11]).to be_an(Integer) # memory_99
      expect(row[12]).to be_an(Integer) # memory_max
    end

    it 'includes recommended values' do
      row = deployment.row
      expect(row[13]).to be_an(Integer) # cpu_request_recommended
      expect(row[14]).to be_an(Integer) # cpu_limit_recommended
      expect(row[15]).to be_an(Integer) # memory_request_recommended
      expect(row[16]).to be_an(Integer) # memory_limit_recommended
    end

    it 'includes stanza as last element' do
      row = deployment.row
      expect(row[17]).to be_a(String)
      expect(row[17]).to include('resources:')
    end
  end

  describe 'handling containers with nil values' do
    let(:container_with_nil_cpu) do
      Container.new({
                      name: 'test',
                      resources: {
                        requests: {},
                        limits: {}
                      }
                    }, 'test123')
    end

    before do
      deployment.add_container(container1)
      deployment.add_container(container_with_nil_cpu)
    end

    it 'handles nil values gracefully in max calculations' do
      expect(deployment.max_cpu_request_current).to eq(100)
      expect(deployment.max_cpu_limit_current).to eq(1000)
    end
  end
end
