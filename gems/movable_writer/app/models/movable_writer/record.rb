# frozen_string_literal: true

module MovableWriter
  class Record < ActiveRecord::Base
    self.abstract_class = true
  end
end
