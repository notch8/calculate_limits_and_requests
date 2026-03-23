# frozen_string_literal: true

require 'csv'
require 'json'

require_relative 'node'
require_relative 'prometheus_client'
require_relative 'node_cpu'
require_relative 'node_memory'

# Wrapper class for calculating appropriate sizing for Kubernetes nodes
class CalculateNodes
  def write_csv
    headers = %w[provider_id name node_group cpu_capacity_current memory_capacity_current
                 cpu_95_m cpu_99_m memory_95_mi memory_99_mi memory_max_mi
                 cpu_request_recommended_mi cpu_limit_recommended_m memory_request_recommended_mi
                 memory_limit_recommended_mi].flatten
    CSV.open('node-right-sizing-output.csv', 'w') do |csv|
      csv << headers
      write_nodes(csv)
    end
  end

  def write_nodes(csv)
    all_nodes.each do |node|
      node.write_node(csv)
    end
  end

  def all_nodes
    @all_nodes ||= JSON.parse(`kubectl get nodes -o json`,
                              symbolize_names: true)[:items].map do |node_json|
                                Node.new(node_json)
                              end
  end
end
