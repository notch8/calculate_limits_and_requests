#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage:
#   ./bin/calculate_nodes.rb           # use today's cached report if it exists
#   ./bin/calculate_nodes.rb --fresh   # re-query Prometheus and kubectl regardless

require_relative '../lib/calculate_nodes'

fresh = ARGV.include?('--fresh')
cached_path = CalculateNodes.today_node_csv_path

begin
  if !fresh && cached_path
    puts "Using cached node data from #{cached_path} (pass --fresh to re-query)"
    nodes = CalculateNodes.load_cached_nodes(cached_path)
    puts "CSV written to #{CalculateNodes.new.write_recommendations_csv(nodes: nodes)}"
  else
    puts 'Querying kubectl and Prometheus...' if fresh && cached_path
    calculator = CalculateNodes.new
    puts "CSV written to #{calculator.write_csv}"
    puts "CSV written to #{calculator.write_recommendations_csv}"
  end
rescue Nodes::PrometheusClientError, Nodes::PrometheusEmptyDataError => e
  puts "ERROR: #{e}"
end
