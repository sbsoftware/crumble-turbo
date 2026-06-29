require "../../spec_helper"
require "json"

module Crumble::Turbo::ModelTemplateRefreshResourceSpec
  class MyModel < TestRecord
    id_column id : Int64
    column name : String

    model_template :the_view do
      div do
        span { name }
        span { ctx.request.path }
      end
    end
  end

  class SessionModel < TestRecord
    id_column id : Int64
    column name : String

    model_template :the_view do
      div do
        span { ctx.session.model_template_refresh_value }
      end
    end
  end

  class MultilineModel < TestRecord
    id_column id : Int64
    column transcript : String

    model_template :the_view do
      pre { transcript }
    end
  end

  def self.exported_traces(memory : IO::Memory)
    memory.rewind
    buffer = memory.gets_to_end
    traces = [] of JSON::Any
    start_pos = -1
    depth = 0

    # The IO exporter writes trace JSON objects back-to-back without separators.
    # Track object depth so specs can inspect each exported trace independently.
    buffer.each_char_with_index do |char, index|
      if char == '{'
        start_pos = index if depth == 0
        depth += 1
      elsif char == '}'
        depth -= 1
        if depth == 0 && start_pos >= 0
          traces << JSON.parse(buffer[start_pos..index])
          start_pos = -1
        end
      end
    end

    traces.reject { |trace| trace.size == 0 }
  end

  describe "when an SSE connection is open" do
    it "should initially refresh registered model templates" do
      model = MyModel.create(name: "Yoda")

      session_store = ::Crumble::Server::MemorySessionStore.new
      session = ::Crumble::Server::Session.new
      session_store.set(session)

      res_str = String.build do |res_io|
        headers = HTTP::Headers.new
        cookies = HTTP::Cookies.new
        cookies[::Crumble::Server::RequestContext::SESSION_COOKIE_NAME] = session.id.to_s
        cookies.add_request_headers(headers)

        ctx = ::Crumble::Server::TestRequestContext.new(resource: ModelTemplateRefreshResource.uri_path, method: "GET", response_io: res_io, headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(ctx)

        # Simulate HTTP::Server::RequestProcessor
        spawn do
          if upgrade_handler = ctx.response.upgrade_handler
            upgrade_handler.call(res_io)
          end
        end

        post_ctx = ::Crumble::Server::TestRequestContext.new(resource: ModelTemplateRefreshResource.uri_path, method: "POST", body: "[\"#{model.the_view.dom_id.attr_value}\"]", headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(post_ctx)

        3.times { Fiber.yield }
      end

      expected_html = <<-HTML.squish
      <turbo-stream action="replace" targets="[data-model-template-id='Crumble::Turbo::ModelTemplateRefreshResourceSpec::MyModel##{model.id.value}-the_view']">
        <template>
          <div data-model-template-id="Crumble::Turbo::ModelTemplateRefreshResourceSpec::MyModel##{model.id.value}-the_view" data-crumble--turbo--model-template-refresh-target="modelTemplate">
            <div>
              <span>Yoda</span>
              <span>#{ModelTemplateRefreshResource.uri_path}</span>
            </div>
          </div>
        </template>
      </turbo-stream>
      HTML

      res_str.should contain(expected_html)
    end

    it "should receive a model template refresh turbo stream" do
      model = MyModel.create(name: "Yoda")

      session_store = ::Crumble::Server::MemorySessionStore.new
      session = ::Crumble::Server::Session.new
      session_store.set(session)

      res_str = String.build do |res_io|
        headers = HTTP::Headers.new
        cookies = HTTP::Cookies.new
        cookies[::Crumble::Server::RequestContext::SESSION_COOKIE_NAME] = session.id.to_s
        cookies.add_request_headers(headers)

        ctx = ::Crumble::Server::TestRequestContext.new(resource: ModelTemplateRefreshResource.uri_path, method: "GET", response_io: res_io, headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(ctx)

        # Simulate HTTP::Server::RequestProcessor
        spawn do
          if upgrade_handler = ctx.response.upgrade_handler
            upgrade_handler.call(res_io)
          end
        end

        post_ctx = ::Crumble::Server::TestRequestContext.new(resource: ModelTemplateRefreshResource.uri_path, method: "POST", body: "[\"#{model.the_view.dom_id.attr_value}\"]", headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(post_ctx)

        model.the_view.refresh!

        Fiber.yield
      end

      expected_html = <<-HTML.squish
      <turbo-stream action="replace" targets="[data-model-template-id='Crumble::Turbo::ModelTemplateRefreshResourceSpec::MyModel##{model.id.value}-the_view']">
        <template>
          <div data-model-template-id="Crumble::Turbo::ModelTemplateRefreshResourceSpec::MyModel##{model.id.value}-the_view" data-crumble--turbo--model-template-refresh-target="modelTemplate">
            <div>
              <span>Yoda</span>
              <span>#{ModelTemplateRefreshResource.uri_path}</span>
            </div>
          </div>
        </template>
      </turbo-stream>
      HTML

      res_str.should contain(expected_html)
    end

    it "reloads the subscriber session before rendering model template refreshes" do
      model = SessionModel.create(name: "Yoda")

      session_store = ::Crumble::Server::MemorySessionStore.new
      session = ::Crumble::Server::Session.new
      session.update!(model_template_refresh_value: "initial")
      session_store.set(session)

      res_str = String.build do |res_io|
        headers = HTTP::Headers.new
        cookies = HTTP::Cookies.new
        cookies[::Crumble::Server::RequestContext::SESSION_COOKIE_NAME] = session.id.to_s
        cookies.add_request_headers(headers)

        ctx = ::Crumble::Server::TestRequestContext.new(resource: ModelTemplateRefreshResource.uri_path, method: "GET", response_io: res_io, headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(ctx)

        spawn do
          if upgrade_handler = ctx.response.upgrade_handler
            upgrade_handler.call(res_io)
          end
        end

        post_ctx = ::Crumble::Server::TestRequestContext.new(resource: ModelTemplateRefreshResource.uri_path, method: "POST", body: "[\"#{model.the_view.dom_id.attr_value}\"]", headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(post_ctx)

        updated_session = ::Crumble::Server::Session.new(session.id)
        updated_session.update!(model_template_refresh_value: "updated")
        session_store.set(updated_session)

        model.the_view.refresh!

        3.times { Fiber.yield }
      end

      expected_html = <<-HTML.squish
      <turbo-stream action="replace" targets="[data-model-template-id='Crumble::Turbo::ModelTemplateRefreshResourceSpec::SessionModel##{model.id.value}-the_view']">
        <template>
          <div data-model-template-id="Crumble::Turbo::ModelTemplateRefreshResourceSpec::SessionModel##{model.id.value}-the_view" data-crumble--turbo--model-template-refresh-target="modelTemplate">
            <div>
              <span>updated</span>
            </div>
          </div>
        </template>
      </turbo-stream>
      HTML

      res_str.should contain(expected_html)
    end

    it "encodes LF newlines as HTML entities in refresh transport payloads" do
      model = MultilineModel.create(transcript: "line 1\nline 2\nline 3")

      session_store = ::Crumble::Server::MemorySessionStore.new
      session = ::Crumble::Server::Session.new
      session_store.set(session)

      res_str = String.build do |res_io|
        headers = HTTP::Headers.new
        cookies = HTTP::Cookies.new
        cookies[::Crumble::Server::RequestContext::SESSION_COOKIE_NAME] = session.id.to_s
        cookies.add_request_headers(headers)

        ctx = ::Crumble::Server::TestRequestContext.new(resource: ModelTemplateRefreshResource.uri_path, method: "GET", response_io: res_io, headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(ctx)

        spawn do
          if upgrade_handler = ctx.response.upgrade_handler
            upgrade_handler.call(res_io)
          end
        end

        post_ctx = ::Crumble::Server::TestRequestContext.new(resource: ModelTemplateRefreshResource.uri_path, method: "POST", body: "[\"#{model.the_view.dom_id.attr_value}\"]", headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(post_ctx)

        3.times { Fiber.yield }
      end

      data_lines = res_str.lines.select(&.starts_with?("data: "))
      data_lines.should_not be_empty

      encoded_payload = data_lines.last["data: ".size..].rstrip
      encoded_payload.should contain("<pre>line 1&#10;line 2&#10;line 3</pre>")

      decoded_payload = encoded_payload.gsub("&#13;", "\r").gsub("&#10;", "\n")
      decoded_payload.should contain("<pre>line 1\nline 2\nline 3</pre>")
    end

    it "encodes CRLF newlines as HTML entities in refresh transport payloads" do
      model = MultilineModel.create(transcript: "line 1\r\nline 2\r\nline 3")

      session_store = ::Crumble::Server::MemorySessionStore.new
      session = ::Crumble::Server::Session.new
      session_store.set(session)

      res_str = String.build do |res_io|
        headers = HTTP::Headers.new
        cookies = HTTP::Cookies.new
        cookies[::Crumble::Server::RequestContext::SESSION_COOKIE_NAME] = session.id.to_s
        cookies.add_request_headers(headers)

        ctx = ::Crumble::Server::TestRequestContext.new(resource: ModelTemplateRefreshResource.uri_path, method: "GET", response_io: res_io, headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(ctx)

        spawn do
          if upgrade_handler = ctx.response.upgrade_handler
            upgrade_handler.call(res_io)
          end
        end

        post_ctx = ::Crumble::Server::TestRequestContext.new(resource: ModelTemplateRefreshResource.uri_path, method: "POST", body: "[\"#{model.the_view.dom_id.attr_value}\"]", headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(post_ctx)

        3.times { Fiber.yield }
      end

      data_lines = res_str.lines.select(&.starts_with?("data: "))
      data_lines.should_not be_empty

      encoded_payload = data_lines.last["data: ".size..].rstrip
      encoded_payload.should contain("<pre>line 1&#13;&#10;line 2&#13;&#10;line 3</pre>")

      decoded_payload = encoded_payload.gsub("&#13;", "\r").gsub("&#10;", "\n")
      decoded_payload.should contain("<pre>line 1\r\nline 2\r\nline 3</pre>")
    end

    it "creates linked root spans for model template transmissions" do
      model = MyModel.create(name: "Yoda")
      memory = IO::Memory.new
      original_config = OpenTelemetry.config
      original_provider = OpenTelemetry.provider

      begin
        OpenTelemetry.configure do |config|
          config.exporter = OpenTelemetry::Exporter.new(variant: :io, io: memory)
        end

        session_store = ::Crumble::Server::MemorySessionStore.new
        session = ::Crumble::Server::Session.new
        session_store.set(session)
        headers = HTTP::Headers.new
        cookies = HTTP::Cookies.new
        cookies[::Crumble::Server::RequestContext::SESSION_COOKIE_NAME] = session.id.to_s
        cookies.add_request_headers(headers)
        ctx = ::Crumble::Server::TestRequestContext.new(resource: ModelTemplateRefreshResource.uri_path, method: "GET", response_io: IO::Memory.new, headers: headers, session_store: session_store)

        OpenTelemetry.tracer.in_span("GET #{ModelTemplateRefreshResource.uri_path}") do |span|
          span.server!
          ModelTemplateRefreshResource.handle(ctx)
        end

        spawn do
          if upgrade_handler = ctx.response.upgrade_handler
            upgrade_handler.call(IO::Memory.new)
          end
        end

        post_ctx = ::Crumble::Server::TestRequestContext.new(resource: ModelTemplateRefreshResource.uri_path, method: "POST", body: "[\"#{model.the_view.dom_id.attr_value}\"]", headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(post_ctx)
        3.times { Fiber.yield }

        spans = exported_traces(memory).flat_map { |trace| trace["spans"].as_a }
        connection_span = spans.find { |span| span["name"].as_s == "GET #{ModelTemplateRefreshResource.uri_path}" }.not_nil!
        template_span = spans.find { |span| span["name"].as_s == "SSE model template transmission" }.not_nil!

        template_span["traceId"].as_s.should eq(connection_span["traceId"].as_s)
        template_span["parentSpanId"].raw.should be_nil
        template_span["attributes"]["crumble.turbo.model_template.id"].as_s.should eq(model.the_view.dom_id.attr_value)
        template_span["links"].as_a.size.should eq(1)
        template_span["links"][0]["traceId"].as_s.should eq(connection_span["traceId"].as_s)
        template_span["links"][0]["spanId"].as_s.should eq(connection_span["spanId"].as_s)
      ensure
        OpenTelemetry.config = original_config
        OpenTelemetry.provider = original_provider
        Fiber.current.current_trace = nil
        Fiber.current.current_span = nil
      end
    end
  end
end
