# frozen_string_literal: true

##
# Represents a kubernetes pod. Should probably be renamed to Pod
# TODO: Rename to Pod
class Item
  attr_reader :item_json

  def initialize(item_json)
    @item_json = item_json
  end

  def namespace
    item_json.dig(:metadata, :namespace)
  end

  def name
    item_json.dig(:metadata, :name)
  end

  def owner_kind
    item_json.dig(:metadata, :ownerReferences, 0, :kind)
  end

  def owner_name
    item_json.dig(:metadata, :ownerReferences, 0, :name).sub(/-[a-z0-9]+$/, '')
  end

  def containers
    item_json.dig(:spec, :containers).map.with_index do |container_json, index|
      foo = item_json.dig(:status, :containerStatuses, index, :containerID)
      match_data = foo.match(%r{containerd://(?<identifier>\w*)})
      Container.new(container_json, match_data[:identifier], name, owner_name)
    end
  end

  def write_pod_and_containers(csv)
    item_info = [namespace, owner_name]
    containers.each do |container|
      csv << [item_info, container.row].flatten
    end
  end
end
