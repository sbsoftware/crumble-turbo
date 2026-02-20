require "../crumble/turbo/model_template_refresh_service"

module Crumble
  module Turbo
    class ModelTemplateRefreshResource < ::Crumble::Resource
      NEWLINE_ENTITY         = "&#10;"
      CARRIAGE_RETURN_ENTITY = "&#13;"

      def index
        ctx.response.content_type = "text/event-stream"
        ctx.response.headers["Cache-Control"] = "no-cache"
        ctx.response.headers["Connection"] = "keep-alive"
        ctx.response.headers["X-Accel-Buffering"] = "no"

        channel = ModelTemplateRefreshService.subscribe(ctx)

        ctx.response.upgrade do |io|
          if io.is_a?(TCPSocket)
            Socket.set_blocking(io.fd, true)
            io.sync = true
          end

          io << ": connected\n\n"
          io.flush

          loop do
            turbo_stream = channel.receive
            turbo_stream_html = String.build do |stream_io|
              turbo_stream.to_html(stream_io)
            end

            io << "data: "
            io << encode_transport_newlines(turbo_stream_html)
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

      # SSE event parsing is line-based; transport newlines must be encoded
      # and reconstructed by the client before Turbo stream rendering.
      private def encode_transport_newlines(payload : String) : String
        payload
          .gsub("\r\n", "#{CARRIAGE_RETURN_ENTITY}#{NEWLINE_ENTITY}")
          .gsub("\r", CARRIAGE_RETURN_ENTITY)
          .gsub("\n", NEWLINE_ENTITY)
      end
    end
  end
end
