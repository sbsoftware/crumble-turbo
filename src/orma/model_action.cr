require "../crumble/turbo/action"
require "../crumble/turbo/identifiable_view"
require "../crumble/turbo/model_template_refresh_service"
require "./model_action_template_id"

module Orma
  abstract class ModelAction < Crumble::Turbo::Action
    macro inherited
      extend ClassMethods
    end

    private module ClassMethods
      abstract def model_class : ::Orma::Record.class
    end

    abstract def model

    # Model templates that should be streamed to the requester and refreshed for
    # other subscribers after the action controller runs.
    abstract def refreshed_model_templates

    class Policy < ::Crumble::Turbo::Action::Policy
      def model
        action.as(::Orma::ModelAction).model
      end
    end

    macro policy(&blk)
      class Policy < ::Orma::ModelAction::Policy
        def model
          action.as({{@type}}).model
        end

        {{blk.body}}
      end
    end

    macro view(&blk)
      ::Crumble::Turbo::Action.view do
        delegate :model, to: action

        def dom_id
          raise "Cannot render action template for unpersisted model" unless model_id = model.id.try(&.value)

          ::Orma::ModelActionTemplateId.new(action.class.model_class.name, model_id, action.class.action_name)
        end

        {{blk.body}}
      end
    end

    def initialize(ctx : ::Crumble::Server::HandlerContext, @model)
      @request_ctx = ctx.request_context
      @ctx = ctx
    end

    def initialize(@request_ctx : ::Crumble::Server::RequestContext, @model); end

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

      if templates = refreshed_model_templates
        templates.each do |tpl|
          tpl.renderer(ctx).turbo_stream.to_html(ctx.response)
          tpl.refresh!
        end
      end
    end

    abstract def model_action_controller

    macro controller(&blk)
      def model_action_controller
        {{blk.body}}
      end
    end
  end
end
