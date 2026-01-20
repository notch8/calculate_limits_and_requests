# frozen_string_literal: true

##
# Represents the container on a kubernetes pod. Used to calculate appropriate requests and limits for that container
class Container
  attr_reader :container_json, :identifier, :pod_name, :owner_name, :cpu

  def initialize(container_json, identifier, pod_name, owner_name)
    @container_json = container_json
    @identifier = identifier
    @pod_name = pod_name
    @owner_name = owner_name
    @cpu = Cpu.new(identifier:, current_resources: container_json[:resources], type: type)
  end

  def name
    container_json[:name]
  end

  def combined
    "#{pod_name} #{name} #{owner_name}".downcase
  end

  def type
    case combined
    when /redis|memcached/
      :cache
    when /postgres|postgresql|mysql|mariadb/
      :database
    when /fcrepo/
      :fcrepo
    when /fits|solr|elasticsearch/
      :java_app
    when /nginx|webhook/
      :utility
    when /hyrax|hyku|rails|puma|passenger|worker|sidekiq|job|cable|clockwork|web/
      :rails_app
    else
      :utility
    end
  end

  def minimums
    MINIMUMS[type]
  end

  def self.headers
    %w[
      container container_type cpu_request_current cpu_limit_current memory_request_current
      memory_limit_current cpu_95_m cpu_99_m memory_95_mi memory_99_mi memory_max_mi
      cpu_request_recommended_mi cpu_limit_recommended_m memory_request_recommended_mi
      memory_limit_recommended_mi stanza
    ]
  end

  def row
    [
      name, type,
      current_display, quantile_display, memory_max_mi, recommended_display, stanza
    ].flatten
  end

  def current_display
    [cpu.request.current_millicores, cpu.limit.current_millicores, memory_request_current, memory_limit_current]
  end

  def quantile_display
    [cpu.quantile.ninety_five_in_millicores, cpu.quantile.ninety_nine_in_millicores,
     memory_95_quantile_mi, memory_99_quantile_mi]
  end

  def recommended_display
    [cpu.request.recommended, cpu.limit.recommended,
     memory_request_recommended, memory_limit_recommended]
  end

  def stanza
    <<-YAML.chomp
  resources:
    limits:
      memory: #{memory_limit_display}
      cpu: #{cpu.limit.display}
    requests:
      memory: #{memory_request_display}
      cpu: #{cpu.request.display}
    YAML
  end

  def memory_request_recommended
    minimum = minimums[:memory_request]
    return minimum unless memory_95_quantile_b

    multiplied = memory_95_quantile_b * MEMORY_REQUEST_MULTIPLIER
    [ConversionService.bytes_to_mi(multiplied), minimum].max
  end

  def memory_request_display
    if memory_request_recommended_rounded >= 1024
      "#{memory_request_recommended_rounded / 1024}Gi"
    else
      "#{memory_request_recommended_rounded}Mi"
    end
  end

  def memory_request_recommended_rounded
    2**Math.log2(memory_request_recommended).ceil
  end

  def memory_limit_display
    if memory_limit_recommended_rounded > 1024
      "#{memory_limit_recommended_rounded / 1024}Gi"
    else
      "#{memory_limit_recommended_rounded}Mi"
    end
  end

  def memory_limit_recommended
    minimum = minimums[:memory_limit]
    return minimum unless memory_99_quantile_b

    multiplied = memory_99_quantile_b * MEMORY_LIMIT_MULTIPLIER
    [ConversionService.bytes_to_mi(multiplied), minimum].max
  end

  def memory_limit_recommended_rounded
    2**Math.log2(memory_limit_recommended).ceil
  end

  def memory_request_current
    ConversionService.k8s_memory_to_mi(container_json.dig(:resources, :requests, :memory))
  end

  def memory_limit_current
    ConversionService.k8s_memory_to_mi(container_json.dig(:resources, :limits, :memory))
  end

  def memory_95_quantile_b
    @memory_95_quantile_b ||= CalculateResources.new.memory_95_quantiles.select do |quant|
      quant.name == identifier
    end.first&.value || nil
  end

  def memory_95_quantile_mi
    ConversionService.bytes_to_mi(memory_95_quantile_b)
  end

  def memory_99_quantile_b
    @memory_99_quantile_b ||= CalculateResources.new.memory_99_quantiles.select do |quant|
      quant.name == identifier
    end.first&.value || nil
  end

  def memory_99_quantile_mi
    ConversionService.bytes_to_mi(memory_99_quantile_b)
  end

  def memory_max
    @memory_max ||= CalculateResources.new.memory_maximums.select do |quant|
      quant.name == identifier
    end.first&.value || nil
  end

  def memory_max_mi
    ConversionService.bytes_to_mi(memory_max)
  end
end
