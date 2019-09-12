# imapfilter

Debian/Ubuntu!

Tested on debian

## Install

How to use:
[`man imapfilter`](https://linux.die.net/man/1/imapfilter)

How to write rules:
[`man imapfilter_config`](https://linux.die.net/man/5/imapfilter_config)

## Server

Create /var/log/imapfilter/, permissions to running user

## Usage

```bash
imapfilter -v -c ~/.imapfilter/john_doe_example_com.lua -d ~/.imapfilter/debug.log -l ~/.imapfilter/john_doe_example_com.log
```



https://wiki.debian.org/LSBInitScripts


## Usage

Maske onloy sense when usig make_daemon or idle!

while true do
    imap["Inbox"]:enter_idle()
    filter()
end


exit numbers: check/clean up + list in readme