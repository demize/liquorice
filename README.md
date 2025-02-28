# liquorice.zig

A twitch client library for zig designed around webhooks.

## Why `liquorice`?

Because "twiz" is a terrible name for a library, but a good inspiration for a decent name for a library.

...you meant why *use* it? Well, uh,

## Disclaimer

I make no guarantees of safety or suitability here. The usual "this software is provided as-is, without warranty of any kind" applies.

This is, ultimately, an academic project. I'm planning on using it in production (and I'm developing a bot or two alongside this
library), but I am significantly using this project to learn Zig. I've been programming for a while in mostly Rust and Python, two very
different languages to Zig, so you should expect a lot of memory sanitization issues (I've been bitten by many during the development
process!) and non-idiomatic code. I'm not a software engineer and I'm new to the zig ecosystem, so you should also expect weird
solutions and unnecessary reimplementations. The scheduler system is the exemplar of all of this: I *could* have used ZUL's scheduler,
but I wasn't aware of it at the time, and I ended up taking a different (more complex) approach because, well, it was fun.

Suggestions and contributions are welcome, though please try to coordinate with me prior to working on a PR. This project is still in
the "push directly to main" stage of my development process, which often means large commits sprawling out across the codebase.

Once it's a bit more complete I'll have a proper CONTRIBUTING.md, I promise :)

## Requirements

During development, we're tracking `httpz` master, and thus also tracking `zig` master.

## Roadmap

Current tasks we're working on:

- [X] Handle client credentials grant flow for an app token on initialization
- [ ] Handle client-initiated authorization code grant flow for user tokens
      - This needs to handle both "a user token for the account the bot is running as" *and* "user tokens for channels the bot is
        operating in"
- [ ] Client-initiated validation of stored tokens
- [ ] Automatic refresh of tokens:
      - [ ] User tokens, through a callback into the client to update its token store
      - [ ] App tokens, fully autonomously (the client actually doesn't need the app's access token, it's used entirely by the library;
            it also doesn't need to be stored, since they're non-refreshable anyway--a "refresh" here means requesting an entirely new
            token)

Once the auth side is done:

- [ ] Join channels
- [ ] EventSub for new messages in each channel (callback to client)
- [ ] Send messages in specific channels (as a response or otherwise)
