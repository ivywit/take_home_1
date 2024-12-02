# Example Event Generator

This service is focused on creating example events an EDR agent could use to validate an update to ensure the agent is functioning as expected. This tool was created as part of a test for an interview and should not be considered a finished product, as it has many limitations which will be outlined below.

## Running the service

To setup this service a version of ruby needs to be installed on the computer then from the project's root directory run the following

```
gem bundler
bundle config specific_platform true # This ensures the right version of ffi is installed for the project.
bundle install
```

This service is focused on a few flows an EDR agent might be watching and reporting on, such as:
- Starting a process on an executable file
- Creating, modifying, or deleting a file
- Connecting to a network endpoint and transmitting data

Events are logged in `/tmp/rc_take_home_logs/log.json`, these logs could be used to validate events being tracked by an EDR agent to ensure issues haven't developed.

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

## A breif description of how the service works
This program has several methods for generating events relating to files, network transmission, and process execution. Things were also setup to allow a user run a predefined set of tests when no inputs are given or to run a specific generation method independently with the ability to pass in relevent arguments. 


### Logging
To log these generated events they're stored in a json log file in the format outlined in the projects description. The service leverages the sys/proctable gem to fetch information about the active processes generating the events, along with ruby's Process module and Etc module for finding the username associated with an active process. This information is stored in the service class's state in order to simplify and centralize the logging of events. That said were I to build this again I would instead build out an event class that took in the variables to log as they're fetched in each method and then pass this event instance to the log method instead. One of the major issues I encountered with getting data to log was generating the timestamp for the event. I collected the timestamp immediately after the process was completed for each method, but in some rare cases there could be some divergence between the timestamp gathered in this service and what an EDR agent is referencing. I looked at using ctime or mtime from the file data for creating and modifying file events, but That wasn't possible with remove events so for consistency I fetched the timestamp for each event in the same way. If the service is run multiple times the log is appended, to reset the log a user would need to manually delete the existing log.

### File activity
Generating file activity was relatively straight forward, using ruby's existing File module to complete these operations. In the case of generating file create events I set the method up to check if the path chosen exists and if not to create the path to the generated file. This was to avoid potential errors when attempting to create a test file, though this could easily be updated if it was preferred that it errors when the path isn't present. With file modification and removal the service first checks if the file exists and outputs a message to the console if it doesn't. Permissions aren't checked on these files but could be were this service to be updated to handle errors of a user not having permission to alter a file they don't have access to.

### Data transmission
In this service data transmission is restricted to http based json endpoints. Were there more time allotted to building this service it could be fairly easily extended to allow for other types of network exchanges as well, such as http form data, ssh, ftp, or web sockets to name a few. Errors in the network connection aren't caught here but are raised to the console when they occur.

### Process execution
This method of the service looks at the path to an executable checks that the file exists and can be executed before executing the program. The optional `--args` flag and string can be included to pass arguments to the executable if desired.  A sample file exists in this repo and is used in the automated generation.

## Limitations of this software

First I'll mention that due to time constraints I only implemented a very basic error handling where if the happy path isn't met the program will ideally fail early and explain what was incorrect. There are many issues that will raise an error and stop execution. The method setting up a network connection and transmitting data only focused on http connections. Were there more time for this project I would have wanted to extended it to cover the multitude of possible connections from websockets, to ftp, to ssh connections to name a few.
