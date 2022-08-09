module Crumble
  class TurboStyle < CSS::Stylesheet
    rules do
      rule BooleanFlipController > form do
        display None
      end
    end
  end
end
