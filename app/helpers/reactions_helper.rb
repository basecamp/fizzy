module ReactionsHelper
  def reaction_path_prefix_for(reactable)
    case reactable
    when Card then [ reactable ]
    when Comment then [ reactable.card, reactable ]
    end
  end
end
