# frozen_string_literal: true

##
# Represents a kubernetes node.
class Node
  REGION = 'us-west-2'
  attr_reader :item_json

  def initialize(item_json)
    @item_json = item_json
  end

  def name
    item_json.dig(:metadata, :name)
  end

  def node_group
    item_json.dig(:metadata, :labels, :'eks.amazonaws.com/nodegroup')
  end

  def provider_id
    # aws:\/\/\/us-west-2[abc]\/i-09bd87854f37b962d
    item_json.dig(:spec, :providerID)&.sub(%r{aws:///#{REGION}[abc]/}o, '')
  end

  def write_node(csv)
    item_info = [provider_id, name, node_group]
    csv << item_info
  end
end
