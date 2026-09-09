# frozen_string_literal: true

require 'socket'

##
# Manages a kubectl port-forward to Prometheus so callers don't need to run it separately.
class PortForward
  PORT = 9090

  class PortInUseError < StandardError
    def initialize(port)
      super("Port #{port} is already in use. A port-forward from a different cluster may be running. " \
            "Stop it first (e.g. kill the process listening on port #{port}) and try again.")
    end
  end

  def self.start(cluster:)
    raise PortInUseError, PORT if port_in_use?(PORT)

    pid = spawn(
      "kubectl port-forward --context=#{cluster} -n monitoring " \
      "svc/kube-prometheus-stack-prometheus #{PORT}:9090",
      out: '/dev/null', err: '/dev/null'
    )
    Process.detach(pid)
    at_exit { Process.kill('TERM', pid) rescue nil } # rubocop:disable Style/RescueModifier
    wait_for_ready
    pid
  end

  def self.port_in_use?(port)
    TCPSocket.new('localhost', port).close
    true
  rescue Errno::ECONNREFUSED
    false
  end

  def self.wait_for_ready(timeout: 15)
    deadline = Time.now + timeout
    loop do
      TCPSocket.new('localhost', PORT).close
      return
    rescue Errno::ECONNREFUSED
      raise "Prometheus port-forward not ready after #{timeout}s" if Time.now > deadline

      sleep 0.3
    end
  end
end
