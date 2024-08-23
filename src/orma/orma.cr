require "./model_template"
require "./boolean_flip_action"
require "./create_child_action"
require "../crumble/turbo/action_registry"

class Orma::Record
  macro boolean_flip_action(name, attr, tpl, &blk)
    class {{name.capitalize.id}}Action < ::Orma::BooleanFlipAction
      @model : {{@type}}?

      def attribute
        model.{{attr.id}}
      end

      def model
        @model ||= self.class.model_class.find(model_id)
      end

      def model_template : IdentifiableView
        model.{{tpl.id}}
      end

      {% if blk.is_a?(Block) && blk.body.is_a?(Call) && blk.body.name.id == "before".id %}
      def before_action
        {{blk.body.block.body}}
      end
      {% end %}

      def self.action_name : String
        {{name.id.stringify}}
      end

      def self.model_class : ::Orma::Record.class
        {{@type.resolve}}
      end
    end

    def {{name.id}}_action_template
      {{name.capitalize.id}}Action::Template.new({{name.capitalize.id}}Action.uri_path(self.id.value), self.{{attr.id}}.value || false)
    end

    Crumble::Turbo::ActionRegistry.add({{@type.name}}::{{name.capitalize.id}}Action)
  end

  macro create_child_action(name, child_class, parent_id_attr, tpl, &blk)
    class {{name.camelcase.id}}Action < ::Orma::CreateChildAction
      @model : {{@type}}?

      class Template
        getter uri_path : String

        def initialize(@uri_path); end

        ToHtml.instance_template do
          FormTemplate.new(uri_path).to_html do
            {% if blk.body.is_a?(Expressions) && blk.body.expressions.find { |e| e.is_a?(Call) && e.name.id == "form".id } %}
              {{blk.body.expressions.find { |e| e.is_a?(Call) && e.name.id == "form".id }.block.body}}
            {% end %}
          end
        end
      end

      def model
        @model ||= self.class.model_class.find(model_id)
      end

      def model_template : IdentifiableView
        model.{{tpl.id}}
      end

      def self.action_name : String
        {{name.id.stringify}}
      end

      def self.model_class : ::Orma::Record.class
        {{@type.resolve}}
      end

      def self.child_class : ::Orma::Record.class
        {{child_class.resolve}}
      end

      {% if blk.body.is_a?(Expressions) && blk.body.expressions.find { |e| e.is_a?(Call) && e.name.id == "before".id } %}
      def before_action
        {{blk.body.expressions.find { |e| e.is_a?(Call) && e.name.id == "before".id }.block.body}}
      end
      {% end %}

      def child_instance(req_body : String)
        child = self.class.child_class.new
        child.{{parent_id_attr.id}} = model.id
        HTTP::Params.parse(req_body) do |name, value|
          {% if blk.is_a?(Block) %}
            case name
              {% for attr in blk.body.expressions.find { |exp| exp.is_a?(Call) && exp.name.id == "params".id }.args %}
                when {{attr.id.stringify}}
                  child.{{attr.id}} = value
              {% end %}
            end
          {% end %}
        end
        child
      end
    end

    def {{name.id}}_action_template
      {{name.camelcase.id}}Action::Template.new({{name.camelcase.id}}Action.uri_path(self.id.value))
    end

    Crumble::Turbo::ActionRegistry.add({{@type.name}}::{{name.camelcase.id}}Action)
  end
end
