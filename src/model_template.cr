require "crumble"
require "./identifiable_view"
require "./turbo_stream"

macro model_template(method_name, &blk)
  private class {{method_name.id.stringify.camelcase.id}}Template < Crumble::ModelTemplate
    include IdentifiableView

    @model : {{@type}}

    forward_missing_to @model

    def initialize(@model); end

    def dom_id
      id
    end

    Crumble::ModelTemplate.template {{blk}}
  end

  def {{method_name.id}}
    {{method_name.id.stringify.camelcase.id}}Template.new(self)
  end
end

# TODO: This probably belongs into `orma` directly or into an integration shard like `crumble-orma`.
#       Not sure about the CSS part, though.
class Orma::Attribute(T)
  def selector
    CSS::AttrSelector.new("data-crumble-#{model.name.underscore.gsub(/_/, "-").gsub(/::/, "--")}-#{name}", value.to_s)
  end

  def to_html_attrs(_tag, attrs)
    attrs["data-crumble-#{model.name.underscore.gsub(/_/, "-").gsub(/::/, "--")}-#{name}"] = value.to_s
  end
end

module Crumble
  class ModelTemplate
    macro template(&blk)
      ToHtml.instance_template do
        {{blk.body}}
      end
    end
  end
end
