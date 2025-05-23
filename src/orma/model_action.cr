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
      abstract def action_template(model)
    end

    abstract def model
    abstract def model_template : IdentifiableView

    def self.path_matcher : Regex
      @@path_matcher ||= /#{URI_PATH_PREFIX}\/#{model_class.name.gsub(/::/, "\\/").underscore}\/(\d+)\/#{action_name}/
    end

    def self.uri_path(model_id) : String
      "#{URI_PATH_PREFIX}/#{model_class.name.gsub(/::/, "/").underscore}/#{model_id}/#{action_name}"
    end

    def self.action_template(model)
      GenericModelActionTemplate.new(self.uri_path(model.id))
    end

    def model_id
      path_match[1].to_i
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

    stimulus_controller GenericModelActionController do
      targets :submit
      values confirm_prompt: String

      action :submit do |event|
        event.preventDefault._call
        event.stopPropagation._call

        if this.hasConfirmPromptValue
          return unless window.confirm(this.confirmPromptValue)
        end

        this.submitTarget.click._call
      end
    end

    class GenericModelActionTemplate
      getter form_template
      getter confirm_prompt : String?

      def initialize(action_path, *, hidden = true, @confirm_prompt = nil)
        @form_template = FormTemplate.new(action_path, hidden: hidden)
      end

      def initialize(action_path, fields, *, hidden = true, @confirm_prompt = nil)
        @form_template = FormTemplate.new(action_path, fields, hidden: hidden)
      end

      class Inner < CSS::CSSClass; end

      class Style < CSS::Stylesheet
        rules do
          rule Inner do
            width 100.percent
            height 100.percent
          end
        end
      end

      def confirm_prompt_value
        return unless prompt = confirm_prompt

        GenericModelActionController.confirm_prompt_value(prompt)
      end

      ToHtml.instance_template do
        div GenericModelActionController, confirm_prompt_value do
          form_template.to_html do
            input GenericModelActionController.submit_target, type: :submit
          end
          div Inner, GenericModelActionController.submit_action("click") do
            yield
          end
        end
      end
    end
  end
end
