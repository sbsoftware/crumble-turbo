require "./model_action"

module Orma
  abstract class CreateChildAction < ModelAction
    abstract def assign_parent_id(child)

    controller do
      return unless body = ctx.request.body

      child = child_instance(body.gets_to_end)
      child.save

      ctx.response.status_code = 201
    end

    def child_instance(req_body : String)
      child = self.class.child_class.new
      assign_parent_id(child)
      HTTP::Params.parse(req_body) do |name, value|
        assign_param(child, name, value)
      end

      add_context_attributes(child, ctx)

      child
    end

    macro params(*attrs)
      def assign_param(instance, param_name, param_value)
        {% if @type.has_method?("assign_param") %}
          {% if @type.methods.map(&.name).includes?("assign_param") %}
            previous_def
          {% else %}
            super
          {% end %}
        {% end %}

        case param_name
          {% for attr in attrs %}
            when {{attr.id.stringify}}
              instance.{{attr.id}} = param_value
          {% end %}
        end
      end
    end

    macro context_attributes(**attrs)
      def add_context_attributes(instance, ctx)
        {% if @type.has_method?("add_context_attributes") %}
          {% if @type.methods.map(&.name).includes?("add_context_attributes") %}
            previous_def
          {% else %}
            super
          {% end %}
        {% end %}

        {% for name, value in attrs %}
          instance.{{name.id}} = ctx.{{value.id}}
        {% end %}
      end
    end

    def assign_param(instance, param_name, param_value)
    end

    def add_context_attributes(instance, ctx)
    end

    macro form(&blk)
      view do
        template do
          action_form(hidden: false).to_html do
            {{blk.body}}
          end
        end
      end
    end
  end
end
