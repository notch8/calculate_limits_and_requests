# frozen_string_literal: true

module Nodes
  ##
  # A lightweight read-only stand-in for Node populated from a saved CSV row.
  # Exposes the same interface that NodeGroupRecommender needs so it works
  # unchanged whether nodes come from live Prometheus data or a cached report.
  CachedNode = Struct.new(
    :instance_type,
    :node_group,
    :ninety_nine_in_millicores,
    :ninety_nine_in_mebibytes,
    :allocated_cpu_requests,
    :allocated_memory_requests,
    :current_pod_count,
    keyword_init: true
  ) do
    def self.from_csv_row(row)
      new(
        instance_type: row['instance_type'],
        node_group: row['node_group'],
        ninety_nine_in_millicores: row['ninety_nine_in_millicores'].to_f,
        ninety_nine_in_mebibytes: row['ninety_nine_in_mebibytes'].to_f,
        allocated_cpu_requests: row['allocated_cpu_requests'].to_f,
        allocated_memory_requests: row['allocated_memory_requests'].to_f,
        current_pod_count: row['current_pod_count'].to_i
      )
    end
  end
end
