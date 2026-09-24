use crate::domain::{PlannerRequest, PlannerResponse, ProposedAssignment};
use crate::model::{Person, Plan, Task};
use solverforge::{SolverEvent, SolverManager};
use std::collections::HashMap;
use std::error::Error;
use std::time::{Duration, Instant};

static MANAGER: SolverManager<Plan> = SolverManager::new();

pub fn solve_request(request: &PlannerRequest) -> Result<PlannerResponse, Box<dyn Error>> {
    let started = Instant::now();
    let plan = prepare(request)?;

    if plan.people.is_empty() && !plan.tasks.is_empty() {
        return Ok(response(
            "infeasible",
            "0hard/0medium/0soft",
            started,
            vec![],
        ));
    }

    let (job_id, mut events) = MANAGER.solve(plan)?;
    let deadline = started + Duration::from_secs(request.time_limit_seconds.max(1));
    let mut best = None;
    let mut cancelling = false;

    let result = loop {
        match events.try_recv() {
            Ok(SolverEvent::BestSolution { solution, .. }) => best = Some(solution),
            Ok(SolverEvent::Completed { solution, .. }) => break Some(solution),
            Ok(SolverEvent::Cancelled { .. }) => break best,
            Ok(SolverEvent::Failed { error, .. }) => {
                MANAGER.delete(job_id)?;
                return Err(error.into());
            }
            Ok(_) => {}
            Err(_) if events.is_closed() => {
                return Err("Solver stopped without a terminal event".into());
            }
            Err(_) => {
                if Instant::now() >= deadline && !cancelling && MANAGER.cancel(job_id).is_ok() {
                    cancelling = true;
                }
                std::thread::sleep(Duration::from_millis(10));
            }
        }
    };
    MANAGER.delete(job_id)?;

    if let Some(plan) = result {
        let score = plan.score.ok_or("Solver completed without a score")?;
        if score.hard() < 0 || plan.tasks.iter().any(|task| task.person_idx.is_none()) {
            Ok(response("infeasible", &score.to_string(), started, vec![]))
        } else {
            let assignments = plan
                .tasks
                .iter()
                .filter_map(|task| {
                    task.card_id
                        .as_ref()
                        .filter(|_| task.pinned_to.is_none())
                        .map(|card_id| ProposedAssignment {
                            card_id: card_id.clone(),
                            assignee_id: plan.people
                                [task.person_idx.expect("hard-feasible assignment")]
                            .id
                            .clone(),
                        })
                })
                .collect();
            Ok(response(
                "feasible",
                &score.to_string(),
                started,
                assignments,
            ))
        }
    } else {
        Ok(response(
            "infeasible",
            "0hard/0medium/0soft",
            started,
            vec![],
        ))
    }
}

fn prepare(request: &PlannerRequest) -> Result<Plan, Box<dyn Error>> {
    let people = request
        .users
        .iter()
        .map(|user| Person {
            id: user.id.clone(),
        })
        .collect::<Vec<_>>();
    let positions = people
        .iter()
        .enumerate()
        .map(|(idx, person)| (person.id.as_str(), idx))
        .collect::<HashMap<_, _>>();
    if positions.len() != people.len() {
        return Err("Duplicate board users".into());
    }

    let all_people = (0..people.len()).collect::<Vec<_>>();
    let mut tasks = Vec::with_capacity(request.work_units.len() + people.len());
    for unit in &request.work_units {
        let pinned_to = if unit.pinned {
            let id = unit
                .assignee_id
                .as_deref()
                .ok_or("Pinned work has no assignee")?;
            Some(
                *positions
                    .get(id)
                    .ok_or("Pinned assignee is not a board user")?,
            )
        } else {
            None
        };
        if unit.urgency_weight < 0 {
            return Err("Urgency weight must be nonnegative".into());
        }
        if !unit.pinned && unit.card_id.is_none() {
            return Err("Unassigned work has no card".into());
        }
        tasks.push(Task {
            id: unit.id.clone(),
            card_id: unit.card_id.clone(),
            urgency_weight: unit.urgency_weight,
            count_weight: 1,
            pinned_to,
            allowed_people: pinned_to.map_or_else(|| all_people.clone(), |idx| vec![idx]),
            person_idx: pinned_to,
        });
    }

    // The collector ignores zero metrics. One equal offset per person keeps idle
    // members in both balances without changing their relative differences.
    for (idx, person) in people.iter().enumerate() {
        tasks.push(Task {
            id: format!("baseline:{}", person.id),
            card_id: None,
            urgency_weight: 1,
            count_weight: 1,
            pinned_to: Some(idx),
            allowed_people: vec![idx],
            person_idx: Some(idx),
        });
    }

    Ok(Plan {
        people,
        tasks,
        score: None,
    })
}

fn response(
    status: &str,
    score: &str,
    started: Instant,
    proposed_assignments: Vec<ProposedAssignment>,
) -> PlannerResponse {
    PlannerResponse {
        status: status.to_owned(),
        score: score.to_owned(),
        elapsed_ms: started.elapsed().as_millis() as u64,
        proposed_assignments,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{PlannerUser, WorkUnit};

    fn user(id: &str) -> PlannerUser {
        PlannerUser {
            id: id.to_owned(),
            name: id.to_owned(),
        }
    }

    fn unit(id: &str, weight: i64, pinned_to: Option<&str>) -> WorkUnit {
        WorkUnit {
            id: id.to_owned(),
            card_id: Some(id.to_owned()),
            card_number: Some(1),
            title: Some(id.to_owned()),
            due_on: None,
            golden: false,
            stalled: false,
            urgency_weight: weight,
            assignee_id: pinned_to.map(str::to_owned),
            assignee_idx: None,
            pinned: pinned_to.is_some(),
        }
    }

    #[test]
    fn solver_keeps_existing_work_and_balances_urgent_cards_first() {
        let result = solve_request(&PlannerRequest {
            board_id: "board-1".to_owned(),
            time_limit_seconds: 1,
            users: vec![user("a"), user("b")],
            work_units: vec![unit("pinned", 8, Some("a")), unit("urgent", 8, None)],
        })
        .unwrap();

        assert_eq!(result.status, "feasible");
        assert_eq!(
            result.proposed_assignments,
            vec![ProposedAssignment {
                card_id: "urgent".to_owned(),
                assignee_id: "b".to_owned(),
            }]
        );
        assert!(result.score.starts_with("0hard/"), "{}", result.score);
    }

    #[test]
    fn solver_uses_card_count_to_break_equal_urgency_load() {
        let result = solve_request(&PlannerRequest {
            board_id: "board-1".to_owned(),
            time_limit_seconds: 1,
            users: vec![user("a"), user("b")],
            work_units: vec![
                unit("a1", 1, Some("a")),
                unit("a2", 1, Some("a")),
                unit("b1", 2, Some("b")),
                unit("next", 1, None),
            ],
        })
        .unwrap();

        assert_eq!(result.status, "feasible");
        assert_eq!(result.proposed_assignments[0].assignee_id, "b");
    }

    #[test]
    fn candidates_without_people_are_infeasible() {
        let result = solve_request(&PlannerRequest {
            board_id: "board-1".to_owned(),
            time_limit_seconds: 1,
            users: vec![],
            work_units: vec![unit("orphan", 1, None)],
        })
        .unwrap();

        assert_eq!(result.status, "infeasible");
        assert!(result.proposed_assignments.is_empty());
    }
}
