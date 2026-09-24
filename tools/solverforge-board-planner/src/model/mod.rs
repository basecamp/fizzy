solverforge::planning_model! {
    root = "src/model";

    mod person;
    mod plan;
    mod task;

    pub use person::Person;
    pub use plan::Plan;
    pub use task::Task;
}
