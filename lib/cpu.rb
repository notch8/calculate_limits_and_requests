# frozen_string_literal: true

##
# Represents Cpu objects
class Cpu
  attr_reader :request, :limit, :quantile, :type

  def initialize(identifier:, current_resources:, type:)
    @quantile = Quantile.new(identifier:)
    @request = Request.new(current: current_resources.dig(:requests, :cpu),
                           minimum: MINIMUMS[type][:cpu_request],
                           quantile: quantile.ninety_five_in_millicores)
    @limit = Limit.new(current: current_resources.dig(:limits, :cpu),
                       minimum: MINIMUMS[type][:cpu_limit],
                       quantile: quantile.ninety_nine_in_millicores)
    @type = type
  end

  def self.string_to_millicores(string:)
    return nil if string&.empty? || string.nil?

    if string.match(/m$/)
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
  # Requests for Cpu objects
  class Request
    attr_reader :current, :minimum, :quantile

    def initialize(current:, minimum:, quantile:)
      @current = current
      @minimum = minimum
      @quantile = quantile
    end

    def current_string
      current
    end

    def current_millicores
      Cpu.string_to_millicores(string: current)
    end

    def recommended
      Cpu.round(millicores: recommendation_in_millicores_raw)
    end

    def display
      Cpu.millicores_to_string(millicores: recommended)
    end

    private

    def recommendation_in_millicores_raw
      return minimum unless quantile

      rec = Cpu.round(millicores: quantile * CPU_REQUEST_MULTIPLIER)

      [rec, minimum].max
    end
  end

  ##
  # Limits for Cpu objects
  class Limit
    attr_reader :current, :minimum, :quantile

    def initialize(current:, minimum:, quantile:)
      @current = current
      @minimum = minimum
      @quantile = quantile
    end

    def current_string
      current
    end

    def display
      Cpu.millicores_to_string(millicores: recommended)
    end

    def current_millicores
      Cpu.string_to_millicores(string: current)
    end

    def recommended
      Cpu.round(millicores: recommendation_in_millicores_raw)
    end

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
    attr_reader :identifier

    def initialize(identifier:)
      @identifier = identifier
    end

    def ninety_five_in_millicores
      Cpu.cores_to_millicores(cores: ninety_five_in_cores)
    end

    def ninety_five_in_cores
      @ninety_five_in_cores ||= CalculateResources.new.cpu_95_quantiles.select do |quant|
        quant.name == identifier
      end.first&.value || nil
    end

    def ninety_nine_in_millicores
      Cpu.cores_to_millicores(cores: ninety_nine_in_cores)
    end

    def ninety_nine_in_cores
      @ninety_nine_in_cores ||= CalculateResources.new.cpu_99_quantiles.select do |quant|
        quant.name == identifier
      end.first&.value || nil
    end
  end
end
