require "./action_form"

module Crumble::Turbo
  struct CustomActionTrigger
    getter uri_path : String
    getter form : ::Crumble::Form
    getter confirm_prompt : String?

    def initialize(@uri_path, @form, *, @confirm_prompt = nil); end

    def confirm_prompt_value
      return unless prompt = confirm_prompt

      ActionTriggerController.confirm_prompt_value(prompt)
    end

    ToHtml.instance_template do
      div ActionTriggerController, confirm_prompt_value do
        ActionForm.new(uri_path, form, hidden: true).to_html do
          input ActionTriggerController.submit_target, type: :submit
        end
        div Inner, ActionTriggerController.submit_action("click") do
          yield
        end
      end
    end

    stimulus_controller ActionTriggerController do
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

    css_class Inner

    style do
      rule Inner do
        width 100.percent
        height 100.percent
      end
    end
  end
end
