# frozen_string_literal: true

RSpec.shared_context 'with access to kubernetes', kubernetes: :metadata do
  let(:cluster) { 'test-cluster' }
  let(:calculator) { CalculateResources.new(cluster: cluster) }

  before do
    allow(CalculateResources).to receive(:new).and_return(calculator)
    allow(calculator).to receive(:`)
      .with("kubectl get pods --all-namespaces --context=#{cluster} -o json")
      .and_return(File.read(File.open('spec/fixtures/kubernetes_pods_sanitized.json')))
    allow(calculator).to receive(:`)
      .with("kubectl get nodes --context=#{cluster} -o json")
      .and_return(File.read(File.open('spec/fixtures/kubernetes_nodes.json')))
  end
end
