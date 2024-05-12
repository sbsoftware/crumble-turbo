require "crumble"
require "./turbo_stream"

macro model_template(method_name, tag = :div, &blk)
  private class {{method_name.id.stringify.camelcase.id}}Template < Crumble::ModelTemplate
    @model : {{@type}}

    forward_missing_to @model

    def initialize(@model); end

    Crumble::ModelTemplate.template({{tag}}) {{blk}}
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
    def turbo_stream
      TurboStream.new(:replace, id.selector, self)
    end

    macro template(tag, &blk)
      ToHtml.instance_template do
        {{tag.id}} id do
          {{blk.body}}
        end
      end
    end
  end
end
