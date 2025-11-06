create_tenant "Honcho"

david = find_or_create_user "David Heinemeier Hansson", "david@37signals.com"
jason = find_or_create_user "Jason Fried", "jason@37signals.com"
jz    = find_or_create_user "Jason Zimdars", "jz@37signals.com"
kevin = find_or_create_user "Kevin McConnell", "kevin@37signals.com"
jorge = find_or_create_user "Jorge Manrubia", "jorge@37signals.com"
mike  = find_or_create_user "Mike Dalessio", "mike@37signals.com"

login_as david

authors = [ david, jason, jz, kevin, jorge, mike ]

card_titles = [
  "Implement authentication",
  "Design landing page",
  "Set up database",
  "Create API endpoints",
  "Write unit tests",
  "Optimize performance",
  "Add user profiles",
  "Implement search",
  "Create admin panel",
  "Set up CI/CD"
]

boards = [
  "Project Launch",
  "Frontend Dev",
  "Backend Dev",
  "Design System",
  "Testing Suite"
]

time_range = (60 .. 30.days.in_minutes)

boards.each_with_index do |board_name, index|
  create_board(board_name, access_to: authors.sample(3)).tap do |board|
    card_titles.each do |title|
      travel(-rand(time_range).minutes) do
        card = create_card title,
                           description: "#{title} for #{board_name} phase #{index + 1}.",
                           board: board,
                           creator: authors.sample

        # Randomly assign to 1-2 authors
        travel rand(0..20).minutes
        card.toggle_assignment(authors.sample)

        if rand > 0.5
          travel rand(0..20).minutes
          card.toggle_assignment(authors.sample)
        end

        # Randomly set card state
        travel rand(0..20).minutes
        case rand(3)
        when 0
          if column = card.board&.columns&.sample
            card.triage_into(column)
          end
        when 1
          card.close
          # 2 remains open
        end
      end
    end
  end
end
