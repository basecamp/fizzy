json.partial! "cards/card", card: @card
json.steps @card.steps, partial: "cards/steps/step", as: :step
