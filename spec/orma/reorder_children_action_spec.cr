require "../spec_helper"
require "uri"
require "crumble/spec/test_request_context"

module ReorderChildrenActionSpec
  class Parent < Orma::Record
    id_column id : Int32
    column name : String

    def children
      Child.where({"parent_id" => id})
    end

    model_template :children_view do
      div do
        children.each do |child|
          child.default_view(ctx)
        end
      end
    end

    reorder_children_action :sort_children, children, default_view, children_view
  end

  class Child < Orma::Record
    id_column id : Int32
    column parent_id : Int32
    column name : String
    column sort_order : Int32 = 0

    model_template :default_view do
      div { name }
    end
  end

  Parent.continuous_migration!
  Child.continuous_migration!

  describe "Parent#sort_children_action_template#to_html" do
    it "should generate the correct HTML" do
      parent = Parent.create(name: "Parent")
      child_1 = Child.create(parent_id: parent.id, name: "One")
      child_2 = Child.create(parent_id: parent.id, name: "Two")

      expected = <<-HTML.squish
      <div data-model-action-template-id="ReorderChildrenActionSpec::Parent##{parent.id}-sort_children">
        <div data-controller="reorder-children-action-spec--parent--sort-children-action--template--drag" data-action="dragstart->reorder-children-action-spec--parent--sort-children-action--template--drag#dragstart drag->reorder-children-action-spec--parent--sort-children-action--template--drag#drag dragover->reorder-children-action-spec--parent--sort-children-action--template--drag#dragover dragenter->reorder-children-action-spec--parent--sort-children-action--template--drag#dragenter drop->reorder-children-action-spec--parent--sort-children-action--template--drag#drop dragend->reorder-children-action-spec--parent--sort-children-action--template--drag#dragend">
          <form class="crumble--turbo--action-form--hidden" action="/a/reorder_children_action_spec/parent/1/sort_children" method="POST">
            <input data-reorder-children-action-spec--parent--sort-children-action--template--drag-target="subjectId" type="hidden" name="subject_id">
            <input data-reorder-children-action-spec--parent--sort-children-action--template--drag-target="targetId" type="hidden" name="target_id">
            <input data-reorder-children-action-spec--parent--sort-children-action--template--drag-target="submit" type="submit" name="submit" value="submit">
          </form>
          <div>
            <div data-reorder-children-action-subject-id="1" draggable="true">
              <div data-model-template-id="ReorderChildrenActionSpec::Child#1-default_view" data-crumble--turbo--model-template-refresh-target="modelTemplate">
                <div>One</div>
              </div>
            </div>
            <div data-reorder-children-action-subject-id="2" draggable="true">
              <div data-model-template-id="ReorderChildrenActionSpec::Child#2-default_view" data-crumble--turbo--model-template-refresh-target="modelTemplate">
                <div>Two</div>
              </div>
            </div>
          </div>
        </div>
      </div>
      HTML

      ctx = Crumble::Server::TestRequestContext.new
      parent.sort_children_action_template(ctx).to_html.should eq(expected)
    end

    context "when handling a request" do
      it "should switch the order of the children with the provided IDs" do
        parent = Parent.create(name: "Parent")
        child_1 = Child.create(parent_id: parent.id, name: "One", sort_order: 1)
        child_2 = Child.create(parent_id: parent.id, name: "Two", sort_order: 2)
        child_3 = Child.create(parent_id: parent.id, name: "Three", sort_order: 3)

        test_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: Parent::SortChildrenAction.uri_path(parent.id), body: URI::Params.encode({subject_id: child_1.id.value.to_s, target_id: child_2.id.value.to_s}))

        Parent::SortChildrenAction.handle(test_ctx)

        child_1_reload = Child.find(child_1.id)
        child_2_reload = Child.find(child_2.id)

        child_1_reload.sort_order.should eq(2)
        child_2_reload.sort_order.should eq(1)
      end
    end
  end
end
