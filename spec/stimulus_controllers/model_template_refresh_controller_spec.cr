require "../spec_helper"

module Crumble::Turbo::ModelTemplateRefreshControllerSpec
  describe ModelTemplateRefreshController do
    it "waits for window load before opening the initial EventSource" do
      js = ModelTemplateRefreshController.to_js

      js.should contain(%(if (document.readyState == "complete") {this.connect_event_source();} else {window.addEventListener("load", this.connect_event_source_after_load);}))
      js.should contain(%(window.removeEventListener("load", this.connect_event_source_after_load);))
      js.should contain(%(this.evt_source = new EventSource("#{ModelTemplateRefreshResource.uri_path}");))
    end
  end
end
