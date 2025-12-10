# Claude Hooks Config file

This is a config file for the claude_hooks ruby gem (library). This file can only be flat, nesting isn't supported.

## Configuration

### contextPreLoad

The files to preload into claude on session start

### preLoadBegin

The message to display before loading context files

### preLoadSeparator

The separator to use between context files

### preLoadEnd

The message to display after loading context files

### treeFolders

The folders to include in the tree output. 
Use `""` to parse all folders.

### treeExcludePatterns

The file patterns to exclude from the tree output. 
Use `""` to parse all files.

### treeOutputPath

The path to save the tree output to.
