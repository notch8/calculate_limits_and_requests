# frozen_string_literal: true

##
# Represents the container on a kubernetes pod. Used to calculate appropriate requests and limits for that container
class Container
  attr_reader :container_json, :identifier, :cpu, :memory

  def initialize(container_json, identifier, pod_name, owner_name)
    @container_json = container_json
    @identifier = identifier
    @combined = "#{pod_name} #{name} #{owner_name}".downcase
    resources = container_json[:resources]
    @cpu = Cpu.new(identifier:, current_resources: resources, type: type)
    @memory = Memory.new(identifier:, current_resources: resources, type: type)
  end

  def name
    container_json[:name]
  end

  def type
    case @combined
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
      current_display, quantile_display, memory.max.in_mi, recommended_raw, stanza
    ].flatten
  end

  def current_display
    [cpu.request.current_millicores, cpu.limit.current_millicores, memory.request.current_normalized,
     memory.limit.current_normalized]
  end

  def quantile_display
    cpu_quantile = cpu.quantile
    memory_quantile = memory.quantile
    [cpu_quantile.ninety_five_in_millicores, cpu_quantile.ninety_nine_in_millicores,
     memory_quantile.ninety_five_in_mi, memory_quantile.ninety_nine_in_mi]
  end

  def recommended_raw
    [cpu.request.recommended, cpu.limit.recommended,
     memory.request.recommended, memory.limit.recommended]
  end

  def stanza
    <<-YAML.chomp
  resources:
    limits:
      memory: #{memory.limit.display}
      cpu: #{cpu.limit.display}
    requests:
      memory: #{memory.request.display}
      cpu: #{cpu.request.display}
    YAML
  end
end
