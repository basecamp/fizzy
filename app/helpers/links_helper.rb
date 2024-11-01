module LinksHelper
  def link_back_or_to(path, **, &)
    path = :back if request.referer.present?
    link_to path, **, &
  end
end
