require "to_html"
require "../../crumble/turbo/turbo_asset"
require "../../stimulus_controllers/model_template_refresh_controller"

class ToHtml::Layout
  append_to_head ToHtml::ExternalScript.new(Crumble::Turbo::TurboAsset.uri_path)
  append_to_head Crumble::Turbo::ActionForm::Style

  body_attributes Crumble::Turbo::ModelTemplateRefreshController
end
