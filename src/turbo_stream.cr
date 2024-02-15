require "to_html"
require "./turbo_stream/action"

class TurboStream(T)
  {{ ToHtml::TAG_NAMES["turbo_stream"] = "turbo-stream" }}

  @action : TurboStream::Action
  @targets : CSS::Selector
  @content : T

  def initialize(@action : TurboStream::Action, @targets, @content)
  end

  ToHtml.instance_template do
    turbo_stream(action: @action, targets: @targets.to_s.dump_unquoted) do
      template do
        @content.to_html
      end
    end
  end
end
