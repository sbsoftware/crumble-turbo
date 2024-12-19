require "./model_action"
require "../stimulus_controllers/boolean_flip_controller"

module Orma
  abstract class BooleanFlipAction < ModelAction
    abstract def assign_attribute(new_val)

    delegate :to_s, to: template

    class Template
      getter uri_path : String
      getter value : Bool

      def initialize(@uri_path, @value); end

      ToHtml.instance_template do
        div BooleanFlipController do
          FormTemplate.new(uri_path).to_html do
            input(type: "hidden", name: "value", value: (!value).to_s)
            input(BooleanFlipController.submitButton_target, type: "submit")
          end
          div BooleanFlipController.flip_action("click") do
            yield
          end
        end
      end
    end

    def model_action_controller
      new_val = nil
      request_params(ctx.request.body) do |name, value|
        if name == "value"
          new_val = (value == "true")
        end
      end

      unless new_val.nil?
        assign_attribute(new_val)
      end
      model.save

      model_template.turbo_stream.to_html(ctx.response)
    end

    def request_params(req_body)
      return if req_body.nil?

      HTTP::Params.parse(req_body.gets_to_end) do |name, value|
        yield name, value
      end
    end
  end
end
