# frozen_string_literal: true

# Copied from the hotcell repository's examples/operations/echo.rb. /hotcellz calls it: one round trip
# through the caller's own descriptors proves SCM_RIGHTS passing end to end, and it is the only check
# there that touches the work socket.
module Examples
  class Echo < HotCell::Operation
    operation "example.echo"

    def perform(inputs, outputs)
      bytes = outputs.first.to_io.write(inputs.first.to_io.read)

      { bytes: bytes, staged: inputs.first.staged? }
    end
  end
end
