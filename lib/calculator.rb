# frozen_string_literal: true

require 'csv'
require 'json'

require_relative 'calculate_nodes'
require_relative 'calculate_resources'
require_relative 'container'
require_relative 'cpu'
require_relative 'memory'
require_relative 'node_cpu'
require_relative 'node_memory'
require_relative 'node'
require_relative 'pod'
require_relative 'prometheus_client'
require_relative 'quantile'

PROMETHEUS_URL = 'http://localhost:9090'

QUERY_CLASSES = {
  %w[cpu pod] => Cpu,
  %w[cpu node] => NodeCpu,
  %w[memory pod] => Memory,
  %w[memory node] => NodeMemory
}.freeze
