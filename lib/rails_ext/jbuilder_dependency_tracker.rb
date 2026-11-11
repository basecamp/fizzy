# Jbuilder doesn't register its dependency tracker, so cached JSON wouldn't
# expire when a partial it renders changes. Remove once rails/jbuilder#620 ships.
ActiveSupport.on_load :action_view do
  require "jbuilder/jbuilder_dependency_tracker"
  ActionView::DependencyTracker.register_tracker :jbuilder, Jbuilder::DependencyTracker
end
