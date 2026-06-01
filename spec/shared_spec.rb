# frozen_string_literal: true

require 'shared'

RSpec.describe '#report_path' do
  it 'includes the cluster name in the path' do
    path = report_path('my-cluster', 'output.csv')
    expect(path).to include('my-cluster')
    expect(path).to include('output.csv')
  end

  it 'sanitizes special characters in the cluster name' do
    path = report_path('arn:aws:eks:us-east-1:123456789:cluster/my-cluster', 'output.csv')
    filename = File.basename(path)
    expect(filename).not_to include(':')
    expect(filename).not_to include('/')
  end

  it "includes today's date" do
    path = report_path('test-cluster', 'output.csv')
    date = Time.now.strftime('%Y-%m-%d')
    expect(path).to include(date)
  end
end
