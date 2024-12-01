# Example Event Generator

This service is focused on creating example events an EDR agent could use to validate an update to ensure the agent is functioning as expected. This tool was created as part of a test for an interview and should not be considered a finished product, as it has many limitations which will be outlined below.

## Running the service

To setup this service a version of ruby needs to be installed on the computer then from the project's root directory run the following

```
$ bundle config specific_platform true # This ensures the right version of ffi is installed for the project.
$ bundle install
```

This service is focused on a few flows an EDR agent might be watching and reporting on, such as:
- Starting a process on an executable file
- Creating, modifying, or deleting a file
- Connecting to a network endpoint and transmitting data

Events are logged in `/tmp/rc_take_home_logs/log.json`

The service can either be run with explicit inputs to run a specific tests or without inputs to run a preprogrammed set of events. Example commands:

```
./service.rb
./service.rb create_file /tmp/rc_take_home/test.jpg
./service.rb modify_file /tmp/rc_take_home/test.jpg
./service.rb remove_file /tmp/rc_take_home/test.jpg
./service.rb transmit_data http://example.com --http-method post --data '{"name": "book", "amount": "$35"}'
./service.rb start_process ./sample_files/executable
./service.rb start_process /opt/homebrew/bin/brew --args "update"
```

## Limitations of this software

First I'll mention that due to time constraints I only implemented a very basic error handling where if the happy path isn't met the program will ideally fail early and explain what was incorrect. There are many issues that will raise an error and stop execution. The method setting up a network connection and transmitting data only focused on http connections. Were there more time for this project I would have wanted to extended it to cover the multitude of possible connections from websockets, to ftp, to ssh connections to name a few.
