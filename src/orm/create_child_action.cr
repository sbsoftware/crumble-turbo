require "./action"

module Crumble::ORM
  abstract class CreateChildAction < Action
    template :form_template do
      form action(uri_path), Method::Post do
        main_docking_point
      end
    end

    def self.handle(ctx) : Bool
      match = path_matcher.match(ctx.request.path)
      return false unless match

      parent_id = match[1]
      model = model_class.find(parent_id)
      action = self.new(model)

      return true if action.before_action_halted?(ctx)

      child = action.child_instance(ctx.request.body.try(&.gets_to_end) || "")
      child.save

      ctx.response.status_code = 201
      ctx.response.headers.add("Content-Type", TURBO_STREAM_MIME_TYPE)
      ctx.response << action.model_template.turbo_stream

      true
    end
  end
end
