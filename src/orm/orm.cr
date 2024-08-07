require "./boolean_flip_action"
require "./create_child_action"
require "./action_registry"

class Orma::Record
  macro boolean_flip_action(name, attr, tpl, &blk)
    class {{name.capitalize.id}}Action < Crumble::ORM::BooleanFlipAction
      getter model : {{@type}}

      def initialize(@model); end

      def attribute
        model.{{attr.id}}
      end

      def model_template : IdentifiableView
        model.{{tpl.id}}
      end

      {% if blk.is_a?(Block) && blk.body.is_a?(Call) && blk.body.name.id == "before".id %}
      def before_action({{blk.body.block.args.splat}})
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

    def {{name.id}}_action
      {{name.capitalize.id}}Action.new(self)
    end

    Crumble::ORM::ActionRegistry.add({{@type.name}}::{{name.capitalize.id}}Action)
  end

  macro create_child_action(name, child_class, parent_id_attr, tpl, &blk)
    class {{name.camelcase.id}}Action < Crumble::ORM::CreateChildAction
      getter model : {{@type}}

      def initialize(@model); end

      private class Template
        getter parent : Crumble::ORM::CreateChildAction

        def initialize(@parent); end

        ToHtml.instance_template do
          parent.form_template.to_html do
            {% if blk.body.is_a?(Expressions) && blk.body.expressions.find { |e| e.is_a?(Call) && e.name.id == "form".id } %}
              {{blk.body.expressions.find { |e| e.is_a?(Call) && e.name.id == "form".id }.block.body}}
            {% end %}
          end
        end
      end

      def template
        Template.new(self)
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
      def before_action({{blk.body.expressions.find { |e| e.is_a?(Call) && e.name.id == "before".id }.block.args.splat}})
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

    def {{name.id}}_action
      {{name.camelcase.id}}Action.new(self)
    end

    Crumble::ORM::ActionRegistry.add({{@type.name}}::{{name.camelcase.id}}Action)
  end
end
