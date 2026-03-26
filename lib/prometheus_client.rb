# frozen_string_literal: true

##
# Custom error to remind to forward Prometheus pod to gather metrics
class PrometheusClientError < StandardError
  def initialize(msg = custom_message)
    super
  end

  def custom_message
    <<~MESSAGE
      Empty response from Prometheus - make sure you have run the following in another terminal window:

      kubectl port-forward -n monitoring \\
      svc/kube-prometheus-stack-prometheus 9090:9090
    MESSAGE
  end
end

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
    @quantile_data ||= JSON.parse(response, symbolize_names: true).dig(:data, :result)
  end

  def response
    response = `#{curl_command(quantile_query_string)}`
    raise PrometheusClientError if response.empty?

    response
  end

  def curl_command(query)
    "curl -s '#{PROMETHEUS_URL}/api/v1/query' --data-urlencode 'query=#{query}'"
  end

  def quantile_query_string
    if compute_type == 'cpu'
      Cpu.prometheus_command(quantile)
    else
      Memory.prometheus_command(quantile)
    end
  end

  def max_memory_query_string
    'max_over_time(container_memory_working_set_bytes{container!=""}[10d])'
  end
end
