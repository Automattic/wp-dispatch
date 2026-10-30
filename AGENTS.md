# Notes for agents working on Dispatch

Read [README.md](README.md) first, then the doc for your task:

| Task | Doc |
|---|---|
| Building, running, checking a change | [docs/development.md](docs/development.md) |
| Finding where something lives | [docs/architecture.md](docs/architecture.md) |
| Sign-in or OAuth | [docs/auth.md](docs/auth.md) |
| Shipping an update or changing the website | [docs/releasing.md](docs/releasing.md) |

## Rules

- **Build with `./build.sh --install`**, not bare `swift build`, when you need the real app. It embeds and signs Sparkle.
- **Restart the app by exact PID.** Get it with `pgrep -fl "Dispatch.app/Contents/MacOS/Dispatch"`. Never `pkill -f` a name pattern.
- **Check UI changes yourself** with `DISPATCH_SCENE=reader|post|comments` and `screencapture -l<windowID>`. The status item can't be clicked by automation.
- **Never print, log or commit secrets.** That covers the WordPress.com token in `credentials.json`, the Sparkle private key, and Spacefast keys. `site/.spacefast/state.json` is gitignored. Only `space.json` is committed.
- **Releasing publishes to real users.** `./release.sh` pushes an update to every installed copy within a day. Only run it when you've been asked to ship. Use `--no-publish` for a dry run.
- **The website is public.** The demo (`site/sim.js`) uses made-up people, blogs and P2s. Keep it that way. Never put real notifications, P2 content or anything internal to Automattic on the site.
- **When the app changes, update the demo.** If you add, remove or rename a visible feature, change `site/sim.js` and its row in `site/index.html` to match.
- **Keep the module name `DispatchApp`.** Renaming it to `Dispatch` collides with Apple's GCD module.
- **Don't add a custom URL scheme for sign-in.** WordPress.com only allows its own schemes. The reason is in [docs/auth.md](docs/auth.md).
- **Match the existing code.** Comment density, naming, and plain AppKit/SwiftUI without extra dependencies. When you change how something works, update the doc for it in the same commit.
