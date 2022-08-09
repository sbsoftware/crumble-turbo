require "./action"
require "../stimulus_controllers/boolean_flip_controller"

module Crumble::ORM
  abstract class BooleanFlipAction < Action
    abstract def attribute

    delegate :to_s, to: template

    def apply(new_val : Bool)
      attribute.value = new_val
    end

    private class Template < ::Template
      getter parent : BooleanFlipAction

      def initialize(@parent); end

      template do
        div BooleanFlipController do
          form Method::Post, action(parent.uri_path) do
            input(InputType::Hidden, {"name", "value"}, {"value", (!parent.attribute.value).to_s})
            input(InputType::Submit, BooleanFlipController.submitButton_target)
          end
          div BooleanFlipController.flip_action(ClickEvent) do
            main_docking_point
          end
        end
      end
    end

    def template
      Template.new(self)
    end

    def self.handle(ctx) : Bool
      match = path_matcher.match(ctx.request.path)
      return false unless match

      id = match[1]
      new_val = nil
      request_params(ctx.request.body) do |name, value|
        if name == "value"
          new_val = (value == "true")
        end
      end

      model = model_class.find(id)
      instance = self.new(model)
      unless new_val.nil?
        instance.apply(new_val)
      end
      model.save

      ctx.response.headers.add("Content-Type", TURBO_STREAM_MIME_TYPE)
      instance.model_template.turbo_stream.to_s(ctx.response)

      true
    end

    def self.request_params(req_body)
      return if req_body.nil?

      HTTP::Params.parse(req_body.gets_to_end) do |name, value|
        yield name, value
      end
    end
  end
end
