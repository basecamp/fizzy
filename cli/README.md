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

If `fizzy` is not found after install, add the Ruby user gem bin directory to your `PATH`.

```bash
export PATH="$PATH:$(ruby -e 'require "rubygems"; print Gem.user_dir + "/bin"')"
```

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
