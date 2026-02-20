require "../../spec_helper"

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

  class MultilineModel < TestRecord
    id_column id : Int64
    column transcript : String

    model_template :the_view do
      pre { transcript }
    end
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
  end
end
