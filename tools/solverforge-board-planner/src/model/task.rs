use solverforge::prelude::*;

use super::Plan;

#[planning_entity]
pub struct Task {
    #[planning_id]
    pub id: String,
    pub card_id: Option<String>,
    pub urgency_weight: i64,
    pub count_weight: i64,
    pub pinned_to: Option<usize>,
    pub allowed_people: Vec<usize>,

    #[planning_variable(value_range_provider = "people", allows_unassigned = true, candidate_values = "people_for_task")]
    pub person_idx: Option<usize>,
}

pub(super) fn people_for_task(plan: &Plan, entity_index: usize, _variable_index: usize) -> &[usize] {
    &plan.tasks[entity_index].allowed_people
}
