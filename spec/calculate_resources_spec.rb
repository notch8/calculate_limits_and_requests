# frozen_string_literal: true

require 'prometheus'
require 'kubernetes'

RSpec.describe CalculateResources do
  include_context 'with access to prometheus'
  include_context 'with access to kubernetes'

  describe 'creating pod items' do
    it 'can generate an array of items' do
      expect(calculator.all_pods.first).to be_an_instance_of(Pod)
    end
  end

  describe 'combining pod items with quantiles' do
    it 'can assign values to Item' do
      item = calculator.all_pods.first
      item.containers.first.cpu.quantile.ninety_nine_in_cores
      quantile = item.containers.first.cpu.quantile.ninety_five_in_cores
      expect(quantile).to eq(0.0011895495658745458)
      expect(item.containers.first.identifier)
        .to eq('7a92c63742675dc745a4eb1533e4d9c5b848661c70713dc76a321bd06ad8fb90')
      expect(item.owner_name).to eq('loki')
    end
  end

  describe 'generating a CSV' do
    it 'can generate a csv' do
      calculator.write_csv
      expect(File.exist?('right-sizing-output.csv')).to be(true)
    end
  end

  describe 'getting memory maximums' do
    it 'can get the memory maximums from Prometheus' do
      item = calculator.all_pods.first
      memory_max = item.containers.first.memory.max.in_bytes
      expect(memory_max).to eq(27_238_400)
    end
  end

  describe '#deployments' do
    it 'groups pods by namespace and owner_name' do
      deployments = calculator.deployments
      expect(deployments).to be_an(Array)
      expect(deployments.first).to be_an_instance_of(Deployment)
    end

    it 'creates unique deployments for each namespace/owner/container combination' do
      deployments = calculator.deployments
      deployment_keys = deployments.map { |d| "#{d.namespace}/#{d.owner_name}/#{d.container_name}" }
      expect(deployment_keys.uniq.length).to eq(deployment_keys.length)
    end

    it 'aggregates all containers from pods with the same deployment' do
      deployments = calculator.deployments
      # Each deployment should have at least one container
      deployments.each do |deployment|
        expect(deployment.containers).not_to be_empty
      end
    end

    it 'includes containers from all pods in the deployment' do
      deployments = calculator.deployments
      total_containers_in_deployments = deployments.sum { |d| d.containers.length }
      total_containers_in_pods = calculator.all_pods.sum { |p| p.containers.length }
      expect(total_containers_in_deployments).to eq(total_containers_in_pods)
    end
  end

  describe '#write_deployments' do
    it 'writes deployment rows to CSV' do
      csv_rows = []
      calculator.write_deployments(csv_rows)
      expect(csv_rows).not_to be_empty
      expect(csv_rows.length).to eq(calculator.deployments.length)
    end

    it 'writes rows with correct structure' do
      csv_rows = []
      calculator.write_deployments(csv_rows)
      csv_rows.each do |row|
        expect(row).to be_an(Array)
        expect(row.length).to eq(19) # All deployment columns
        expect(row[0]).to be_a(String) # namespace
        expect(row[1]).to be_a(String) # owner_name
        expect(row[2]).to be_a(String) # container_name
        expect(row[3]).to be_a(Symbol) # container_type
        expect(row[4]).to be_an(Integer) # pod_count
      end
    end
  end

  describe 'generating a deployment CSV' do
    it 'generates a CSV with deployment-level data' do
      calculator.write_csv
      expect(File.exist?('right-sizing-output.csv')).to be(true)

      csv_content = CSV.read('right-sizing-output.csv')
      expect(csv_content).not_to be_empty

      # Check headers
      headers = csv_content.first
      expect(headers).to eq(Deployment.headers)

      # Check that we have deployment rows
      expect(csv_content.length).to be > 1 # At least headers + one row
    end

    it 'groups containers by deployment and container name in CSV output' do
      calculator.write_csv
      csv_content = CSV.read('right-sizing-output.csv')

      # Skip header row
      data_rows = csv_content[1..]

      # Each row should represent a unique namespace/owner/container combination
      deployment_identifiers = data_rows.map { |row| "#{row[0]}/#{row[1]}/#{row[2]}" }
      expect(deployment_identifiers.uniq.length).to eq(deployment_identifiers.length)
    end

    it 'includes pod count in CSV output' do
      calculator.write_csv
      csv_content = CSV.read('right-sizing-output.csv')

      # Skip header row
      data_rows = csv_content[1..]

      data_rows.each do |row|
        pod_count = row[4].to_i # pod_count column
        expect(pod_count).to be > 0
      end
    end

    it 'includes container name in CSV output' do
      calculator.write_csv
      csv_content = CSV.read('right-sizing-output.csv')

      # Skip header row
      data_rows = csv_content[1..]

      data_rows.each do |row|
        container_name = row[2] # container column
        expect(container_name).to be_a(String)
        expect(container_name).not_to be_empty
      end
    end

    it 'includes stanza in CSV output' do
      calculator.write_csv
      csv_content = CSV.read('right-sizing-output.csv')

      # Skip header row
      data_rows = csv_content[1..]

      data_rows.each do |row|
        stanza = row[18] # stanza is last column
        expect(stanza).to include('resources:')
        expect(stanza).to include('limits:')
        expect(stanza).to include('requests:')
      end
    end
  end
end
