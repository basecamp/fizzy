module Bubble::Colored
  extend ActiveSupport::Concern

  COLORS = %w[ #b7462b #ff63a8 #eb7a32 #6ac967 #2c6da8 #663251  ]

  included do
    attribute :color, default: "#2c6da8"
  end
end
