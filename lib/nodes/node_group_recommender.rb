# frozen_string_literal: true

module Nodes
  ##
  # Given a set of Node objects (already populated with Prometheus metrics), suggests
  # alternative instance type + count configurations for each node group, ranked by cost.
  class NodeGroupRecommender
    # EKS reserves ~6% of node capacity for system daemons
    NODE_OVERHEAD_FACTOR = 0.94
    # How much headroom to leave above p99 actual usage when sizing
    HEADROOM_FACTOR = 1.30
    # Standard EKS max pods per node (ENI-based limit for these instance types)
    PODS_PER_NODE = 58
    HOURS_PER_MONTH = 730
    # Candidates to return per node group
    TOP_N = 5

    # T3/T3a instances burst above a baseline CPU; sustained burst accrues charges in Unlimited mode.
    # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-credits-baseline-concepts.html
    T3_UNLIMITED_SURCHARGE_PER_VCPU_HOUR = 0.05
    # Baseline CPU as a fraction of one vCPU, keyed by instance size.
    T3_BASELINE_CPU_FRACTION = {
      'nano' => 0.05,
      'micro' => 0.10,
      'small' => 0.20,
      'medium' => 0.20,
      'large' => 0.30,
      'xlarge' => 0.40,
      '2xlarge' => 0.40
    }.freeze

    # General-purpose and memory-optimized families appropriate for mixed K8s workloads.
    # Excludes compute-optimized (c*), GPU (p*, g*), storage-optimized (d*, i*, h*),
    # accelerated (inf*, trn*), and bare metal.
    PREFERRED_FAMILIES = %w[m5 m5a m5n m6i m6a m6in m7i m7a r5 r5a r5n r6i r6a r7i r7a t3 t3a].freeze

    def self.headers
      %w[
        node_group
        current_instance_type
        current_node_count
        current_monthly_cost_usd
        recommended_instance_type
        recommended_node_count
        recommended_vcpu_per_node
        recommended_memory_gib_per_node
        recommended_base_cost_usd
        t3_unlimited_surcharge_usd
        recommended_monthly_cost_usd
        monthly_savings_usd
        cpu_headroom_pct
        memory_headroom_pct
        notes
        terraform_vars
      ]
    end

    def initialize(nodes)
      @nodes = nodes
    end

    def write_csv(csv)
      groups = @nodes.group_by(&:node_group)
      groups.each do |group_name, group_nodes|
        rows = recommend_for_group(group_name, group_nodes)
        rows.each { |row| csv << row }
        csv << [] # blank separator between groups
      end
    end

    private

    def pricing_data
      # Reuse AwsClient's cached CSV load
      @pricing_data ||= Nodes::AwsClient.new.pricing_data
    end

    def candidate_instances
      @candidate_instances ||= pricing_data.values.select do |instance|
        family = instance[:instance_type].sub(/\..+/, '')
        PREFERRED_FAMILIES.include?(family) &&
          instance[:vcpu].between?(2, 32) &&
          instance[:memory_mib] >= 4096
      end.sort_by { |i| i[:price_per_hour] }
    end

    def recommend_for_group(group_name, group_nodes)
      required = aggregate_requirements(group_nodes)
      current_type = group_nodes.first.instance_type
      current_price = pricing_data.dig(current_type, :price_per_hour) || 0
      current_monthly = current_price * group_nodes.size * HOURS_PER_MONTH

      candidates = find_candidates(required, group_nodes.size)

      candidates.first(TOP_N).each_with_index.map do |candidate, index|
        instance = candidate[:instance]
        node_count = candidate[:node_count]
        base_cost = instance[:price_per_hour] * node_count * HOURS_PER_MONTH
        surcharge = t3_unlimited_surcharge(instance, node_count, required[:p99_cpu_actual_millicores])
        monthly_cost = base_cost + surcharge
        cpu_avail = instance[:vcpu] * 1000 * node_count * NODE_OVERHEAD_FACTOR
        mem_avail = instance[:memory_mib] * node_count * NODE_OVERHEAD_FACTOR
        cpu_headroom = ((cpu_avail - required[:cpu_millicores]) / cpu_avail * 100).round(1)
        mem_headroom = ((mem_avail - required[:memory_mib]) / mem_avail * 100).round(1)
        notes = candidate[:notes].dup
        notes = "#{notes}; burstable: cost varies with load" if surcharge.positive?

        [
          group_name,
          current_type,
          group_nodes.size,
          current_monthly.round(2),
          instance[:instance_type],
          node_count,
          instance[:vcpu],
          (instance[:memory_mib] / 1024.0).round(1),
          base_cost.round(2),
          surcharge.positive? ? surcharge.round(2) : nil,
          monthly_cost.round(2),
          (current_monthly - monthly_cost).round(2),
          "#{cpu_headroom}%",
          "#{mem_headroom}%",
          notes,
          index.zero? ? terraform_vars(group_name, instance[:instance_type], node_count) : nil
        ]
      end
    end

    def t3_unlimited_surcharge(instance, node_count, p99_cpu_actual_millicores)
      size = instance[:instance_type].split('.').last
      baseline_fraction = T3_BASELINE_CPU_FRACTION[size]
      return 0 unless baseline_fraction

      baseline_millicores = instance[:vcpu] * baseline_fraction * 1000 * node_count
      surplus_vcpus = [(p99_cpu_actual_millicores - baseline_millicores) / 1000.0, 0].max
      surplus_vcpus * T3_UNLIMITED_SURCHARGE_PER_VCPU_HOUR * HOURS_PER_MONTH
    end

    def aggregate_requirements(nodes)
      # Use p99 actual * headroom or allocated requests, whichever is larger
      p99_cpu_actual = nodes.sum(&:ninety_nine_in_millicores)
      p99_cpu  = p99_cpu_actual * HEADROOM_FACTOR
      p99_mem  = nodes.sum(&:ninety_nine_in_mebibytes) * HEADROOM_FACTOR
      alloc_cpu = nodes.sum(&:allocated_cpu_requests)
      alloc_mem = nodes.sum(&:allocated_memory_requests)
      pod_count = nodes.sum(&:current_pod_count)

      {
        cpu_millicores: [p99_cpu, alloc_cpu].max,
        p99_cpu_actual_millicores: p99_cpu_actual,
        memory_mib: [p99_mem, alloc_mem].max,
        pod_count: pod_count
      }
    end

    def terraform_vars(group_name, instance_type, node_count)
      desired = node_count
      min = [desired - 1, 1].max
      max = desired + 1

      if group_name.to_s.include?('stateful')
        <<~TERRAFORM.strip
          stateful_node_instance_type = "#{instance_type}"
          stateful_desired_size       = #{desired}
          stateful_min_size           = #{min}
          stateful_max_size           = #{max}
        TERRAFORM
      else
        <<~TERRAFORM.strip
          node_instance_type = "#{instance_type}"
          desired_size       = #{desired}
          min_size           = #{min}
          max_size           = #{max}
        TERRAFORM
      end
    end

    def find_candidates(required, current_count)
      candidates = []

      # Try node counts from 1 up to current + 2; stop early once we've found enough cheap options
      max_count = current_count + 2
      (1..max_count).each do |node_count|
        next if node_count * PODS_PER_NODE < required[:pod_count]

        candidate_instances.each do |instance|
          cpu_avail = instance[:vcpu] * 1000 * node_count * NODE_OVERHEAD_FACTOR
          mem_avail = instance[:memory_mib] * node_count * NODE_OVERHEAD_FACTOR

          next unless cpu_avail >= required[:cpu_millicores]
          next unless mem_avail >= required[:memory_mib]

          notes = []
          notes << 'no HA - single node' if node_count == 1
          notes << "#{current_count - node_count} fewer nodes" if node_count < current_count
          notes << "#{node_count - current_count} more nodes" if node_count > current_count

          candidates << {
            instance: instance,
            node_count: node_count,
            monthly_cost: instance[:price_per_hour] * node_count * HOURS_PER_MONTH,
            notes: notes.join('; ')
          }
        end
      end

      candidates.sort_by { |c| c[:monthly_cost] }
    end
  end
end
