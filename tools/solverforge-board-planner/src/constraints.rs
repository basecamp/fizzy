use crate::domain::{PlannerRequest, PlannerResponse, ProposedAssignment, WorkUnit};
use std::cmp::Ordering;
use std::collections::HashMap;
use std::time::{Duration, Instant};

pub fn solve_request(request: &PlannerRequest) -> PlannerResponse {
    let started_at = Instant::now();
    let prepared = PreparedProblem::from_request(request);

    let response = if prepared.user_ids.is_empty() && !prepared.candidates.is_empty() {
        PlannerResponse {
            status: "infeasible".to_string(),
            score: "0hard/0medium/0soft".to_string(),
            elapsed_ms: 0,
            proposed_assignments: Vec::new(),
        }
    } else {
        let deadline = started_at + Duration::from_secs(request.time_limit_seconds.max(1));
        let plan = prepared.solve(deadline);
        let score = score_for(&plan.loads, &plan.counts);

        PlannerResponse {
            status: "feasible".to_string(),
            score: format!("0hard/-{}medium/-{}soft", score.medium, score.soft),
            elapsed_ms: 0,
            proposed_assignments: prepared
                .candidates
                .iter()
                .zip(plan.assignments.iter())
                .map(|(work_unit, assignee_idx)| ProposedAssignment {
                    card_id: work_unit.card_id.clone().unwrap_or_default(),
                    assignee_id: prepared.user_ids[*assignee_idx].clone(),
                })
                .collect(),
        }
    };

    PlannerResponse {
        elapsed_ms: started_at.elapsed().as_millis() as u64,
        ..response
    }
}

#[derive(Clone)]
struct PreparedProblem {
    user_ids: Vec<String>,
    candidates: Vec<WorkUnit>,
    base_loads: Vec<i64>,
    base_counts: Vec<i32>,
    beam_width: usize,
}

impl PreparedProblem {
    fn from_request(request: &PlannerRequest) -> Self {
        let user_ids = request
            .users
            .iter()
            .map(|user| user.id.clone())
            .collect::<Vec<_>>();
        let user_index = request
            .users
            .iter()
            .enumerate()
            .map(|(idx, user)| (user.id.as_str(), idx))
            .collect::<HashMap<_, _>>();

        let mut base_loads = vec![0_i64; user_ids.len()];
        let mut base_counts = vec![0_i32; user_ids.len()];
        let mut candidates = Vec::new();

        for work_unit in &request.work_units {
            if work_unit.pinned {
                let Some(assignee_id) = work_unit.assignee_id.as_deref() else {
                    continue;
                };
                let Some(&idx) = user_index.get(assignee_id) else {
                    continue;
                };

                base_loads[idx] += work_unit.urgency_weight;
                base_counts[idx] += 1;
            } else if work_unit.card_id.is_some() {
                candidates.push(work_unit.clone());
            }
        }

        candidates.sort_by(candidate_sort_key);

        Self {
            beam_width: beam_width_for(request.time_limit_seconds, user_ids.len()),
            user_ids,
            candidates,
            base_loads,
            base_counts,
        }
    }

    fn solve(&self, deadline: Instant) -> SearchState {
        let mut beam = vec![SearchState::new(
            self.base_loads.clone(),
            self.base_counts.clone(),
        )];
        let mut completed_through = 0;

        for (candidate_idx, work_unit) in self.candidates.iter().enumerate() {
            if Instant::now() >= deadline {
                break;
            }

            let mut expanded = Vec::with_capacity(beam.len().saturating_mul(self.user_ids.len()));

            for state in &beam {
                for user_idx in 0..self.user_ids.len() {
                    expanded.push(state.with_assignment(user_idx, work_unit.urgency_weight));
                }
            }

            expanded.sort_by(|left, right| compare_states(left, right));
            beam = deduplicate_states(expanded, self.beam_width);
            completed_through = candidate_idx + 1;
        }

        if completed_through < self.candidates.len() {
            beam = beam
                .into_iter()
                .map(|state| self.finish_greedily(state, completed_through))
                .collect();
        }

        let mut best = beam
            .into_iter()
            .min_by(|left, right| compare_states(left, right))
            .unwrap_or_else(|| SearchState::new(self.base_loads.clone(), self.base_counts.clone()));

        self.local_improve(&mut best, deadline);
        best
    }

    fn finish_greedily(&self, mut state: SearchState, start_idx: usize) -> SearchState {
        for work_unit in self.candidates.iter().skip(start_idx) {
            let mut best_user_idx = 0;
            let mut best_score = None;

            for user_idx in 0..self.user_ids.len() {
                let candidate = state.preview_assignment(user_idx, work_unit.urgency_weight);
                let key = candidate.sort_key();

                if best_score.as_ref().map_or(true, |score| key < *score) {
                    best_score = Some(key);
                    best_user_idx = user_idx;
                }
            }

            state = state.with_assignment(best_user_idx, work_unit.urgency_weight);
        }

        state
    }

    fn local_improve(&self, state: &mut SearchState, deadline: Instant) {
        loop {
            if Instant::now() >= deadline {
                break;
            }

            let mut best_move = None;
            let mut best_score = state.score();

            for (candidate_idx, work_unit) in self.candidates.iter().enumerate() {
                let current_user_idx = state.assignments[candidate_idx];

                for next_user_idx in 0..self.user_ids.len() {
                    if next_user_idx == current_user_idx {
                        continue;
                    }

                    let candidate_score = state.preview_reassignment(
                        candidate_idx,
                        current_user_idx,
                        next_user_idx,
                        work_unit.urgency_weight,
                    );

                    if candidate_score < best_score {
                        best_score = candidate_score;
                        best_move = Some((
                            candidate_idx,
                            current_user_idx,
                            next_user_idx,
                            work_unit.urgency_weight,
                        ));
                    }
                }
            }

            let Some((candidate_idx, current_user_idx, next_user_idx, weight)) = best_move else {
                break;
            };

            state.apply_reassignment(candidate_idx, current_user_idx, next_user_idx, weight);
        }
    }
}

#[derive(Clone, Debug)]
struct SearchState {
    loads: Vec<i64>,
    counts: Vec<i32>,
    assignments: Vec<usize>,
}

impl SearchState {
    fn new(loads: Vec<i64>, counts: Vec<i32>) -> Self {
        Self {
            loads,
            counts,
            assignments: Vec::new(),
        }
    }

    fn with_assignment(&self, user_idx: usize, weight: i64) -> Self {
        let mut next = self.clone();
        next.loads[user_idx] += weight;
        next.counts[user_idx] += 1;
        next.assignments.push(user_idx);
        next
    }

    fn preview_assignment(&self, user_idx: usize, weight: i64) -> Self {
        self.with_assignment(user_idx, weight)
    }

    fn preview_reassignment(
        &self,
        _candidate_idx: usize,
        current_user_idx: usize,
        next_user_idx: usize,
        weight: i64,
    ) -> Score {
        let mut loads = self.loads.clone();
        let mut counts = self.counts.clone();

        loads[current_user_idx] -= weight;
        counts[current_user_idx] -= 1;
        loads[next_user_idx] += weight;
        counts[next_user_idx] += 1;

        score_for(&loads, &counts)
    }

    fn apply_reassignment(
        &mut self,
        candidate_idx: usize,
        current_user_idx: usize,
        next_user_idx: usize,
        weight: i64,
    ) {
        self.loads[current_user_idx] -= weight;
        self.counts[current_user_idx] -= 1;
        self.loads[next_user_idx] += weight;
        self.counts[next_user_idx] += 1;
        self.assignments[candidate_idx] = next_user_idx;
    }

    fn score(&self) -> Score {
        score_for(&self.loads, &self.counts)
    }

    fn sort_key(&self) -> SortKey {
        let score = self.score();
        SortKey {
            medium: score.medium,
            soft: score.soft,
            max_load: *self.loads.iter().max().unwrap_or(&0),
            max_count: *self.counts.iter().max().unwrap_or(&0),
            loads: self.loads.clone(),
            counts: self.counts.clone(),
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Hash)]
struct StateSignature {
    loads: Vec<i64>,
    counts: Vec<i32>,
}

#[derive(Clone, Debug, Eq, Ord, PartialEq, PartialOrd)]
struct SortKey {
    medium: i64,
    soft: i64,
    max_load: i64,
    max_count: i32,
    loads: Vec<i64>,
    counts: Vec<i32>,
}

#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
struct Score {
    medium: i64,
    soft: i64,
}

fn compare_states(left: &SearchState, right: &SearchState) -> Ordering {
    left.sort_key().cmp(&right.sort_key())
}

fn deduplicate_states(states: Vec<SearchState>, beam_width: usize) -> Vec<SearchState> {
    let mut seen = HashMap::<StateSignature, SearchState>::new();

    for state in states {
        let signature = StateSignature {
            loads: state.loads.clone(),
            counts: state.counts.clone(),
        };

        seen.entry(signature).or_insert(state);
        if seen.len() >= beam_width {
            break;
        }
    }

    let mut unique = seen.into_values().collect::<Vec<_>>();
    unique.sort_by(|left, right| compare_states(left, right));
    unique.truncate(beam_width);
    unique
}

fn candidate_sort_key(left: &WorkUnit, right: &WorkUnit) -> Ordering {
    right
        .urgency_weight
        .cmp(&left.urgency_weight)
        .then_with(|| left.due_on.cmp(&right.due_on))
        .then_with(|| right.golden.cmp(&left.golden))
        .then_with(|| right.stalled.cmp(&left.stalled))
        .then_with(|| left.card_number.cmp(&right.card_number))
        .then_with(|| left.id.cmp(&right.id))
}

fn beam_width_for(time_limit_seconds: u64, user_count: usize) -> usize {
    let baseline = match time_limit_seconds {
        0..=5 => 256,
        6..=10 => 512,
        11..=30 => 2048,
        _ => 4096,
    };

    baseline.max(user_count.saturating_mul(64))
}

fn score_for(loads: &[i64], counts: &[i32]) -> Score {
    Score {
        medium: pairwise_distance(loads.iter().copied()),
        soft: pairwise_distance(counts.iter().map(|count| *count as i64)),
    }
}

fn pairwise_distance<I>(values: I) -> i64
where
    I: IntoIterator<Item = i64>,
{
    let values = values.into_iter().collect::<Vec<_>>();
    let mut distance = 0;

    for left_idx in 0..values.len() {
        for right_idx in (left_idx + 1)..values.len() {
            distance += (values[left_idx] - values[right_idx]).abs();
        }
    }

    distance
}

#[cfg(test)]
mod tests {
    use super::solve_request;
    use crate::domain::{PlannerRequest, PlannerResponse, PlannerUser, WorkUnit};

    #[test]
    fn pinned_work_units_never_move() {
        let response = solve_request(&PlannerRequest {
            board_id: "board-1".to_string(),
            time_limit_seconds: 1,
            users: vec![user("user-a"), user("user-b")],
            work_units: vec![pinned("pinned-1", "user-a", 8), candidate("card-1", 5)],
        });

        assert_eq!("feasible", response.status);
        assert_eq!(1, response.proposed_assignments.len());
        assert_eq!("card-1", response.proposed_assignments[0].card_id);
    }

    #[test]
    fn all_mutable_units_get_assigned() {
        let response = solve_request(&PlannerRequest {
            board_id: "board-1".to_string(),
            time_limit_seconds: 1,
            users: vec![user("user-a"), user("user-b")],
            work_units: vec![candidate("card-1", 5), candidate("card-2", 3)],
        });

        assert_eq!(2, response.proposed_assignments.len());
        assert_eq!(
            sort_card_ids(&response),
            vec!["card-1".to_string(), "card-2".to_string()]
        );
    }

    #[test]
    fn urgent_load_balance_is_preferred_over_raw_count_balance() {
        let response = solve_request(&PlannerRequest {
            board_id: "board-1".to_string(),
            time_limit_seconds: 1,
            users: vec![user("user-a"), user("user-b")],
            work_units: vec![
                pinned("pinned-urgent", "user-a", 8),
                pinned("pinned-low-1", "user-b", 1),
                pinned("pinned-low-2", "user-b", 1),
                pinned("pinned-low-3", "user-b", 1),
                candidate("urgent-card", 8),
            ],
        });

        assert_eq!(
            "user-b",
            response
                .proposed_assignments
                .iter()
                .find(|assignment| assignment.card_id == "urgent-card")
                .unwrap()
                .assignee_id
        );
    }

    #[test]
    fn card_count_balance_breaks_ties_when_urgent_load_is_equal() {
        let response = solve_request(&PlannerRequest {
            board_id: "board-1".to_string(),
            time_limit_seconds: 1,
            users: vec![user("user-a"), user("user-b")],
            work_units: vec![
                pinned("pinned-a-1", "user-a", 1),
                pinned("pinned-a-2", "user-a", 1),
                pinned("pinned-b-1", "user-b", 2),
                candidate("tie-card", 1),
            ],
        });

        assert_eq!(
            "user-b",
            response
                .proposed_assignments
                .iter()
                .find(|assignment| assignment.card_id == "tie-card")
                .unwrap()
                .assignee_id
        );
    }

    fn sort_card_ids(response: &PlannerResponse) -> Vec<String> {
        let mut ids = response
            .proposed_assignments
            .iter()
            .map(|assignment| assignment.card_id.clone())
            .collect::<Vec<_>>();
        ids.sort();
        ids
    }

    fn user(id: &str) -> PlannerUser {
        PlannerUser {
            id: id.to_string(),
            name: id.to_string(),
        }
    }

    fn candidate(card_id: &str, urgency_weight: i64) -> WorkUnit {
        WorkUnit {
            id: format!("card:{card_id}"),
            card_id: Some(card_id.to_string()),
            card_number: Some(1),
            title: Some(card_id.to_string()),
            due_on: None,
            golden: false,
            stalled: false,
            urgency_weight,
            assignee_id: None,
            assignee_idx: None,
            pinned: false,
        }
    }

    fn pinned(id: &str, assignee_id: &str, urgency_weight: i64) -> WorkUnit {
        WorkUnit {
            id: id.to_string(),
            card_id: None,
            card_number: None,
            title: None,
            due_on: None,
            golden: false,
            stalled: false,
            urgency_weight,
            assignee_id: Some(assignee_id.to_string()),
            assignee_idx: None,
            pinned: true,
        }
    }
}
