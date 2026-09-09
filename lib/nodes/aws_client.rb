# frozen_string_literal: true

module Nodes
  ##
  # Get data about instance types from AWS pricing CSV
  class AwsClient
    PRICING_CSV_PATH = File.join(__dir__, '../../data/ec2_instance_pricing.csv')

    def memory_capacity_by_instance_type(instance_type:)
      instance = pricing_data[instance_type]
      raise "Instance type not found in pricing data: #{instance_type}" unless instance

      instance[:memory_mib].to_s
    end

    def pricing_data
      @pricing_data ||= CSV.read(PRICING_CSV_PATH, headers: true).each_with_object({}) do |row, hash|
        hash[row['instance_type']] = {
          instance_type: row['instance_type'],
          vcpu: row['vcpu'].to_i,
          memory_mib: row['memory_mib'].to_i,
          price_per_hour: row['price_per_hour'].to_f,
          max_pods: max_pods(row:)
        }
      end
    end

    def max_pods(row:)
      max_pods = row['max_pods']&.to_i
      max_pods = nil if max_pods&.zero?
      max_pods
    end
  end
end
