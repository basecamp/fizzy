# frozen_string_literal: true

# Copied from the hotcell repository's examples/operations/reopen.rb, and it stays permanently. The same
# round trip as echo, reading the input through its path rather than through the descriptor.
#
# `/dev/fd/N` is a fresh open, rechecked against the opening process's uid and the file's mode, so this
# succeeds only where the cell can open a file the app owns. Echo consumes the descriptor directly and
# never establishes that, which is why both exist: a cell missing the shared group answers echo perfectly
# and fails this with EACCES, and every operation that hands a tool a filename fails with it.
#
# `staged` is always false here, because this reads fd_path and never path. It is asserted as a canary
# rather than as the proof: if it ever comes back true, someone has rewritten this to stage onto scratch,
# the reopen is reading a copy the worker owns, and the check has stopped testing the group.
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
