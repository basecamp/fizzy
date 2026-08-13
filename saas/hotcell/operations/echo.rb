# frozen_string_literal: true

# Copied from the hotcell repository's examples/operations/echo.rb, and it stays permanently. The message
# arrives through the caller's own input descriptor and leaves through the caller's own output descriptor,
# with no copy onto scratch — so one round-trip proves the SCM_RIGHTS descriptor passing end to end.
#
# It carries no library and runs no tool, so it costs the blast radius nothing. /hotcellz calls it, and it
# is the only check there that says anything about the work socket: describe and metrics both answer on the
# control socket, which a descriptor never crosses.
module Examples
  class Echo < HotCell::Operation
    operation "example.echo"

    def perform(inputs, outputs)
      bytes = outputs.first.to_io.write(inputs.first.to_io.read)

      { bytes: bytes, staged: inputs.first.staged? }
    end
  end
end
