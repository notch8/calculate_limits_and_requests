# frozen_string_literal: true

##
# Represents a kubernetes node.
class Node
  REGION = 'us-west-2'
  attr_reader :item_json

  def initialize(item_json)
    @item_json = item_json
  end

  def name
    item_json.dig(:metadata, :name)
  end

  def node_group
    item_json.dig(:metadata, :labels, :'eks.amazonaws.com/nodegroup')
  end

  # Represents vCPU cores
  def cpu_capacity_current
    item_json.dig(:status, :capacity, :cpu)&.to_i
  end

  def ninety_five_in_millicores
    ''
    # cpu.quantile.ninety_five_in_millicores
  end

  # Memory in Ki
  def memory_capacity_current
    item_json.dig(:status, :capacity, :memory)&.sub('Ki', '')
  end

  def instance_type
    item_json.dig(:metadata, :labels, :'node.kubernetes.io/instance-type')
  end

  def provider_id
    # aws:\/\/\/us-west-2[abc]\/i-09bd87854f37b962d
    item_json.dig(:spec, :providerID)&.sub(%r{aws:///#{REGION}[abc]/}o, '')
  end

  def internal_ip
    item_json.dig(:status, :addresses).find { |addr| addr[:type] == 'InternalIP' }[:address]
  end

  def prometheus_identifier
    "#{internal_ip}:9100"
  end

  def write_node(csv)
    item_info = [provider_id, name, node_group, cpu_capacity_current, memory_capacity_current,
                 ninety_five_in_millicores]
    csv << item_info
  end
end
