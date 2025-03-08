const std = @import("std");
const zul = @import("zul");

pub const TokenType = enum {
    App,
    User,
};

pub const LiquoriceToken = union(TokenType) {
    App: AppToken,
    User: UserToken,
};

pub const AppToken = struct {
    clientId: []const u8,
    clientSecret: []const u8,
    accessToken: []u8,
    expiresAt: zul.DateTime,

    pub fn jsonStringify(self: *const AppToken, jws: anytype) !void {
        try jws.beginObject();
        try jws.objectField("accessToken");
        try jws.write(self.accessToken);
        try jws.objectField("expiresAt");
        try jws.write(self.expiresAt);
        try jws.endObject();
    }
};

pub const UserToken = struct {
    accessToken: []u8,
    refreshToken: []u8,
    scopes: [][]u8,
    expiresAt: zul.DateTime,

    pub fn jsonStringify(self: *const UserToken, jws: anytype) !void {
        try jws.beginObject();
        try jws.objectField("accessToken");
        try jws.write(self.accessToken);
        try jws.objectField("refreshToken");
        try jws.write(self.refreshToken);
        try jws.objectField("scopes");
        try jws.write(self.scopes);
        try jws.objectField("expiresIn");
        try jws.write(self.expiresAt);
        try jws.endObject();
    }
};
