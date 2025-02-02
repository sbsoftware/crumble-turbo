require "to_html"
require "../../stimulus_controllers/model_template_refresh_controller"

class ToHtml::Layout
  add_to_head ToHtml::ExternalScript.new("https://unpkg.com/@hotwired/turbo@8.0.4/dist/turbo.es2017-umd.js")
  add_to_head Crumble::Turbo::Action::FormTemplate::Style
  add_to_head Orma::ModelAction::GenericModelActionTemplate::Style

  body_attributes Crumble::Turbo::ModelTemplateRefreshController
end
