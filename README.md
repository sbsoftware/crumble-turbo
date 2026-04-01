# crumble-turbo

`crumble-turbo` adds Turbo-friendly action helpers for Crumble and Orma applications. It gives you:

- static actions that answer `POST` requests with Turbo streams
- model templates that render identifiable record fragments
- model actions that update a record and refresh one or more model templates

## Installation

Add the shard and install dependencies:

```yaml
dependencies:
  crumble-turbo:
    github: sbsoftware/crumble-turbo
```

```bash
shards install
```

Require the shard from your app:

```crystal
require "crumble-turbo"
```

The shard appends the Turbo script tag, action form styles, and the model template refresh controller to Crumble's default layout.

## Static Actions

Use `Crumble::Turbo::Action` when a page needs to submit a `POST` request that answers with a Turbo stream. An action owns both the server-side controller logic and the template used to render the trigger.

```crystal
class PublishReport < Crumble::Turbo::Action
  controller do
    ReportPublishedBanner.new.turbo_stream.to_html(ctx.response)
  end

  view do
    template do
      action_form.to_html do
        button { "Publish" }
      end
    end
  end
end
```

Render the trigger with `PublishReport.new(ctx).action_template`. Use `action_form` for a plain form submit or `custom_action_trigger` when you want a clickable wrapper around a hidden submit input.

## Model Templates

Use `model_template` on an `Orma::Record` when you want a record-bound fragment with a stable DOM identity. The rendered wrapper gets a `data-model-template-id`, so the same template can be replaced later through Turbo streams.

```crystal
class Invoice < Orma::Record
  id_column id : Int64
  column total_cents : Int32

  model_template :summary do
    strong { total_cents }
  end
end
```

Render a template with `invoice.summary.renderer(ctx)`. You can embed it directly in a page layout with `to_html`. Calling `invoice.summary.refresh!` pushes the refreshed template to subscribed sessions through the built-in model template refresh resource.

## Model Actions

Use `model_action` when an action should load a record from the request path, run controller logic against that record, and refresh one or more model templates after a successful `POST`.

```crystal
class Invoice < Orma::Record
  id_column id : Int64
  column total_cents : Int32 = 0

  model_template :summary do
    strong { total_cents }
  end

  model_action :increment_total, summary do
    controller do
      model.update(total_cents: model.total_cents.value + 100)
    end

    view do
      template do
        custom_action_trigger.to_html do
          button { "Add fee" }
        end
      end
    end
  end
end
```

Render the trigger with `invoice.increment_total_action_template(ctx)`. The action loads `model` for you, and `summary` is rendered back to the requester and refreshed for other subscribed sessions after the controller runs. Pass `nil` as the refresh target to skip template refreshes, or pass an array/tuple to refresh multiple templates.

## Development

```bash
shards install
crystal tool format --check src spec
crystal spec
```

## Contributors

- [Stefan Bilharz](https://github.com/sbsoftware)
