# How to contribute to Fizzy

Fizzy uses GitHub
[discussions](https://github.com/basecamp/fizzy/discussions) to track
feature requests and questions, rather than [the issue
tracker](https://github.com/basecamp/fizzy/issues). If you're considering
opening an issue or pull request, please open a discussion instead.

Whenever a discussion leads to an actionable and well-understood task, we'll
move it to the issue tracker where it can be worked on.

This is a little different than how some other projects work, but it makes it
easier for us to triage and prioritise the work. It also means that the open
issues all represent agreed-upon tasks that are either being worked on, or are
ready to be worked on.

This should also make it easier to see what's in progress, and to find
something to work on if you'd like to do so.

## What this means in practice

### If you'd like to contribute to the code...

1. If you're interested in working on one of the open issues, please do! We are
   grateful for the help!
2. You'll want to make sure someone else isn't already working on the same
   issue. If they are, it will be tagged "in progress" and/or it should be clear
   from the comments. When in doubt, you can always comment on the issue to ask.
3. Similarly, if you need any help or guidance on the issue, please comment on
   the issue as you go, and we'll do our best to help.
4. When you have something ready for review or collaboration, open a PR.

### If you've found a bug...

1. If you don't have steps to reproduce the problem, or you're not certain it's a
   bug, open a discussion.
2. If you have steps to reproduce, open an issue.

### If you have an idea for a feature...

1. Open a discussion.

### If you have a question, or are having trouble with configuration...

1. Open a discussion.

Hopefully this process makes it easier for everyone to be involved. Thanks for
helping! ❤️

## Internationalization (i18n)

User-facing strings should use Rails I18n so the app can be localized.

- **Where to add keys**: Put translations under `config/locales/en/` in YAML files
  by feature (e.g. `boards.yml`, `cards.yml`, `shared.yml`, `users.yml`).
- **Naming**: Use namespaced keys that match the view path, e.g. `cards.container.edit`,
  `boards.new.page_title`, `shared.save_changes`.
- **In views**: Use the `t()` helper, e.g. `<%= t("cards.container.edit") %>`.
- **Interpolation**: For dynamic values use `t("key", name: value)` in Ruby and
  `%{name}` in the YAML value.
- **HTML**: For strings that contain HTML, use a key ending in `_html` and mark
  the value as html_safe only when the translation is trusted (e.g. in shared
  welcome letter content).
- **New strings**: When adding UI copy, add the key to the appropriate locale
  file and use `t("...")` instead of hardcoding English.

