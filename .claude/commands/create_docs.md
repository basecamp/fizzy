---
name: Create Docs
description: Place a comment place holder on all newly created files.
---

Using `git status` find all newly created files. Place a comment with the following format on relevant code files and methods:

```rb
# DOC:
```

```erb
<%# DOC: %>
```

```js
// DOC:
```

Skip files that would not normally be documented (like migrations, test files, configuration files, etc)
