# frozen_string_literal: true

##
# Represents Cpu objects
class Cpu
  attr_reader :request, :limit, :quantile, :type, :resource_type

  def initialize(identifier:, current_resources: nil, type: nil, resource_type: 'pod')
    @quantile = Quantile.new(identifier:, resource_type:)
    @resource_type = resource_type
    return unless resource_type == 'pod'

    minimums = MINIMUMS[type]
    @request = Request.new(current: current_resources.dig(:requests, :cpu),
                           minimum: minimums[:cpu_request],
                           quantile: quantile.ninety_five_in_millicores)
    @limit = Limit.new(current: current_resources.dig(:limits, :cpu),
                       minimum: minimums[:cpu_limit],
                       quantile: quantile.ninety_nine_in_millicores)
    @type = type
  end

  def self.prometheus_command(quantile, resource_type: 'pod')
    case resource_type
    when 'pod'
      Pod.prometheus_command(quantile)
    when 'node'
      Node.prometheus_command(quantile)
    else
      raise "Unexpected resource_type: #{resource_type}. Expected either 'pod' or 'node'"
    end
  end

  # Doesn't know the resource_type because it's a class method, not an instance method
  # Need to figure out a way to get the list for nodes, rather than pods
  def self.ninety_five_quantiles(resource_type: 'pod')
    PrometheusClient.new(quantile: 0.95, compute_type: 'cpu', resource_type:).quantile_list
  end

  def self.ninety_nine_quantiles
    PrometheusClient.new(quantile: 0.99, compute_type: 'cpu').quantile_list
  end

  def self.string_to_millicores(string:)
    return nil if string&.empty?

    if string.match?(/m$/)
      string.chop.to_i
    else
      string.to_i * 1_000
    end
  end

  def self.cores_to_millicores(cores:)
    return nil unless cores

    [1, (cores * 1000).to_i].max
  end

  # TODO: use this and actually round
  def self.round(millicores:)
    case millicores
    when 0..100
      # Round to nearest 10m
      ((millicores / 10.0).ceil * 10)
    when 101..500
      # Round to nearest 50m
      ((millicores / 50.0).ceil * 50)
    when 501..1000
      # Round to nearest 100m
      ((millicores / 100.0).ceil * 100)
    else
      # Round to nearest 250m
      ((millicores / 250.0).ceil * 250)
    end
  end

  def self.millicores_to_string(millicores:)
    if millicores >= 1_000
      return (millicores / 1_000).to_s if (millicores % 1_000).zero?

      (millicores / 1_000.0).to_s
    else
      "#{millicores}m"
    end
  end

  ##
  # Pod-specific methods related to CPU
  class Pod
    def self.prometheus_command(quantile)
      query = 'quantile_over_time(%s, rate(container_cpu_usage_seconds_total{container!="",namespace!~"kube-.*"}' \
              '[5m])[10d:5m])'
      format(query, quantile)
    end
  end

  ##
  # Node-specific methods related to CPU
  class Node
    def self.prometheus_command(quantile)
      query = 'quantile_over_time(%s, (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))[10d:5m])'
      format(query, quantile)
    end
  end

  ##
  # Shared between CPU limits and requests
  class CpuComputeResource
    attr_reader :current, :minimum, :quantile

    def initialize(current:, minimum:, quantile:)
      @current = current
      @minimum = minimum
      @quantile = quantile
    end

    def current_string
      current || ''
    end

    def current_millicores
      Cpu.string_to_millicores(string: current_string)
    end

    def recommended
      Cpu.round(millicores: recommendation_in_millicores_raw)
    end

    def display
      Cpu.millicores_to_string(millicores: recommended)
    end
  end

  ##
  # Requests for Cpu objects
  class Request < CpuComputeResource
    private

    def recommendation_in_millicores_raw
      return minimum unless quantile

      rec = Cpu.round(millicores: quantile * CPU_REQUEST_MULTIPLIER)

      [rec, minimum].max
    end
  end

  ##
  # Limits for Cpu objects
  class Limit < CpuComputeResource
    private

    def recommendation_in_millicores_raw
      return minimum unless quantile

      rec = Cpu.round(millicores: quantile * CPU_LIMIT_MULTIPLIER)

      [rec, minimum].max
    end
  end

  ##
  # Quantiles for Cpu objects
  class Quantile
    attr_reader :identifier, :resource_type

    def initialize(identifier:, resource_type: 'pod')
      @identifier = identifier
      @resource_type = resource_type
    end

    def ninety_five_in_millicores
      Cpu.cores_to_millicores(cores: ninety_five_in_cores)
    end

    def ninety_five_in_cores
      Cpu.ninety_five_quantiles(resource_type:).find do |quant|
        byebug
        quant.name == identifier
      end&.value || nil
    end

    def ninety_nine_in_millicores
      Cpu.cores_to_millicores(cores: ninety_nine_in_cores)
    end

    def ninety_nine_in_cores
      @ninety_nine_in_cores ||= Cpu.ninety_nine_quantiles.find do |quant|
        quant.name == identifier
      end&.value || nil
    end
  end
end
