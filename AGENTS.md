# AGENTS

## Shard: js.cr
- `JS::Class` generates JavaScript classes; `js_method` defines methods and auto-collects them for `to_js` output. `to_js_ref` returns the class name string for embedding in generated JS.
- `JS::Code.def_to_js` emits JS from Crystal blocks; use `_call` to force function invocation vs property access. `_literal_js` can inject raw JS when needed.
- `JS::Method.def_to_js` sets the JS function name; `JS::Code` predeclares vars in nested scopes when needed. `js_alias` maps Crystal identifiers to JS globals (e.g., `$`).

## Shard: stimulus
- `Stimulus::Controller` extends `JS::Class`; `values`, `targets`, and `outlets` macros build data attributes (`data-*-value`, `data-*-target`) and static metadata. `action` macro creates `data-action="event->controller#method"` entries and emits the JS method via `js_method`.
- `controller_name` is derived from the class name: camel parts → kebab, strip `Controller`, then joined by `--`; `data-controller` uses this value.
- JS methods call into Stimulus API via generated class; `_call` is used to invoke zero-arg JS functions (e.g., `event.preventDefault._call`).

## Shard: css
- DSL lives in `CSS::Stylesheet`; `prop`/`prop2`/… macros enforce units (non-zero numbers must use unit helpers like `2.px`, `0.5.rem`). Enum-like values are symbols (e.g., `display :inline_block`). Colors can be strings or built via `rgb(r, g, b, alpha: 0.15)`.
- `translate_x`, `translate_y`, and other transforms are provided; `box_shadow` is overloaded for multiple arities.
- `css_class` macro defines a `CSS::Class`; `CSS::Class#to_s` converts CamelCase to kebab, and `ext/css/class.cr` adds `to_js_ref` so class constants can be passed directly to JS `classList`.

## Project: Orma / Crumble Turbo scaffolds
- `ToHtml.instance_template` and `stimulus_controller` macros compose HTML with attached Stimulus controllers. The accessible share element uses `ShareController` with actions that prefer `navigator.share`, fall back to `navigator.clipboard.writeText`, then alert otherwise.
- Tooltip implementation: CSS classes (`ShareContainer`, `ShareTooltip`, `ShareTooltipVisible`) are declared inside `Accessible::ShareElement`; JS toggles the fully qualified constant `::Orma::Record::Accessible::ShareElement::ShareTooltipVisible` on the tooltip element. Positioning is purely CSS (`position :absolute`, `top 100.percent`, `left 50.percent`, `translate_x(-50.percent)`), keeping layout untouched.
- Compiler note: Crystal automatically maps symbol literals to enum values, converting CamelCase enums to underscored symbols (e.g., `display :inline_block`).

## Limitations / gotchas
- `pointer_events` property support is limited in the current CSS DSL context, so it was avoided.
- Keep JS minimal by preferring CSS-driven UI states (e.g., pseudo-element or class toggles) and relying on generated class names via `to_js_ref`.
