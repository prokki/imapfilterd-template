# imapfilterd-template

This repository provides a script to set up one or multiple services for your custom
imapfilter configuration. The script provides two main functionalities:

1. The service could be installed multiple times as you have multiple configurations/mailboxes to manage.

1. The services could be installed as a daemon to start/stop automatically on boot.


## Perquisites

This script is tested with debian v10 (buster).

You need a running [imapfilter](https://github.com/lefcha/imapfilter) binary and a proper imapfilter configuration file.

The configuration file should contain an infinite statement call, i.e. possible by either
calling the `make_daemon` command

```lua
    become_daemon(300, filter)
```

or to loop the `idle` statement 

```lua
    while true do
        imap["Inbox"]:enter_idle()
        filter()
    end
```


## Usage

```bash
Usage: ./$(basename ${SCRIPT}) --config=PATH
       [--mail=ADDRESS] [--log-dir=PATH] [--log-mode=MODE] [--user=USER]
       [--autostart] [--verbose]

Installs an imapfilter daemon for the specified imapfilter config file.

-a, --autostart       [optional]
                      Installs the created daemon script in the related
                      runlevels 2, 3, 4 and 5. You are also able to install the
                      script manually later by your own.
                      (see command insserv)

-c, --config=PATH     [REQUIRED]
                      The lua configuration file used for imapfilter

-d, --log-dir=PATH    [optional, default=/var/log/imapfilter]
                      A directory to save the log files in. If not passed the
                      log files are saved in the default log directory.

-h, --help            Displays this help.

-l, --log-mode=MODE   [optional, default=3]
                      Sets the log mode of the imapfitler daemon:
                        0 = do not log anything
                        1 = log all output in a log file
                        2 = log errors in a separate error log file
                        3 = log all output AND all errors in the related files
                            (similar to log-mode 1 AND 2)

-m, --mail=ADDRESS    [optional]
                      A mail address to describe the daemon

-u, --user=USER       [optional, default=current user]
                      By default, the user which runs this command
                      is used to execute the daemon. To use a different user
                      specify the --user option.
                      Take care of permissions, if your are running multiple
                      imapfilter daemons!

-v, --verbose         [optional]
                      Runs the script in verbose mode.
                      Will print out each step of execution.

Examples:

1. Basic example:

   ./$(basename ${SCRIPT}) --config=/home/john_doe/.imapfilter/imapfilter.lua

2. Create the daemon for user john.doe with mail address john.doe@example.com.
   The daemon should not write any log files. Both statements are equivalent:

   ./$(basename ${SCRIPT}) \\
       --config=/home/john_doe/.imapfilter/imapfilter.lua \\
       --mail=john.doe@example.com \\
       --user=imapfilter
       --log-mode=0

   ./$(basename ${SCRIPT}) \\
       -c/home/john_doe/.imapfilter/imapfilter.lua \\
       -mjohn.doe@example.com -uimapfilter -l0

3. Create the daemon with a custom log directory and installs the daemon
   to start automatically at the end of the boot process as
   user "imapfilter":

   ./$(basename ${SCRIPT}) \\
       --config=/home/john_doe/.imapfilter/imapfilter.lua \\
       --log-dir=/home/john_doe/.imapfilter/logs \\
       --user=imapfilter \\
       --autostart

```

## Others

* [ ] [README.md](README.md): use sieve / sieve protocol! - sieve not supported: use imapfilter
* [ ] [README.md](README.md): describe options
* [ ] [README.md](README.md): how to start/stop the daemon
* [ ] [README.md](README.md): how to install/remove the daemon manually, https://wiki.debian.org/LSBInitScripts
* [ ] exit numbers: check/clean up + list in readme
* [ ] Better solution than to use md5checksum for daemon name?
* [ ] fix add >&2


https://wiki.debian.org/Daemon
https://superuser.com/questions/1062576/difference-between-su-c-and-runuser-l-c