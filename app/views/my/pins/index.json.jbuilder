json.array! @pins do |pin|
  json.partial! "cards/card", card: pin.card
end
