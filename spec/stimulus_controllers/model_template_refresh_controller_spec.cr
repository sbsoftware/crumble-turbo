require "../spec_helper"

module Crumble::Turbo::ModelTemplateRefreshControllerSpec
  describe ModelTemplateRefreshController do
    it "handles EventSource errors by scheduling a capped reconnect" do
      js = ModelTemplateRefreshController.to_js

      js.should contain("this.evt_source.addEventListener(\"error\"")
      js.should contain("that.connected = false;that.schedule_reconnect();")
      js.should contain("delay = Math.min(100 * Math.pow(2, this.reconnect_attempts), 30000);")
      js.should contain("this.reconnect_timeout = setTimeout(reconnect, delay);")
    end

    it "cleans up reconnect timers and stream sources on disconnect" do
      js = ModelTemplateRefreshController.to_js

      js.should contain("this.clear_reconnect_timeout();")
      js.should contain("clearTimeout(this.reconnect_timeout);")
      js.should contain("Turbo.session.disconnectStreamSource(this.evt_source);")
      js.should contain("this.evt_source.close();")
    end

    it "queues model template registrations while disconnected and flushes them on open" do
      js = ModelTemplateRefreshController.to_js

      js.should contain("that.register_model_templates(true);")
      js.should contain("this.pending_model_template_ids = model_template_ids;")
      js.should contain("this.pending_model_template_ids = undefined;fetch")
      js.should contain("modelTemplateTargetConnected() {this.register_model_templates();}")
      js.should contain("modelTemplateTargetDisconnected() {this.register_model_templates();}")
    end
  end
end
