# crumble-material

TODO: Write a description here

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     crumble-material:
       github: your-github-user/crumble-material
   ```

2. Run `shards install`

## Usage

```crystal
require "crumble-material"
```

### Model-aware action forms

`model_action` and `create_child_action` now use `Crumble::ModelForm` for `form do ... end` blocks.
This allows model-dependent field helpers (for example dynamic select options) without storing
manual `@submitted_form` ivars on the action.

```crystal
create_child_action :create_reimbursement, Reimbursement, group_id, default_view do
  form do
    field amount : Float64, attrs: {required: true, step: ".01"}
    field recipient_membership_id : Int64, type: :select, options: recipient_options

    def recipient_options
      options = [{"", t.form.recipient_membership_id_prompt}] of Tuple(String, String)
      model.group_memberships.each do |membership|
        next if membership.user_id == ctx.session.user_id
        options << {membership.id.value.to_s, membership.display_name}
      end
      options
    end
  end
end
```

Migration note: existing model actions can remove manual submitted-form storage and custom option
setter workarounds; submitted values and validation errors are preserved by the built-in form lifecycle.

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/your-github-user/crumble-material/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Stefan Bilharz](https://github.com/your-github-user) - creator and maintainer
