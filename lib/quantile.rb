# frozen_string_literal: true

##
# TODO: What even is this class? It makes no sense.
class Quantile
  attr_reader :item_hash

  def initialize(item_hash:)
    @item_hash = item_hash
  end

  def name
    item_hash.dig(:metric, :name)
  end

  def namespace
    item_hash.dig(:metric, :namespace)
  end

  def pod
    item_hash.dig(:metric, :pod)
  end

  def container
    item_hash.dig(:metric, :container)
  end

  def value
    item_hash.dig(:value, 1)&.to_f
  end
end
