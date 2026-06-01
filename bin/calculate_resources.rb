#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage:
#   ./bin/calculate_resources.rb <cluster>

require_relative '../lib/port_forward'
require_relative '../lib/calculate_resources'

cluster = ARGV.find { |a| !a.start_with?('--') }
abort('Usage: calculate_resources.rb <cluster>') unless cluster

PortForward.start(cluster: cluster)

begin
  puts "CSV written to #{CalculateResources.new(cluster: cluster).write_csv}"
rescue PrometheusClientError => e
  puts "ERROR: #{e}"
end
