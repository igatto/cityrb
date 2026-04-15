# Plan: Install PixiJS

## Context

- Rails 8.1.3 app using **Propshaft** + **importmap-rails** (no Webpack/Vite bundler)
- PixiJS v8 is used — it requires `unsafe-eval` for WebGL/WebGPU shader compilation (known, accepted trade-off for game/graphics apps)
- CSP initializer exists at `config/initializers/content_security_policy.rb` but is fully commented out

---

## Steps

### 1. Pin PixiJS via importmap

importmap-rails fetches from jspm.io by default. Run:

```sh
bin/importmap pin pixi.js
```

This appends a versioned pin to `config/importmap.rb`, e.g.:

```ruby
pin "pixi.js", to: "https://ga.jspm.io/npm:pixi.js@8.x.x/dist/pixi.min.js"
```

> **Alternative (manual CDN pin):** If the auto-pin resolution fails or pulls an incompatible build, pin the ESM bundle from esm.sh directly:
> ```ruby
> pin "pixi.js", to: "https://esm.sh/pixi.js@8"
> ```

---

### 2. Enable and configure the Content Security Policy

Uncomment and expand `config/initializers/content_security_policy.rb`:

```ruby
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    policy.style_src   :self, :https, :unsafe_inline

    # 'unsafe-eval' is required by PixiJS for WebGL/WebGPU shader compilation.
    # This is a documented and accepted trade-off for game/graphics applications.
    # See: https://pixijs.com/llms.txt
    policy.script_src  :self, :https, :unsafe_eval

    # Allow PixiJS to create blob: URLs for worker scripts
    policy.worker_src  :self, :blob

    # Allow WebGL/WebGPU canvas data extraction
    policy.connect_src :self, :https, :blob
  end

  # Nonce for importmap inline script tag
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src)
end
```

> **Note on `unsafe-eval`:** PixiJS compiles GLSL shaders at runtime via `new Function()` and `eval`-equivalent WebGL APIs. There is no way to avoid this without pre-compiling shaders outside the browser, which PixiJS v8 does not support. This is a well-known and widely-accepted CSP trade-off in game/graphics frameworks (Three.js, Babylon.js, and PixiJS all share this requirement).

---

### 3. Create a PixiJS application module

Create `app/javascript/pixi_app.js`:

```js
import { Application, Sprite, Assets } from "pixi.js"

export async function initPixiApp(containerId) {
  const app = new Application()

  await app.init({
    background: "#1099bb",
    resizeTo: document.getElementById(containerId),
  })

  document.getElementById(containerId).appendChild(app.canvas)

  return app
}
```

---

### 4. Wire into a Stimulus controller (recommended)

Create `app/javascript/controllers/pixi_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"
import { initPixiApp } from "pixi_app"

export default class extends Controller {
  async connect() {
    this.app = await initPixiApp(this.element.id)
  }

  disconnect() {
    this.app?.destroy(true)
    this.app = null
  }
}
```

Reference it in a view:

```html
<div id="pixi-canvas"
     data-controller="pixi"
     style="width: 800px; height: 600px;">
</div>
```

---

### 5. Update `config/importmap.rb` (verify after pin)

After running `bin/importmap pin pixi.js`, confirm the pin is present:

```ruby
pin "pixi.js", to: "..."          # added by bin/importmap
pin_all_from "app/javascript/controllers", under: "controllers"
```

Also pin the new module if not auto-discovered:

```ruby
pin "pixi_app", to: "pixi_app.js"
```

---

### 6. Restart the server

```sh
bin/rails server
```

CSP changes and importmap pins require a full server restart (no hot reload for initializers).

---

## Verification checklist

- [ ] `config/importmap.rb` contains a `pixi.js` pin
- [ ] Browser DevTools → Network shows `pixi.js` loaded with HTTP 200
- [ ] No CSP violations in browser console
- [ ] PixiJS canvas renders on the target page
- [ ] `disconnect()` on the Stimulus controller destroys the app without memory leaks

---

## Known gotchas

| Issue | Cause | Fix |
|-------|-------|-----|
| `EvalError` / CSP blocked | `unsafe-eval` missing from `script-src` | Add `:unsafe_eval` to `policy.script_src` |
| Blank canvas / no renderer | Top-level `await` in importmap context | Wrap in `async connect()` (already done above) |
| `blob:` worker errors | Worker CSP not set | Add `policy.worker_src :self, :blob` |
| importmap pin 404 | jspm.io resolved wrong build | Switch to `esm.sh/pixi.js@8` pin manually |
| Canvas removed on Turbo navigation | Turbo replaces DOM, Stimulus `disconnect` not called cleanly | Ensure `disconnect()` calls `app.destroy(true)` |
