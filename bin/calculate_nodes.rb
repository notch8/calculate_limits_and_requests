#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage:
#   ./bin/calculate_nodes.rb <cluster>           # use today's cached report if it exists
#   ./bin/calculate_nodes.rb <cluster> --fresh   # re-query Prometheus and kubectl regardless

require_relative '../lib/port_forward'
require_relative '../lib/calculate_nodes'

cluster = ARGV.find { |a| !a.start_with?('--') }
abort('Usage: calculate_nodes.rb <cluster> [--fresh]') unless cluster

fresh = ARGV.include?('--fresh')

PortForward.start(cluster: cluster)

cached_path = CalculateNodes.today_node_csv_path(cluster)

begin
  if !fresh && cached_path
    puts "Using cached node data from #{cached_path} (pass --fresh to re-query)"
    nodes = CalculateNodes.load_cached_nodes(cached_path)
    puts "CSV written to #{CalculateNodes.new(cluster: cluster).write_recommendations_csv(nodes: nodes)}"
  else
    puts 'Querying kubectl and Prometheus...' if fresh && cached_path
    calculator = CalculateNodes.new(cluster: cluster)
    puts "CSV written to #{calculator.write_csv}"
    puts "CSV written to #{calculator.write_recommendations_csv}"
  end
rescue Nodes::PrometheusClientError, Nodes::PrometheusEmptyDataError => e
  puts "ERROR: #{e}"
end
