# frozen_string_literal: true

##
# Represents a kubernetes pod.
class Pod
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
    item_json.dig(:metadata, :ownerReferences, 0, :name)&.sub(/-[a-z0-9]+$/, '')
  end

  def containers
    item_json.dig(:spec, :containers).map do |container_json|
      Container.new(container_json, container_identifier(container_json:))
    end
  end

  def write_pod_and_containers(csv)
    item_info = [namespace, owner_name]
    containers.each do |container|
      csv << [item_info, container.row].flatten
    end
  end

  private

  def container_identifier(container_json:)
    item_json.dig(:status, :containerStatuses).find do |stat|
      stat[:name] == container_json[:name]
    end[:containerID].match(%r{containerd://(?<identifier>\w*)})[:identifier]
  end
end
