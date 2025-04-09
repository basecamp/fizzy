module WorkflowsHelper
  def button_to_set_stage(card, stage)
    button_to card_stagings_path(card, stage_id: stage),
        method: :post, class: [ "btn full-width justify-start workflow-stage txt-uppercase", { "workflow-stage--current": stage == card.stage } ],
        form_class: "flex align-center gap-half",
        data: { turbo_frame: "_top" } do
      tag.span class: "overflow-ellipsis" do
        stage.name
      end
    end
  end
end
