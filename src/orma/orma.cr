require "./model_template"
require "./model_action"
require "./create_child_action"
require "../crumble/turbo/action_registry"

class Orma::Record
  macro model_action(name, refreshed_model_template, base_class = Orma::ModelAction, &blk)
    class {{name.id.stringify.camelcase.id}}Action < {{base_class}}
      @model : {{@type}}?

      def self.action_name : String
        {{name.id.stringify}}
      end

      def self.action_template(model)
        ::Orma::ModelAction::GenericModelActionTemplate.new(self.uri_path(model.id))
      end

      def self.model_class : Orma::Record.class
        {{@type.resolve}}
      end

      def model
        @model ||= self.class.model_class.find(model_id)
      end

      def model_template : IdentifiableView
        model.{{refreshed_model_template.id}}
      end

      {{blk.body}}
    end

    def {{name.id.stringify.underscore.id}}_action_template
      {{name.id.stringify.camelcase.id}}Action.action_template(self)
    end

    Crumble::Turbo::ActionRegistry.add({{@type.name}}::{{name.id.stringify.camelcase.id}}Action)
  end

  macro boolean_flip_action(name, attr, tpl, &blk)
    model_action({{name}}, {{tpl}}) do
      controller do
        return unless body = ctx.request.body

        new_val = nil
        HTTP::Params.parse(body.gets_to_end) do |name, value|
          if name == "value"
            new_val = (value == "true")
          end
        end

        unless new_val.nil?
          model.{{attr.id}} = new_val
          model.save
        end
      end

      def self.action_template(model)
        ::Orma::ModelAction::GenericModelActionTemplate.new(
          self.uri_path(model.id),
          [
            Crumble::Turbo::Action::FormTemplate::Field.new(
              type: Crumble::Turbo::Action::FormTemplate::Field::Type::Hidden,
              name: "value",
              value: (!model.{{attr.id}}.value).to_s
            )
          ],
          hidden: true
        )
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

      def self.action_template(model)
        Template.new(uri_path(model.id))
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
  # Possible customizations:
  #   * `def self.confirm_prompt(model)` - String message to be used as the prompt for a JavaScript confirm dialog
  macro delete_record_action(name, tpl, &blk)
    model_action({{name}}, {{tpl}}) do
      controller do
        model.destroy
      end

      def self.action_template(model)
        ::Orma::ModelAction::GenericModelActionTemplate.new(self.uri_path(model.id), confirm_prompt: confirm_prompt(model))
      end

      def self.confirm_prompt(model)
        nil
      end

      {% if blk %}
        {{blk.body}}
      {% end %}
    end
  end
end
