module LinksHelper
  def link_back_or_to(path, **, &)
    path = :back if request.referer.present? && request.referer != request.path
    link_to path, **, &
  end
end
