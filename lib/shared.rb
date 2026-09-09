# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'json'
require 'byebug'

PROMETHEUS_URL = 'http://localhost:9090'

def report_path(cluster, suffix)
  date = Time.now.strftime('%Y-%m-%d')
  safe_cluster = cluster.to_s.gsub(/[^a-z0-9-]/i, '-')
  dir = File.join(__dir__, '..', 'reports')
  FileUtils.mkdir_p(dir)
  File.join(dir, "#{date}-#{safe_cluster}-#{suffix}")
end
