module RoadmapsHelper
  STATUS_CLASSES = {
    shipped: "txt-positive",
    in_flight: "font-weight-semibold",
    stalled: "txt-alert",
    not_now: "txt-subtle",
    planned: ""
  }.freeze

  def roadmap_status_label(status)
    status.to_s.humanize
  end

  def roadmap_status_class(status)
    STATUS_CLASSES.fetch(status)
  end
end
