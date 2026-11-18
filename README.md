# MDLook

Minimal Quick Look preview for Markdown on macOS. Select a `.md` file in Finder and press Space.

- GitHub-flavoured Markdown: tables, task lists, fenced code, strikethrough
- Follows system light/dark mode
- YAML front matter is hidden
- No web view, no network, no footer

## Install

Requires macOS 13+ and Command Line Tools (`xcode-select --install`).

```bash
git clone <this repo>
cd MDLook
./install.sh
```

If the preview doesn't show up, enable **MDLook Preview** in System Settings → General → Login Items & Extensions → Quick Look. Remove any other Markdown Quick Look extension first so they don't conflict.

## Uninstall

```bash
rm -rf /Applications/MDLook.app && qlmanage -r
```

## Customise

The look lives in `Preview/style.css`. Rerun `./install.sh` after editing it.

Markdown is parsed with [marked](https://github.com/markedjs/marked) (MIT, see `Preview/marked-LICENSE.txt`).
