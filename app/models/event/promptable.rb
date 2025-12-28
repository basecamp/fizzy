# rbs_inline: enabled

module Event::Promptable
  extend ActiveSupport::Concern

  def to_prompt
    # @type self: Event & Event::Promptable
    <<~PROMPT
        BEGIN OF EVENT #{id}
        ## Event #{action} (#{eventable_type} #{eventable_id}))

        * Created at: #{created_at}
        * Created by: #{creator.name}

        #{eventable.to_prompt}
        END OF EVENT #{id}
      PROMPT
  end
end
