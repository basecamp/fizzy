module ReactionsHelper
  def reaction_path_prefix_for(reactable)
    case reactable
    when Card then [ reactable ]
    when Comment then [ reactable.card, reactable ]
    else
      raise ArgumentError, "Unknown reactable type: #{reactable.class}"
    end
  end
end
