---
layout: post
title: "Lua IRC Engine"
---

I maintain a Lua module named Lua IRC Engine, also known as `irc-engine`, or IRCe for short. I describe it as "A Lua IRC module that tries to be minimal and extensible." ([GitHub repo](https://github.com/mirrexagon/lua-irc-engine), [LuaRocks](https://luarocks.org/modules/mirrexagon/irc-engine))

It's my first ever versioned piece of software, and the first that is actually used by more than three people. In this post, I'll talk about its history, some of the things I did badly, and things I've learnt from it (mainly about versioning).


# History
Years ago, when I was still new to programming, I wanted to try writing an IRC bot from scratch in Lua, the language I was most comfortable in. And so, I did just that.

It was honestly pretty bad - my code style was extremely messy and stuff was hardcoded all over the place. But it worked, and I learned a lot from doing it - about programming, Lua, and IRC.

I rewrote that one IRC bot at least three times, improving its code and architecture each time. Eventually I got to the point where I could easily split out the IRC code from the bot. So that's what I did.

After all this iterating, rewriting and learning, I eventually created Lua IRC Engine. From all that experience, I wrote its README first; it ended up detailing how the entire API was going to work, before I even wrote a single line of code. For the most part, the module has stuck to the original design.

I was pretty proud of it. It's minimal, flexible and very extensible, making it easy to add support for new IRC protocol commands.


# Issues and lessons learnt
The most obvious thing you might notice if you went to use the module, is the version number. As of writing, it is `v5.1.0`. Seems a bit high, doesn't it?

I tried to follow [Semantic Versioning](http://semver.org/) with this project. The problem was, I released `v1.0.0` far too early. I though I was happy with the API; the method names and what they did was good. However, I later found that I was not happy with some details of the behaviour of the module, one in particular.

To explain it, I have to explain a bit about how `irc-engine` works, specifically how it processes messages it receives.

---

After `irc-engine` parses a raw IRC message, it looks for a function to process it. There are two kinds of these:

- **Handlers**, which are internal;
- **Callbacks**, which are defined by the user of the module.

**Handlers** take in the raw parts of an IRC message, and do some processing. A **handler** can do some processing and *maybe* return some data, which is passed to the corresponding **callback**.

The problem is this: when do you call the callback, and when don't you? Should you always call the callback, even when there is no handler, or when the handler doesn't return anything?

The behaviour I eventually went with is specified in the README:

>Whether a callback is actually called depends on whether a handler exists for the command, and whether it returns anything.
>
>A callback will be called if:
>
>- a handler exists and it returns something, or;
>- if a handler does not exist for the command, in which case the callback gets the sender and the command parameters as arguments.
>
>If a handler exists but doesn't return anything, the callback isn't called.
>
>This behaviour allows for handlers which sometimes pass processing on to another handler; eg. when a CTCP ACTION is received, the CTCP handler passes processing over to ACTION. This way, the ACTION callback is called instead of the CTCP callback. If the callback were always called (as they were in versions 2.1.0 to 5.0.0), the CTCP handler would be called regardless. NOTICE and PRIVMSG also work this way, passing over to CTCP when they detect a CTCP message.

And it only took until `v5.0.0` to decide on it!

The main thing I learnt from this is that there's a major version zero (`0.x.y`) for a reason - to get everything how you want it, including all the subtle details about how your API works. Even though I thought I had planned the module well, little details still came up once I actually implemented it, and I didn't handle those very well.


# Conclusion
The big issue now is that I don't actually use IRC Engine myself right now, and I haven't for most of its existence. (Plus, I recently started learning and playing around with [Rust](https://www.rust-lang.org), and I have to say, it's pretty awesome! I kinda want to write an IRC bot in Rust instead.)

I kind of wish I could start again with what I've learned, especially making good use of major version zero to really make sure I'm happy with everything (and not break SemVer, as I've done a few times).

I don't work on it much anymore. I'll probably keep working on it when I feel like it, but that may not be very often. If you want to take it, work on it and release your own version, feel free!