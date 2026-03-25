# frozen_string_literal: true

require_relative 'shared'
require_relative 'nodes/node'
require_relative 'nodes/prometheus_client'
require_relative 'nodes/aws_client'
require_relative 'nodes/all_nodes'
##
# Wrapper class for calculating appropriate limits and requests for Kubernetes nodes
class CalculateNodes
  def write_csv
    headers = [Node.headers].flatten
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
                              symbolize_names: true)[:items].map do |node_hash|
                                Node.new(node_hash)
                              end
  end
end
