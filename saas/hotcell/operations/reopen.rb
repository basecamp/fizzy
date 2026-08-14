# frozen_string_literal: true

# Copied from the hotcell repository's examples/operations/reopen.rb, and it stays permanently. The same
# round trip as echo, reading the input through its path rather than through the descriptor.
#
# `/dev/fd/N` is a fresh open, rechecked against the opening process's uid and the file's mode, so this
# succeeds only where the cell can open a file the app owns. Echo consumes the descriptor directly and
# never establishes that, which is why both exist: a cell missing the shared group answers echo perfectly
# and fails this with EACCES, and every operation that hands a tool a filename fails with it.
#
# `staged` is always false here, because this reads fd_path and never path. The caller fails the check on
# a true, because that would mean this had been rewritten to stage onto scratch — reading a copy the worker
# owns, which tests nothing about the group.
module Examples
  class Reopen < HotCell::Operation
    operation "example.reopen"

    def perform(inputs, outputs)
      source, = inputs
      bytes = File.open(source.fd_path, "rb") { |file| outputs.first.to_io.write(file.read) }

      { bytes: bytes, staged: source.staged? }
    end
  end
end
