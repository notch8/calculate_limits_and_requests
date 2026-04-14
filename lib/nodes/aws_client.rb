# frozen_string_literal: true

module Nodes
  ##
  # Get data about instance types from AWS
  # I'd like to find a way to be able to do this without having to have AWS credentials set up
  class AwsClient
    def memory_capacity_by_instance_type(instance_type: 'm5.xlarge')
      case instance_type
      when 'm5.xlarge', 't3.xlarge'
        '16384'
      when 'm5.4xlarge'
        '65536'
      else
        raise "Instance type not yet implemented. instance_type: #{instance_type}"
      end
    end

    # This method seems to work but is untested, and having AWS set up is not documented yet
    # def memory_capacity_by_instance_type(instance_type:)
    #   command = <<~CMD.chomp
    #     aws ec2 describe-instance-types \
    #       --instance-types #{instance_type} \
    #       --query "InstanceTypes[*].{type:InstanceType,memory_mib:MemoryInfo.SizeInMiB,vcpus:VCpuInfo.DefaultVCpus}" \
    #       --output json
    #   CMD
    #   raw = `#{command}`
    #   instance_info = JSON.parse(raw).to_h { |instance| [instance['type'], instance] }
    #   instance_info.dig(instance_type, 'memory_mib')
    # end
  end
end
