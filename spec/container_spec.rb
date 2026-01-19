# frozen_string_literal: true

require 'prometheus'
RSpec.describe Container do
  include_context 'with access to prometheus'
  let(:container) do
    described_class.new(container_json, identifier, 'hyku-demo-hyrax-worker-64b578df7f-dghnr',
                        'hyku-demo-hyrax-worker')
  end
  let(:identifier) { '362ceb96e7974476a747003788070192bb53a8c32422dc098780e76404f5ecc9' }
  let(:container_json) do
    {
      name: 'hyrax-worker',
      resources: {
        requests: { cpu: '100m', memory: '1Gi' },
        limits: { cpu: '1', memory: '2Gi' }
      }
    }
  end
  let(:stanza_string) do
    <<-YAML.chomp
  resources:
    limits:
      memory: 4Gi
      cpu: 1
    requests:
      memory: 2Gi
      cpu: 100m
    YAML
  end

  it 'has a name' do
    expect(container.name).to eq('hyrax-worker')
  end

  it 'has requests and limits' do
    expect(container.cpu_request_current).to eq(100)
    expect(container.cpu_limit_current).to eq(1000)
    expect(container.memory_request_current).to eq(1024)
    expect(container.memory_limit_current).to eq(2048)
    expect(container.identifier).to eq(identifier)
  end

  it 'can give recommendations for cpu requests' do
    # container = described_class.new(container_json, identifier)
    expect(container.cpu_request_recommended).to be_an_instance_of(Integer)
    expect(container.cpu_request_recommended).to eq(100)
  end

  it 'can give recommendations for cpu limits' do
    expect(container.cpu_limit_recommended).to be_an_instance_of(Integer)
    expect(container.cpu_limit_recommended).to eq(1000)
  end

  it 'can determine a likely container type' do
    expect(container.type).to eq(:rails_app)
  end

  it 'has sane values for the row' do
    expect(container.row).to eq(['hyrax-worker', :rails_app, 100, 1000, 1024, 2048, 1, 26, 714, 716, 718, 100, 1000,
                                 2048, 4096, stanza_string])
  end

  it 'can generate a stanza for copy-pasting' do
    expect(container.stanza).to eq(stanza_string)
  end
end
