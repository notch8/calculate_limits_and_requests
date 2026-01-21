# frozen_string_literal: true

require 'csv'
require 'json'
require_relative 'prometheus_client'
require_relative 'pod'
require_relative 'container'
require_relative 'cpu'
require_relative 'quantile'
require_relative 'memory'
require_relative 'deployment'

PROMETHEUS_URL = 'http://localhost:9090'
CPU_REQUEST_MULTIPLIER = 1.3
CPU_LIMIT_MULTIPLIER = 1.5
MEMORY_REQUEST_MULTIPLIER = 1.2
MEMORY_LIMIT_MULTIPLIER = 1.3

# CPU values are in millicores (m)
# Memory values are in Mebibytes (Mi)
MINIMUMS = {
  rails_app: { cpu_request: 100, cpu_limit: 1000, memory_request: 2048, memory_limit: 4096 },
  java_app: { cpu_request: 250, cpu_limit: 1000, memory_request: 1024, memory_limit: 2048 },
  fcrepo: { cpu_request: 100, cpu_limit: 1000, memory_request: 3072, memory_limit: 4096 },
  database: { cpu_request: 50, cpu_limit: 500, memory_request: 512, memory_limit: 1024 },
  cache: { cpu_request: 20, cpu_limit: 100, memory_request: 256, memory_limit: 512 },
  utility: { cpu_request: 20, cpu_limit: 100, memory_request: 128, memory_limit: 256 }
}.freeze

##
# Wrapper class for calculating appropriate limits and requests for Kubernetes containers
class CalculateResources
  def all_pods
    @all_pods ||= JSON.parse(`kubectl get pods --all-namespaces -o json`,
                             symbolize_names: true)[:items].map do |pod_json|
      Pod.new(pod_json)
    end
  end

  def deployments
    @deployments ||= begin
      deployment_hash = {}

      all_pods.each do |pod|
        key = "#{pod.namespace}/#{pod.owner_name}"

        deployment_hash[key] ||= Deployment.new(
          namespace: pod.namespace,
          owner_name: pod.owner_name
        )

        pod.containers.each do |container|
          deployment_hash[key].add_container(container)
        end
      end

      deployment_hash.values
    end
  end

  def write_csv
    headers = Deployment.headers
    CSV.open('right-sizing-output.csv', 'w') do |csv|
      csv << headers
      write_deployments(csv)
    end
  end

  def write_deployments(csv)
    deployments.each do |deployment|
      csv << deployment.row
    end
  end

  # Legacy method for writing individual container rows (kept for compatibility)
  def write_pods(csv)
    all_pods.each do |pod|
      pod.write_pod_and_containers(csv)
    end
  end
end

##
# Helper class for getting the maximum memory - probably should be in another class?
class MaxMemory
  attr_reader :item_hash

  def initialize(item_hash: item)
    @item_hash = item_hash
  end

  def name
    item_hash.dig(:metric, :name)
  end

  def value
    item_hash.dig(:value, 1)&.to_f
  end
end
