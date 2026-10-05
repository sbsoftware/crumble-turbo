require "../crumble/turbo/model_template_refresh_service"

module Crumble
  module Turbo
    class ModelTemplateRefreshResource < ::Crumble::Resource
      NEWLINE_ENTITY         = "&#10;"
      CARRIAGE_RETURN_ENTITY = "&#13;"
      HEARTBEAT_INTERVAL     = 15.seconds

      def index
        unless subscription_id = requested_subscription_id
          ctx.response.status = :bad_request
          return
        end

        ctx.response.content_type = "text/event-stream"
        ctx.response.headers["Cache-Control"] = "no-cache"
        ctx.response.headers["X-Accel-Buffering"] = "no"

        channel = ModelTemplateRefreshService.subscribe(ctx, subscription_id)

        ctx.response.upgrade do |io|
          if io.is_a?(TCPSocket)
            Socket.set_blocking(io.fd, true)
            io.sync = true
          end

          io << ": connected\n\n"
          io.flush

          loop do
            select
            when turbo_stream = channel.receive
              turbo_stream_html = String.build do |stream_io|
                turbo_stream.to_html(stream_io)
              end

              io << "data: "
              io << encode_transport_newlines(turbo_stream_html)
              io << "\n\n"
              io.flush
            when timeout(HEARTBEAT_INTERVAL)
              # Periodic writes detect clients that disconnect while no model
              # refreshes are being sent, bounding stale subscription lifetime.
              io << ": keepalive\n\n"
              io.flush
            end
          rescue e : IO::Error
            ModelTemplateRefreshService.unsubscribe(ctx, channel)

            break
          end
        rescue Channel::ClosedError
        ensure
          ModelTemplateRefreshService.unsubscribe(ctx, channel)
          channel.close
          io.close
        end
      end

      def create
        unless subscription_id = requested_subscription_id
          ctx.response.status = :bad_request
          return
        end
        unless body = ctx.request.body
          ctx.response.status = :bad_request
          return
        end

        model_template_ids = Array(String).from_json(body.gets_to_end)
        unless ModelTemplateRefreshService.register(ctx, subscription_id, model_template_ids)
          ctx.response.status = :bad_request
          return
        end
      end

      private def requested_subscription_id : String?
        return unless subscription_id = ctx.request.query_params["subscription_id"]?.presence
        return if subscription_id.bytesize > 128

        subscription_id
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
