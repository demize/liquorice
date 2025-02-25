# liquorice.zig

A twitch client library for zig designed around webhooks.

## Requirements

During development, we're tracking `httpz` master, and thus also tracking `zig` master.

## Roadmap

Current tasks we're working on:

- [X] Handle client credentials grant flow for an app token on initialization
- [ ] Handle client-initiated authorization code grant flow for user tokens
      - This needs to handle both "a user token for the account the bot is running as" *and* "user tokens for channels the bot is operating in"
- [ ] Client-initiated validation of stored tokens
- [ ] Automatic refresh of tokens:
      - [ ] User tokens, through a callback into the client to update its token store
      - [ ] App tokens, fully autonomously (the client actually doesn't need the app's access token, it's used entirely by the library; it also doesn't need to be stored, since they're non-refreshable anyway)

Once the auth side is done:

- [ ] Join channels
- [ ] EventSub for new messages in each channel (callback to client)
- [ ] Send messages in specific channels (as a response or otherwise)
