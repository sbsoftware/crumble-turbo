require "./turbo_stream"

module ModelResource
  TURBO_STREAM_MIME_TYPE = "text/vnd.turbo-stream.html"

  def render(tpl)
    if @ctx.request.headers.get("Accept").includes?(TURBO_STREAM_MIME_TYPE)
      @ctx.response.headers.add("Content-Type", TURBO_STREAM_MIME_TYPE)
      tpl.turbo_stream.to_s(@ctx.response)
    else
      super
    end
  end
end
