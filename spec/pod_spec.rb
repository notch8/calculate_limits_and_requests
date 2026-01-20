# frozen_string_literal: true

require 'prometheus'
RSpec.describe Pod do
  include_context 'with access to prometheus'
  let(:pod_json) do
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
    pod = described_class.new(pod_json)

    expect(pod.namespace).to eq('crash-world-cake-friends')
    expect(pod.owner_kind).to eq('ReplicaSet')
    expect(pod.owner_name).to eq('crash-world-cake-friends-hyrax-auxiliary-worker')
    expect(pod.containers.first).to be_an_instance_of(Container)
    expect(pod.containers.first.identifier).to eq('362ceb96e7974476a747003788070192bb53a8c32422dc098780e76404f5ecc9')
  end
end
