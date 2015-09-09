# TODO/Ideas list
+ [ ] Incomplete item.
+ [x] Complete item.
+ [x] `version` Complete item and version it was included in.

Items with a question mark (?) on the end are ideas, and are not guaranteed to ever be done.

---

### v2.1.0
+ [x] Make sure NAMES handlers are stable (and don't hog memory if a `RPL_ENDOFNAMES` is never received? How to do this?). *Should be okay, incomplete messages can be cleaned up on disconnect*

+ [ ] Make MODE sender "better". It's not that great (as of 6c33fed43b8eb50a7b5dbaf0355644a3f276461e).
  + Have it take tables, not strings?


### General
+ [x] Move MODE sender and handler to `base` module.

+ [ ] Use `init.lua` package scheme?
+ [ ] Put utility functions in separate file?

#### Senders and handlers
+ [ ] WHO
+ [ ] WHOIS
