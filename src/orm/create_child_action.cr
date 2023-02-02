require "./action"

module Crumble::ORM
  abstract class CreateChildAction < Action
    template :template do
      form action(uri_path), Method::Post do
        input(InputType::Submit, {"name", "Submit"})
      end
    end

    def self.handle(ctx) : Bool
      match = path_matcher.match(ctx.request.path)
      return false unless match

      parent_id = match[1]
      model = model_class.find(parent_id)
      action = self.new(model)
      child = action.child_instance
      child.save

      ctx.response.headers.add("Content-Type", TURBO_STREAM_MIME_TYPE)
      ctx.response << action.model_template.turbo_stream

      true
    end
  end
end
