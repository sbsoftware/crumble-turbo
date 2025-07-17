require "crumble"
require "../crumble/turbo/identifiable_view"
require "../turbo_stream"
require "./model_template_id"
require "../stimulus_controllers/model_template_refresh_controller"

macro model_template(method_name, wrapper_attributes = nil, &blk)
  private class {{method_name.id.stringify.camelcase.id}}Template
    include IdentifiableView

    getter model : {{@type}}

    forward_missing_to @model

    def initialize(@model); end

    def dom_id
      if id = self.id
        Orma::ModelTemplateId.new({{@type.name.stringify}}, id.value, {{method_name.id.stringify}})
      else
        raise ArgumentError.new("Cannot render model template for unpersisted record")
      end
    end

    def wrapper_attributes
      arr = [Crumble::Turbo::ModelTemplateRefreshController.model_template_target]
      {% if wrapper_attributes %}
        arr + {{wrapper_attributes}}
      {% end %}
    end

    ToHtml.instance_template {{blk}}
  end

  def {{method_name.id}}
    {{method_name.id.stringify.camelcase.id}}Template.new(self)
  end
end
