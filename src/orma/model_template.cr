require "crumble"
require "orma"
require "../crumble/turbo/identifiable_view"
# require "../crumble/turbo/model_template_refresh_service"
require "./model_template_id"
require "../stimulus_controllers/model_template_refresh_controller"

class Orma::Record
  annotation ModelTemplateMethod; end

  macro model_template(method_name, wrapper_attributes = nil, &blk)
    private struct {{method_name.id.stringify.camelcase.id}}Template
      getter model : {{@type}}

      def initialize(@model); end

      def dom_id
        if id = model.id
          Orma::ModelTemplateId.new({{@type.name.stringify}}, id.value, {{method_name.id.stringify}})
        else
          raise ArgumentError.new("Cannot render model template for unpersisted record")
        end
      end

      def renderer(ctx)
        Renderer.new(ctx: ctx, model_template: self)
      end

      def refresh!
        raise ArgumentError.new("Cannot render model template for unpersisted record") unless id = model.id

        ::Crumble::Turbo::ModelTemplateRefreshService.refresh_model_template({{@type.name.stringify}}, id.value, {{method_name.id.stringify}})
      end

      private struct Renderer
        include Crumble::ContextView
        include IdentifiableView

        getter model_template : {{method_name.id.stringify.camelcase.id}}Template

        delegate :dom_id, :model, to: model_template

        forward_missing_to model_template.model

        def wrapper_attributes
          arr = [Crumble::Turbo::ModelTemplateRefreshController.model_template_target]
          {% if wrapper_attributes %}
            arr + {{wrapper_attributes}}
          {% end %}
        end

        ToHtml.instance_template {{blk}}
      end
    end

    @[ModelTemplateMethod]
    def {{method_name.id}}
      {{method_name.id.stringify.camelcase.id}}Template.new(self)
    end
  end
end
