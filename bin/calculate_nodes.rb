#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/calculate_nodes'

begin
  CalculateNodes.new.write_csv

  puts 'CSV written to node-right-sizing-output.csv'
rescue Nodes::PrometheusClientError, Nodes::PrometheusEmptyDataError => e
  puts "ERROR: #{e}"
end
