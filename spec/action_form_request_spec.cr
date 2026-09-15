require "./spec_helper"

module Crumble::Turbo::ActionFormRequestSpec
  class PayloadAction < Crumble::Turbo::Action
    form do
      field name : String, allow_blank: false
    end

    controller do
      # no-op
    end

    view do
      template do
        action_form.to_html do
          button { "Submit" }
        end
      end
    end
  end

  class UploadAction < Crumble::Turbo::Action
    form do
      field name : String, allow_blank: false
      field attachment : Crumble::UploadedFile?, type: :file
    end

    controller do
      # no-op
    end

    view do
      template do
        action_form.to_html { "Upload" }
      end
    end
  end

  describe "Action#form" do
    it "uses the request payload and memoizes when the action is the handler" do
      body = URI::Params.encode({name: "Alice"})
      request_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: PayloadAction.uri_path, headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}, body: body)
      action = PayloadAction.new(request_ctx)

      form = action.form
      form.name.should eq("Alice")
      form.valid?.should be_true
      action.form.should be(form)
      action.action_form.form.should be(form)
    end

    it "does not parse the payload when the action is built from another handler context" do
      body = URI::Params.encode({name: "Alice"})
      request_ctx = Crumble::Server::TestRequestContext.new(method: "GET", resource: "/", body: body)
      handler = TestViewHandler.new(request_ctx)
      ctx = Crumble::Server::HandlerContext.new(request_ctx, handler)

      action = PayloadAction.new(ctx)
      action.form.name.should be_nil
    end

    it "builds from an empty payload when the action is the handler" do
      request_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: PayloadAction.uri_path, headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"})
      action = PayloadAction.new(request_ctx)

      form = action.form
      form.name.should be_nil
      form.valid?.should be_false
      form.errors.should eq(["name"])
    end

    it "resets the form after a valid submit before refreshing the template" do
      response = String.build do |io|
        body = URI::Params.encode({name: "Alice"})
        ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: PayloadAction.uri_path, headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}, body: body, response_io: io)
        action = PayloadAction.new(ctx)
        action.handle
        action.form.name.should be_nil
        action.form.submitted?.should be_false
        action.form.errors.should be_nil
        ctx.response.flush
      end

      response.should contain(%(name="name" value=""))
      response.should_not contain(%(value="Alice"))
      response.should_not contain("crumble--field-errors")
    end

    it "preserves submitted values and errors after an invalid submit" do
      response = String.build do |io|
        body = URI::Params.encode({name: ""})
        ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: PayloadAction.uri_path, headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}, body: body, response_io: io)
        action = PayloadAction.new(ctx)
        action.handle
        action.form.name.should eq("")
        action.form.errors.should eq(["name"])
        ctx.response.flush
      end

      response.should contain("crumble--field-errors")
    end

    it "parses multipart text and file fields and reuses the submitted form" do
      boundary = "turbo-action-boundary"
      body = multipart_body(boundary, [{"name", nil, nil, "Alice"}, {"attachment", "note.txt", "text/plain", "hello"}])
      request_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: UploadAction.uri_path, headers: HTTP::Headers{"Content-Type" => "multipart/form-data; boundary=#{boundary}"}, body: body)
      action = UploadAction.new(request_ctx)

      form = action.form
      form.name.should eq("Alice")
      upload = form.attachment.not_nil!
      upload.filename.should eq("note.txt")
      upload.open(&.gets_to_end).should eq("hello")
      action.form.should be(form)
      request_ctx.cleanup_temporary_files
    end
  end

  describe "ActionForm" do
    it "renders multipart encoding for a form with a file field" do
      request_ctx = Crumble::Server::TestRequestContext.new
      action = UploadAction.new(Crumble::Server::HandlerContext.new(request_ctx, TestViewHandler.new(request_ctx)))
      action.action_form.to_html { |io, _| io << "Contents" }.should contain(%(enctype="multipart/form-data"))
    end

    it "omits encoding for an ordinary form" do
      request_ctx = Crumble::Server::TestRequestContext.new
      action = PayloadAction.new(Crumble::Server::HandlerContext.new(request_ctx, TestViewHandler.new(request_ctx)))
      html = action.action_form.to_html { |io, _| io << "Contents" }

      html.should_not contain("enctype=")
      html.should contain(%(action="#{PayloadAction.uri_path}" method="POST"))
      html.should contain("Contents")
      html.should contain(%(name="name"))
    end
  end
end
