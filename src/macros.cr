macro css_class(name)
  class {{name.id}} < CSS::CSSClass; end
end

macro style(name = Style, &blk)
  class {{name.id}} < CSS::Stylesheet
    rules do
      {{blk.body}}
    end
  end

  class ::ToHtml::Layout
    append_to_head {{name.id}}
  end
end
