# TODO/Ideas list
+ [ ] Incomplete item.
+ [x] Complete item.
+ [x] `version` Complete item and version it was included in.

Items with a question mark (?) on the end are ideas, and are not guaranteed to ever be done.

---

### v2.1.0
+ [x] Make sure NAMES handlers are stable (and don't hog memory if a `RPL_ENDOFNAMES` is never received? How to do this?). *Should be okay, incomplete messages can be cleaned up on disconnect*

+ [x] Make MODE sender "better". It's not that great (as of 6c33fed43b8eb50a7b5dbaf0355644a3f276461e).
  + Have it take tables, not strings?
  + *Still probably needs work.*


### General
+ [x] `v2.1.0` Move MODE sender and handler to `base` module.

+ [x] `v3.0.0` Use `init.lua` package scheme?
+ [x] `v3.0.0` Put utility functions in separate file?

+ [x] `v4.0.0` Fix unloading modules in hooks breaking iteration. _Hopefully fixed._
+ [ ] Improve `MODE` sender.
+ [ ] Add a registry in the IRC object for module state.

#### Senders and handlers
List is from [RFC2812](http://tools.ietf.org/html/rfc2812)

+ [ ] PASS
+ [x] NICK
+ [x] USER
+ [ ] OPER
+ [x] MODE (user)
+ [ ] SERVICE
+ [x] QUIT
+ [ ] SQUIT

+ [x] JOIN
+ [x] PART
+ [x] MODE (channel)
+ [x] TOPIC
+ [ ] NAMES _Handler done._
+ [ ] LIST
+ [ ] INVITE
+ [ ] KICK

+ [x] PRIVMSG
+ [x] NOTICE

+ [ ] MOTD
+ [ ] LUSERS
+ [ ] VERSION
+ [ ] STATS
+ [ ] LINKS
+ [ ] TIME
+ [ ] CONNECT
+ [ ] TRACE
+ [ ] ADMIN
+ [ ] INFO

+ [ ] SERVLIST
+ [ ] SQUERY

+ [ ] WHO
+ [ ] WHOIS
+ [ ] WHOWAS

+ [ ] KILL
+ [x] PING
+ [x] PONG
+ [ ] ERROR

+ [ ] AWAY
+ [ ] REHASH
+ [ ] DIE
+ [ ] RESTART
+ [ ] SUMMON
+ [ ] USERS
+ [ ] OPERWALL
+ [ ] USERHOST
+ [ ] ISON
