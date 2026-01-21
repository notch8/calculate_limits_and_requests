# frozen_string_literal: true

##
# Represents a Kubernetes deployment, grouping all containers across all pods
# Calculates maximum values across all containers for right-sizing recommendations
class Deployment
  attr_reader :namespace, :owner_name, :containers

  # Container type priority (higher priority types take precedence)
  TYPE_PRIORITY = {
    rails_app: 5,
    java_app: 4,
    fcrepo: 3,
    database: 2,
    cache: 1,
    utility: 0
  }.freeze

  def initialize(namespace:, owner_name:, containers: [])
    @namespace = namespace
    @owner_name = owner_name
    @containers = containers
  end

  def add_container(container)
    @containers << container
  end

  # Returns the most demanding container type in this deployment
  def primary_type
    containers.map(&:type).max_by { |type| TYPE_PRIORITY[type] } || :utility
  end

  # Calculate maximum current CPU request across all containers
  def max_cpu_request_current
    containers.map { |c| c.cpu.request.current_millicores }.compact.max
  end

  # Calculate maximum current CPU limit across all containers
  def max_cpu_limit_current
    containers.map { |c| c.cpu.limit.current_millicores }.compact.max
  end

  # Calculate maximum current memory request across all containers
  def max_memory_request_current
    containers.map { |c| c.memory.request.current_normalized }.compact.max
  end

  # Calculate maximum current memory limit across all containers
  def max_memory_limit_current
    containers.map { |c| c.memory.limit.current_normalized }.compact.max
  end

  # Calculate maximum 95th percentile CPU across all containers
  def max_cpu_95
    containers.map { |c| c.cpu.quantile.ninety_five_in_millicores }.compact.max
  end

  # Calculate maximum 99th percentile CPU across all containers
  def max_cpu_99
    containers.map { |c| c.cpu.quantile.ninety_nine_in_millicores }.compact.max
  end

  # Calculate maximum 95th percentile memory across all containers
  def max_memory_95
    containers.map { |c| c.memory.quantile.ninety_five_in_mi }.compact.max
  end

  # Calculate maximum 99th percentile memory across all containers
  def max_memory_99
    containers.map { |c| c.memory.quantile.ninety_nine_in_mi }.compact.max
  end

  # Calculate maximum memory usage across all containers
  def max_memory_max
    containers.map { |c| c.memory.max.in_mi }.compact.max
  end

  # Calculate maximum recommended CPU request across all containers
  def max_cpu_request_recommended
    containers.map { |c| c.cpu.request.recommended }.compact.max
  end

  # Calculate maximum recommended CPU limit across all containers
  def max_cpu_limit_recommended
    containers.map { |c| c.cpu.limit.recommended }.compact.max
  end

  # Calculate maximum recommended memory request across all containers
  def max_memory_request_recommended
    containers.map { |c| c.memory.request.recommended }.compact.max
  end

  # Calculate maximum recommended memory limit across all containers
  def max_memory_limit_recommended
    containers.map { |c| c.memory.limit.recommended }.compact.max
  end

  # Display format for recommended CPU request
  def cpu_request_display
    max = max_cpu_request_recommended
    max ? Cpu.millicores_to_string(millicores: max) : ''
  end

  # Display format for recommended CPU limit
  def cpu_limit_display
    max = max_cpu_limit_recommended
    max ? Cpu.millicores_to_string(millicores: max) : ''
  end

  # Display format for recommended memory request
  def memory_request_display
    max = max_memory_request_recommended
    max ? Memory.mebibytes_to_string(mebibytes: max) : ''
  end

  # Display format for recommended memory limit
  def memory_limit_display
    max = max_memory_limit_recommended
    max ? Memory.mebibytes_to_string(mebibytes: max) : ''
  end

  # Generate YAML stanza for deployment configuration
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

  # CSV headers for deployment-level output
  def self.headers
    %w[
      namespace owner deployment_type container_count
      cpu_request_current cpu_limit_current memory_request_current memory_limit_current
      cpu_95_m cpu_99_m memory_95_mi memory_99_mi memory_max_mi
      cpu_request_recommended_mi cpu_limit_recommended_m memory_request_recommended_mi
      memory_limit_recommended_mi stanza
    ]
  end

  # Generate CSV row with all maximum values
  def row
    [
      namespace,
      owner_name,
      primary_type,
      containers.length,
      max_cpu_request_current,
      max_cpu_limit_current,
      max_memory_request_current,
      max_memory_limit_current,
      max_cpu_95,
      max_cpu_99,
      max_memory_95,
      max_memory_99,
      max_memory_max,
      max_cpu_request_recommended,
      max_cpu_limit_recommended,
      max_memory_request_recommended,
      max_memory_limit_recommended,
      stanza
    ]
  end
end
