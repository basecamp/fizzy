use crate::domain::{PlannerRequest, PlannerResponse};
use std::error::Error;
use std::io::{Read, Write};

pub fn read_request<R: Read>(reader: R) -> Result<PlannerRequest, Box<dyn Error>> {
    Ok(serde_json::from_reader(reader)?)
}

pub fn write_response<W: Write>(
    mut writer: W,
    response: &PlannerResponse,
) -> Result<(), Box<dyn Error>> {
    serde_json::to_writer(&mut writer, response)?;
    writer.write_all(b"\n")?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{read_request, write_response};
    use crate::domain::{PlannerRequest, PlannerResponse, ProposedAssignment};

    #[test]
    fn request_response_json_round_trip_works() {
        let request_json = r#"{
          "board_id": "board-1",
          "time_limit_seconds": 30,
          "users": [
            { "id": "user-a", "name": "User A" }
          ],
          "work_units": [
            {
              "id": "card:1",
              "card_id": "card-1",
              "card_number": 1,
              "title": "Test card",
              "due_on": null,
              "golden": false,
              "stalled": false,
              "urgency_weight": 1,
              "assignee_id": null,
              "assignee_idx": null,
              "pinned": false
            }
          ]
        }"#;

        let request: PlannerRequest = read_request(request_json.as_bytes()).unwrap();
        assert_eq!("board-1", request.board_id);
        assert_eq!(1, request.users.len());
        assert_eq!(1, request.work_units.len());

        let response = PlannerResponse {
            status: "feasible".to_string(),
            score: "0hard/0medium/0soft".to_string(),
            elapsed_ms: 5,
            proposed_assignments: vec![ProposedAssignment {
                card_id: "card-1".to_string(),
                assignee_id: "user-a".to_string(),
            }],
        };

        let mut output = Vec::new();
        write_response(&mut output, &response).unwrap();

        let parsed: PlannerResponse = serde_json::from_slice(&output).unwrap();
        assert_eq!(response, parsed);
    }
}
