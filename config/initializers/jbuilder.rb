# Jbuilder ships a dependency tracker but doesn't register it, so without this
# a cached JSON fragment's digest covers its own template and none of the
# partials it renders: editing cards/_card.json.jbuilder wouldn't expire the
# cached activities that embed a card.
ActiveSupport.on_load :action_view do
  require "jbuilder/jbuilder_dependency_tracker"
  ActionView::DependencyTracker.register_tracker :jbuilder, Jbuilder::DependencyTracker
end
