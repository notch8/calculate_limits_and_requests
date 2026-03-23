# frozen_string_literal: true

RSpec.shared_context 'with access to kubernetes', kubernetes: :metadata do
  let(:calculator) { CalculateResources.new }
  let(:node_calculator) { CalculateNodes.new }

  before do
    allow(CalculateResources).to receive(:new).and_return(calculator)
    allow(calculator).to receive(:`)
      .with('kubectl get pods --all-namespaces -o json')
      .and_return(File.read(File.open('spec/fixtures/kubernetes_pods_sanitized.json')))
    allow(CalculateNodes).to receive(:new).and_return(node_calculator)
    allow(node_calculator).to receive(:`)
      .with('kubectl get nodes -o json')
      .and_return(File.read(File.open('spec/fixtures/kubernetes_nodes.json')))
  end
end
