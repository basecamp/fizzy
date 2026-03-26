# Fizzy CLI

This directory contains the standalone `fizzy` CLI tool.

## Install (one command)

From the repo root:

```bash
./bin/install-fizzy-cli
```

That script will:
1. install CLI dependencies,
2. build the `fizzy-cli` gem,
3. install it for the current user.
4. install a launcher at `~/.local/bin/fizzy`.
5. add `~/.local/bin` to your shell startup file when present (`.bashrc` or `.zshrc`), so you can use `fizzy` directly next shell session.

## Development usage (no install)

If you are testing against a local checkout, you can run the CLI without installing:

```bash
cd cli
bundle exec exe/fizzy --version
```

You can also use the repo wrapper directly:

```bash
cd /path/to/fizzy
./bin/fizzy --version
```
