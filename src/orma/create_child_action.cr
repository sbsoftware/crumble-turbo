require "./model_action"

module Orma
  abstract class CreateChildAction < ModelAction
    abstract def child_instance(req_body : String)

    def form_template
      FormTemplate.new(uri_path)
    end

    def controller
      child = child_instance(ctx.request.body.try(&.gets_to_end) || "")
      child.save

      ctx.response.status_code = 201
      model_template.turbo_stream.to_html(ctx.response)
    end
  end
end
