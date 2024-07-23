require "crumble"
require "./identifiable_view"
require "./turbo_stream"

macro model_template(method_name, wrapper_attributes = nil, &blk)
  private class {{method_name.id.stringify.camelcase.id}}Template
    include IdentifiableView

    @model : ::{{@type}}

    forward_missing_to @model

    def initialize(@model); end

    def dom_id
      id
    end

    {% if wrapper_attributes %}
      def wrapper_attributes
        {{wrapper_attributes}}
      end
    {% end %}

    ToHtml.instance_template {{blk}}
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
