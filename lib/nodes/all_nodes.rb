# frozen_string_literal: true

require_relative '../cpu'
require_relative '../memory'

module Nodes
  ##
  # For gathering data that an only be gathered on a cluster level, but that is relevant on a per-node level
  class AllNodes
    def self.current_pod_counts(cluster:)
      command = <<~CMD.chomp
        kubectl get pods -A --context=#{cluster} \
          --field-selector=status.phase=Running \
          -o json | \
          jq '.items | group_by(.spec.nodeName) | map({node: .[0].spec.nodeName, pod_count: length})'
      CMD
      raw = `#{command}`
      JSON.parse(raw, symbolize_names: true)
    end

    def self.sum_of_resources_by_node(cluster:)
      container_resources(cluster:).group_by { |r| r[:node] }.map do |node, containers|
        {
          node: node,
          cpu_millicores: containers.sum { |c| c[:cpu_millicores] || 0 },
          memory_mib: containers.sum { |c| c[:memory_mib] || 0 }
        }
      end
    end

    def self.container_resources(cluster:)
      container_resources_json(cluster:).map do |resource|
        {
          node: resource[:node],
          cpu_millicores: Cpu.string_to_millicores(string: resource[:cpu_millicores].to_s),
          memory_mib: Memory.string_to_mebibytes(string: resource[:memory_mib].to_s)
        }
      end
    end

    def self.container_resources_json(cluster:)
      command = <<~CMD.chomp
        kubectl get pods -A --context=#{cluster} \
          --field-selector=status.phase=Running \
          -o json | \
          jq '[.items[] | {node: .spec.nodeName, containers: .spec.containers[].resources.requests}] | map({node: .node, cpu_millicores: .containers.cpu, memory_mib: .containers.memory})'
      CMD
      raw = `#{command}`
      JSON.parse(raw, symbolize_names: true)
    end
  end
end
