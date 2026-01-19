# frozen_string_literal: true

##
# Helper class for unit conversion, including from human readable to normalized, and normalized to human readable
# TODO: Make the comment above true
class ConversionService
  # Convert CPU cores to millicores
  def self.cores_to_millicores(cores)
    return nil unless cores

    [1, (cores * 1000).to_i].max
  end

  # Convert bytes to Mi
  def self.bytes_to_mi(bytes)
    return nil unless bytes

    mi = (bytes / (1024.0 * 1024.0)).to_i
    [1, mi].max
  end

  def self.k8s_cpu_to_millicores(k8s_value)
    return nil if k8s_value&.empty? || k8s_value.nil?

    if k8s_value.match(/m$/)
      k8s_value.chop.to_i
    else
      k8s_value.to_i * 1_000
    end
  end

  def self.k8s_memory_to_mi(k8s_value)
    return nil if k8s_value&.empty? || k8s_value.nil?

    k8s_to_integer = k8s_value[0..-3].to_i
    if k8s_value.match(/Mi$/)
      k8s_to_integer
    elsif k8s_value.match(/Gi$/)
      k8s_to_integer * 1024
    end
  end
end
