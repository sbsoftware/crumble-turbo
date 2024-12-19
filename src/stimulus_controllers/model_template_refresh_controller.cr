require "../resources/model_template_refresh_resource"

module Crumble
  module Turbo
    class ModelTemplateRefreshController < ::Stimulus::Controller
      targets :model_template

      js_method :connect do
        this.evt_source = EventSource.new(Crumble::Turbo::ModelTemplateRefreshResource.uri_path.to_js_ref)
        Turbo.session.connectStreamSource(this.evt_source)

        that = this
        this.evt_source.addEventListener("open") do
          that.register_model_templates(true)
        end
      end

      js_method :register_model_templates do |force|
        unless this.model_template_ids
          this.model_template_ids = [] of String
        end

        model_template_ids = this.modelTemplateTargets.map do |elem|
          return elem.dataset["modelTemplateId"]
        end.sort._call

        model_template_ids_changed = this.model_template_ids.length != model_template_ids.length
        unless model_template_ids_changed
          model_template_ids_changed = this.model_template_ids.every do |index, value|
            model_template_ids[index] == value
          end
        end

        if model_template_ids_changed || force
          this.model_template_ids = model_template_ids

          fetch(
            Crumble::Turbo::ModelTemplateRefreshResource.uri_path.to_js_ref,
            {
              "method" => "POST",
              "body" => JSON.stringify(model_template_ids)
            }
          )
        end
      end

      js_method :modelTemplateTargetConnected do
        this.register_model_templates._call
      end

      js_method :modelTemplateTargetDisconnected do
        this.register_model_templates._call
      end
    end
  end
end
