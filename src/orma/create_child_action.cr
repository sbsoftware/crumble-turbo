require "./model_action"

module Orma
  abstract class CreateChildAction < ModelAction
    abstract def parent_params

    controller do
      return unless form.valid?

      self.class.child_class.create(**create_params(form))

      ctx.response.status_code = 201
    end

    macro inherited
      def create_params(request_body : String)
        create_params(parse_form_for_action(request_body))
      end

      def create_params(submitted_form = form)
        parent_params.merge(submitted_form.values).merge(context_params)
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
