require "crumble"
require "./turbo_stream/action"

class TurboStream < Template
  {{ Template::CONTENT_TAG_NAMES << "turbo_stream" }}

  @action : TurboStream::Action
  @targets : CSS::Selector
  @content : Template

  def initialize(@action : TurboStream::Action, @targets, @content)
  end

  template do
    turbo_stream({"action", @action}, {"targets", @targets}) do
      @content
    end
  end
end
