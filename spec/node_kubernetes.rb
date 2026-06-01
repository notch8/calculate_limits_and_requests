# frozen_string_literal: true

RSpec.shared_context 'with nodes with access to kubernetes', kubernetes: :metadata do
  let(:cluster) { 'test-cluster' }
  let(:calculator) { CalculateNodes.new(cluster: cluster) }

  let(:pod_command) do
    <<~CMD.chomp
      kubectl get pods -A --context=#{cluster} \
        --field-selector=status.phase=Running \
        -o json | \
        jq '.items | group_by(.spec.nodeName) | map({node: .[0].spec.nodeName, pod_count: length})'
    CMD
  end
  let(:container_command) do
    <<~CMD.chomp
      kubectl get pods -A --context=#{cluster} \
        --field-selector=status.phase=Running \
        -o json | \
        jq '[.items[] | {node: .spec.nodeName, containers: .spec.containers[].resources.requests}] | map({node: .node, cpu_millicores: .containers.cpu, memory_mib: .containers.memory})'
    CMD
  end
  before do
    allow(CalculateNodes).to receive(:new).and_return(calculator)
    allow(calculator).to receive(:`)
      .with("kubectl get nodes --context=#{cluster} -o json")
      .and_return(File.read(File.open('spec/fixtures/kubernetes_nodes.json')))
    allow(Nodes::AllNodes).to receive(:`)
      .with(pod_command)
      .and_return(File.read(File.open('spec/fixtures/nodes/pod_count.json')))
    allow(Nodes::AllNodes).to receive(:`)
      .with(container_command)
      .and_return(File.read(File.open('spec/fixtures/nodes/container_resources.json')))
  end
end
