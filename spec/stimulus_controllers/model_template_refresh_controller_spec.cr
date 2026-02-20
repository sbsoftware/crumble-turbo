require "../spec_helper"

module Crumble::Turbo::ModelTemplateRefreshControllerSpec
  describe Crumble::Turbo::ModelTemplateRefreshController do
    it "connects the event source through Turbo stream source integration" do
      js = Crumble::Turbo::ModelTemplateRefreshController.to_js

      js.should contain("connectStreamSource")
      js.should_not contain("decode_transport_payload")
      js.should_not contain("renderStreamMessage")
    end
  end
end
