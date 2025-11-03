class Collections::EntropiesController < ApplicationController
  include CollectionScoped

  def update
    @collection.entropy.update!(entropy_params)
  end

  private
    def entropy_params
      params.expect(collection: [ :auto_postpone_period ])
    end
end
