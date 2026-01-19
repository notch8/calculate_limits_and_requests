# frozen_string_literal: true

RSpec.describe Item do
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
