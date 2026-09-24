use solverforge::prelude::*;
use solverforge::stream::collector::LoadBalance;
use solverforge::IncrementalConstraint;

use super::{Person, Task};

#[planning_solution(constraints = "define_constraints", solver_toml = "../../solver.toml")]
pub struct Plan {
    #[problem_fact_collection]
    pub people: Vec<Person>,

    #[planning_entity_collection]
    pub tasks: Vec<Task>,

    #[planning_score]
    pub score: Option<HardMediumSoftScore>,
}

fn define_constraints() -> impl ConstraintSet<Plan, HardMediumSoftScore> {
    (assigned_constraint(), pinned_constraint(), urgency_constraint(), count_constraint())
}

fn assigned_constraint() -> impl IncrementalConstraint<Plan, HardMediumSoftScore> {
    ConstraintFactory::<Plan, HardMediumSoftScore>::new()
        .for_each(Plan::tasks())
        .unassigned()
        .penalize(HardMediumSoftScore::ONE_HARD)
        .named("Every work unit has an assignee")
}

fn pinned_constraint() -> impl IncrementalConstraint<Plan, HardMediumSoftScore> {
    ConstraintFactory::<Plan, HardMediumSoftScore>::new()
        .for_each(Plan::tasks())
        .filter(|task: &Task| task.pinned_to.is_some() && task.person_idx != task.pinned_to)
        .penalize(HardMediumSoftScore::ONE_HARD)
        .named("Existing assignments stay pinned")
}

fn urgency_constraint() -> impl IncrementalConstraint<Plan, HardMediumSoftScore> {
    ConstraintFactory::<Plan, HardMediumSoftScore>::new()
        .for_each(Plan::tasks())
        .filter(|task: &Task| task.person_idx.is_some())
        .group_by(
            |_: &Task| 0usize,
            load_balance(|task: &Task| task.person_idx.unwrap_or(usize::MAX), |task: &Task| task.urgency_weight),
        )
        .penalize(|_: &usize, loads: &LoadBalance<usize>| HardMediumSoftScore::of_medium(loads.unfairness()))
        .named("Balance urgent work")
}

fn count_constraint() -> impl IncrementalConstraint<Plan, HardMediumSoftScore> {
    ConstraintFactory::<Plan, HardMediumSoftScore>::new()
        .for_each(Plan::tasks())
        .filter(|task: &Task| task.person_idx.is_some())
        .group_by(
            |_: &Task| 0usize,
            load_balance(|task: &Task| task.person_idx.unwrap_or(usize::MAX), |task: &Task| task.count_weight),
        )
        .penalize(|_: &usize, loads: &LoadBalance<usize>| HardMediumSoftScore::of_soft(loads.unfairness()))
        .named("Balance card count")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn plan() -> Plan {
        Plan {
            people: vec![Person { id: "a".into() }, Person { id: "b".into() }],
            tasks: vec![
                Task { id: "a".into(), card_id: Some("a".into()), urgency_weight: 8,
                    count_weight: 1, pinned_to: Some(0), allowed_people: vec![0], person_idx: Some(0) },
                Task { id: "b".into(), card_id: Some("b".into()), urgency_weight: 8,
                    count_weight: 1, pinned_to: None, allowed_people: vec![0, 1], person_idx: Some(1) },
                Task { id: "idle-a".into(), card_id: None, urgency_weight: 1,
                    count_weight: 1, pinned_to: Some(0), allowed_people: vec![0], person_idx: Some(0) },
                Task { id: "idle-b".into(), card_id: None, urgency_weight: 1,
                    count_weight: 1, pinned_to: Some(1), allowed_people: vec![1], person_idx: Some(1) },
            ],
            score: None,
        }
    }

    #[test]
    fn every_task_must_be_assigned() {
        let mut plan = plan();
        assert_eq!((assigned_constraint(),).evaluate_all(&plan), HardMediumSoftScore::ZERO);
        plan.tasks[1].person_idx = None;
        assert_eq!((assigned_constraint(),).evaluate_all(&plan), HardMediumSoftScore::of_hard(-1));
    }

    #[test]
    fn existing_assignments_cannot_move() {
        let mut plan = plan();
        assert_eq!((pinned_constraint(),).evaluate_all(&plan), HardMediumSoftScore::ZERO);
        plan.tasks[0].person_idx = Some(1);
        assert_eq!((pinned_constraint(),).evaluate_all(&plan), HardMediumSoftScore::of_hard(-1));
    }

    #[test]
    fn urgency_balance_precedes_card_count() {
        let mut plan = plan();
        assert_eq!((urgency_constraint(),).evaluate_all(&plan), HardMediumSoftScore::ZERO);
        plan.tasks[1].person_idx = Some(0);
        assert!((urgency_constraint(),).evaluate_all(&plan).medium() < 0);
        plan.tasks[1].person_idx = None;
        assert!((urgency_constraint(),).evaluate_all(&plan).medium() < 0);
    }

    #[test]
    fn card_count_breaks_urgency_ties() {
        let mut plan = plan();
        assert_eq!((count_constraint(),).evaluate_all(&plan), HardMediumSoftScore::ZERO);
        plan.tasks[1].person_idx = Some(0);
        assert!((count_constraint(),).evaluate_all(&plan).soft() < 0);
    }
}
