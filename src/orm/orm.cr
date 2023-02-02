require "./boolean_flip_action"
require "./create_child_action"
require "./action_registry"

module Crumble::ORM
  class Base
    macro boolean_flip_action(name, attr, tpl, &blk)
      class {{name.capitalize.id}}Action < Crumble::ORM::BooleanFlipAction
        PATH_MATCHER = /#{Crumble::ORM::Action::URI_PATH_PREFIX}\/{{@type.resolve.name.gsub(/::/, "\\/").underscore.id}}\/(\d+)\/{{name.id}}/

        getter model : {{@type}}

        def initialize(@model); end

        def attribute
          model.{{attr.id}}
        end

        def model_template : Crumble::ModelTemplate
          model.{{tpl.id}}
        end

        def self.model_class : Crumble::ORM::Base.class
          {{@type.resolve}}
        end

        def self.path_matcher : Regex
          PATH_MATCHER
        end

        def uri_path : String
          "#{Crumble::ORM::Action::URI_PATH_PREFIX}/{{@type.resolve.name.gsub(/::/, "/").underscore.id}}/#{model.id.value}/{{name.id}}"
        end
      end

      def {{name.id}}_action
        {{name.capitalize.id}}Action.new(self)
      end

      Crumble::ORM::ActionRegistry.add({{@type.name}}::{{name.capitalize.id}}Action)
    end

    macro create_child_action(name, child_class, parent_id_attr, tpl, &blk)
      class {{name.capitalize.id}}Action < Crumble::ORM::CreateChildAction
        PATH_MATCHER = /#{Crumble::ORM::Action::URI_PATH_PREFIX}\/{{@type.resolve.name.gsub(/::/, "\\/").underscore.id}}\/(\d+)\/{{name.id}}/

        getter model : {{@type}}

        def initialize(@model); end

        def model_template : Crumble::ModelTemplate
          model.{{tpl.id}}
        end

        def self.model_class : Crumble::ORM::Base.class
          {{@type.resolve}}
        end

        def self.child_class : Crumble::ORM::Base.class
          {{child_class.resolve}}
        end

        def child_instance
          child = self.class.child_class.new
          child.{{parent_id_attr}} = model.id
          child
        end

        def self.path_matcher : Regex
          PATH_MATCHER
        end

        def uri_path : String
          "#{Crumble::ORM::Action::URI_PATH_PREFIX}/{{@type.resolve.name.gsub(/::/, "/").underscore.id}}/#{model.id.value}/{{name.id}}"
        end
      end

      def {{name.id}}_action
        {{name.capitalize.id}}Action.new(self)
      end

      Crumble::ORM::ActionRegistry.add({{@type.name}}::{{name.capitalize.id}}Action)
    end
  end
end
