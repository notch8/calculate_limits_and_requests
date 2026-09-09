# frozen_string_literal: true

require 'prometheus'
require 'kubernetes'
RSpec.describe Pod do
  include_context 'with access to prometheus'
  include_context 'with access to kubernetes'
  let(:pod_hash) do
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
          { containerID: 'containerd://362ceb96e7974476a747003788070192bb53a8c32422dc098780e76404f5ecc9',
            name: 'hyrax-worker' }
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
    pod = described_class.new(pod_hash)

    expect(pod.namespace).to eq('crash-world-cake-friends')
    expect(pod.owner_kind).to eq('ReplicaSet')
    expect(pod.owner_name).to eq('crash-world-cake-friends-hyrax-auxiliary-worker')
    expect(pod.containers.first).to be_an_instance_of(Container)
    expect(pod.containers.first.identifier).to eq('362ceb96e7974476a747003788070192bb53a8c32422dc098780e76404f5ecc9')
  end

  context 'when the pod errored before containers were created' do
    let(:pod) do
      described_class.new(pod_hash.merge(status: {}))
    end

    it 'does not raise a NoMethodError when calling containers' do
      expect { pod.containers }.not_to raise_error
    end
  end

  context 'with multiple containers' do
    let(:pod) do
      calculator.all_pods[29]
    end

    it 'associates the container with the appropriate id' do
      expect(pod.name).to eq('prometheus-rancher-monitoring-prometheus-0')
      expect(pod.containers.map(&:name)).to match_array(%w[config-reloader prometheus prometheus-proxy])
      expect(pod.containers.find do |cont|
        cont.name == 'config-reloader'
      end.identifier).to eq('c5ae469a9ddf45c60e5f7fb5e5d09380c32fafaa42b0b1c392aedfcc70de69fb')
    end
  end
end
