# frozen_string_literal: true

##
# For memory resources for nodes
class NodeMemory
  def self.prometheus_command(quantile)
    <<~CMD.chomp
      quantile_over_time(#{quantile}, (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))[10d:1m])
    CMD
  end
end
