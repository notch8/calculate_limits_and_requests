# frozen_string_literal: true

##
# Represents the container on a kubernetes pod. Used to calculate appropriate requests and limits for that container
class Container
  attr_reader :container_json, :identifier, :pod_name, :owner_name

  def initialize(container_json, identifier, pod_name, owner_name)
    @container_json = container_json
    @identifier = identifier
    @pod_name = pod_name
    @owner_name = owner_name
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
      cpu_request_current, cpu_limit_current, memory_request_current, memory_limit_current,
      cpu_95_quantile_m, cpu_99_quantile_m, memory_95_quantile_mi, memory_99_quantile_mi, memory_max_mi,
      cpu_request_recommended, cpu_limit_recommended, memory_request_recommended, memory_limit_recommended, stanza
    ]
  end

  def stanza
    <<-YAML.chomp
  resources:
    limits:
      memory: #{memory_limit_display}
      cpu: #{cpu_limit_display}
    requests:
      memory: #{memory_request_display}
      cpu: #{cpu_request_display}
    YAML
  end

  def cpu_to_s(millicores); end

  def memory_to_s(mebibytes); end

  def round_cpu(millicores)
    millicores
  end

  def round_memory(mebibytes); end

  def cpu_request_recommended
    minimum = minimums[:cpu_request]
    return minimum unless cpu_95_quantile_m

    rec = round_cpu(cpu_95_quantile_m * CPU_REQUEST_MULTIPLIER)

    [rec, minimum].max
  end

  def cpu_request_display
    if cpu_request_recommended >= 1000
      cpu_request_recommended / 1000
    else
      "#{cpu_request_recommended}m"
    end
  end

  def cpu_limit_recommended
    minimum = minimums[:cpu_limit]
    return minimum unless cpu_99_quantile_m

    rec = round_cpu(cpu_99_quantile_m * CPU_LIMIT_MULTIPLIER)
    [rec, minimum].max
  end

  def cpu_limit_display
    if cpu_limit_recommended >= 1000
      cpu_limit_recommended / 1000
    else
      "#{cpu_limit_recommended}m"
    end
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

  def cpu_request_current
    ConversionService.k8s_cpu_to_millicores(container_json.dig(:resources, :requests, :cpu))
  end

  def cpu_limit_current
    ConversionService.k8s_cpu_to_millicores(container_json.dig(:resources, :limits, :cpu))
  end

  def memory_request_current
    ConversionService.k8s_memory_to_mi(container_json.dig(:resources, :requests, :memory))
  end

  def memory_limit_current
    ConversionService.k8s_memory_to_mi(container_json.dig(:resources, :limits, :memory))
  end

  def cpu_95_quantile_c
    @cpu_95_quantile_c ||= CalculateResources.new.cpu_95_quantiles.select do |quant|
      quant.name == identifier
    end.first&.value || nil
  end

  def cpu_95_quantile_m
    ConversionService.cores_to_millicores(cpu_95_quantile_c)
  end

  def cpu_99_quantile_c
    @cpu_99_quantile_c ||= CalculateResources.new.cpu_99_quantiles.select do |quant|
      quant.name == identifier
    end.first&.value || nil
  end

  def cpu_99_quantile_m
    ConversionService.cores_to_millicores(cpu_99_quantile_c)
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
