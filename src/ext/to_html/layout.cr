require "to_html"
require "../../stimulus_controllers/model_template_refresh_controller"

class ToHtml::Layout
  append_to_head ToHtml::ExternalScript.new("https://unpkg.com/@hotwired/turbo@8.0.4/dist/turbo.es2017-umd.js")
  append_to_head Orma::ModelAction::GenericModelActionTemplate::Style
  append_to_head ReorderChildrenAction::Template::Style

  body_attributes Crumble::Turbo::ModelTemplateRefreshController
end
