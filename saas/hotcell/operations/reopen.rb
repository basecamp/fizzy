# frozen_string_literal: true

# Copied from the hotcell repository's examples/operations/reopen.rb, and it stays permanently. The same
# round trip as echo, through both paths instead of both descriptors.
#
# `/dev/fd/N` is a fresh open, rechecked against the opening process's uid and the file's mode, so this
# succeeds only where the cell can open files the app owns by name. Echo consumes the descriptors directly
# and never establishes that, which is why both exist: a cell missing the shared group answers echo
# perfectly and fails this with EACCES, and every operation that hands a tool a filename fails with it.
#
# Both directions, because they are different permissions and a tool may need either: an input is readable
# by the group and an output is writable by it, and one shipped operation re-opens each — the ffmpeg
# previewer writes its destination by name. Reading alone passed on a cell whose outputs the group could
# not write, where every video preview failed on the write.
#
# `staged` is always false here, because this reads and writes fd_path and never path. The caller fails
# the check on a true, because that would mean this had been rewritten to stage onto scratch — reading or
# writing a copy the worker owns, which tests nothing about the group.
module Examples
  class Reopen < HotCell::Operation
    operation "example.reopen"

    def perform(inputs, outputs)
      source, = inputs
      destination, = outputs

      bytes = File.open(source.fd_path, "rb") do |input|
        File.open(destination.fd_path, "wb") { |output| output.write(input.read) }
      end

      { bytes: bytes, staged: source.staged? || destination.staged? }
    end
  end
end
