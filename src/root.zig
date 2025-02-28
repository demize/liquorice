const std = @import("std");
const httpz = @import("httpz");
const auth = @import("auth.zig");
const schd = @import("scheduler.zig");
const zul = @import("zul");

pub const Config = struct {
    port: u16 = 8080,
    listenAddr: ?[]const u8,
    baseUrl: []const u8 = "http://localhost",
    clientId: []const u8,
    clientSecret: []const u8,
    /// The base URL for the Twitch ID service.
    /// You probably don't need to set this unless you're doing testing.
    idBase: []const u8 = "https://id.twitch.tv",
};

pub const LiquoriceClient = struct {
    _allocator: std.mem.Allocator,
    _lq: *InnerClient,
    _server: *httpz.Server(*InnerClient),
    _serverThread: std.Thread,
    _oauthTokenUrl: []u8,
    _schd: *schd.LiquoriceScheduler,

    /// Initialize a liquorice client.
    /// This won't start the client; see `LiquoriceClient.start()` for that.
    ///
    /// Will always request a new access token from Twitch for the given client ID/secret.
    pub fn init(allocator: std.mem.Allocator, config: Config) !*LiquoriceClient {
        // set up an HTTP client to get our tokens
        var client: *std.http.Client = try allocator.create(std.http.Client);
        client.* = .{ .allocator = allocator };
        try client.initDefaultProxies(allocator);

        // perform the twitch authentication
        const oauthTokenUrl = try std.fmt.allocPrint(allocator, "{s}/oauth2/token", .{config.idBase});
        const twitchOauthUri = try std.Uri.parse(oauthTokenUrl);
        const authBody = try std.fmt.allocPrint(allocator, "client_id={s}&client_secret={s}&grant_type=client_credentials", .{ config.clientId, config.clientSecret });
        defer allocator.free(authBody);
        var header_buffer: [2048]u8 = undefined;
        var authReq = try client.open(.POST, twitchOauthUri, .{ .headers = .{ .content_type = .{ .override = "application/x-www-form-urlencoded" } }, .server_header_buffer = &header_buffer });
        defer authReq.deinit();

        authReq.transfer_encoding = .{ .content_length = authBody.len };
        try authReq.send();
        try authReq.writeAll(authBody);
        try authReq.finish();
        try authReq.wait();

        const authRes = try authReq.reader().readAllAlloc(allocator, 256);
        defer allocator.free(authRes);
        const parsedRes = try std.json.parseFromSlice(struct { access_token: []const u8, expires_in: u32, token_type: []const u8 }, allocator, authRes, .{});
        defer parsedRes.deinit();

        const appToken: auth.AppToken = .{
            .clientId = config.clientId,
            .clientSecret = config.clientSecret,
            .accessToken = try allocator.dupe(u8, parsedRes.value.access_token),
            .expiresIn = parsedRes.value.expires_in,
            .obtained = zul.DateTime.now(),
        };

        // create our liquorice client
        var lq = try allocator.create(InnerClient);
        lq._rwlock = .{};
        lq._allocator = allocator;
        lq._client = client;
        lq.appToken = appToken;

        // set up the httpz server
        const server = try allocator.create(httpz.Server(*InnerClient));
        server.* = try httpz.Server(*InnerClient).init(allocator, .{
            .port = config.port,
            .address = config.listenAddr,
        }, lq);

        // set up the outer client
        var oc = try allocator.create(LiquoriceClient);
        oc._allocator = allocator;
        oc._server = server;
        oc._lq = lq;
        oc._oauthTokenUrl = oauthTokenUrl;

        // set up our routes, but don't start listening yet
        var router = try oc._server.router(.{});
        router.get("/callback", InnerClient.callback, .{});

        return oc;
    }

    pub fn update_token(_: *LiquoriceClient) u32 {
        std.debug.print("refresh\n", .{});
        return 1;
    }

    pub fn start(self: *LiquoriceClient) !void {
        self._schd = try schd.LiquoriceScheduler.init(self._allocator);
        try self._schd.start();
        try self._schd.register_app_token(self, update_token);
        self._serverThread = try self._server.listenInNewThread();
    }

    pub fn deinit(self: *LiquoriceClient) void {
        self._server.stop();
        self._serverThread.join();
        self._server.deinit();
        self._allocator.destroy(self._server);
        self._lq.deinit();
        self._allocator.free(self._oauthTokenUrl);
        self._schd.deinit();
        self._allocator.destroy(self);
    }
};

const InnerClient = struct {
    appToken: auth.AppToken,
    _allocator: std.mem.Allocator,
    _client: *std.http.Client,
    _rwlock: std.Thread.RwLock,

    pub fn deinit(self: *InnerClient) void {
        self._client.deinit();
        self._allocator.destroy(self._client);
        self._allocator.free(self.appToken.accessToken);
        self._allocator.destroy(self);
    }

    fn callback(handler: *InnerClient, _: *httpz.Request, res: *httpz.Response) !void {
        res.content_type = .JSON;
        const body_text =
            \\{{"status": "500", "message": "{s}"}}
        ;
        handler._rwlock.lockShared();
        defer handler._rwlock.unlockShared();
        try std.fmt.format(res.writer(), body_text, .{handler.appToken.accessToken});
    }
};
