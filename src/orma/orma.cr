require "./model_template"
require "./model_action"
require "./create_child_action"
require "./reorder_children_action"
require "../crumble/turbo/action_registry"

class Orma::Record
  macro model_action(name, refreshed_model_template, base_class = Orma::ModelAction, &blk)
    class {{name.id.stringify.camelcase.id}}Action < {{base_class}}
      getter model : ::{{@type}}

      def self.action_name : String
        {{name.id.stringify}}
      end

      def self.model_class : Orma::Record.class
        {{@type.resolve}}
      end

      def model_template : IdentifiableView
        model.{{refreshed_model_template.id}}
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
        return unless body = ctx.request.body

        form = Form.from_www_form(body.gets_to_end)

        if form.valid?
          model.update(**form.values)
        end
      end

      def form
        Form.new({{attr.id}}: !model.{{attr.id}}.value)
      end

      {% if blk %}
        {{blk.body}}
      {% end %}
    end
  end

  macro create_child_action(name, child_class, parent_id_attr, tpl, &blk)
    model_action({{name}}, {{tpl}}, Orma::CreateChildAction) do
      def self.child_class : ::Orma::Record.class
        {{child_class.resolve}}
      end

      def assign_parent_id(child)
        child.{{parent_id_attr.id}} = model.id
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
        child.{{child_view.id}}
      end

      {% if blk %}
        {{blk.body}}
      {% end %}
    end
  end
end
