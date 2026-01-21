# frozen_string_literal: true

##
# For memory resources and requests for containers
class Memory
  attr_reader :request, :limit, :quantile, :type, :max

  def initialize(identifier:, current_resources:, type:)
    @quantile = Quantile.new(identifier:)
    minimums = MINIMUMS[type]
    @request = Request.new(current: current_resources.dig(:requests, :memory),
                           minimum: minimums[:memory_request],
                           quantile: quantile.ninety_five_in_mi)
    @limit = Limit.new(current: current_resources.dig(:limits, :memory),
                       minimum: minimums[:memory_limit],
                       quantile: quantile.ninety_nine_in_mi)
    @max = Max.new(identifier:)
  end

  def self.prometheus_command(quantile)
    <<~CMD.chomp
      quantile_over_time(#{quantile}, container_memory_working_set_bytes{container!="",namespace!~"kube-.*"}[10d:1m])
    CMD
  end

  def self.ninety_five_quantiles
    @ninety_five_quantiles ||= PrometheusClient.new(quantile: 0.95, compute_type: 'memory').quantile_list
  end

  def self.ninety_nine_quantiles
    @ninety_nine_quantiles ||= PrometheusClient.new(quantile: 0.99, compute_type: 'memory').quantile_list
  end

  def self.memory_maximums
    @memory_maximums ||= PrometheusClient.new(quantile: nil, compute_type: 'memory').max_memory_list
  end

  def self.string_to_mebibytes(string:)
    return nil if string&.empty? # || string.nil?

    as_integer = string[0..-3].to_i
    if string.match(/Mi$/)
      as_integer
    elsif string.match(/Gi$/)
      as_integer * 1024
    end
  end

  def self.round(mebibytes:)
    return mebibytes if (mebibytes % 1024).zero?

    if mebibytes < 1024
      # round to nearest power of 2
      2**Math.log2(mebibytes).ceil
    else
      (mebibytes / 512.0).ceil * 512
    end
  end

  def self.bytes_to_mi(bytes:)
    return nil unless bytes

    mi = (bytes / (1024.0 * 1024.0)).to_i
    [1, mi].max
  end

  def self.mebibytes_to_string(mebibytes:)
    if mebibytes >= 1024
      "#{mebibytes / 1024}Gi"
    else
      "#{mebibytes}Mi"
    end
  end

  ##
  # Memory compute resources shared with limits and requests
  class MemoryComputeResource
    attr_reader :current, :minimum, :quantile

    def initialize(current:, minimum:, quantile:)
      @current = current
      @minimum = minimum
      @quantile = quantile
    end

    def current_string
      current || ''
    end

    def current_normalized
      Memory.string_to_mebibytes(string: current_string)
    end

    def display
      Memory.mebibytes_to_string(mebibytes: recommended)
    end

    def recommended
      Memory.round(mebibytes: recommendation_in_mebibytes_raw)
    end
  end

  ##
  # Memory requests
  class Request < MemoryComputeResource
    private

    def recommendation_in_mebibytes_raw
      return minimum unless quantile

      multiplied = quantile * MEMORY_REQUEST_MULTIPLIER
      [Memory.bytes_to_mi(bytes: multiplied), minimum].max
    end
  end

  ##
  # Memory limits
  class Limit < MemoryComputeResource
    private

    def recommendation_in_mebibytes_raw
      return minimum unless quantile

      multiplied = quantile * MEMORY_LIMIT_MULTIPLIER
      [Memory.bytes_to_mi(bytes: multiplied), minimum].max
    end
  end

  ##
  # Used for calculating recommended limits and requests
  class Quantile
    attr_reader :identifier

    def initialize(identifier:)
      @identifier = identifier
    end

    def ninety_five_in_mi
      Memory.bytes_to_mi(bytes: ninety_five_in_bytes)
    end

    def ninety_nine_in_mi
      Memory.bytes_to_mi(bytes: ninety_nine_in_bytes)
    end

    def ninety_five_in_bytes
      @ninety_five_in_bytes ||= Memory.ninety_five_quantiles.select do |quant|
        quant.name == identifier
      end.first&.value || nil
    end

    def ninety_nine_in_bytes
      @ninety_nine_in_bytes ||= Memory.ninety_nine_quantiles.select do |quant|
        quant.name == identifier
      end.first&.value || nil
    end
  end

  ##
  # Used for displaying maximum memory used by container to ensure we are recommending reasonable limits
  class Max
    attr_reader :identifier

    def initialize(identifier:)
      @identifier = identifier
    end

    def in_bytes
      @in_bytes ||= Memory.memory_maximums.select do |quant|
        quant.name == identifier
      end.first&.value || nil
    end

    def in_mi
      Memory.bytes_to_mi(bytes: in_bytes)
    end
  end
end
