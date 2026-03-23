# frozen_string_literal: true

##
# Represents Cpu objects for nodes
class NodeCpu
  def self.prometheus_command(quantile)
    <<~CMD.chomp
      quantile_over_time(#{quantile}, (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))[10d:5m])
    CMD
  end
end
