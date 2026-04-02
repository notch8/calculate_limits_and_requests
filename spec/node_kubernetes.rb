# frozen_string_literal: true

RSpec.shared_context 'with nodes with access to kubernetes', kubernetes: :metadata do
  let(:calculator) { CalculateNodes.new }

  let(:command) do
    <<~CMD.chomp
      kubectl get pods -A \
        --field-selector=status.phase=Running \
        -o json | \
        jq '.items | group_by(.spec.nodeName) | map({node: .[0].spec.nodeName, pod_count: length}) | sort_by(.pod_count) | reverse'
    CMD
  end
  before do
    allow(CalculateNodes).to receive(:new).and_return(calculator)
    allow(calculator).to receive(:`)
      .with('kubectl get nodes -o json')
      .and_return(File.read(File.open('spec/fixtures/kubernetes_nodes.json')))
    allow(Nodes::AllNodes).to receive(:`)
      .with(command)
      .and_return(File.read(File.open('spec/fixtures/nodes/pod_count.json')))
  end
end
