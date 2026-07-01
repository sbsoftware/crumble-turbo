require "../resources/model_template_refresh_resource"

module Crumble
  module Turbo
    class ModelTemplateRefreshController < ::Stimulus::Controller
      targets :model_template

      js_method :connect do
        this.connected = false
        this.reconnect_attempts = 0
        this.connect_event_source._call
      end

      js_method :disconnect do
        this.connected = false
        this.clear_reconnect_timeout._call

        if this.evt_source
          Turbo.session.disconnectStreamSource(this.evt_source)
          this.evt_source.close._call
          this.evt_source = nil
        end
      end

      js_method :connect_event_source do
        this.clear_reconnect_timeout._call
        this.evt_source = EventSource.new(Crumble::Turbo::ModelTemplateRefreshResource.uri_path.to_js_ref)
        Turbo.session.connectStreamSource(this.evt_source)
        that = this

        this.evt_source.addEventListener("open") do
          that.connected = true
          that.reconnect_attempts = 0
          that.register_model_templates(true)
        end

        this.evt_source.addEventListener("error") do
          that.connected = false
          that.schedule_reconnect._call
        end
      end

      js_method :clear_reconnect_timeout do
        if this.reconnect_timeout
          clearTimeout(this.reconnect_timeout)
          this.reconnect_timeout = nil
        end
      end

      js_method :schedule_reconnect do
        return if this.reconnect_timeout

        if this.evt_source
          Turbo.session.disconnectStreamSource(this.evt_source)
          this.evt_source.close._call
          this.evt_source = nil
        end

        delay = Math.min(100 * Math.pow(2, this.reconnect_attempts), 30000)
        this.reconnect_attempts = this.reconnect_attempts + 1
        that = this

        reconnect = -> {
          that.reconnect_timeout = nil
          that.connect_event_source._call
        }

        this.reconnect_timeout = setTimeout(reconnect, delay)
      end

      js_method :register_model_templates do |force|
        unless this.model_template_ids
          this.model_template_ids = [] of String
        end

        model_template_ids = this.modelTemplateTargets.map do |elem|
          return elem.dataset["modelTemplateId"]
        end.sort._call

        model_template_ids_changed = (this.model_template_ids.length != model_template_ids.length)
        unless model_template_ids_changed
          model_template_ids_changed = this.model_template_ids.every do |index, value|
            return model_template_ids[index] == value
          end
        end

        if model_template_ids_changed || force
          this.model_template_ids = model_template_ids

          fetch(
            Crumble::Turbo::ModelTemplateRefreshResource.uri_path.to_js_ref,
            {
              "method" => "POST",
              "body"   => JSON.stringify(model_template_ids),
            }
          )
        end
      end

      js_method :modelTemplateTargetConnected do
        if this.connected
          this.register_model_templates._call
        end
      end

      js_method :modelTemplateTargetDisconnected do
        if this.connected
          this.register_model_templates._call
        end
      end
    end
  end
end
