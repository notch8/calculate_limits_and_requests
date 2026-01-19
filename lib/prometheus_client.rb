# frozen_string_literal: true

##
# Utility class for connecting with Prometheus metrics API
# Right now this is a bit too intertwined with the "Quantile" concept
class PrometheusClient
  attr_reader :quantile, :compute_type

  def initialize(quantile:, compute_type:)
    @quantile = quantile
    @compute_type = compute_type
  end

  def quantile_list
    @quantile_list ||= quantile_data.map do |item|
      Quantile.new(item_hash: item)
    end
  end

  def max_memory_list
    @max_memory_list ||= max_memory_data.map do |item|
      MaxMemory.new(item_hash: item)
    end
  end

  def max_memory_data
    @max_memory_data ||= JSON.parse(`#{curl_command(max_memory_query_string)}`, symbolize_names: true).dig(:data,
                                                                                                           :result)
  end

  def quantile_data
    @quantile_data ||= JSON.parse(`#{curl_command(quantile_query_string)}`, symbolize_names: true).dig(:data, :result)
  end

  def curl_command(query)
    "curl -s '#{PROMETHEUS_URL}/api/v1/query' --data-urlencode 'query=#{query}'"
  end

  def quantile_query_string
    if compute_type == 'cpu'
      cpu_command(quantile)
    else
      memory_command(quantile)
    end
  end

  def cpu_command(quantile)
    <<~CMD.chomp
      quantile_over_time(#{quantile}, rate(container_cpu_usage_seconds_total{container!="",namespace!~"kube-.*"}[5m])[10d:5m])
    CMD
  end

  def memory_command(quantile)
    <<~CMD.chomp
      quantile_over_time(#{quantile}, container_memory_working_set_bytes{container!="",namespace!~"kube-.*"}[10d:1m])
    CMD
  end

  def max_memory_query_string
    'max_over_time(container_memory_working_set_bytes{container!="",namespace!~"kube-.*"}[10d])'
  end
end
