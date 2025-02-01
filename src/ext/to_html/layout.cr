require "to_html"
require "../../stimulus_controllers/model_template_refresh_controller"

class ToHtml::Layout
  body_attributes Crumble::Turbo::ModelTemplateRefreshController
end
