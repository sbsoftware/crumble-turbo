require "../spec_helper"

module Crumble::Turbo::ModelTemplateRefreshControllerSpec
  describe Crumble::Turbo::ModelTemplateRefreshController do
    it "decodes encoded transport newlines before rendering turbo stream messages" do
      js = Crumble::Turbo::ModelTemplateRefreshController.to_js

      js.should contain("addEventListener(\"message\"")
      js.should contain("renderStreamMessage")
      js.should contain("replace(/&#13;/g, \"\\r\")")
      js.should contain("replace(/&#10;/g, \"\\n\")")
    end
  end
end
