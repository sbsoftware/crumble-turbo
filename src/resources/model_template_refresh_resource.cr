require "../crumble/turbo/model_template_refresh_service"

module Crumble
  module Turbo
    class ModelTemplateRefreshResource < ::Crumble::Resource
      def index
        ctx.response.content_type = "text/event-stream"
        ctx.response.headers["Cache-Control"] = "no-cache"
        ctx.response.headers["Connection"] = "keep-alive"
        ctx.response.headers["X-Accel-Buffering"] = "no"

        ctx.response.upgrade do |io|
          channel = ModelTemplateRefreshService.subscribe(ctx.session.id.to_s)

          loop do
            view = channel.receive

            io << "data: "
            view.turbo_stream.to_html(io)
            io << "\n\n"
            io.flush
          rescue e : Exception
            ModelTemplateRefreshService.unsubscribe(ctx.session.id.to_s)

            break
          end

        ensure
          io.close
        end
      end

      def create
        return :bad_request unless body = ctx.request.body

        model_template_ids = Array(String).from_json(body.gets_to_end)

        model_template_ids.each do |model_template_id|
          ModelTemplateRefreshService.register(ctx.session.id.to_s, model_template_id)
        end
      end
    end
  end
end
