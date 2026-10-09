use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct PlannerRequest {
    pub board_id: String,
    pub time_limit_seconds: u64,
    pub users: Vec<PlannerUser>,
    pub work_units: Vec<WorkUnit>,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
pub struct PlannerUser {
    pub id: String,
    pub name: String,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
pub struct WorkUnit {
    pub id: String,
    pub card_id: Option<String>,
    pub card_number: Option<u64>,
    pub title: Option<String>,
    pub due_on: Option<String>,
    pub golden: bool,
    pub stalled: bool,
    pub urgency_weight: i64,
    pub assignee_id: Option<String>,
    pub assignee_idx: Option<usize>,
    pub pinned: bool,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
pub struct ProposedAssignment {
    pub card_id: String,
    pub assignee_id: String,
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Eq)]
pub struct PlannerResponse {
    pub status: String,
    pub score: String,
    pub elapsed_ms: u64,
    pub proposed_assignments: Vec<ProposedAssignment>,
}
