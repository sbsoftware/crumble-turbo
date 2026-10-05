require "../../spec_helper"
require "json"
require "log/spec"

module Crumble::Turbo::ModelTemplateRefreshService
  def self.registered_model_template_count : Int32
    @@subscriptions_by_model_template.size
  end
end

module Crumble::Turbo::ModelTemplateRefreshResourceSpec
  SUBSCRIPTION_ID = "spec-subscription"

  def self.subscription_resource(subscription_id = SUBSCRIPTION_ID)
    "#{ModelTemplateRefreshResource.uri_path}?subscription_id=#{subscription_id}"
  end

  def self.session_headers(session : ::Crumble::Server::Session) : HTTP::Headers
    headers = HTTP::Headers.new
    cookies = HTTP::Cookies.new
    cookies[::Crumble::Server::RequestContext::SESSION_COOKIE_NAME] = session.id.to_s
    cookies.add_request_headers(headers)
    headers
  end

  def self.handler_context(headers : HTTP::Headers, session_store : ::Crumble::Server::SessionStore)
    request_ctx = ::Crumble::Server::TestRequestContext.new(headers: headers, session_store: session_store)
    ::Crumble::Server::HandlerContext.new(request_ctx, TestViewHandler.new(request_ctx))
  end

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
    it "keeps multiple connections for the same session subscribed" do
      model = MyModel.create(name: "Yoda")
      session_store = ::Crumble::Server::MemorySessionStore.new
      session = ::Crumble::Server::Session.new
      session_store.set(session)
      headers = session_headers(session)
      first_ctx = handler_context(headers, session_store)
      second_ctx = handler_context(headers, session_store)
      first_channel = ModelTemplateRefreshService.subscribe(first_ctx, "first-tab")
      second_channel = ModelTemplateRefreshService.subscribe(second_ctx, "second-tab")

      begin
        ModelTemplateRefreshService.register(first_ctx, "first-tab", [model.the_view.dom_id.attr_value])
        ModelTemplateRefreshService.register(second_ctx, "second-tab", [model.the_view.dom_id.attr_value])
        3.times { Fiber.yield }
        first_channel.receive
        second_channel.receive

        previous_log_level = ModelTemplateRefreshService::LOGGER.level
        begin
          Log.capture(ModelTemplateRefreshService::LOGGER.source) do |logs|
            ModelTemplateRefreshService::LOGGER.level = Log::Severity::Info
            ModelTemplateRefreshService.log_subscriptions
            logs.empty

            ModelTemplateRefreshService::LOGGER.level = Log::Severity::Debug
            ModelTemplateRefreshService.log_subscriptions
            logs.check("a subscription log with session diagnostics") do |entry|
              entry.severity.debug? && entry.message == "Active model template refresh subscription" && entry.data[:session_id].as_s == session.id.to_s && entry.data[:subscription_id].as_s.in?({"first-tab", "second-tab"}) && entry.data[:connection_uptime_seconds].as_f64 >= 0 && entry.data[:model_template_ids].as_a.any?(&.as_s.==(model.the_view.dom_id.attr_value))
            end
          end
        ensure
          ModelTemplateRefreshService::LOGGER.level = previous_log_level
        end

        model.the_view.refresh!
        3.times { Fiber.yield }

        first_channel.receive.should_not be_nil
        second_channel.receive.should_not be_nil

        ModelTemplateRefreshService.unsubscribe(first_ctx, first_channel)
        first_channel.close
        model.the_view.refresh!
        3.times { Fiber.yield }

        second_channel.receive.should_not be_nil
      ensure
        ModelTemplateRefreshService.unsubscribe(second_ctx)
      end
    end

    it "keeps template registrations isolated per tab and discards empty index entries" do
      first_model = MyModel.create(name: "Yoda")
      second_model = MyModel.create(name: "Leia")
      first_model_template_id = first_model.the_view.dom_id.attr_value
      second_model_template_id = second_model.the_view.dom_id.attr_value
      initial_template_count = ModelTemplateRefreshService.registered_model_template_count
      session_store = ::Crumble::Server::MemorySessionStore.new
      session = ::Crumble::Server::Session.new
      session_store.set(session)
      headers = session_headers(session)
      first_ctx = handler_context(headers, session_store)
      second_ctx = handler_context(headers, session_store)
      first_channel = ModelTemplateRefreshService.subscribe(first_ctx, "first-distinct-tab")
      second_channel = ModelTemplateRefreshService.subscribe(second_ctx, "second-distinct-tab")

      begin
        ModelTemplateRefreshService.register(first_ctx, "first-distinct-tab", [first_model_template_id])
        ModelTemplateRefreshService.register(second_ctx, "second-distinct-tab", [second_model_template_id])
        3.times { Fiber.yield }
        first_channel.receive
        second_channel.receive
        ModelTemplateRefreshService.registered_model_template_count.should eq(initial_template_count + 2)

        first_model.the_view.refresh!
        3.times { Fiber.yield }
        first_channel.receive.should_not be_nil

        second_refresh = nil
        select
        when second_refresh = second_channel.receive
        when timeout(10.milliseconds)
        end
        second_refresh.should be_nil

        # Registration payloads are complete snapshots, so an empty payload must
        # remove the connection and the now-unused template key from the index.
        ModelTemplateRefreshService.register(first_ctx, "first-distinct-tab", [] of String)
        ModelTemplateRefreshService.registered_model_template_count.should eq(initial_template_count + 1)

        first_model.the_view.refresh!
        3.times { Fiber.yield }
        first_refresh = nil
        select
        when first_refresh = first_channel.receive
        when timeout(10.milliseconds)
        end
        first_refresh.should be_nil

        second_model.the_view.refresh!
        3.times { Fiber.yield }
        second_channel.receive.should_not be_nil
      ensure
        ModelTemplateRefreshService.unsubscribe(first_ctx, first_channel)
        first_channel.close
        ModelTemplateRefreshService.unsubscribe(second_ctx, second_channel)
        second_channel.close
      end

      ModelTemplateRefreshService.registered_model_template_count.should eq(initial_template_count)
    end

    it "replaces a reconnecting tab that reuses its subscription token" do
      model = MyModel.create(name: "Yoda")
      model_template_id = model.the_view.dom_id.attr_value
      request_ctx = ::Crumble::Server::TestRequestContext.new
      ctx = ::Crumble::Server::HandlerContext.new(request_ctx, TestViewHandler.new(request_ctx))
      old_channel = ModelTemplateRefreshService.subscribe(ctx, "reconnecting-tab")
      ModelTemplateRefreshService.register(ctx, "reconnecting-tab", [model_template_id])

      new_channel = ModelTemplateRefreshService.subscribe(ctx, "reconnecting-tab")
      begin
        ModelTemplateRefreshService.register(ctx, "reconnecting-tab", [model_template_id])
        3.times { Fiber.yield }
        new_channel.receive

        model.the_view.refresh!
        3.times { Fiber.yield }

        old_channel.closed?.should be_true
        new_channel.receive.should_not be_nil
      ensure
        ModelTemplateRefreshService.unsubscribe(ctx, new_channel)
        new_channel.close
      end
    end

    it "rejects registration without a matching connection token" do
      missing_token_ctx = ::Crumble::Server::TestRequestContext.new(resource: ModelTemplateRefreshResource.uri_path, method: "GET")
      ModelTemplateRefreshResource.handle(missing_token_ctx)
      missing_token_ctx.response.status_code.should eq(400)

      unknown_token_ctx = ::Crumble::Server::TestRequestContext.new(resource: subscription_resource("unknown"), method: "POST", body: "[]")
      ModelTemplateRefreshResource.handle(unknown_token_ctx)
      unknown_token_ctx.response.status_code.should eq(400)

      session_store = ::Crumble::Server::MemorySessionStore.new
      owner_session = ::Crumble::Server::Session.new
      attacker_session = ::Crumble::Server::Session.new
      session_store.set(owner_session)
      session_store.set(attacker_session)
      owner_ctx = handler_context(session_headers(owner_session), session_store)
      owner_channel = ModelTemplateRefreshService.subscribe(owner_ctx, "owner-token")

      begin
        attacker_headers = session_headers(attacker_session)
        attacker_ctx = ::Crumble::Server::TestRequestContext.new(resource: subscription_resource("owner-token"), method: "POST", body: "[]", headers: attacker_headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(attacker_ctx)
        attacker_ctx.response.status_code.should eq(400)
      ensure
        ModelTemplateRefreshService.unsubscribe(owner_ctx, owner_channel)
        owner_channel.close
      end
    end

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

        ctx = ::Crumble::Server::TestRequestContext.new(resource: subscription_resource, method: "GET", response_io: res_io, headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(ctx)

        # Simulate HTTP::Server::RequestProcessor
        spawn do
          if upgrade_handler = ctx.response.upgrade_handler
            upgrade_handler.call(res_io)
          end
        end

        post_ctx = ::Crumble::Server::TestRequestContext.new(resource: subscription_resource, method: "POST", body: "[\"#{model.the_view.dom_id.attr_value}\"]", headers: headers, session_store: session_store)
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

        ctx = ::Crumble::Server::TestRequestContext.new(resource: subscription_resource, method: "GET", response_io: res_io, headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(ctx)

        # Simulate HTTP::Server::RequestProcessor
        spawn do
          if upgrade_handler = ctx.response.upgrade_handler
            upgrade_handler.call(res_io)
          end
        end

        post_ctx = ::Crumble::Server::TestRequestContext.new(resource: subscription_resource, method: "POST", body: "[\"#{model.the_view.dom_id.attr_value}\"]", headers: headers, session_store: session_store)
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

        ctx = ::Crumble::Server::TestRequestContext.new(resource: subscription_resource, method: "GET", response_io: res_io, headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(ctx)

        spawn do
          if upgrade_handler = ctx.response.upgrade_handler
            upgrade_handler.call(res_io)
          end
        end

        post_ctx = ::Crumble::Server::TestRequestContext.new(resource: subscription_resource, method: "POST", body: "[\"#{model.the_view.dom_id.attr_value}\"]", headers: headers, session_store: session_store)
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

        ctx = ::Crumble::Server::TestRequestContext.new(resource: subscription_resource, method: "GET", response_io: res_io, headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(ctx)

        spawn do
          if upgrade_handler = ctx.response.upgrade_handler
            upgrade_handler.call(res_io)
          end
        end

        post_ctx = ::Crumble::Server::TestRequestContext.new(resource: subscription_resource, method: "POST", body: "[\"#{model.the_view.dom_id.attr_value}\"]", headers: headers, session_store: session_store)
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

        ctx = ::Crumble::Server::TestRequestContext.new(resource: subscription_resource, method: "GET", response_io: res_io, headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(ctx)

        spawn do
          if upgrade_handler = ctx.response.upgrade_handler
            upgrade_handler.call(res_io)
          end
        end

        post_ctx = ::Crumble::Server::TestRequestContext.new(resource: subscription_resource, method: "POST", body: "[\"#{model.the_view.dom_id.attr_value}\"]", headers: headers, session_store: session_store)
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
        ctx = ::Crumble::Server::TestRequestContext.new(resource: subscription_resource, method: "GET", response_io: IO::Memory.new, headers: headers, session_store: session_store)

        OpenTelemetry.tracer.in_span("GET #{ModelTemplateRefreshResource.uri_path}") do |span|
          span.server!
          ModelTemplateRefreshResource.handle(ctx)
        end

        spawn do
          if upgrade_handler = ctx.response.upgrade_handler
            upgrade_handler.call(IO::Memory.new)
          end
        end

        post_ctx = ::Crumble::Server::TestRequestContext.new(resource: subscription_resource, method: "POST", body: "[\"#{model.the_view.dom_id.attr_value}\"]", headers: headers, session_store: session_store)
        ModelTemplateRefreshResource.handle(post_ctx)
        3.times { Fiber.yield }

        spans = exported_traces(memory).flat_map { |trace| trace["spans"].as_a }
        connection_span = spans.find { |span| span["name"].as_s == "GET #{ModelTemplateRefreshResource.uri_path}" }.not_nil!
        template_span = spans.find { |span| span["name"].as_s == "SSE model template transmission" }.not_nil!

        template_span["traceId"].as_s.should_not eq(connection_span["traceId"].as_s)
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
