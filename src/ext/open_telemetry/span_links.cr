module OpenTelemetry
  class Span
    getter links : Array(Proto::Trace::V1::Span::Link) = [] of Proto::Trace::V1::Span::Link

    # The pinned SDK protobuf supports links, but Span does not expose them yet.
    # Keep the extension local so template send spans can export link metadata.
    def add_link(context : SpanContext, attributes : Hash(String, AnyAttribute) = {} of String => AnyAttribute) : Nil
      links << Proto::Trace::V1::Span::Link.new(trace_id: context.trace_id, span_id: context.span_id, trace_state: context.trace_state.map { |key, value| "#{key}=#{value}" }.join(","), attributes: attributes.map do |key, value|
        Proto::Common::V1::KeyValue.new(key: key, value: Attribute.to_anyvalue(value))
      end)
    end

    def add_link(context : SpanContext, attributes : Hash(String, _) = {} of String => String) : Nil
      converted_attributes = {} of String => AnyAttribute
      attributes.each do |key, value|
        converted_attributes[key] = AnyAttribute.new(key: key, value: value)
      end

      add_link(context, converted_attributes)
    end

    def to_protobuf
      return unless can_export?

      span = Proto::Trace::V1::Span.new(name: name, trace_id: context.trace_id, span_id: context.span_id, parent_span_id: parent.try(&.context.span_id), start_time_unix_nano: start_time_unix_nano, end_time_unix_nano: end_time_unix_nano, kind: pb_span_kind, status: status.to_protobuf)
      span.attributes = attributes.map do |key, value|
        Proto::Common::V1::KeyValue.new(key: key, value: Attribute.to_anyvalue(value))
      end
      span.events = events.map(&.to_protobuf)
      span.links = links
      span
    end

    def to_json(json : JSON::Builder)
      if can_export?
        json.object do
          json.field "type", "span"
          json.field "traceId", context.trace_id.hexstring
          json.field "spanId", context.span_id.hexstring
          json.field "parentSpanId", parent.try(&.context.span_id.hexstring)
          json.field "kind", kind.value
          json.field "name", name
          json.field "status", status.to_json
          json.field "startTime", start_time_unix_nano
          json.field "endTime", end_time_unix_nano
          json.field "attributes" do
            json.object do
              attributes.each do |_, value|
                json.field value.key, value.value
              end
            end
          end
          json.field "events" do
            json.array do
              events.each do |event|
                event.to_json(json)
              end
            end
          end
          json.field "links" do
            json.array do
              links.each do |link|
                json.object do
                  json.field "traceId", link.trace_id.try(&.hexstring)
                  json.field "spanId", link.span_id.try(&.hexstring)
                  json.field "traceState", link.trace_state
                end
              end
            end
          end
          json
        end
      else
        json.object do
        end
      end
    end
  end
end
