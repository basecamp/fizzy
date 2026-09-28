class WidenActionPackPasskeysSignCountToBigint < ActiveRecord::Migration[8.2]
  # WebAuthn signature counters are unsigned 32-bit integers (max 4294967295),
  # but the column was created as a signed 4-byte INT (max 2147483647). A
  # spec-legal high counter from a genuine authenticator overflows the column
  # and raises ActiveModel::RangeError. Widen to bigint so the full uint32
  # range persists and the replay/clone check compares real values.
  def change
    change_column :action_pack_passkeys, :sign_count, :bigint, default: 0, null: false
  end
end
