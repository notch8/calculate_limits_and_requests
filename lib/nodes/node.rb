# frozen_string_literal: true

##
# Represents a node in a kubernetes cluster
class Node # rubocop:disable Metrics/ClassLength
  def self.headers
    %w[provider_id name instance_type node_group cpu_capacity_current memory_capacity_current
       ninety_five_in_millicores ninety_nine_in_millicores ninety_five_in_mebibytes
       ninety_nine_in_mebibytes pod_capacity_current current_pod_count ninety_five_cpu_percent
       ninety_nine_cpu_percent ninety_five_memory_percent ninety_nine_memory_percent allocated_cpu_requests
       allocated_memory_requests allocated_cpu_percent allocated_memory_percent cpu_headroom_millicores
       memory_headroom_mib]
  end

  def self.map_prometheus_to_node(prometheus_identifier:, prometheus_response_json:)
    prometheus_response_json.dig(:data, :result).find do |entry|
      entry.dig(:metric, :instance) == prometheus_identifier
    end
  end

  REGION = 'us-west-2'
  attr_reader :item_hash

  def initialize(item_hash)
    @item_hash = item_hash
  end

  # Identifier in Rancher and Kubectl
  def name
    item_hash.dig(:metadata, :name)
  end

  # Identifier for AWS
  def provider_id
    item_hash.dig(:spec, :providerID)&.sub(%r{aws:///#{REGION}[abc]/}o, '')
  end

  # Identifier in Prometheus
  def prometheus_identifier
    "#{internal_ip}:9100"
  end

  def node_group
    item_hash.dig(:metadata, :labels, :'eks.amazonaws.com/nodegroup')
  end

  # Represents vCPU cores
  def cpu_capacity_current
    item_hash.dig(:status, :capacity, :cpu)&.to_i
  end

  # Memory in Mi (Mebibytes)
  def memory_capacity_current
    Nodes::AwsClient.new.memory_capacity_by_instance_type(instance_type:).to_i
  end

  def instance_type
    item_hash.dig(:metadata, :labels, :'node.kubernetes.io/instance-type')
  end

  def internal_ip
    item_hash.dig(:status, :addresses).find { |addr| addr[:type] == 'InternalIP' }[:address]
  end

  def ninety_five_cpu_percent
    client = Nodes::PrometheusClient.new(quantile: 0.95, compute_type: 'cpu')
    our_quantile = Node.map_prometheus_to_node(prometheus_identifier:, prometheus_response_json: client.response_json)
    our_quantile.dig(:value, 1).to_f
  end

  def ninety_five_in_millicores
    ninety_five_cpu_percent * cpu_capacity_current * 1_000
  end

  def ninety_nine_cpu_percent
    client = Nodes::PrometheusClient.new(quantile: 0.99, compute_type: 'cpu')
    our_quantile = Node.map_prometheus_to_node(prometheus_identifier:, prometheus_response_json: client.response_json)
    our_quantile.dig(:value, 1).to_f
  end

  def ninety_nine_in_millicores
    ninety_nine_cpu_percent * cpu_capacity_current * 1_000
  end

  def ninety_five_memory_percent
    client = Nodes::PrometheusClient.new(quantile: 0.95, compute_type: 'memory')
    our_quantile = Node.map_prometheus_to_node(prometheus_identifier:, prometheus_response_json: client.response_json)
    our_quantile.dig(:value, 1).to_f
  end

  def ninety_five_in_mebibytes
    ninety_five_memory_percent * memory_capacity_current
  end

  def ninety_nine_memory_percent
    client = Nodes::PrometheusClient.new(quantile: 0.99, compute_type: 'memory')
    our_quantile = Node.map_prometheus_to_node(prometheus_identifier:, prometheus_response_json: client.response_json)
    our_quantile.dig(:value, 1).to_f
  end

  def ninety_nine_in_mebibytes
    ninety_nine_memory_percent * memory_capacity_current
  end

  def current_pod_count
    pod_entry = Nodes::AllNodes.current_pod_counts.find do |entry|
      entry[:node] == name
    end
    pod_entry[:pod_count]
  end

  def allocated_cpu_requests
    pod_entry = Nodes::AllNodes.sum_of_resources_by_node.find do |entry|
      entry[:node] == name
    end
    pod_entry&.dig(:cpu_millicores) || 0
  end

  def allocated_memory_requests
    pod_entry = Nodes::AllNodes.sum_of_resources_by_node.find do |entry|
      entry[:node] == name
    end
    pod_entry&.dig(:memory_mib) || 0
  end

  def allocated_cpu_percent
    allocated_cpu_requests / cpu_capacity_current_millicores.to_f
  end

  def allocated_memory_percent
    allocated_memory_requests / memory_capacity_current.to_f
  end

  def pod_capacity_current
    item_hash.dig(:status, :capacity, :pods)&.to_i
  end

  # How much headroom exists between scheduled requests and p99 actual usage
  def cpu_headroom_millicores
    allocated_cpu_requests - ninety_nine_in_millicores
  end

  def memory_headroom_mib
    allocated_memory_requests - ninety_nine_in_mebibytes
  end

  def cpu_capacity_current_millicores
    cpu_capacity_current * 1_000
  end

  def write_node(csv) # rubocop:disable Metrics/AbcSize
    csv << [provider_id, name, instance_type, node_group, cpu_capacity_current_millicores, memory_capacity_current,
            ninety_five_in_millicores, ninety_nine_in_millicores, ninety_five_in_mebibytes,
            ninety_nine_in_mebibytes, pod_capacity_current, current_pod_count, ninety_five_cpu_percent,
            ninety_nine_cpu_percent, ninety_five_memory_percent, ninety_nine_memory_percent, allocated_cpu_requests,
            allocated_memory_requests, allocated_cpu_percent, allocated_memory_percent, cpu_headroom_millicores,
            memory_headroom_mib]
  end
end
