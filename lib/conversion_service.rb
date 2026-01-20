# frozen_string_literal: true

##
# Helper class for unit conversion, including from human readable to normalized, and normalized to human readable
# TODO: Make the comment above true
class ConversionService
  # Convert bytes to Mi
  def self.bytes_to_mi(bytes)
    return nil unless bytes

    mi = (bytes / (1024.0 * 1024.0)).to_i
    [1, mi].max
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

  def self.round_memory(mebibytes:)
    return mebibytes if (mebibytes % 1024).zero?

    if mebibytes < 1024
      # round to nearest power of 2
      2**Math.log2(mebibytes).ceil
    else
      (mebibytes / 512.0).ceil * 512
    end
  end

  def self.memory_to_s(mebibytes:)
    if mebibytes < 1024
      "#{mebibytes}Mi"
    else
      "#{(mebibytes / 1024).to_i}Gi"
    end
  end
end
