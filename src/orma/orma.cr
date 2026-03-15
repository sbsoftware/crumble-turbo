require "./model_template"
require "./model_action"
require "./create_child_action"
require "./reorder_children_action"
require "../crumble/turbo/action_registry"

class Orma::Record
  macro model_action(name, refreshed_model_template, base_class = Orma::ModelAction, &blk)
    class {{name.id.stringify.camelcase.id}}Action < {{base_class}}
      alias ModelFormModel = ::{{@type.resolve}}

      getter model : ::{{@type}}

      def self.action_name : String
        {{name.id.stringify}}
      end

      def self.model_class : Orma::Record.class
        {{@type.resolve}}
      end

      def refreshed_model_templates
        {% tpl_expr = refreshed_model_template %}
        {% if tpl_expr.is_a?(Path) %}
          {% tpl_expr = tpl_expr.resolve %}
        {% end %}

        {% if tpl_expr.is_a?(NilLiteral) %}
          nil
        {% else %}
          {
            {% if tpl_expr.is_a?(ArrayLiteral) || tpl_expr.is_a?(TupleLiteral) %}
              {% if tpl_expr.size == 0 %}
                {% tpl_expr.raise "model_action tpl must not be empty" %}
              {% end %}

              {% for tpl in tpl_expr %}
                model.{{tpl.id}},
              {% end %}
            {% else %}
              model.{{tpl_expr.id}},
            {% end %}
          }
        {% end %}
      end

      {{blk.body}}
    end

    def {{name.id.stringify.underscore.id}}_action_template(ctx)
      {{name.id.stringify.camelcase.id}}Action.new(ctx, self).action_template
    end
  end

  macro boolean_flip_action(name, attr, tpl, &blk)
    model_action({{name}}, {{tpl}}) do
      form do
        field {{attr.id}} : Bool, type: :hidden
      end

      controller do
        model.update(**form.values) if form.valid?
      end

      def form
        Form.new(ctx, model, {{attr.id}}: !model.{{attr.id}}.value)
      end

      {% if blk %}
        {{blk.body}}
      {% end %}
    end
  end

  # Defines a model action that creates a child record and merges:
  #   * `parent_params`
  #   * submitted form values
  #   * optional `context_attributes`
  #
  # Form blocks in model actions are model-aware by default (`Crumble::ModelForm`),
  # so option helpers can directly access `model`.
  #
  # Example:
  # ```
  # create_child_action :create_reimbursement, Reimbursement, group_id, default_view do
  #   form do
  #     field amount : Float64, attrs: {required: true, step: ".01"}
  #     field recipient_membership_id : Int64, type: :select, options: recipient_options
  #
  #     def recipient_options
  #       options = [{"", t.form.recipient_membership_id_prompt}] of Tuple(String, String)
  #       model.group_memberships.each do |membership|
  #         next if membership.user_id == ctx.session.user_id
  #         options << {membership.id.value.to_s, membership.display_name}
  #       end
  #       options
  #     end
  #   end
  # end
  # ```
  #
  # Migration note:
  # Existing actions can drop manual `@submitted_form` bookkeeping and most
  # custom setter workarounds for model-dependent fields.
  macro create_child_action(name, child_class, parent_id_attr, tpl, &blk)
    model_action({{name}}, {{tpl}}, Orma::CreateChildAction) do
      def self.child_class : ::Orma::Record.class
        {{child_class.resolve}}
      end

      def parent_params
        { {{parent_id_attr.id}}: model.id.try(&.value).not_nil! }
      end

      {% if blk %}
        {{blk.body}}
      {% end %}
    end
  end

  # Defines an action to delete the record from the database.
  # Parameters:
  #   * `name` - the name of the action
  #   * `tpl` - the model template to render in the response
  macro delete_record_action(name, tpl, &blk)
    model_action({{name}}, {{tpl}}) do
      controller do
        model.destroy
      end

      {% if blk %}
        {{blk.body}}
      {% end %}
    end
  end

  # Defines an action to make a list of child models sortable via dragging.
  # Parameters:
  #   * `name` - the name of the action
  #   * `assoc` - method of the parent model returning the children collection
  #   * `child_view` - method of the child model returning the template to use in the sortable list
  #   * `tpl` - the model template to render in the response
  macro reorder_children_action(name, assoc, child_view, tpl, &blk)
    model_action({{name}}, {{tpl}}, ReorderChildrenAction) do
      def association
        model.{{assoc.id}}
      end

      def child_view(child)
        child.{{child_view.id}}.renderer(ctx)
      end

      {% if blk %}
        {{blk.body}}
      {% end %}
    end
  end
end
