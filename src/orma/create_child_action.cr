require "./model_action"

module Orma
  abstract class CreateChildAction < ModelAction
    abstract def parent_params

    controller do
      return unless body = ctx.request.body

      params = create_params(body.gets_to_end)
      self.class.child_class.create(**params)

      ctx.response.status_code = 201
    end

    macro inherited
      def create_params(request_body : String)
        form = Form.from_www_form(ctx, request_body)

        parent_params.merge(form.values).merge(context_params)
      end
    end

    macro context_attributes(**attrs)
      def context_params
        {% if @type.has_method?("context_params") %}
          {% if @type.methods.map(&.name).includes?("context_params") %}
            params = previous_def
          {% else %}
            params = super
          {% end %}
        {% end %}

        params.merge({{attrs}})
      end
    end

    def context_params
      NamedTuple.new
    end
  end
end
