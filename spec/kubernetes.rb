RSpec.shared_context 'with access to kubernetes', kubernetes: :metadata do
  let(:calculator) { CalculateResources.new }

  before do
    allow(CalculateResources).to receive(:new).and_return(calculator)
    allow(calculator).to receive(:`)
      .with('kubectl get pods --all-namespaces -o json')
      .and_return(File.read(File.open('spec/fixtures/kubernetes_pods_sanitized.json')))
  end
end
