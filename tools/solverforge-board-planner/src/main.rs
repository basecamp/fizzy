use std::process::ExitCode;

fn main() -> ExitCode {
    match solverforge_board_planner::run_cli(
        std::env::args().skip(1),
        std::io::stdin().lock(),
        std::io::stdout().lock(),
    ) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("{error}");
            ExitCode::FAILURE
        }
    }
}
