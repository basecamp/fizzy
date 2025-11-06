create_tenant "37signals"

david = find_or_create_user "David Heinemeier Hansson", "david@37signals.com"
jason = find_or_create_user "Jason Fried", "jason@37signals.com"
jz    = find_or_create_user "Jason Zimdars", "jz@37signals.com"
kevin = find_or_create_user "Kevin Mcconnell", "kevin@37signals.com"

login_as david

create_board("Fizzy", access_to: [ jason, jz, kevin ]).tap do |fizzy|
  create_card("Prepare sign-up page", description: "We need to do this before the launch.", board: fizzy)

  create_card("Prepare sign-up page", description: "We need to do this before the launch.", board: fizzy).tap do |card|
    card.toggle_assignment(kevin)
    if column = card.board&.columns&.sample
      card.triage_into(column)
    end
  end

  create_card("Plain text mentions", description: "We'll support plain text mentions first.", board: fizzy).tap do |card|
    card.toggle_assignment(david)
    card.close
  end
end
