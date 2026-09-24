pub mod constraints;
pub mod domain;
pub mod io;

use std::error::Error;
use std::io::{Read, Write};

pub fn run_cli<I, R, W>(args: I, reader: R, writer: W) -> Result<(), Box<dyn Error>>
where
    I: IntoIterator,
    I::Item: AsRef<str>,
    R: Read,
    W: Write,
{
    let mut args = args.into_iter();
    let Some(command) = args.next() else {
        return Err("missing command".into());
    };

    match command.as_ref() {
        "solve" => {
            let request = io::read_request(reader)?;
            let response = constraints::solve_request(&request);
            io::write_response(writer, &response)?;
            Ok(())
        }
        other => Err(format!("unsupported command: {other}").into()),
    }
}
