#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/calculator'
begin
  CalculateNodes.new.write_csv

  puts 'CSV written to node-right-sizing-output.csv'
rescue PrometheusClientError => e
  puts "ERROR: #{e}"
end
