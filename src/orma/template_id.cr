module Orma::TemplateId
  getter model_class : String
  getter model_id : Int32 | Int64
  getter template_name : String

  def initialize(@model_class, @model_id, @template_name); end

  macro included
    def to_css_selector
      CSS::AttrSelector.new(ATTR_NAME, attr_value)
    end

    def to_html_attrs(_tag, attrs)
      attrs[ATTR_NAME] = attr_value
    end
  end

  def attr_value
    "#{model_class}##{model_id.to_s}-#{template_name}"
  end
end
