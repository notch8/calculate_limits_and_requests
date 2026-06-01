#!/usr/bin/env ruby
# frozen_string_literal: true

# Regenerates data/ec2_instance_pricing.csv from live AWS APIs.
#
# Usage:
#   ./bin/generate_pricing_csv.rb [--profile=PROFILE]
#
# Fetches:
#   - Instance type metadata (vCPU, memory, ENI limits) from ec2 describe-instance-types
#   - On-demand Linux pricing for us-west-2 from the AWS Pricing API
#
# max_pods is computed as: (max_network_interfaces * (ipv4_addresses_per_interface - 1)) + 2
# This is the standard EKS formula for ENI-based pod limits (without prefix delegation).

require 'json'
require 'csv'

PROFILE = ARGV.find { |a| a.start_with?('--profile=') }&.sub('--profile=', '') || 'default'
OUTPUT_PATH = File.join(__dir__, '../data/ec2_instance_pricing.csv')

def aws(service, subcommand, extra_args = '')
  cmd = "aws #{service} #{subcommand} --profile=#{PROFILE} #{extra_args} --output json"
  raw = `#{cmd}`
  raise "AWS CLI error running: #{cmd}\n#{raw}" unless $?.success?

  JSON.parse(raw)
end

# ---------------------------------------------------------------------------
# 1. Fetch all instance types with network info (paginated)
# ---------------------------------------------------------------------------
puts 'Fetching instance type metadata...'
instance_data = {}
next_token = nil

loop do
  token_arg = next_token ? "--next-token '#{next_token}'" : ''
  result = aws('ec2', 'describe-instance-types', token_arg)

  result['InstanceTypes'].each do |type|
    name = type['InstanceType']
    vcpu = type.dig('VCpuInfo', 'DefaultVCpus')
    memory_mib = type.dig('MemoryInfo', 'SizeInMiB')
    max_enis = type.dig('NetworkInfo', 'MaximumNetworkInterfaces')
    ips_per_eni = type.dig('NetworkInfo', 'Ipv4AddressesPerInterface')

    max_pods = if max_enis && ips_per_eni
                 (max_enis * (ips_per_eni - 1)) + 2
               end

    instance_data[name] = {
      instance_type: name,
      vcpu: vcpu,
      memory_mib: memory_mib,
      max_pods: max_pods
    }
  end

  next_token = result['NextToken']
  break unless next_token

  print '.'
end
puts "\nFound #{instance_data.size} instance types."

# ---------------------------------------------------------------------------
# 2. Fetch on-demand Linux pricing for us-west-2 (paginated)
# ---------------------------------------------------------------------------
puts 'Fetching on-demand pricing for us-west-2...'
pricing = {}
next_token = nil

filters = [
  'Type=TERM_MATCH,Field=location,Value="US West (Oregon)"',
  'Type=TERM_MATCH,Field=operatingSystem,Value=Linux',
  'Type=TERM_MATCH,Field=tenancy,Value=Shared',
  'Type=TERM_MATCH,Field=capacitystatus,Value=Used',
  'Type=TERM_MATCH,Field=preInstalledSw,Value=NA'
].join(' ')

loop do
  token_arg = next_token ? "--next-token '#{next_token}'" : ''
  result = aws('pricing', 'get-products',
               "--service-code AmazonEC2 --region us-east-1 --filters #{filters} #{token_arg}")

  result['PriceList'].each do |raw|
    product = JSON.parse(raw)
    instance_type = product.dig('product', 'attributes', 'instanceType')
    next unless instance_type

    on_demand = product.dig('terms', 'OnDemand')
    next unless on_demand

    price_per_unit = on_demand.values.first&.dig('priceDimensions')&.values&.first&.dig('pricePerUnit', 'USD')
    next if price_per_unit.nil? || price_per_unit.to_f.zero?

    pricing[instance_type] = price_per_unit.to_f
  end

  next_token = result['NextToken']
  break unless next_token

  print '.'
end
puts "\nFound pricing for #{pricing.size} instance types."

# ---------------------------------------------------------------------------
# 3. Merge and write CSV
# ---------------------------------------------------------------------------
rows = instance_data.values
  .select { |i| pricing.key?(i[:instance_type]) }
  .map do |i|
    {
      instance_type: i[:instance_type],
      vcpu: i[:vcpu],
      memory_mib: i[:memory_mib],
      price_per_hour: format('%.10f', pricing[i[:instance_type]]),
      max_pods: i[:max_pods]
    }
  end
  .sort_by { |r| r[:instance_type] }

CSV.open(OUTPUT_PATH, 'w') do |csv|
  csv << %w[instance_type vcpu memory_mib price_per_hour max_pods]
  rows.each { |r| csv << r.values }
end

puts "Wrote #{rows.size} rows to #{OUTPUT_PATH}"
puts "Instance types with no pricing data (excluded): #{instance_data.size - rows.size}"
