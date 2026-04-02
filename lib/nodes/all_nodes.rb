# frozen_string_literal: true

module Nodes
  ##
  # For gathering data that an only be gathered on a cluster level, but that is relevant on a per-node level
  class AllNodes
    # Right now this is very slow, I think it ends up calling it once per node
    # Need to figure out how to cache this
    def self.current_pod_counts
      command = <<~CMD.chomp
        kubectl get pods -A \
          --field-selector=status.phase=Running \
          -o json | \
          jq '.items | group_by(.spec.nodeName) | map({node: .[0].spec.nodeName, pod_count: length}) | sort_by(.pod_count) | reverse'
      CMD
      raw = `#{command}`
      JSON.parse(raw, symbolize_names: true)
    end
  end
end
