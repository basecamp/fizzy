# frozen_string_literal: true

# Copied from the hotcell repository's examples/operations/reopen.rb. The same round trip as echo, but
# re-opening both descriptors by name — `/dev/fd/N` on Linux, the file's own path on macOS — a fresh open,
# rechecked against the cell's uid, which is what every operation that hands a tool a filename does. A cell
# missing the shared group answers echo perfectly and fails only this. It re-opens in both directions
# because reading and writing are different permissions, and shipped operations do each.
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
