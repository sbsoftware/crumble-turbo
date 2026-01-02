require "../crumble/turbo/model_template_refresh_service"

module Crumble
  module Turbo
    class ModelTemplateRefreshResource < ::Crumble::Resource
      def index
        ctx.response.content_type = "text/event-stream"
        ctx.response.headers["Cache-Control"] = "no-cache"
        ctx.response.headers["Connection"] = "keep-alive"
        ctx.response.headers["X-Accel-Buffering"] = "no"

        channel = ModelTemplateRefreshService.subscribe(ctx)

        ctx.response.upgrade do |io|
          if io.is_a?(TCPSocket)
            io.blocking = true
            io.sync = true
          end

          io << ": connected\n\n"
          io.flush

          loop do
            turbo_stream = channel.receive

            io << "data: "
            turbo_stream.to_html(io)
            io << "\n\n"
            io.flush
          rescue e : IO::Error
            ModelTemplateRefreshService.unsubscribe(ctx)

            break
          end
        rescue Channel::ClosedError
        ensure
          channel.close
          io.close
        end
      end

      def create
        return :bad_request unless body = ctx.request.body

        model_template_ids = Array(String).from_json(body.gets_to_end)

        model_template_ids.each do |model_template_id|
          ModelTemplateRefreshService.register(ctx, model_template_id)
          ModelTemplateRefreshService.refresh_model_template_id(model_template_id, only: ctx.session.id)
        end
      end
    end
  end
end
