#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/calculate_resources'
begin
  puts "CSV written to #{CalculateResources.new.write_csv}"
rescue PrometheusClientError => e
  puts "ERROR: #{e}"
end
