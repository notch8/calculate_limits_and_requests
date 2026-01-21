#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/calculate_resources'
begin
  CalculateResources.new.write_csv

  puts 'CSV written to right-sizing-output.csv'
rescue PrometheusClientError => e
  puts "ERROR: #{e}"
end
