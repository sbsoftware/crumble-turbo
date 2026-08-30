require "./child"

module CreateChildCircularAssociationSpec
  class Parent < TestRecord
    id_column id : Int64
    column name : String?
    has_many_of Child

    create_child_action :add_child, Child, create_child_circular_association_spec_parent_id, default_view do
      form do
        field name : String
      end

      view do
        template do
          action_form.to_html do
            input(type: "submit")
          end
        end
      end
    end

    model_template :default_view do
      div do
        id
      end
    end
  end
end
