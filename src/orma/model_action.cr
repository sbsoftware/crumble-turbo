require "../crumble/turbo/action"
require "../crumble/turbo/identifiable_view"
require "../crumble/turbo/model_template_refresh_service"

module Orma
  abstract class ModelAction < Crumble::Turbo::Action
    macro inherited
      extend ClassMethods
    end

    private module ClassMethods
      abstract def model_class : ::Orma::Record.class
    end

    abstract def model
    abstract def model_template : IdentifiableView

    macro view(&blk)
      class Template
        include IdentifiableView

        getter action : ::{{@type}}

        delegate :ctx, :model, :action_form, :custom_action_trigger, to: action

        macro template(&tpl_blk)
          ToHtml.instance_template \{{tpl_blk}}
        end

        class {{@type.name}}Id < CSS::ElementId; end

        def initialize(@action); end

        def dom_id
          {{@type.name}}Id
        end

        {{blk.body}}
      end

      def action_template : IdentifiableView
        Template.new(self)
      end
    end

    def initialize(@request_ctx, @model); end

    def self.path_matcher : Regex
      @@path_matcher ||= /#{URI_PATH_PREFIX}\/#{model_class.name.gsub(/::/, "\\/").underscore}\/(\d+)\/#{action_name}/
    end

    def self.uri_path(model_id) : String
      "#{URI_PATH_PREFIX}/#{model_class.name.gsub(/::/, "/").underscore}/#{model_id}/#{action_name}"
    end

    def uri_path
      self.class.uri_path(model.id)
    end

    def self.matched_handle(ctx, match)
      model_id = match[1].to_i
      model = model_class.where(id: model_id).first?

      if model
        new(ctx, model).handle
      else
        model_not_found(ctx)
      end
    end

    def self.model_not_found(ctx)
      ctx.response.status_code = 404
      ctx.response << "Not Found"
    end

    def controller
      model_action_controller

      model_template.turbo_stream.to_html(ctx.response)
      Crumble::Turbo::ModelTemplateRefreshService.notify(model_template)
    end

    abstract def model_action_controller

    macro controller(&blk)
      def model_action_controller
        {{blk.body}}
      end
    end
  end
end
