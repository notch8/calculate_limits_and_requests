# frozen_string_literal: true

require_relative 'shared'
require_relative 'nodes/node'
require_relative 'nodes/cached_node'
require_relative 'nodes/prometheus_client'
require_relative 'nodes/aws_client'
require_relative 'nodes/all_nodes'
require_relative 'nodes/node_group_recommender'

##
# Wrapper class for calculating appropriate limits and requests for Kubernetes nodes
class CalculateNodes
  def write_csv
    path = report_path('node-right-sizing-output.csv')
    headers = [Node.headers].flatten
    CSV.open(path, 'w') do |csv|
      csv << headers
      write_nodes(csv)
    end
    path
  end

  def write_recommendations_csv(nodes: all_nodes)
    path = report_path('node-group-recommendations-output.csv')
    CSV.open(path, 'w') do |csv|
      csv << Nodes::NodeGroupRecommender.headers
      Nodes::NodeGroupRecommender.new(nodes).write_csv(csv)
    end
    path
  end

  # Load CachedNode objects from an existing node CSV, bypassing Prometheus entirely.
  def self.load_cached_nodes(csv_path)
    CSV.read(csv_path, headers: true).map { |row| Nodes::CachedNode.from_csv_row(row) }
  end

  # Returns the path of today's node CSV if it already exists, nil otherwise.
  def self.today_node_csv_path
    path = report_path('node-right-sizing-output.csv')
    File.exist?(path) ? path : nil
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
