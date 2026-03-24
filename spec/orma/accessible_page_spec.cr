require "../spec_helper"
require "crumble/spec/test_request_context"

class ApplicationLayout < ToHtml::Layout
end

abstract class ApplicationPage < Crumble::Page
  layout ApplicationLayout
end

class AccessiblePageSpecGroupResource
  def self.uri_path(id)
    "/groups/#{id}"
  end
end

class AccessiblePageSpecGroupMember < TestRecord
  id_column id : Int64
  column accessible_page_spec_group_id : Int64
  column invitee_id : Int64
  column session_id : String
end

class AccessiblePageSpecGroup < TestRecord
  id_column id : Int64
  column name : String

  model_template :member_list do
    div { name }
  end

  accessible AccessiblePageSpecGroupMember, AccessiblePageSpecGroupResource, member_list do
    access_view do
      def heading
        "Join #{model.name}"
      end

      template do
        article do
          h1 { heading }
          model.accept_access_action_template(ctx)
        end
      end
    end

    accept_access_view do
      template do
        button { "Join" }
      end
    end

    access_model_attributes invitee_id: 88_i64, session_id: "session-1"
  end
end

describe "accessible pages" do
  it "renders the access page with the generated page template" do
    group = AccessiblePageSpecGroup.create(name: "Chess Club", access_token: "ChessClubToken1")
    expected_action_path = AccessiblePageSpecGroup::AcceptAccessAction.uri_path(group.id.value)

    res = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(io, resource: AccessiblePageSpecGroup::AccessPage.uri_path(access_token: group.access_token.value))
      AccessiblePageSpecGroup::AccessPage.handle(ctx).should eq(true)
      ctx.response.flush
    end

    res.should contain("<h1>Join Chess Club</h1>")
    res.should contain(%(action="#{expected_action_path}"))
    res.should contain(%(data-model-action-template-id="AccessiblePageSpecGroup##{group.id.value}-accept_access"))
  end

  it "creates the access record, redirects to the target resource, and refreshes the model template when the submitted token matches" do
    group = AccessiblePageSpecGroup.create(name: "Sailing Club", access_token: "SailingClubToken1")
    res = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(io, method: "POST", resource: AccessiblePageSpecGroup::AcceptAccessAction.uri_path(group.id.value), body: "access_token=#{group.access_token.value}")
      AccessiblePageSpecGroup::AcceptAccessAction.handle(ctx).should eq(true)
      ctx.response.status_code.should eq(303)
      ctx.response.headers["Location"].should eq("/groups/#{group.id.value}")
      ctx.response.flush
    end

    AccessiblePageSpecGroupMember.where(accessible_page_spec_group_id: group.id.value, invitee_id: 88_i64, session_id: "session-1").first?.should_not be_nil
    res.should contain(%(data-model-template-id="AccessiblePageSpecGroup##{group.id.value}-member_list"))
  end
end
