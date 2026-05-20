# frozen_string_literal: true

module Nodes
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

  class PrometheusEmptyDataError < StandardError
  end

  ##
  # PrometheusClient specific to nodes - connects to prometheus instance running on cluster, port-forwarded
  # (see readme for instructions on forwarding)
  class PrometheusClient
    attr_reader :quantile, :compute_type

    def initialize(quantile:, compute_type:)
      @quantile = quantile
      @compute_type = compute_type
    end

    def curl_command(query)
      "curl -s '#{PROMETHEUS_URL}/api/v1/query' --data-urlencode 'query=#{query}'"
    end

    def response
      response = `#{curl_command(quantile_query_string)}`
      raise PrometheusClientError if response.empty?

      response
    end

    def response_json
      response_json = JSON.parse(response, symbolize_names: true)
      if response_json[:status] == 'success' && response_json[:data][:result].empty?
        raise(PrometheusEmptyDataError,
              'Got a response from Prometheus, but the data was empty. Original curl command was: ' \
              "#{curl_command(quantile_query_string)}")
      end

      response_json
    end

    def max_memory_data
      @max_memory_data ||= JSON.parse(`#{curl_command(max_memory_query_string)}`, symbolize_names: true).dig(:data,
                                                                                                             :result)
    end

    def max_memory_query_string
      'max_over_time((1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))[30d:1m])'
    end

    def quantile_query_string
      query = if compute_type == 'cpu'
                'quantile_over_time(%s, (1 - avg by (instance) ' \
                  '(rate(node_cpu_seconds_total{mode="idle"}[1m])))[30d:1m])'
              else
                'quantile_over_time(%s, (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))[30d:1m])'
              end
      format(query, quantile)
    end
  end
end
